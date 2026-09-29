#!/usr/bin/env python3
"""Check that tracked outputs are registered or covered by exact historical hashes.

The policy intentionally has no directory or glob exemptions. Legitimate inputs
are registered by exact repository path and role. Existing historical outputs
are listed individually in a baseline with their SHA-256 digest. Baseline
generation is a separate, explicit operation over caller-selected paths; normal
validation never adds entries.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path, PurePosixPath
from typing import Iterable, Mapping

SCHEMA = "wvm-artifact-baseline-v1"
REGISTERED_ROLES = frozenset({
    "fixture",
    "source-schema",
    "contract",
    "benchmark-reference",
    "qualification-evidence",
})
HISTORICAL_ROLE = "historical-output"


class ArtifactPolicyError(ValueError):
    """Raised when repository paths violate the artifact policy."""


def sha256(path: Path) -> str:
    """Return the lowercase SHA-256 digest of a file."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _safe_path(value: str) -> str:
    if not isinstance(value, str) or not value or "\\" in value or "\n" in value:
        raise ArtifactPolicyError(f"Invalid repository-relative path: {value!r}")
    path = PurePosixPath(value)
    if path.is_absolute() or any(part in ("", ".", "..") for part in path.parts):
        raise ArtifactPolicyError(f"Invalid repository-relative path: {value!r}")
    normalized = path.as_posix()
    if normalized != value:
        raise ArtifactPolicyError(f"Path is not normalized: {value!r}")
    return normalized


def _records(value: object, section: str, required: set[str]) -> dict[str, dict]:
    if not isinstance(value, list):
        raise ArtifactPolicyError(f"Baseline {section} must be a list")
    result = {}
    for item in value:
        if not isinstance(item, dict) or set(item) != required:
            raise ArtifactPolicyError(f"Malformed baseline {section} record: {item!r}")
        path = _safe_path(item["path"])
        if path in result:
            raise ArtifactPolicyError(f"Duplicate baseline path in {section}: {path}")
        result[path] = item
    return result


def parse_baseline(value: object) -> tuple[dict[str, dict], dict[str, dict]]:
    """Validate and index a baseline document."""
    if not isinstance(value, dict) or set(value) != {"schema", "entries", "retired"}:
        raise ArtifactPolicyError("Baseline must contain exactly schema, entries, and retired")
    if value["schema"] != SCHEMA:
        raise ArtifactPolicyError(f"Unsupported artifact baseline schema: {value['schema']!r}")
    entries = _records(value["entries"], "entries", {"path", "sha256", "role"})
    retired = _records(value["retired"], "retired", {"path", "sha256", "reason", "sourceCommit"})
    for path, item in entries.items():
        if item["role"] != HISTORICAL_ROLE or not _valid_digest(item["sha256"]):
            raise ArtifactPolicyError(f"Invalid historical baseline entry: {path}")
    for path, item in retired.items():
        if (not _valid_digest(item["sha256"]) or not isinstance(item["reason"], str) or not item["reason"].strip()
                or not _valid_commit(item["sourceCommit"])):
            raise ArtifactPolicyError(f"Invalid retirement record: {path}")
        if path in entries:
            raise ArtifactPolicyError(f"Path cannot be both active and retired: {path}")
    return entries, retired


def _valid_digest(value: object) -> bool:
    return isinstance(value, str) and len(value) == 64 and all(c in "0123456789abcdef" for c in value)


def _valid_commit(value: object) -> bool:
    return isinstance(value, str) and len(value) == 40 and all(c in "0123456789abcdef" for c in value)


def validate_baseline_transition(previous: object, current: object, base_commit: str) -> list[str]:
    """Reject unrecorded baseline removals or rewritten retirement history.

    ``base_commit`` is the immutable revision against which the head change is
    reviewed. Newly retired rows must preserve the prior digest and record this
    exact commit as their source. Existing retirement rows are append-only.
    """
    previous_entries, previous_retired = parse_baseline(previous)
    current_entries, current_retired = parse_baseline(current)
    if not _valid_commit(base_commit):
        raise ArtifactPolicyError("Base commit must be a lowercase 40-character SHA-1")
    errors = []
    for path in sorted(current_entries.keys() - previous_entries.keys()):
        errors.append(f"Historical baseline entry added after initial registration: {path}")
    for path, old in sorted(previous_entries.items()):
        new = current_entries.get(path)
        if new is not None:
            if new["sha256"] != old["sha256"]:
                errors.append(f"Historical baseline digest changed: {path}")
            continue
        retirement = current_retired.get(path)
        if retirement is None:
            errors.append(f"Baseline entry removed without retirement record: {path}")
        elif retirement["sha256"] != old["sha256"]:
            errors.append(f"Retirement digest does not match prior baseline: {path}")
        elif retirement["sourceCommit"] != base_commit:
            errors.append(f"Retirement source commit does not match base revision: {path}")
    for path, old in sorted(previous_retired.items()):
        if current_retired.get(path) != old:
            errors.append(f"Retirement record changed or removed: {path}")
    return sorted(set(errors))


