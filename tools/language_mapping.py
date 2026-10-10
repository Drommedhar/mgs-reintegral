"""Match donor presentation through stable Integral script contexts."""

from collections import defaultdict

from language_assets import regional_text
from language_pack import DEMO, VOX, add_translation
from language_script import (
    dialogue,
    integral_radio_offset,
    matched_commands,
    procedures,
)
from language_stream import caption_strings, localize_voice, merge_demo, streams
from list_assets import list_assets, stage_table


def stage_scripts(path):
    with path.open("rb") as handle:
        stages = stage_table(handle, path.stat().st_size)
        result = {}
        for stage in stages:
            for asset in list_assets(path, stage):
                if asset.identity.endswith(".g"):
                    handle.seek(asset.offset)
                    result[stage, asset.identity] = procedures(handle.read(asset.size))
    return result


def radio_shape(node):
    if node.code == 0x102:
        return (node.code,)
    value = node.shape()[1]
    return node.code, value, tuple(radio_shape(child) for child in node.children)


def speakers(node):
    result = []
    for talk in node.walk(0x101):
        speaker = talk.children[0].value[:2]
        if not result or result[-1] != speaker:
            result.append(speaker)
    return result


class Mapping:
    def __init__(self, language):
        self.language = language
        self.references = {VOX: defaultdict(set), DEMO: defaultdict(set)}
        self.translations = defaultdict(set)
        self.radio_calls = set()
        self.codec_streams = set()

    def text(self, left, right):
        if left and right:
            self.translations[left].add(regional_text(right, self.language))

    def radio(self, base, donor, left, right):
        frequency, first = dialogue(base, integral_radio_offset(left))
        other_frequency, second = dialogue(donor, right & 0xFFFFFF)
        if frequency != other_frequency:
            return
        if first.shape() == second.shape():
            for a, b in zip(first.walk(0x101), second.walk(0x101)):
                self.text(a.value, b.value)
            for a, b in zip(first.walk(7), second.walk(7)):
                self.text(a.value, b.value)
        if radio_shape(first) != radio_shape(second):
            return
        self.radio_calls.add((left, right))
        for a, b in zip(first.walk(0x102), second.walk(0x102)):
            if speakers(a) == speakers(b):
                original = int.from_bytes(a.value, "big")
                self.codec_streams.add(original)
                self.references[VOX][original].add(int.from_bytes(b.value, "big"))

    def stages(self, first, second, base_radio, donor_radio, banks):
        for key in sorted(first.keys() & second.keys()):
            for _, a, b in matched_commands(first[key], second[key]):
                if (
                    key[0] == "brf"
                    and a.code == 0x60
                    and a.value == b"\x99\x06"
                    and a.children[0].value == b"\x93\xb6"
                ):
                    self.briefing(a, b, banks[VOX])
                for left, right in zip(a.walk(7), b.walk(7)):
                    self.text(left.value, right.value)
                for left, right in zip(a.walk(10), b.walk(10)):
                    x, y = (
                        int.from_bytes(left.value, "big"),
                        int.from_bytes(right.value, "big"),
                    )
                    if a.value == b"\x24\xe1":
                        self.radio(base_radio, donor_radio, x, y)
                    for kind, (base, donor) in banks.items():
                        command = b"\xa2\x42" if kind == DEMO else b"\x69\x8d"
                        if x in base and y in donor and a.value == command:
                            self.references[kind][x].add(y)

    def briefing(self, first, second, banks):
        options = [
            [
                node
                for option in command.walk(0x50)
                if option.value == b"v"
                for node in option.walk(10)
            ]
            for command in (first, second)
        ]
        if len(options[0]) != 19 or len(options[1]) != 19:
            raise ValueError("Briefing actor no longer has 19 voice references")
        for left, right in zip(*options):
            x, y = int.from_bytes(left.value, "big"), int.from_bytes(right.value, "big")
            if x not in banks[0] or y not in banks[1]:
                raise ValueError("Briefing voice reference is outside its bank")
            self.references[VOX][x].add(y)

    def compile(self, records, number, banks):
        coverage = {"radioCalls": len(self.radio_calls), "streams": {}, "rejected": []}
        for kind, (base, donor) in banks.items():
            accepted = []
            for original, candidates in sorted(self.references[kind].items()):
                if len(candidates) != 1 or original not in base:
                    continue
                translated = next(iter(candidates))
                if translated not in donor:
                    continue
                first, second = base[original], donor[translated]
                try:
                    left, right = caption_strings(first, 6), caption_strings(second, 3)
                    if (
                        kind == VOX
                        and original in self.codec_streams
                        and len(left) != len(right)
                    ):
                        raise ValueError(
                            "Subtitle segment count differs; preserve Integral Codec progression"
                        )
                    payload = (
                        merge_demo(first, second, self.language)
                        if kind == DEMO
                        else localize_voice(second, self.language)
                    )
                except ValueError as error:
                    coverage["rejected"].append(
                        {"kind": kind, "sector": original, "reason": str(error)}
                    )
                    continue
                records[kind, number, original] = payload
                if len(left) == len(right):
                    for a, b in zip(left, right):
                        self.text(a, b)
                accepted.append(original)
            coverage["streams"]["demo" if kind == DEMO else "vox"] = {
                "mapped": len(accepted),
                "total": len(base),
                "sectors": accepted,
                "fallbackSectors": sorted(base.keys() - set(accepted)),
            }
        return coverage


def compile_disc(records, number, language, base, donor):
    banks = {
        kind: (streams(base[name]), streams(donor[name]))
        for kind, name in ((VOX, "VOX.DAT"), (DEMO, "DEMO.DAT"))
    }
    mapping = Mapping(language)
    mapping.stages(
        stage_scripts(base["STAGE.DIR"]),
        stage_scripts(donor["STAGE.DIR"]),
        base["RADIO.DAT"],
        donor["RADIO.DAT"],
        banks,
    )
    coverage = mapping.compile(records, number, banks)
    return coverage, mapping.translations


def compile_text(records, candidates):
    ambiguous = []
    accepted = 0
    for source, translated in sorted(candidates.items()):
        if len(translated) != 1:
            ambiguous.append(source.hex())
            continue
        add_translation(records, source, next(iter(translated)))
        accepted += 1
    return {"matched": accepted, "ambiguousSourcesHex": ambiguous}
