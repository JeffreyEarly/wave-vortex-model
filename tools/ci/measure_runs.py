#!/usr/bin/env python3
"""Collect GitHub Actions timing evidence, retaining every job attempt.

Uses the authenticated gh CLI; reported runner time is elapsed job time,
not billing data. Queue time is reported separately from execution.
"""
import argparse
import concurrent.futures
import datetime as dt
import json
import subprocess
from pathlib import Path


def api(path):
    return json.loads(subprocess.run(['gh', 'api', path], check=True,
                                    capture_output=True, text=True).stdout)


def timestamp(value):
    return dt.datetime.fromisoformat(value.replace('Z', '+00:00')) if value else None


def seconds(start, end):
    return max(0, (timestamp(end) - timestamp(start)).total_seconds()) if start and end else None


def category(name):
    name = name.lower()
    if any(token in name for token in ('setup-matlab', 'set up matlab', 'install ', 'provision', 'checkout', 'check out', 'download', 'set up job')):
        return 'setup'
    if 'build' in name or 'compile' in name:
        return 'build_or_combined_build_test'
    if any(token in name for token in ('test', 'qualif', 'analy', 'catalog', 'verify', 'matlab-actions/run-command', 'matlab gate')):
        return 'validation'
    return 'other'


def collect(repo, run_id):
    run = api(f'repos/{repo}/actions/runs/{run_id}')
    jobs = []
    page = 1
    while True:
        batch = api(f'repos/{repo}/actions/runs/{run_id}/jobs?filter=all&per_page=100&page={page}')['jobs']
        jobs.extend(batch)
        if len(batch) < 100:
            break
        page += 1
    rows = []
    executions = set()
    for job in jobs:
        steps = [dict(name=s['name'], category=category(s['name']), conclusion=s.get('conclusion'),
                      seconds=seconds(s.get('started_at'), s.get('completed_at')))
                 for s in job.get('steps', [])]
        identity = (job['name'], job['started_at'], job['completed_at'])
        carried = identity in executions and job['conclusion'] == 'success'
        executions.add(identity)
        rows.append(dict(carriedForward=carried, id=job['id'], name=job['name'], attempt=job.get('run_attempt'),
                         status=job['status'], conclusion=job['conclusion'], url=job['html_url'],
                         startedAt=job['started_at'], completedAt=job['completed_at'],
                         seconds=seconds(job['started_at'], job['completed_at']), steps=steps))
    durations = [r['seconds'] for r in rows if r['seconds'] is not None and not r['carriedForward']]
    return dict(id=run_id, name=run['name'], sourceCommit=run['head_sha'], event=run['event'],
                url=run['html_url'], status=run['status'], conclusion=run['conclusion'],
                createdAt=run['created_at'], startedAt=run['run_started_at'],
                initialQueueSeconds=seconds(run['created_at'], run['run_started_at']),
                completedJobSeconds=sum(durations), incompleteJobs=sum(r['seconds'] is None for r in rows),
                jobs=rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', default='JeffreyEarly/wave-vortex-model')
    parser.add_argument('--run', action='append', type=int, required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        runs = list(pool.map(lambda run: collect(args.repo, run), args.run))
    result = dict(schema='wvm-ci-timing-v1', repository=args.repo,
                  capturedAt=dt.datetime.now(dt.timezone.utc).isoformat(),
                  method='All job attempts; successful results carried into later attempts are identified by identical name/start/end and counted only once. Elapsed runner seconds, not billing. Combined build/test steps remain explicitly combined. Incomplete jobs are not counted as zero cost.',
                  runs=runs)
    Path(args.output).write_text(json.dumps(result, indent=2) + '\n')
    for run in runs:
        print(f"{run['id']} {run['name']}: {run['completedJobSeconds']/60:.1f} completed runner-minutes, {run['incompleteJobs']} incomplete jobs")


if __name__ == '__main__':
    main()
