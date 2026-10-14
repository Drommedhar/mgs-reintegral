"""Exercise native host shortcuts over the authenticated renderer transport."""

import os
import secrets
import socket
import struct
import subprocess
import sys
from pathlib import Path

from test_godot_protocol import receive


def reply(peer, operation, buttons, payload=b""):
    peer.sendall(
        struct.pack("<III", len(payload) + 4, operation | 0x80000000, buttons) + payload
    )


def batches(peer, invalid):
    # All requests must arrive before any response is available.
    for index in range(5):
        assert struct.unpack("<II", receive(peer, 8)) == (8, 31 - index)
        assert struct.unpack("<II", receive(peer, 8)) == (index, 0xABCDEF)
    assert struct.unpack("<II", receive(peer, 8)) == (0, 6)
    if invalid:
        reply(peer, 30 if invalid == "operation" else 31, 0, b"" if invalid == "size" else bytes(8))
        return
    for index in range(5):
        reply(peer, 31 - index, index, struct.pack("<II", 31 - index, index))
    reply(peer, 6, 0x8010)
    assert struct.unpack("<4I", receive(peer, 16)) == (8, 31, 0, 0xABCDEF)
    assert struct.unpack("<II", receive(peer, 8)) == (0, 6)
    reply(peer, 31, 0, struct.pack("<II", 31, 0))
    reply(peer, 6, 0x8010)


def run(executable, selected, offered, invalid=None):
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        listener.listen(1)
        listener.settimeout(10)
        token = secrets.token_hex(16)
        environment = os.environ | {
            "MGS_GODOT_PORT": str(listener.getsockname()[1]),
            "MGS_GODOT_SESSION_TOKEN": token,
            "MGS_GODOT_SCENE_VIEW": "0",
            "MGS_PRESENTATION_MINOR": str(offered),
        }
        process = subprocess.Popen(
            [str(executable), str(selected)],
            env=environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        try:
            with listener.accept()[0] as peer:
                peer.settimeout(10)
                assert struct.unpack("<II", receive(peer, 8)) == (40, 1)
                hello = receive(peer, 40)
                assert struct.unpack("<6I", hello[:24]) == (
                    0x3152474D,
                    15,
                    offered,
                    20,
                    0xFFFFFFFF,
                    29,
                )
                assert hello[24:] == bytes.fromhex(token)
                reply(
                    peer,
                    1,
                    0x10000,
                    struct.pack("<3I", 15, selected, 29) + secrets.token_bytes(16),
                )
                for flag in (0x10000, 0, 0x10000):
                    assert struct.unpack("<II", receive(peer, 8)) == (0, 6)
                    reply(peer, 6, flag | 0x8010)
                batches(peer, invalid)
            stdout, stderr = process.communicate(timeout=10)
            if invalid:
                assert process.returncode != 0 and b"invalid reply size or operation" in stderr
            else:
                assert process.returncode == 0, (stdout + stderr).decode(errors="replace")
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()


if __name__ == "__main__":
    executable = Path(sys.argv[1]).resolve()
    for selected, offered in ((31, 31), (30, 31), (30, 30)):
        run(executable, selected, offered)
    for invalid in ("size", "operation"):
        run(executable, 31, 31, invalid)
    print("PASS: ordered batches, malformed replies, F2 delivery and protocol negotiation")
