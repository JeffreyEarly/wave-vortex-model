import copy
import unittest
from gate import validate
from route import select


def evidence(plan):
    identities = [(release, 'release', group) for release in plan['releases'] for group in plan['matlabShards']]
    if plan['cpp']:
        identities.extend(('R2025b', 'sanitized', group) for group in plan['sanitizedShards'])
    reports = []
    for release, configuration, group in identities:
        classes, shard = group['classes'], group['id']
        reports.append(dict(schema='wvm-ci-matlab-v1', sourceCommit=plan['sourceCommit'],
                            matlabRelease=release, configuration=configuration, shard=shard, passed=True,
                            requestedClasses=classes, deferredMethods=plan['deferredMethods'], excludedTags=plan['excludedTags'],
                            excludedClasses=[], excludedTests=[], expectedTests=[name+'/parity' for name in classes],
                            phases=dict(smoke=configuration == 'release' and shard == 0,
                                        analyzer=configuration == 'release' and release == 'R2025b' and shard == 0 and plan['analyzer'],
                                        documentation=configuration == 'release' and release == 'R2025b' and shard == 0 and plan['documentation']),
                            tests=[dict(name=name+'/parity', passed=True, incomplete=False) for name in classes]))
    jobs = {name: {'result': 'success' if selected else 'skipped'} for name, selected in
            dict(route=True, repository=True, matlab=True,
                 **{'cpp-release': plan['cpp'], 'cpp-sanitized': plan['cpp'], 'matlab-sanitized': plan['cpp'], 'packages': plan['packaging']}).items()}
    return jobs, reports


class GateTests(unittest.TestCase):
    def setUp(self):
        self.plan = select(['.github/workflows/ci.yml'], source_commit='abc123')
        self.jobs, self.reports = evidence(self.plan)

    def test_broad_coverage_passes_only_with_complete_evidence(self):
        self.assertTrue(validate(self.plan, self.jobs, self.reports))

    def test_every_selected_job_rejects_failure_cancel_skip_and_missing(self):
        for name in self.jobs:
            for result in ['failure', 'cancelled', 'skipped', None, '']:
                with self.subTest(job=name, result=result):
                    jobs = copy.deepcopy(self.jobs)
                    jobs[name]['result'] = result
                    with self.assertRaises(ValueError):
                        validate(self.plan, jobs, self.reports)
            jobs = copy.deepcopy(self.jobs); del jobs[name]
            with self.assertRaises(ValueError):
                validate(self.plan, jobs, self.reports)

    def test_intentionally_unselected_work_must_be_skipped(self):
        plan = select(['README.md'], source_commit='abc123')
        jobs, reports = evidence(plan)
        self.assertTrue(validate(plan, jobs, reports))
        jobs['cpp-release']['result'] = 'success'
        with self.assertRaises(ValueError):
            validate(plan, jobs, reports)

    def test_missing_release_or_sanitizer_report_is_rejected(self):
        for index in range(len(self.reports)):
            with self.assertRaises(ValueError):
                validate(self.plan, self.jobs, self.reports[:index]+self.reports[index+1:])

    def test_duplicate_report_is_rejected(self):
        with self.assertRaises(ValueError):
            validate(self.plan, self.jobs, self.reports+[self.reports[0]])

    def test_stale_revision_failed_test_and_missing_phase_are_rejected(self):
        mutations = [lambda r: r.update(sourceCommit='old'), lambda r: r.update(passed=False),
                     lambda r: r['phases'].update(analyzer=False), lambda r: r.update(tests=[]),
                     lambda r: r['tests'][0].update(passed=False), lambda r: r['tests'][0].update(incomplete=True),
                     lambda r: r.update(requestedClasses=[]), lambda r: r.update(excludedTags=[])]
        for mutate in mutations:
            reports = copy.deepcopy(self.reports); mutate(reports[0])
            with self.assertRaises(ValueError):
                validate(self.plan, self.jobs, reports)

    def test_selection_cannot_silently_drop_required_work(self):
        plan = copy.deepcopy(self.plan); plan['cpp'] = False
        with self.assertRaises(ValueError):
            validate(plan, self.jobs, self.reports)

    def test_missing_method_fails_even_when_its_class_has_another_result(self):
        reports = copy.deepcopy(self.reports)
        reports[0]['expectedTests'].append(reports[0]['requestedClasses'][0]+'/secondMethod')
        with self.assertRaises(ValueError):
            validate(self.plan, self.jobs, reports)

    def test_parameterized_class_names_are_recognized(self):
        reports = copy.deepcopy(self.reports)
        report = next(r for r in reports if r['requestedClasses'])
        old = report['tests'][0]['name']
        new = old.replace('/parity', '[grid=even,transform=hydrostatic]/parity')
        report['tests'][0]['name'] = new
        report['expectedTests'][0] = new
        self.assertTrue(validate(self.plan, self.jobs, reports))

    def test_wholly_exhaustive_class_requires_explicit_category_evidence(self):
        reports = copy.deepcopy(self.reports)
        report = reports[0]
        name = report['requestedClasses'][0]
        method = report['tests'].pop(0)['name']
        report['expectedTests'].remove(method)
        with self.assertRaises(ValueError):
            validate(self.plan, self.jobs, reports)
        report['excludedClasses'] = [name]
        with self.assertRaises(ValueError):
            validate(self.plan, self.jobs, reports)
        report['excludedTests'] = [method]
        self.assertTrue(validate(self.plan, self.jobs, reports))
        report['tests'].append(dict(name=method, passed=True, incomplete=False))
        report['expectedTests'].append(method)
        with self.assertRaises(ValueError):
            validate(self.plan, self.jobs, reports)

    def test_changed_batch_identity_and_cross_batch_duplicates_fail(self):
        reports = copy.deepcopy(self.reports)
        reports[0]['shard'] = 99
        with self.assertRaises(ValueError):
            validate(self.plan, self.jobs, reports)
        reports = copy.deepcopy(self.reports)
        reports[1]['tests'].append(reports[0]['tests'][0])
        reports[1]['expectedTests'].append(reports[0]['tests'][0]['name'])
        with self.assertRaises(ValueError):
            validate(self.plan, self.jobs, reports)


if __name__ == '__main__':
    unittest.main()
