"""Record machine metadata and checksums after a reproduced macOS study run."""
import datetime
import hashlib
import json
import subprocess
from pathlib import Path

study = Path(__file__).resolve().parent
results = study / "results"
machine = results / "machine.json"
if not machine.exists():
    cost = next((results / "cost-matrix-v1").glob("*/cost-summary.json"))
    matlab = json.loads(cost.read_text())
    def command(*args):
        return subprocess.check_output(args, text=True).strip()
    metadata = dict(cpu=command("sysctl", "-n", "machdep.cpu.brand_string"),
                    installedMemoryBytes=int(command("sysctl", "-n", "hw.memsize")),
                    macOSVersion=command("sw_vers", "-productVersion"),
                    matlabVersion=matlab["matlabVersion"], architecture=matlab["computer"],
                    recordedAtUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    costMethod="One fresh MATLAB process per candidate policy/case, measured with /usr/bin/time -l; phase times recorded in MATLAB.")
    machine.write_text(json.dumps(metadata, indent=2) + "\n")
manifest = []
for path in sorted(results.rglob("*.mat")):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    manifest.append(dict(path=str(path.relative_to(study)), bytes=path.stat().st_size,
                         sha256=digest.hexdigest(),
                         storage="preserved local MAT file; CSV/JSON results and reproduction code versioned"))
(results / "mat-artifact-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(f"Preserved machine metadata and recorded {len(manifest)} MAT checksums.")
