#!/usr/bin/env python3
"""Validate and stage benchmark JSON downloads for the documentation site."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys
from typing import Iterable

SCHEMA = "wvm-benchmark-downloads-v1"
MANIFEST_RELATIVE = Path("docs/benchmarks/downloads.json")
CATALOG_RELATIVE = Path("Benchmarks/results/catalog.json")
PUBLISHED_ID = re.compile(r"^[a-z0-9][a-z0-9-]*--(?:matlab|cpp)-[a-z0-9][a-z0-9-]*--[a-z0-9][a-z0-9-]*--\d{8}T\d{6}Z$")
INTERFACE_ID = re.compile(r"^three-interface--[a-z0-9][a-z0-9-]*--\d{8}T\d{6}Z$")
URL_PATTERN = re.compile(r"^/benchmarks/(?:data|raw)/[a-z0-9][a-zA-Z0-9-]*\.json$")
DIGEST_PATTERN = re.compile(r"^[0-9a-f]{64}$")


class DownloadError(ValueError):
    """Raised when a manifest, source, or staging destination is unsafe."""


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _json_bytes(path: Path, description: str):
    try:
        raw = path.read_bytes()
        return raw, json.loads(raw)
    except (OSError, json.JSONDecodeError) as exc:
        raise DownloadError(f"Cannot read {description}: {path}: {exc}") from exc


def _safe_repo_file(root: Path, relative: object, description: str) -> tuple[str, Path, bytes]:
    if not isinstance(relative, str) or not relative or "\\" in relative or "\n" in relative:
        raise DownloadError(f"Invalid {description} path: {relative!r}")
    posix = PurePosixPath(relative)
    if (posix.is_absolute() or ".." in posix.parts or posix.as_posix() != relative
            or not relative.startswith("Benchmarks/results/") or posix.suffix != ".json"):
        raise DownloadError(f"{description} must be a canonical Benchmarks/results JSON path: {relative!r}")

    current = root
    for part in posix.parts:
        current = current / part
        if current.is_symlink():
            raise DownloadError(f"{description} path contains a symlink: {relative}")
    try:
        resolved = current.resolve(strict=True)
        resolved.relative_to(root)
    except (OSError, ValueError) as exc:
        raise DownloadError(f"{description} path escapes the repository or is missing: {relative}") from exc
    if not resolved.is_file():
        raise DownloadError(f"{description} is not a regular file: {relative}")
    try:
        content = resolved.read_bytes()
    except OSError as exc:
        raise DownloadError(f"Cannot read {description}: {relative}: {exc}") from exc
    return relative, resolved, content


def _catalog_list(catalog: dict, key: str, required: bool = True) -> list:
    value = catalog.get(key)
    if value is None and not required:
        return []
    if not isinstance(value, list):
        raise DownloadError(f"Benchmark catalog {key} must be an array")
    return value


def _dataset_id(value: object, pattern: re.Pattern, description: str) -> str:
    if not isinstance(value, str) or not pattern.fullmatch(value):
        raise DownloadError(f"Invalid {description} datasetId: {value!r}")
    return value


def derive_expected_downloads(root: Path) -> dict[str, str]:
    """Derive exact URL-to-source rows from the catalog and source provenance."""
    root = Path(root).resolve()
    _, catalog_path, catalog_content = _safe_repo_file(
        root, CATALOG_RELATIVE.as_posix(), "benchmark catalog"
    )
    try:
        catalog = json.loads(catalog_content)
    except json.JSONDecodeError as exc:
        raise DownloadError(f"Cannot read benchmark catalog: {catalog_path}: {exc}") from exc
    if not isinstance(catalog, dict) or catalog.get("schemaVersion") != "benchmark-catalog-v1":
        raise DownloadError("Benchmark catalog must use schemaVersion benchmark-catalog-v1")

    scoring = _catalog_list(catalog, "scoringReferences")
    allowed_suites = set()
    for row in scoring:
        if not isinstance(row, dict) or not isinstance(row.get("suiteId"), str) or not row["suiteId"]:
            raise DownloadError("Benchmark catalog contains an invalid scoring reference")
        allowed_suites.add(row["suiteId"])

    expected: dict[str, str] = {}
    seen_published: set[str] = set()
    for row in _catalog_list(catalog, "publishedDatasets"):
        if not isinstance(row, dict):
            raise DownloadError("Benchmark catalog publishedDatasets entries must be objects")
        dataset_id = _dataset_id(row.get("datasetId"), PUBLISHED_ID, "published")
        _, _, raw_dataset = _safe_repo_file(root, row.get("artifact"), "published dataset")
        try:
            dataset = json.loads(raw_dataset)
        except json.JSONDecodeError as exc:
            raise DownloadError(f"Published dataset is invalid JSON: {row.get('artifact')}") from exc
        if (not isinstance(dataset, dict) or dataset.get("datasetId") != dataset_id
                or dataset.get("schemaVersion") != "published-benchmark-v1"):
            raise DownloadError(f"Published dataset identity or schema does not match catalog: {dataset_id}")
        if dataset_id in seen_published:
            raise DownloadError(f"Duplicate published datasetId: {dataset_id}")
        seen_published.add(dataset_id)
        benchmark = dataset.get("benchmark")
        if not isinstance(benchmark, dict) or not isinstance(benchmark.get("suiteId"), str):
            raise DownloadError(f"Published dataset lacks benchmark.suiteId: {dataset_id}")
        if benchmark["suiteId"] not in allowed_suites:
            continue

        artifact_path = row["artifact"]
        provenance = dataset.get("provenance")
        if not isinstance(provenance, dict):
            raise DownloadError(f"Published dataset lacks provenance: {dataset_id}")
        raw_path = provenance.get("rawArtifact")
        _safe_repo_file(root, raw_path, "raw benchmark artifact")
        _add_expected(expected, f"/benchmarks/data/{dataset_id}.json", artifact_path)
        _add_expected(expected, f"/benchmarks/raw/{dataset_id}.json", raw_path)

    seen_interfaces: set[str] = set()
    for row in _catalog_list(catalog, "interfaceComparisons", required=False):
        if not isinstance(row, dict):
            raise DownloadError("Benchmark catalog interfaceComparisons entries must be objects")
        dataset_id = _dataset_id(row.get("datasetId"), INTERFACE_ID, "interface")
        artifact_path = row.get("artifact")
        _, _, raw_dataset = _safe_repo_file(root, artifact_path, "interface comparison")
        try:
            dataset = json.loads(raw_dataset)
        except json.JSONDecodeError as exc:
            raise DownloadError(f"Interface comparison is invalid JSON: {artifact_path}") from exc
        if (not isinstance(dataset, dict) or dataset.get("datasetId") != dataset_id
                or dataset.get("schemaVersion") not in {
                    "published-three-interface-v1", "published-three-interface-v2",
                    "published-three-interface-v3", "published-three-interface-v4",
                }):
            raise DownloadError(f"Interface comparison identity or schema does not match catalog: {dataset_id}")
        if dataset_id in seen_interfaces:
            raise DownloadError(f"Duplicate interface datasetId: {dataset_id}")
        seen_interfaces.add(dataset_id)
        _add_expected(expected, f"/benchmarks/data/{dataset_id}.json", artifact_path)
    return expected


def _add_expected(expected: dict[str, str], url: str, source: str):
    if url in expected:
        raise DownloadError(f"Duplicate generated benchmark download URL: {url}")
    expected[url] = source


def _safe_url(value: object) -> str:
    if not isinstance(value, str) or not URL_PATTERN.fullmatch(value):
        raise DownloadError(f"Invalid benchmark download URL: {value!r}")
    path = PurePosixPath(value)
    if path.as_posix() != value or ".." in path.parts or "\\" in value:
        raise DownloadError(f"Noncanonical benchmark download URL: {value!r}")
    return value


def _manifest_path(root: Path, manifest: Path) -> Path:
    path = Path(manifest).expanduser()
    if not path.is_absolute():
        path = Path.cwd() / path
    if path.is_symlink():
        raise DownloadError(f"Manifest cannot be a symlink: {path}")
    try:
        resolved = path.resolve(strict=True)
    except OSError as exc:
        raise DownloadError(f"Download manifest is missing: {path}") from exc
    if not resolved.is_file():
        raise DownloadError(f"Download manifest is not a regular file: {resolved}")
    return resolved


def validate_manifest(root: Path, manifest: Path) -> list[dict]:
    """Validate manifest mappings and source bytes; return rows with payloads."""
    root = Path(root).resolve()
    manifest_path = _manifest_path(root, manifest)
    _, value = _json_bytes(manifest_path, "benchmark download manifest")
    if not isinstance(value, dict) or set(value) != {"schema", "entries"} or value.get("schema") != SCHEMA:
        raise DownloadError(f"Download manifest must contain schema {SCHEMA!r} and entries")
    rows = value["entries"]
    if not isinstance(rows, list):
        raise DownloadError("Download manifest entries must be an array")

    expected = derive_expected_downloads(root)
    actual: dict[str, str] = {}
    errors = []
    validated_rows = []
    urls = []
    for row in rows:
        if not isinstance(row, dict) or set(row) != {"url", "source", "sha256", "bytes"}:
            errors.append(f"Malformed download manifest entry: {row!r}")
            continue
        try:
            url = _safe_url(row["url"])
            source, source_path, content = _safe_repo_file(root, row["source"], "download source")
        except DownloadError as exc:
            errors.append(str(exc))
            continue
        urls.append(url)
        if url in actual:
            errors.append(f"Duplicate download URL: {url}")
        actual[url] = source
        digest = row["sha256"]
        byte_count = row["bytes"]
        if not isinstance(digest, str) or not DIGEST_PATTERN.fullmatch(digest):
            errors.append(f"Invalid SHA-256 for {url}")
        elif digest != sha256(content):
            errors.append(f"Stale SHA-256 for {url}")
        if type(byte_count) is not int or byte_count < 0:
            errors.append(f"Invalid byte count for {url}")
        elif byte_count != len(content):
            errors.append(f"Stale byte count for {url}")
        validated_rows.append({"url": url, "source": source, "path": source_path,
                               "sha256": sha256(content), "bytes": len(content), "content": content})
    if urls != sorted(urls):
        errors.append("Download manifest entries must be sorted by URL")
    for url in sorted(expected.keys() - actual.keys()):
        errors.append(f"Missing generated download URL: {url}")
    for url in sorted(actual.keys() - expected.keys()):
        errors.append(f"Unexpected generated download URL: {url}")
    for url in sorted(expected.keys() & actual.keys()):
        if actual[url] != expected[url]:
            errors.append(f"Wrong source for generated download URL {url}: {actual[url]!r}")
    if errors:
        raise DownloadError("\n".join(sorted(set(errors))))
    return validated_rows


def _destination_root(root: Path, destination: Path) -> Path:
    destination = Path(destination).expanduser().absolute()
    if destination.is_symlink():
        raise DownloadError(f"Destination root cannot be a symlink: {destination}")
    resolved = destination.resolve(strict=False)
    docs = (root / "docs").resolve(strict=False)
    if resolved == docs or docs in resolved.parents:
        raise DownloadError(f"Destination cannot be ROOT/docs or a descendant: {destination}")
    if destination.exists() and not destination.is_dir():
        raise DownloadError(f"Destination root is not a directory: {destination}")
    return resolved


def _destination_file(destination: Path, url: str, *, create_parents: bool) -> Path:
    relative = PurePosixPath(url.lstrip("/"))
    current = destination
    for part in relative.parts[:-1]:
        current = current / part
        if current.is_symlink():
            raise DownloadError(f"Staging path contains a symlink: {current}")
        if current.exists() and not current.is_dir():
            raise DownloadError(f"Staging parent is not a directory: {current}")
        if create_parents:
            current.mkdir(exist_ok=True)
    output = current / relative.parts[-1]
    if output.is_symlink():
        raise DownloadError(f"Staged file cannot be a symlink: {output}")
    if output.exists() and not output.is_file():
        raise DownloadError(f"Staged path is not a regular file: {output}")
    return output


def stage_downloads(root: Path, entries: Iterable[dict], destination: Path) -> None:
    """Stage validated downloads, accepting only identical preexisting files."""
    root = Path(root).resolve()
    site_root = _destination_root(root, destination)
    planned = []
    for entry in entries:
        output = _destination_file(site_root, entry["url"], create_parents=False)
        if output.exists() and output.read_bytes() != entry["content"]:
            raise DownloadError(f"Conflicting bytes already staged for {entry['url']}")
        planned.append((entry, output))

    site_root.mkdir(parents=True, exist_ok=True)
    for entry, _ in planned:
        output = _destination_file(site_root, entry["url"], create_parents=True)
        if output.exists():
            if output.read_bytes() != entry["content"]:
                raise DownloadError(f"Conflicting bytes already staged for {entry['url']}")
            continue
        try:
            with output.open("xb") as stream:
                stream.write(entry["content"])
        except FileExistsError:
            if output.is_symlink() or not output.is_file() or output.read_bytes() != entry["content"]:
                raise DownloadError(f"Conflicting path appeared while staging {entry['url']}")


def verify_staged(root: Path, entries: Iterable[dict], destination: Path) -> None:
    """Verify staged outputs without creating or repairing any paths."""
    root = Path(root).resolve()
    site_root = _destination_root(root, destination)
    if not site_root.is_dir():
        raise DownloadError(f"Staged site directory is missing: {site_root}")
    for entry in entries:
        output = _destination_file(site_root, entry["url"], create_parents=False)
        if not output.is_file():
            raise DownloadError(f"Staged download is missing: {entry['url']}")
        content = output.read_bytes()
        if len(content) != entry["bytes"] or sha256(content) != entry["sha256"]:
            raise DownloadError(f"Staged download bytes differ from source: {entry['url']}")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, help="download manifest (defaults to ROOT/docs/benchmarks/downloads.json)")
    parser.add_argument("--destination", type=Path)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--check", action="store_true", help="validate manifest and sources without staging")
    modes.add_argument("--verify-staged", action="store_true", help="verify staged outputs without repairing them")
    args = parser.parse_args(argv)
    root = args.root.resolve()
    if not args.check and args.destination is None:
        parser.error("--destination is required unless --check is used")
    if args.check and args.destination is not None:
        parser.error("--destination cannot be combined with --check")
    if args.verify_staged and args.destination is None:
        parser.error("--destination is required with --verify-staged")
    try:
        manifest = args.manifest or root / MANIFEST_RELATIVE
        entries = validate_manifest(root, manifest)
        if args.check:
            print(f"Validated {len(entries)} benchmark download entries.")
        elif args.verify_staged:
            verify_staged(root, entries, args.destination)
            print(f"Verified {len(entries)} staged benchmark downloads.")
        else:
            stage_downloads(root, entries, args.destination)
            print(f"Staged {len(entries)} benchmark downloads.")
    except DownloadError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
