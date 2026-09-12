"""Summarize declared matched-error targets without changing tolerances."""
import csv
import json
from pathlib import Path

root = Path(__file__).resolve().parent
protocol = json.loads((root / 'comparison-protocol.json').read_text())
results = root / 'results'
rows = []
selected_path = results / 'selected-trajectory-timings.csv'
selected = []
if selected_path.exists():
    with selected_path.open() as stream:
        selected = list(csv.DictReader(stream))
for path in sorted(results.glob('*-trajectories.csv')):
    if path.name.startswith('long-'):
        continue
    tag = path.name.removesuffix('-trajectories.csv')
    with (results / (tag + '-reference.csv')).open() as stream:
        check = next(csv.DictReader(stream))
    with path.open() as stream:
        trials = list(csv.DictReader(stream))
    for index, target in enumerate(protocol['error_targets'], 1):
        limits = [target[k] for k in ['velocity_rms_m_s', 'density_rms_kg_m3', 'ssh_rms_m']]
        time = [float(check[k]) for k in ['timeVelocity', 'timeDensity', 'timeSSH']]
        space = [float(check[k]) for k in ['spaceVelocity', 'spaceDensity', 'spaceSSH']]
        qualified = all(t <= limit / 4 and s <= limit / 4 for t, s, limit in zip(time, space, limits))
        for variant in ['displacement', 'density']:
            eligible = []
            for trial in trials:
                if trial['variant'] != variant:
                    continue
                errors = [float(trial[k]) for k in ['velocityError', 'densityError', 'sshError']]
                # Empirical reference-check margin, not a rigorous error bound.
                if qualified and all(e + t + s <= limit for e, t, s, limit in zip(errors, time, space, limits)):
                    eligible.append(trial)
            row = dict(case=tag, target=index, variant=variant, referenceQualified=qualified,
                       qualifyingRuns=len(eligible), config='', deltaT='', evolutionSeconds='',
                       withDiagnosticsSeconds='', errorScore='')
            if eligible:
                best = min(eligible, key=lambda r: float(r['evolutionSeconds']) + float(r['diagnosticSeconds']))
                row.update(config=best['config'], deltaT=best['deltaT'], evolutionSeconds=best['evolutionSeconds'],
                           withDiagnosticsSeconds=float(best['evolutionSeconds']) + float(best['diagnosticSeconds']),
                           errorScore=max(float(best[k]) / limit for k, limit in zip(['velocityError', 'densityError', 'sshError'], limits)))
            if eligible:
                matched = [r for r in selected if r['profile'] + '-' + r['caseName'] == tag and r['variant'] == variant and r['config'] == row['config'] and r['deltaT'] == row['deltaT']]
                if matched:
                    row['evolutionSeconds'] = matched[0]['evolutionMedian']
                    row['withDiagnosticsSeconds'] = matched[0]['withDiagnosticsMedian']
            rows.append(row)
if rows:
    with (results / 'matched-error-costs.csv').open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
for row in rows:
    print(row)
