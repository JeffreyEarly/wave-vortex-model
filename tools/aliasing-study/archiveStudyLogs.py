"""Preserve exact MATLAB logs and normalize readable copies for source control."""
import gzip
from pathlib import Path

root = Path(__file__).resolve().parent / "results"
archive = root / "raw-logs"


def readable(data):
    cleaned = b"\n".join(line.rstrip(b" \t\r") for line in data.split(b"\n"))
    return cleaned.rstrip(b"\n") + b"\n" if cleaned else cleaned


for path in sorted(root.rglob("*.log")):
    original = path.read_bytes()
    cleaned = readable(original)
    if cleaned == original:
        continue
    archive.mkdir(exist_ok=True)
    target = archive / (str(path.relative_to(root)) + ".gz")
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        if readable(gzip.decompress(target.read_bytes())) != cleaned:
            raise RuntimeError(f"Refusing to replace preserved log {target}")
    else:
        target.write_bytes(gzip.compress(original, mtime=0))
    path.write_bytes(cleaned)
