"""Synthetic GPU integration checks against a running Godot prototype server."""

import argparse
import socket
import struct


def command(peer, operation, payload=b""):
    peer.sendall(struct.pack("<II", len(payload), operation) + payload)


def receive(peer, size):
    result = bytearray()
    while len(result) < size:
        part = peer.recv(size - len(result))
        if not part:
            raise RuntimeError("Godot disconnected before the reply")
        result.extend(part)
    return result


def exchange(peer, operation, payload=b""):
    command(peer, operation, payload)
    size, reply = struct.unpack("<II", receive(peer, 8))
    if reply != operation | 0x80000000 or not 4 <= size <= 2097156:
        raise ValueError("Invalid Godot reply")
    return receive(peer, size)[4:]


def read_pixel(peer, x, y):
    return tuple(exchange(peer, 5, struct.pack("<4i", x, y, 1, 1)))


def draw_quad(peer, color, force=0, preserve=0):
    header = struct.pack(
        "<2I4i8f2IfI",
        4,
        6,
        0,
        0,
        1024,
        512,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        force,
        preserve,
        1,
        0,
    )
    vertices = b"".join(
        struct.pack("<2h4H4BI", x, y, 0, 0, 0, 0x8000, *color, 0)
        for x, y in [(20, 30), (40, 30), (20, 50), (40, 50)]
    )
    command(peer, 2, header + vertices + struct.pack("<6H", 0, 1, 2, 1, 3, 2))


def check_fragmented_upload(peer):
    pixels = bytes(range(256)) * 1024
    region = struct.pack("<4i", 256, 128, 256, 256)
    packet = struct.pack("<II", len(region) + len(pixels), 3) + region + pixels
    peer.sendall(packet[:3])
    for offset in range(3, len(packet), 8191):
        peer.sendall(packet[offset : offset + 8191])
    assert exchange(peer, 5, region) == pixels, "fragmented large upload/read ordering"


def run(port):
    with socket.create_connection(("127.0.0.1", port), timeout=30) as peer:
        exchange(peer, 1, struct.pack("<3I", 0x3152474D, 13, 20))
        command(peer, 11, b"FPS 60.0  FRAME 16.67 ms\nMAX 18.00 ms")
        command(peer, 8, struct.pack("<7i", 0, 0, 1024, 512, 248, 0, 0))
        command(peer, 8, struct.pack("<7i", 10, 10, 4, 4, 0, 248, 0))
        assert read_pixel(peer, 11, 11) == (0, 255, 0, 0), "regional clear"
        assert read_pixel(peer, 0, 0) == (255, 0, 0, 0), (
            "clear must preserve other pixels"
        )
        draw_quad(peer, (0, 0, 248, 255), force=1)
        assert read_pixel(peer, 25, 35) == (0, 0, 255, 255), (
            "triangle raster / orientation"
        )
        draw_quad(peer, (0, 248, 0, 255), preserve=1)
        assert read_pixel(peer, 25, 35) == (0, 0, 255, 255), "preserve mask"
        command(peer, 3, struct.pack("<4i", 80, 60, 1, 1) + bytes([8, 16, 24, 255]))
        command(peer, 4, struct.pack("<6i", 80, 60, 1, 1, 90, 70))
        assert read_pixel(peer, 90, 70) == (8, 16, 24, 255), "upload/move/readback"
        check_fragmented_upload(peer)
        exchange(peer, 7, struct.pack("<7I", 1, 0, 0, 320, 240, 4, 3))
    print(
        "Godot GPU: regional clear, triangle raster, mask, fragmented upload, move and readback passed"
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=28740)
    run(parser.parse_args().port)
