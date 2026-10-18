"""Fetch one export template out of the pinned Godot template archive.

The archive is 1.28 GB but the web template inside it is about 10 MB, so this
reads only the zip directory and that one member with HTTP Range requests and
checks the member against the SHA-512 pinned in dependencies.json.

    python3 tools/fetch_web_template.py <destination_dir>
"""
import hashlib
import io
import json
import os
import sys
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLOCK = 4 << 20


class RangeReader(io.RawIOBase):
    """Seekable read-only view of a remote file, fetched in 4 MiB blocks."""

    def __init__(self, url: str) -> None:
        request = urllib.request.Request(url, headers={"Range": "bytes=0-0"})
        with urllib.request.urlopen(request, timeout=60) as response:
            # GitHub redirects to a signed URL; reuse it so every range hits the same object.
            self.url = response.geturl()
            self.size = int(response.headers["Content-Range"].split("/")[-1])
        self.pos = 0
        self.block_start = -1
        self.block = b""

    def readable(self) -> bool:
        return True

    def seekable(self) -> bool:
        return True

    def tell(self) -> int:
        return self.pos

    def seek(self, offset: int, whence: int = 0) -> int:
        base = {0: 0, 1: self.pos, 2: self.size}[whence]
        self.pos = max(0, base + offset)
        return self.pos

    def _fetch(self, start: int, length: int) -> None:
        end = min(self.size, start + max(length, BLOCK)) - 1
        request = urllib.request.Request(self.url, headers={"Range": "bytes=%d-%d" % (start, end)})
        with urllib.request.urlopen(request, timeout=120) as response:
            if response.status != 206:
                raise RuntimeError("server ignored the Range header")
            self.block = response.read()
        self.block_start = start

    def readinto(self, buffer) -> int:
        if self.pos >= self.size:
            return 0
        wanted = min(len(buffer), self.size - self.pos)
        offset = self.pos - self.block_start
        if self.block_start < 0 or offset < 0 or offset + wanted > len(self.block):
            self._fetch(self.pos, wanted)
            offset = 0
        buffer[:wanted] = self.block[offset:offset + wanted]
        self.pos += wanted
        return wanted


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    destination = sys.argv[1]
    with open(os.path.join(ROOT, "dependencies.json"), encoding="utf-8") as handle:
        godot = json.load(handle)["godot"]
    templates = godot["export_templates"]
    member = templates["web"]["file"]
    url = "https://github.com/godotengine/godot/releases/download/%s/%s" % (godot["version"], templates["archive"])
    archive = zipfile.ZipFile(io.BufferedReader(RangeReader(url), BLOCK))
    data = archive.read("templates/" + member)
    digest = hashlib.sha512(data).hexdigest()
    if digest != templates["web"]["sha512"]:
        print("checksum mismatch for %s: %s" % (member, digest), file=sys.stderr)
        return 1
    os.makedirs(destination, exist_ok=True)
    with open(os.path.join(destination, member), "wb") as handle:
        handle.write(data)
    with open(os.path.join(destination, "version.txt"), "w", encoding="utf-8") as handle:
        handle.write(godot["version"].replace("-", "."))
    print("template ready: %s (%d bytes)" % (member, len(data)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
