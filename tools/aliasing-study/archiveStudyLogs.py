"""Preserve exact MATLAB logs and normalize readable copies for source control."""
import gzip
from pathlib import Path

root = Path(__file__).resolve().parent / "results"
archive = root / "raw-logs"
for path in sorted(root.glob("*.log")):
    original = path.read_bytes()
    cleaned = b"\n".join(line.rstrip(b" \t\r") for line in original.split(b"\n"))
    if cleaned == original:
        continue
    archive.mkdir(exist_ok=True)
    target = archive / (path.name + ".gz")
    if target.exists():
        if gzip.decompress(target.read_bytes()) != original:
            raise RuntimeError(f"Refusing to replace preserved log {target}")
    else:
        target.write_bytes(gzip.compress(original, mtime=0))
    path.write_bytes(cleaned)