def check_repository(
    root: Path,
    tracked_paths: Iterable[str],
    registered: Mapping[str, str],
    baseline: object,
) -> list[str]:
    """Return sorted policy errors for tracked paths under ``root``.

    Registration is exact-path only. Historical baseline entries also match
    exact paths only and their current content must retain the recorded digest.
    A tracked path may disappear only after its active baseline row moves to a
    matching retirement record; call ``validate_baseline_transition`` to check
    that base-to-head change. This function is read-only and never edits data.
    """
    root = Path(root)
    entries, retired = parse_baseline(baseline)
    registration = {}
    for path, role in registered.items():
        normalized = _safe_path(path)
        if role not in REGISTERED_ROLES:
            raise ArtifactPolicyError(f"Unknown registered role for {normalized}: {role!r}")
        if normalized in registration:
            raise ArtifactPolicyError(f"Duplicate registered path: {normalized}")
        registration[normalized] = role

    overlaps = registration.keys() & (entries.keys() | retired.keys())
    if overlaps:
        raise ArtifactPolicyError(
            "Registered paths cannot also be baseline or retired artifacts: " + ", ".join(sorted(overlaps))
        )

    paths = [_safe_path(path) for path in tracked_paths]
    if len(set(paths)) != len(paths):
        raise ArtifactPolicyError("Tracked path list contains duplicates")
    current = set(paths)
    errors = []

    for path in sorted(current):
        if path in registration:
            continue
        if path in retired:
            errors.append(f"Retired artifact path is present again: {path}")
            continue
        entry = entries.get(path)
        if entry is None:
            errors.append(f"Unregistered tracked artifact: {path}")
            continue
        file_path = root / path
        if not file_path.is_file():
            errors.append(f"Tracked artifact is missing from the working tree: {path}")
        elif sha256(file_path) != entry["sha256"]:
            errors.append(f"Historical artifact content changed: {path}")

    for path, entry in sorted(entries.items()):
        if path not in current:
            retirement = retired.get(path)
            if retirement is None or retirement["sha256"] != entry["sha256"]:
                errors.append(f"Baseline entry removed without matching retirement: {path}")
    for path, record in sorted(retired.items()):
        if path in current:
            errors.append(f"Retired artifact path is present again: {path}")
        file_path = root / path
        if file_path.is_file() and path not in current:
            errors.append(f"Retired artifact remains in the working tree: {path}")
    return sorted(set(errors))


def build_baseline(
    root: Path,
    historical_paths: Iterable[str],
    retired: Iterable[Mapping[str, str]] = (),
) -> dict:
    """Build a deterministic baseline from explicitly selected output paths.

    Callers must choose every historical path. This function performs no path
    discovery and is not used by ``check_repository``.
    """
    root = Path(root)
    paths = sorted({_safe_path(path) for path in historical_paths})
    entries = []
    for path in paths:
        file_path = root / path
        if not file_path.is_file():
            raise ArtifactPolicyError(f"Cannot baseline missing historical artifact: {path}")
        entries.append({"path": path, "sha256": sha256(file_path), "role": HISTORICAL_ROLE})
    retirement_rows = []
    for item in retired:
        if set(item) != {"path", "sha256", "reason", "sourceCommit"}:
            raise ArtifactPolicyError(f"Malformed retirement record: {item!r}")
        retirement_rows.append({
            "path": _safe_path(item["path"]),
            "sha256": item["sha256"],
            "reason": item["reason"],
            "sourceCommit": item["sourceCommit"],
        })
    retirement_rows.sort(key=lambda item: item["path"])
    result = {"schema": SCHEMA, "entries": entries, "retired": retirement_rows}
    parse_baseline(result)
    return result


def render_baseline(baseline: object) -> str:
    """Serialize a valid baseline deterministically for review or checked-in use."""
    entries, retired = parse_baseline(baseline)
    value = {
        "schema": SCHEMA,
        "entries": [entries[path] for path in sorted(entries)],
        "retired": [retired[path] for path in sorted(retired)],
    }
    return json.dumps(value, indent=2) + "\n"
