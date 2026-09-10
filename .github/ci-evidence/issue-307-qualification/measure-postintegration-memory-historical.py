#!/usr/bin/env python3
"""Bounded, prospective RSS nonregression for unchanged public run requests."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import statistics
import subprocess
import time


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main(args):
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    work = Path(args.work).resolve()
    work.mkdir(parents=True, exist_ok=True)
    fixture = Path(args.fixtures).resolve()
    binaries = {key: str(Path(getattr(args, key)).resolve())
                for key in ("baseline", "candidate")}
    hashes = {key: sha(path) for key, path in binaries.items()}
    result = {"schema": "wave-vortex-process-memory-qualification-v1",
              "gateDeclaredBeforeMeasurement": True,
              "runsPerExecutable": 5, "rssRelativeAllowance": .1,
              "rssAbsoluteAllowanceBytes": 16 * 1024 * 1024,
              "retainedRelativeAllowance": .03,
              "samplingPauseSeconds": .01,
              "peakAuthority": "runner getrusage process-lifetime high-water mark",
              "externalSampling": "ps resident bytes from launch to exit; sampled lower bound, variable cadence; no phase attribution",
              "binarySHA256": hashes, "cases": []}
    for family in ("constant", "hydrostatic", "boussinesq"):
        source = fixture / f"{family}-source.nc"
        template_path = fixture / f"{family}-request.json"
        template = json.loads(template_path.read_text())
        samples = {key: [] for key in binaries}
        for repetition in range(5):
            order = list(binaries) if repetition % 2 == 0 else list(reversed(binaries))
            for label in order:
                name = f"{family}-{repetition}-{label}"
                model = work / f"{name}.nc"
                report = output / f"{name}-report.json"
                request = output / f"{name}-request.json"
                shutil.copyfile(source, model)
                request.write_text(json.dumps(dict(template, modelFiles=[str(model)],
                                                   report=str(report)), indent=2) + "\n")
                rss = []
                started = time.monotonic()
                with (output / f"{name}.log").open("w") as log:
                    process = subprocess.Popen([binaries[label], "--request", str(request)],
                                               stdout=log, stderr=subprocess.STDOUT)
                    while process.poll() is None:
                        measured = subprocess.run(["/bin/ps", "-o", "rss=", "-p", str(process.pid)],
                                                  capture_output=True, text=True, check=False)
                        values = measured.stdout.split()
                        if measured.returncode == 0 and values:
                            rss.append({"seconds": time.monotonic() - started,
                                        "bytes": int(values[0]) * 1024})
                        time.sleep(.01)
                    code = process.wait()
                if code:
                    raise RuntimeError(f"{name} failed with exit {code}; retained log and request")
                value = json.loads(report.read_text())
                if not rss:
                    raise RuntimeError(f"{name}: no external RSS samples")
                raw_path = output / f"{name}-rss.json"
                raw_path.write_text(json.dumps(rss, indent=2) + "\n")
                item = {"peakRSSBytes": value["rssBytes"]["processPeak"],
                        "integrationBaselineRSSBytes": value["rssBytes"]["integrationBaseline"],
                        "externalSampledPeakRSSBytes": max(row["bytes"] for row in rss),
                        "externalSampleCount": len(rss),
                        "retainedBytes": value["livenessBytes"]["fullModelRetained"],
                        "stepCount": value["state"]["stepCount"],
                        "rhsEvaluationCount": value["state"]["rhsEvaluationCount"],
                        "report": report.name, "reportSHA256": sha(report),
                        "rssSamples": raw_path.name, "rssSamplesSHA256": sha(raw_path)}
                if item["peakRSSBytes"] <= 0:
                    raise RuntimeError(f"{name}: process peak is unavailable")
                samples[label].append(item)
                print(f"{name}: lifetime peak {item['peakRSSBytes']} bytes", flush=True)
        medians = {key: {"peakRSSBytes": statistics.median(row["peakRSSBytes"] for row in rows),
                         "retainedBytes": statistics.median(row["retainedBytes"] for row in rows)}
                   for key, rows in samples.items()}
        bound = medians["baseline"]["peakRSSBytes"] + max(
            .1 * medians["baseline"]["peakRSSBytes"], 16 * 1024 * 1024)
        work_matches = all(len({row[key] for rows in samples.values() for row in rows}) == 1
                           for key in ("stepCount", "rhsEvaluationCount"))
        passed = (medians["candidate"]["peakRSSBytes"] <= bound
                  and medians["candidate"]["retainedBytes"] <= 1.03 * medians["baseline"]["retainedBytes"]
                  and work_matches)
        result["cases"].append({"family": family, "sourceSHA256": sha(source),
                                "requestSHA256": sha(template_path), "samples": samples,
                                "medians": medians, "maximumCandidateMedianRSSBytes": bound,
                                "workMatchesExactly": work_matches, "passes": passed})
        (output / "qualification.json").write_text(json.dumps(result, indent=2) + "\n")
    result["binaryHashesUnchanged"] = all(sha(path) == hashes[key] for key, path in binaries.items())
    result["passes"] = result["binaryHashesUnchanged"] and all(row["passes"] for row in result["cases"])
    (output / "qualification.json").write_text(json.dumps(result, indent=2) + "\n")
    return 0 if result["passes"] else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for argument in ("baseline", "candidate", "fixtures", "work", "output"):
        parser.add_argument("--" + argument, required=True)
    raise SystemExit(main(parser.parse_args()))
