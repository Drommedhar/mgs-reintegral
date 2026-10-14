"""Read localization references without executing or rewriting GCL/radio logic.

Layouts follow the recovered libgcl parser and menu/radiomes interpreter.
"""

from dataclasses import dataclass, field, replace


@dataclass(frozen=True)
class Node:
    code: int
    value: bytes = b""
    children: tuple = ()
    offset: int = field(default=-1, compare=False)

    def shape(self):
        value = b"" if self.code in (7, 10, 0x102, 0x101) else self.value
        if self.code & 0xF0 == 0x10:
            value = b""
        return self.code, value, tuple(child.shape() for child in self.children)

    def walk(self, code):
        if self.code == code:
            yield self
        for child in self.children:
            yield from child.walk(code)


class Reader:
    def __init__(self, data, offset=0, end=None, origin=0):
        self.data = data
        self.origin = origin
        self.pos = offset
        self.end = len(data) if end is None else end
        if not 0 <= offset <= self.end <= len(data):
            raise ValueError("Script extent exceeds its resource")

    def take(self, size):
        if size < 0 or self.pos + size > self.end:
            raise ValueError("Truncated script token")
        result = self.data[self.pos : self.pos + size]
        self.pos += size
        return result

    def number(self, size):
        return int.from_bytes(self.take(size), "big")

    def block(self, size):
        origin = self.origin + self.pos
        return Reader(self.take(size), origin=origin)

    def sequence(self, radio=False, depth=0):
        result = []
        while self.pos < self.end:
            result.append(self.radio(depth + 1) if radio else self.gcl(depth + 1))
        return tuple(result)

    def gcl(self, depth=0):
        offset = self.origin + self.pos
        return replace(self.gcl_node(depth), offset=offset)

    def gcl_node(self, depth):
        if depth > 64:
            raise ValueError("Script nesting exceeds 64 levels")
        code = self.number(1)
        widths = {
            0: 0,
            1: 2,
            2: 1,
            3: 1,
            4: 1,
            6: 2,
            8: 2,
            9: 4,
            10: 4,
            0x20: 1,
            0x31: 1,
        }
        if code in widths or code & 0xF0 == 0x10:
            return Node(code, self.take(3 if code & 0xF0 == 0x10 else widths[code]))
        if code == 7:
            value = self.take(self.number(1))
            if not value or value[-1] or b"\0" in value[:-1]:
                raise ValueError("Invalid GCL string")
            return Node(code, value[:-1])
        if code == 0x50:
            letter = self.take(1)
            self.take(1)  # Some original options have an inaccurate size field.
            children = []
            while self.pos < self.end and self.data[self.pos] not in (0, 0x50):
                children.append(self.gcl(depth + 1))
            return Node(code, letter, tuple(children))
        if code not in (0x30, 0x40, 0x60, 0x70):
            raise ValueError(f"Unsupported GCL token {code:#x}")
        width = 2 if code in (0x40, 0x60) else 1
        body = self.block(self.number(width) - width)
        value = body.take(2) if code in (0x60, 0x70) else b""
        if code == 0x60:
            body.take(1)
        return Node(code, value, body.sequence(depth=depth))

    def radio(self, depth=0):
        if depth > 64:
            raise ValueError("Radio nesting exceeds 64 levels")
        code = self.number(1)
        if code in (0, 0xFF):
            return Node(0x100 + code)
        body = self.block(self.number(2) - 2)
        if code == 1:
            speaker = body.take(6)
            text = body.take(body.end - body.pos)
            if not text or text[-1] or b"\0" in text[:-1]:
                raise ValueError("Invalid radio text")
            return Node(0x101, text[:-1], (Node(0x103, speaker),))
        if code == 2:
            return Node(0x102, body.take(4), body.sequence(True, depth))
        if code == 0x80:
            return Node(0x180, children=body.sequence(True, depth))
        if code in (5, 7, 8, 0x40):
            return Node(0x100 + code, children=body.sequence(depth=depth))
        if code == 0x10:
            children = [body.gcl(depth + 1), body.radio(depth + 1)]
            while body.pos < body.end:
                branch = body.data[body.pos]
                if branch in (0x11, 0x12):
                    body.take(1)
                    children.append(Node(0x100 + branch))
                    if branch == 0x12:
                        children.append(body.gcl(depth + 1))
                else:
                    children.append(body.radio(depth + 1))
            return Node(0x110, children=tuple(children))
        if code == 0x30:
            value = body.take(2)
            children = []
            while body.pos < body.end:
                branch = body.number(1)
                if branch == 0:
                    break
                if branch != 0x31:
                    raise ValueError("Invalid radio random branch")
                children.append(Node(0x131, body.take(2), (body.radio(depth + 1),)))
            return Node(0x130, value, tuple(children))
        if code == 4:
            return Node(
                0x104,
                body.take(2),
                (Node(7, body.take(body.end - body.pos).rstrip(b"\0")),),
            )
        if code not in (3, 6):
            raise ValueError(f"Unsupported radio token {code:#x}")
        return Node(0x100 + code, body.take(body.end))


def procedures(data):
    reader = Reader(data)
    entries = []
    while True:
        identity, offset = reader.number(2), reader.number(2)
        if identity == offset == 0:
            break
        entries.append((identity, offset))
    result = {}
    for identity, offset in entries:
        position = offset + (8 if identity == 0 else reader.pos)
        result[identity] = Reader(data, position).gcl()
    return result


def dialogue(data, offset):
    reader = Reader(data, offset)
    header = reader.take(8)
    node = reader.radio()
    if node.code != 0x180:
        raise ValueError("Radio reference does not point to a dialogue")
    return header[:2], node


def integral_radio_offset(code):
    return ((code & 0xFFFF) + (code >> 24)) * 2048


def matched_commands(first, second):
    for identity in sorted(first.keys() & second.keys()):
        if first[identity].shape() == second[identity].shape():
            for left, right in zip(
                first[identity].walk(0x60), second[identity].walk(0x60)
            ):
                yield identity, left, right
            continue
        groups = []
        for procedure in (first[identity], second[identity]):
            commands = {}
            for command in procedure.walk(0x60):
                commands.setdefault(command.shape(), []).append(command)
            groups.append(commands)
        for shape in groups[0].keys() & groups[1].keys():
            left, right = groups[0][shape], groups[1][shape]
            if len(left) == len(right) == 1:
                yield identity, left[0], right[0]
