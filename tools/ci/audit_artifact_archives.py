#!/usr/bin/env python3
"""Read-only bounded scan of tracked .gz/.zip archives for artifact candidates.

Example:
  python3 tools/ci/audit_artifact_archives.py --root REPOSITORY \
      --candidate-manifest unreferenced-receipt-candidates.json \
      --output archive-audit.json

Scans compressed members in memory, never extracts them, and refuses tracked
worktree changes so the report is bound to the recorded Git commit.
"""
import argparse
import gzip
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import zipfile

MAX_MEMBER = 50 * 1024 * 1024
MAX_TOTAL = 200 * 1024 * 1024


def git(root, *args):
    return subprocess.check_output(["git", *args], cwd=root)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def load_candidates(root, manifest):
    raw = manifest.read_bytes()
    values = json.loads(raw)
    if not isinstance(values, list):
        raise ValueError("candidate manifest must be a JSON array")
    candidates = []
    for relative in sorted(set(values)):
        if not isinstance(relative, str) or not relative or "\\" in relative:
            raise ValueError(f"invalid candidate path: {relative!r}")
        path = PurePosixPath(relative)
        if path.is_absolute() or ".." in path.parts or path.as_posix() != relative:
            raise ValueError(f"invalid candidate path: {relative!r}")
        candidate_file = root / relative
        if not candidate_file.is_file():
            raise ValueError(f"candidate is missing: {relative}")
        data = candidate_file.read_bytes()
        candidates.append({
            "path": relative,
            "basename": path.name,
            "sha256": sha256(data),
            "bytes": data,
            "byteCount": len(data),
        })
    return raw, candidates


def inspect_member(archive, member, compressed_bytes, data, candidates):
    member_sha = sha256(data)
    matches = []
    for candidate in candidates:
        kinds = []
        if candidate["path"].encode() in data:
            kinds.append("repository-path")
        if candidate["basename"].encode() in data:
            kinds.append("basename")
        if candidate["sha256"].encode() in data:
            kinds.append("sha256")
        if data == candidate["bytes"]:
            kinds.append("whole-member-identical-bytes")
        elif candidate["bytes"] in data:
            kinds.append("candidate-bytes-contained-in-member")
        if kinds:
            matches.append({
                "archive": archive,
                "member": member,
                "candidate": candidate["path"],
                "candidateSHA256": candidate["sha256"],
                "candidateBytes": candidate["byteCount"],
                "matches": kinds,
            })
    return {
        "member": member,
        "compressedBytes": compressed_bytes,
        "decompressedBytes": len(data),
        "memberSHA256": member_sha,
        "candidateMatches": len(matches),
    }, matches


def audit(root, manifest):
    root = root.resolve()
    dirty = subprocess.run(["git", "diff-index", "--quiet", "HEAD", "--"], cwd=root).returncode
    if dirty:
        raise ValueError("tracked working tree differs from HEAD; audit a clean revision")
    manifest_raw, candidates = load_candidates(root, manifest)
    tracked = [path.decode() for path in git(root, "ls-files", "-z").split(b"\0") if path]
    archives = sorted(path for path in tracked if path.lower().endswith((".gz", ".zip")))
    result = {
        "sourceCommit": git(root, "rev-parse", "HEAD").decode().strip(),
        "candidateManifestSHA256": sha256(manifest_raw),
        "candidateCount": len(candidates),
        "archiveCount": len(archives),
        "archives": [],
        "matches": [],
        "unsupported": [],
    }
    total = 0
    for relative in archives:
        archive_path = root / relative
        archive_bytes = archive_path.stat().st_size
        row = {"archive": relative, "archiveBytes": archive_bytes, "members": []}
        try:
            if relative.lower().endswith(".zip"):
                with zipfile.ZipFile(archive_path) as zipped:
                    for info in zipped.infolist():
                        if info.is_dir():
                            continue
                        if info.file_size > MAX_MEMBER or total + info.file_size > MAX_TOTAL:
                            raise ValueError(f"expansion cap exceeded for {info.filename}: {info.file_size} bytes")
                        with zipped.open(info) as stream:
                            data = stream.read(MAX_MEMBER + 1)
                        if len(data) > MAX_MEMBER or len(data) != info.file_size:
                            raise ValueError(f"member size mismatch/cap for {info.filename}")
                        total += len(data)
                        member, matches = inspect_member(relative, info.filename, info.compress_size, data, candidates)
                        row["members"].append(member)
                        result["matches"].extend(matches)
            else:
                with gzip.open(archive_path, "rb") as stream:
                    data = stream.read(MAX_MEMBER + 1)
                if len(data) > MAX_MEMBER or total + len(data) > MAX_TOTAL:
                    raise ValueError(f"gzip expansion cap exceeded: {len(data)} bytes")
                total += len(data)
                member, matches = inspect_member(relative, "<gzip-payload>", archive_bytes, data, candidates)
                row["members"].append(member)
                result["matches"].extend(matches)
        except Exception as exc:
            row["error"] = f"{type(exc).__name__}: {exc}"
            result["unsupported"].append({"archive": relative, "error": row["error"]})
        result["archives"].append(row)
    result["totalDecompressedBytes"] = total
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--candidate-manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, help="write report JSON here; defaults to stdout")
    args = parser.parse_args()
    report = audit(args.root, args.candidate_manifest)
    rendered = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.write_text(rendered)
    else:
        print(rendered, end="")
    print(
        f"Scanned {report['archiveCount']} archives; {len(report['matches'])} matches; "
        f"{len(report['unsupported'])} unsupported; {report['totalDecompressedBytes']} bytes decompressed.",
        file=__import__("sys").stderr,
    )


if __name__ == "__main__":
    main()
