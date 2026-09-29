#!/usr/bin/env python3
"""Create a read-only, revision-bound audit of exact artifact candidates.

The input is a JSON array of repository-relative paths. The report records each
candidate's byte digest and size, structured and textual references outside the
candidate set, matching source-manifest references, and heuristic code searches
for directory discovery near qualification paths. Output is deterministic JSON
written to stdout; this tool never edits or deletes repository files.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

SCHEMA = "wvm-artifact-candidate-audit-v1"
SOURCE_SUFFIXES = {".m", ".py", ".sh", ".c", ".cc", ".cpp", ".cxx", ".h", ".hpp"}
MANIFEST_NAME = re.compile(r"(?:manifest|catalog|source-selection|inventory)", re.IGNORECASE)
DIRECTORY_READER = re.compile(
    r"(?:\bdir\s*\(|\bglob\s*\(|\brglob\s*\(|\.glob\s*\(|\.rglob\s*\(|"
    r"\.iterdir\s*\(|\b(?:walk|listdir|scandir)\s*\(|os\.(?:walk|listdir|scandir))"
)
DIRECTORY_CONTEXT = re.compile(r"qualification|evidence|forward-integration", re.IGNORECASE)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def safe_relative_path(value):
    if not isinstance(value, str) or not value or "\\" in value or "\n" in value:
        raise ValueError(f"Invalid candidate path: {value!r}")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or path.as_posix() != value:
        raise ValueError(f"Invalid candidate path: {value!r}")
    return value


def _strings(value, pointer=""):
    if isinstance(value, dict):
        for key, item in value.items():
            escaped = str(key).replace("~", "~0").replace("/", "~1")
            yield from _strings(item, pointer + "/" + escaped)
    elif isinstance(value, list):
        for index, item in enumerate(value):
            yield from _strings(item, pointer + "/" + str(index))
    elif isinstance(value, str):
        yield pointer or "/", value


def _kind_for_text(line, candidate):
    if candidate["path"] in line:
        return "repository-path", candidate["path"]
    if candidate["basename"] in line:
        return "basename", candidate["basename"]
    return "sha256", candidate["sha256"]


def _candidate_index(paths, root):
    records = []
    for path in paths:
        file_path = root / path
        if not file_path.is_file():
            raise ValueError(f"Candidate is missing: {path}")
        data = file_path.read_bytes()
        records.append({
            "path": path,
            "basename": PurePosixPath(path).name,
            "sha256": sha256(data),
            "bytes": len(data),
            "references": [],
        })
    return records


def audit(root, candidate_paths, tracked_paths, source_commit, candidate_manifest_sha256):
    """Return a deterministic report for a supplied clean repository snapshot."""
    root = Path(root)
    candidate_paths = sorted({safe_relative_path(path) for path in candidate_paths})
    tracked_paths = sorted({safe_relative_path(path) for path in tracked_paths})
    tracked = set(tracked_paths)
    missing = sorted(set(candidate_paths) - tracked)
    if missing:
        raise ValueError("Candidates are not tracked: " + ", ".join(missing))

    candidates = _candidate_index(candidate_paths, root)
    aliases = {}
    for candidate in candidates:
        for kind, token in (("repository-path", candidate["path"]),
                            ("basename", candidate["basename"]),
                            ("sha256", candidate["sha256"])):
            aliases.setdefault(token, []).append((candidate, kind))
    token_pattern = re.compile("|".join(re.escape(token) for token in sorted(aliases, key=lambda x: (-len(x), x))))
    candidate_set = set(candidate_paths)
    structured_references = []
    text_references = []
    directory_readers = []
    source_manifests = []
    source_code_files = []

    for relative in tracked_paths:
        if relative in candidate_set:
            continue
        path = root / relative
        try:
            data = path.read_bytes()
        except OSError:
            continue
        if b"\0" in data:
            continue
        text = data.decode("utf-8", errors="replace")

        if PurePosixPath(relative).suffix.lower() == ".json":
            try:
                document = json.loads(text)
            except json.JSONDecodeError:
                document = None
            if document is not None:
                for pointer, value in _strings(document):
                    hits = token_pattern.findall(value)
                    for token in sorted(set(hits)):
                        for candidate, _ in aliases[token]:
                            if candidate["path"] in value or candidate["basename"] in value:
                                kind = "path-value"
                            else:
                                kind = "digest-value"
                            structured_references.append({
                                "candidate": candidate["path"],
                                "sourcePath": relative,
                                "pointer": pointer,
                                "kind": kind,
                                "token": token,
                            })

        for line_number, line in enumerate(text.splitlines(), 1):
            hits = sorted(set(token_pattern.findall(line)))
            for token in hits:
                for candidate, _ in aliases[token]:
                    kind, matched = _kind_for_text(line, candidate)
                    text_references.append({
                        "candidate": candidate["path"],
                        "sourcePath": relative,
                        "line": line_number,
                        "kind": kind,
                        "token": matched,
                        "text": line[:500],
                    })

        if PurePosixPath(relative).suffix.lower() in SOURCE_SUFFIXES:
            source_code_files.append((relative, text))
            has_reader = bool(DIRECTORY_READER.search(text))
            has_context = bool(DIRECTORY_CONTEXT.search(text))
            if has_reader and has_context:
                for line_number, line in enumerate(text.splitlines(), 1):
                    if DIRECTORY_READER.search(line) or "forward-integration-evidence-v1" in line:
                        directory_readers.append({
                            "sourcePath": relative,
                            "line": line_number,
                            "text": line[:500],
                            "basis": "reader-and-qualification-context-in-same-file",
                        })
        if MANIFEST_NAME.search(PurePosixPath(relative).name):
            matches = [row for row in text_references if row["sourcePath"] == relative]
            for row in matches:
                source_manifests.append(row)

    for candidate in candidates:
        candidate["references"] = [
            row for row in structured_references + text_references
            if row["candidate"] == candidate["path"]
        ]

    # Include literal evidence-directory mentions even when the line does not
    # itself enumerate files; callers can review writers and exact-path readers.
    evidence_directory_mentions = []
    for relative, text in source_code_files:
        for line_number, line in enumerate(text.splitlines(), 1):
            if "forward-integration-evidence-v1" in line:
                evidence_directory_mentions.append({
                    "sourcePath": relative,
                    "line": line_number,
                    "text": line[:500],
                })

    return {
        "schema": SCHEMA,
        "sourceCommit": source_commit,
        "candidateManifestSHA256": candidate_manifest_sha256,
        "candidateCount": len(candidates),
        "candidates": candidates,
        "structuredReferences": sorted(structured_references, key=_reference_key),
        "textReferences": sorted(text_references, key=_reference_key),
        "sourceManifestReferences": sorted(source_manifests, key=_reference_key),
        "directoryReaderSearches": sorted(directory_readers, key=_line_key),
        "evidenceDirectoryMentions": sorted(evidence_directory_mentions, key=_line_key),
    }


def _reference_key(row):
    return (row["candidate"], row["sourcePath"], row.get("line", 0), row.get("pointer", ""), row["kind"], row["token"])


def _line_key(row):
    return (row["sourcePath"], row["line"], row["text"])


def _git(root, *args):
    return subprocess.check_output(["git", *args], cwd=root)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate_manifest", type=Path)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    root = args.root.resolve()
    manifest_bytes = args.candidate_manifest.read_bytes()
    candidate_paths = json.loads(manifest_bytes)
    if not isinstance(candidate_paths, list):
        parser.error("candidate manifest must be a JSON array of paths")

    # The report binds file bytes to HEAD. Refuse tracked working-tree changes
    # so sourceCommit cannot claim content different from the recorded revision.
    dirty = subprocess.run(["git", "diff-index", "--quiet", "HEAD", "--"], cwd=root).returncode
    if dirty:
        parser.error("tracked working tree differs from HEAD; audit a clean revision")
    source_commit = _git(root, "rev-parse", "HEAD").decode().strip()
    tracked_paths = [path.decode() for path in _git(root, "ls-files", "-z").split(b"\0") if path]
    report = audit(root, candidate_paths, tracked_paths, source_commit, sha256(manifest_bytes))
    json.dump(report, sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
