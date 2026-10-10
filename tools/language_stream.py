"""Framed speech streams; retain Integral animation and command packets."""

import struct
from dataclasses import dataclass

from language_assets import regional_text


@dataclass(frozen=True)
class Packet:
    kind: int
    data: bytes

    def encode(self):
        size = (len(self.data) + 7) & ~3
        return struct.pack("<I", size << 8 | self.kind) + self.data.ljust(
            size - 4, b"\0"
        )


def streams(data):
    result = {}
    offset = 0
    while offset < len(data):
        start = offset
        packets = []
        while offset + 4 <= len(data):
            header = struct.unpack_from("<I", data, offset)[0]
            kind, size = header & 255, header >> 8
            if kind == 0xF0:
                offset = (offset + 4 + 2047) & ~2047
                break
            if (
                kind not in (1, 2, 3, 4, 5, 6, 7, 16)
                or size < 4
                or size % 4
                or offset + size > len(data)
            ):
                raise ValueError(f"Invalid stream packet at {offset:#x}")
            packets.append(Packet(kind, data[offset + 4 : offset + size]))
            offset += size
        else:
            raise ValueError("Unterminated stream")
        result[start // 2048] = packets
    return result


def captions(payload):
    if len(payload) < 16:
        raise ValueError("Truncated caption header")
    _, _, mouth, text, font = struct.unpack_from("<IIHHI", payload)
    if not 16 <= mouth <= text <= font <= len(payload):
        raise ValueError("Invalid caption offsets")
    result = []
    offset = text
    while offset + 16 <= font:
        size, start, duration, flags = struct.unpack_from("<4I", payload, offset)
        if size == start == duration == 0:
            break
        end = font if size == 0 else offset + size
        if end <= offset + 16 or end > font or size % 4:
            raise ValueError("Invalid caption entry")
        zero = payload.find(b"\0", offset + 16, end)
        if zero < 0:
            raise ValueError("Unterminated caption")
        result.append((start, duration, flags, payload[offset + 16 : zero]))
        if not size:
            break
        offset += size
    return mouth, text, font, result


def convert_captions(payload, language):
    _, text, font, lines = captions(payload)
    output = bytearray(payload[:text])
    for index, (start, duration, flags, string) in enumerate(lines):
        string = regional_text(string, language) + b"\0"
        size = (16 + len(string) + 3) & ~3
        output.extend(
            struct.pack(
                "<4I", size if index + 1 < len(lines) else 0, start, duration, flags
            )
        )
        output.extend(string.ljust(size - 16, b"\0"))
    if not lines:
        output.extend(bytes(16))
    struct.pack_into("<I", output, 12, len(output))
    output.extend(payload[font:])
    if len(output) > 4084:
        raise ValueError("Localized caption exceeds the game's subtitle buffer")
    return bytes(output)


def caption_strings(packets, channel):
    return [
        line[3]
        for packet in packets
        if packet.kind == channel
        for line in captions(packet.data)[3]
    ]


def localized_packet(packet, language):
    if packet.kind == 3:
        return Packet(6, convert_captions(packet.data, language))
    if packet.kind == 4:
        return Packet(7, packet.data)
    if packet.kind == 16 and packet.data[0] == 3:
        return Packet(16, bytes([6]) + packet.data[1:])
    return packet


def encode_stream(packets):
    data = b"".join(packet.encode() for packet in packets) + b"\xf0\0\0\0"
    return data.ljust((len(data) + 2047) & ~2047, b"\0")


def localize_voice(packets, language):
    if any(packet.kind in (5, 6, 7) for packet in packets):
        raise ValueError("Unexpected animation or bilingual channel in donor voice")
    return encode_stream([localized_packet(packet, language) for packet in packets])


def merge_demo(base, donor, language):
    base_audio = [p for p in base if p.kind == 1]
    donor_audio = [p for p in donor if p.kind == 1]
    if len(base_audio) != len(donor_audio) or any(
        len(a.data) != len(b.data) for a, b in zip(base_audio, donor_audio)
    ):
        raise ValueError("Cinematic audio duration differs; keep Integral")
    # Donor presentation is inserted at its authored audio-packet boundaries.
    groups = [[]]
    for packet in donor:
        if packet.kind == 1:
            groups[-1].append(packet)
            groups.append([])
        elif packet.kind in (2, 3, 4) or (packet.kind == 16 and packet.data[0] == 3):
            groups[-1].append(localized_packet(packet, language))
    output = []
    audio = 0
    for packet in base:
        if packet.kind == 1:
            output.extend(groups[audio])
            audio += 1
        elif packet.kind == 5 or (packet.kind == 16 and packet.data[0] not in (3, 6)):
            output.append(packet)
    output.extend(groups[-1])
    return encode_stream(output)
