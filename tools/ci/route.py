#!/usr/bin/env python3
"""Resolve conservative CI work from changed paths; no GitHub API is required."""
import argparse
import json
import math
import os
from pathlib import Path, PurePosixPath
import subprocess

FAMILIES = ('constant', 'barotropic', 'sqg', 'hydrostatic', 'boussinesq')
FAMILY_TESTS = {
    'constant': ['TestCompiledKernelContract', 'TestCoreTransformInvariants'],
    'barotropic': ['TestBarotropicQGCompiledKernel', 'TestBarotropicQGPortableQualificationEvidence'],
    'sqg': ['TestPortableStratifiedQG', 'TestPortableStratifiedQGQualification', 'TestStratifiedQGCompiledKernel', 'TestPortableStratifiedQGQualificationEvidence'],
    'hydrostatic': ['TestPortableHydrostatic', 'TestPortableHydrostaticQualification', 'TestHydrostaticCompiledKernel', 'TestPortableHydrostaticQualificationEvidence'],
    'boussinesq': ['TestPortableBoussinesq', 'TestPortableBoussinesqQualification', 'TestBoussinesqCompiledKernel', 'TestPortableBoussinesqQualificationEvidence'],
}
SHARED_TESTS = ['TestPortableStableForcing', 'TestPortableForcingCompatibility',
                'TestCompiledKernelIntegration', 'TestStratifiedModalRecord',
                'TestPortableQualificationCatalog', 'TestPortableHistoricalQualification', 'TestPortableForwardIntegration',
                'TestPortableForwardIntegrationCatalog', 'TestPortableCompatibilityMatrix', 'TestPortableFieldSamplingMatrix', 'TestPortableNoMotionProfile',
                'TestPortableNoMotionRecovery', 'TestPortableDensityEventEvaluation', 'TestPortableDensityOutput',
                'TestPortableSamplingOutput']
COMPILED_MATLAB_TESTS = [
    'TestWVCompiledAdapterRestore', 'TestWVCompiledBackend',
    'TestWVCompiledBarotropicPrimitives', 'TestWVCompiledCoefficientOnlyRHS',
    'TestWVCompiledConfiguration',
    'TestWVCompiledConstantPrimitives', 'TestWVCompiledConstantVerticalCalculus',
    'TestWVCompiledConsumers',
    'TestWVCompiledEvaluationScope', 'TestWVCompiledPublicAdapters',
    'TestWVCompiledSourceIdentity', 'TestWVCompiledStratifiedPrimitives',
    'TestWVCompiledTransformBackend']
PERSISTENCE_TESTS = ['TestPortableRuntimeCompatibility', 'TestPortableRunRequestWriter',
                     'TestPortableObserverContracts', 'TestPortableForcingContracts',
                     'TestWVModelOutputPersistence', 'TestNetCDF', 'TestNetCDFHandleOwnership',
                     'TestShouldExcludeConjugatesPersistence', 'TestObservingSystems', 'TestWVModelIntegration',
                     'TestSpectralOutputRestart', 'TestSQGTracerConvenience']
MATLAB_CORE_TESTS = ['TestWVTransformInitialization', 'TestCoreTransformInvariants',
                     'TestOperationRegistrationAndCaching', 'TestTotalFlowComponent',
                     'TestFlowComponentSurfaceDiagnostics', 'TestPhysicalUnitMetadata',
                     'TestPublicInterpolationContract', 'TestRandomFlow', 'TestEtaTrueOperation',
                     'TestDensityDiagnosticReference', 'TestNoMotionProfileSolver',
                     'TestVerticalCalculus', 'TestNonlinearFlux', 'TestForcingLifecycle',
                     'TestForcingMathematicalContracts', 'TestTraditionalDamping',
                     'TestNarrowBandGeostrophicForcing', 'TestAdaptiveDampingResolution',
                     'TestEnergyDiagnostics']


TEST_COSTS = json.loads(Path(__file__).with_name('test_costs.json').read_text())['seconds']


def partition_tests(classes, phase_seconds=0):
    """Balance unchanged class inventories; estimates affect placement, not coverage."""
    count = max(1, min(4, math.ceil((phase_seconds + sum(TEST_COSTS.get(c, 60) for c in classes)) / 300)))
    groups = [dict(id=index, classes=[], estimatedSeconds=phase_seconds if index == 0 else 0) for index in range(count)]
    for name in sorted(classes, key=lambda c: (-TEST_COSTS.get(c, 60), c)):
        group = min(groups, key=lambda g: (g['estimatedSeconds'], g['id']))
        group['classes'].append(name)
        group['estimatedSeconds'] += TEST_COSTS.get(name, 60)
    for group in groups:
        group['classes'].sort()
    return groups


def select(paths, *, complete=False, migration=False, source_commit='', content_only_workflows=(), diff_base='', diff_head=''):
    """Union requests. Unrecognized paths select every focused scientific group."""
    flags = dict(cpp=False, diagnostics=False, documentation=False, analyzer=False,
                 packaging=False, crossRelease=False, persistence=False, matlabCore=False)
    families, tests, reasons = set(), set(), []
    direct_native_tests = set()
    content_only_workflows = sorted(set(content_only_workflows))
    if any(p not in paths or not p.startswith('.github/workflows/') or not p.endswith(('.yml', '.yaml')) for p in content_only_workflows):
        raise ValueError('Content-only workflow classification must refer to changed workflows')
    dependency_path = Path(__file__).with_name('test_dependencies.json')
    dependencies = json.loads(dependency_path.read_text())['classes']


    def scientific(reason, selected=FAMILIES):
        flags['cpp'] = flags['diagnostics'] = flags['crossRelease'] = True
        families.update(selected)
        reasons.append(reason)

    for raw in sorted(set(paths)):
        path = str(PurePosixPath(raw))
        if path.startswith('/') or '..' in PurePosixPath(path).parts or '\n' in path or '\r' in path:
            raise ValueError(f'Invalid repository-relative path: {raw!r}')
        lower = path.lower()
        if path.startswith(('.github/ci-evidence/', '.github/planning/')):
            reasons.append(f'{path}: evidence/planning; repository and provenance checks')
            continue
        if path == 'PortableRuntime/COMPATIBILITY.md':
            tests.add('TestPortableCompatibilityMatrix')
            reasons.append(f'{path}: generated compatibility documentation must match its catalog')
            continue
        if path in content_only_workflows:
            reasons.append(f'{path}: trigger/comment-only workflow change; lint and policy checks')
            continue
        if path.startswith(('tools/ci/', '.github/workflows/', '.github/actions/')) or path in ('buildfile.m', 'tools/runFocusedCI.m', 'tools/discoverTestCategory.m', 'tools/selectFocusedCISuite.m'):
            scientific(f'{path}: CI implementation exercises all routes')
            flags.update(documentation=True, analyzer=True, packaging=True, persistence=True, matlabCore=True)
            continue
        if path.startswith(('Documentation/', 'docs/')) or path in ('Gemfile', 'Gemfile.lock'):
            flags['documentation'] = True
            reasons.append(f'{path}: documentation generation/rendering')
            continue
        if path.endswith('.md') or path in ('.gitignore', 'LICENSE'):
            reasons.append(f'{path}: prose/repository metadata; repository and provenance checks')
            continue
        if path.startswith(('resources/', '.mpm/')) or any(word in lower for word in ('package-manifest', 'releaseverification', 'verifywavevortexmodelpackage', 'exportwavevortexmodel')):
            scientific(f'{path}: package boundary')
            flags.update(packaging=True, persistence=True, analyzer=True, documentation=True)
            continue
        if path.startswith('tools/') and any(word in lower for word in ('documentation', 'renderedwebsite')):
            flags.update(documentation=True, analyzer=True)
            tests.update(('TestDocumentationTools', 'TestUserDocumentation'))
            continue
        if path.startswith('UnitTests/') and path.endswith('.m'):
            flags['analyzer'] = flags['crossRelease'] = True
            # UnitTests also contains fixtures and helper classes. Only the
            # repository's top-level Test*.m entries are executable suites.
            test_path = PurePosixPath(path)
            if test_path.parent == PurePosixPath('UnitTests') and test_path.stem.startswith('Test'):
                tests.add(test_path.stem)
                if test_path.stem in dependencies:
                    if dependencies[test_path.stem]['nativeProbes']:
                        flags['cpp'] = True
                        direct_native_tests.add(test_path.stem)
                    reasons.append(f'{path}: registered test class and smoke baseline')
                    continue
            # Tests and helpers still exercise their numerical dependencies.
        if path.endswith('.m') and not path.startswith('UnitTests/'):
            flags['analyzer'] = flags['documentation'] = True
        if any(word in lower for word in ('model', 'observer', 'observing', 'checkpoint', 'netcdf', 'runrequest', 'runge', 'integrator', 'integrationstate', 'output', 'forcing', 'modalrecord')):
            scientific(f'{path}: shared state/forcing/persistence boundary')
            flags['persistence'] = True
            if path.endswith('.m'):
                flags['matlabCore'] = True
            continue
        selected = next((family for tokens, family in [
            (('boussinesq',), 'boussinesq'), (('hydrostatic',), 'hydrostatic'),
            (('stratifiedqg', 'stratified-qg', 'sqg'), 'sqg'), (('barotropic',), 'barotropic'),
            (('constantstratification', 'constant-stratification'), 'constant')]
            if any(token in lower for token in tokens)), None)
        if selected:
            scientific(f'{path}: {selected} numerical surface', (selected,))
            continue
        if any(word in lower for word in ('variablecatalog', 'variable-catalog', 'variable-supplement', 'variablecontracts', 'variableannotations', 'diagnostic')) or path.startswith(('Operations/', 'FlowComponents/')):
            scientific(f'{path}: shared diagnostic contracts')
            flags['matlabCore'] |= path.endswith('.m')
            continue
        if path.startswith(('CompiledKernel/', 'PortableRuntime/', 'tools/compiled-kernel/', '@WVTransform', 'Geometry/', 'Stratification/')):
            scientific(f'{path}: shared numerical dependency')
            flags['matlabCore'] |= path.endswith('.m')
            continue
        if path.startswith('UnitTests/') and path.endswith('.m'):
            # Standalone MATLAB test names outside the known portable groups.
            scientific(f'{path}: conservatively cover MATLAB test dependencies')
            flags['matlabCore'] = True
            continue
        scientific(f'{path}: unrecognized path; conservative shared coverage')
        flags.update(persistence=True, matlabCore=True, analyzer=True, documentation=True, packaging=True)
    if not paths or complete:
        scientific('Explicit complete qualification or unavailable/empty change inventory')
        flags.update(documentation=True, analyzer=True, packaging=True, persistence=True, matlabCore=True)
    if migration:
        # Executes each old required check before protection is switched.
        flags.update(documentation=True, analyzer=True)
        reasons.append('Migration: execute all legacy required MATLAB phases')
    for family in families:
        tests.update(FAMILY_TESTS[family])
    if families:
        tests.update(SHARED_TESTS)
        tests.update(COMPILED_MATLAB_TESTS)
    if flags['persistence']:
        tests.update(PERSISTENCE_TESTS)
    if flags['matlabCore']:
        tests.update(MATLAB_CORE_TESTS)
    if flags['diagnostics']:
        tests.update(('TestPortableVariableCatalog', 'TestPortableDiagnostics'))
    sanitized_tests = set(direct_native_tests)
    for family in families:
        sanitized_tests.update(FAMILY_TESTS[family])
    if families:
        sanitized_tests.update(SHARED_TESTS)
    if flags['diagnostics']:
        sanitized_tests.update(('TestPortableVariableCatalog', 'TestPortableDiagnostics'))
    if flags['persistence']:
        sanitized_tests.add('TestPortableRuntimeCompatibility')
    flags['matlab'] = bool(tests or flags['documentation'] or flags['analyzer'] or migration)
    flags['smoke'] = bool(tests or migration)
    flags['sanitized'] = bool(sanitized_tests)
    flags['crossRelease'] = bool(complete)
    releases = (['R2025b', 'R2026a'] if complete else ['R2025b']) if flags['matlab'] else []
    return dict(schema='wvm-ci-selection-v2', sourceCommit=source_commit,
                contentOnlyWorkflows=content_only_workflows, diffBase=diff_base, diffHead=diff_head,
                paths=sorted(set(paths)), complete=complete, migration=migration,
                **flags, families=sorted(families), matlabTests=sorted(tests), sanitizedTests=sorted(sanitized_tests),
                releases=releases, reasons=reasons, excludedTags=['optional', 'exhaustive'],
                matlabShards=partition_tests(tests, (60 if flags['smoke'] else 0) + (210 if flags['documentation'] else 0)) if flags['matlab'] else [],
                sanitizedShards=partition_tests(sanitized_tests) if flags['sanitized'] else [],
                deferredMethods=[] if complete else [
                    'TestPortableStratifiedQGQualification/longerContinuationMatchesMatlab',
                    'TestPortableHydrostaticQualification/longerContinuationMatchesMatlab',
                    'TestPortableBoussinesqQualification/longerContinuationMatchesMatlab'])


def workflow_execution(source):
    """Compare parsed execution semantics, retaining reusable-workflow inputs."""
    import yaml

    class UniqueLoader(yaml.BaseLoader):
        pass

    def mapping(loader, node):
        result = {}
        for key_node, value_node in node.value:
            key = loader.construct_object(key_node)
            if key in result:
                raise ValueError('Duplicate YAML key')
            result[key] = loader.construct_object(value_node)
        return result

    UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, mapping)
    try:
        value = yaml.load(source, Loader=UniqueLoader)
    except yaml.YAMLError as error:
        raise ValueError('Malformed workflow YAML') from error
    if not isinstance(value, dict) or not isinstance(value.get('jobs'), dict):
        raise ValueError('Not a workflow')
    triggers = value.pop('on', {})
    if isinstance(triggers, dict):
        for interface in ('workflow_call', 'workflow_dispatch'):
            interface_value = triggers.get(interface)
            if interface_value not in (None, '', 'null', 'Null', 'NULL', '~'):
                value[interface] = interface_value
    return value


def content_only_workflows(base, head, paths):
    selected = []
    for path in sorted(set(paths)):
        if not path.startswith('.github/workflows/') or not path.endswith(('.yml', '.yaml')):
            continue
        try:
            before = subprocess.check_output(['git', 'show', f'{base}:{path}'], stderr=subprocess.DEVNULL, text=True)
            after = subprocess.check_output(['git', 'show', f'{head}:{path}'], stderr=subprocess.DEVNULL, text=True)
            if workflow_execution(before) == workflow_execution(after):
                selected.append(path)
        except (subprocess.CalledProcessError, ValueError, TypeError):
            pass
    return selected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base')
    parser.add_argument('--head', default='HEAD')
    parser.add_argument('--merge-base', action='store_true',
                        help='Compare from the common ancestor for a complete pull-request diff')
    parser.add_argument('--paths-json')
    parser.add_argument('--complete', action='store_true')
    parser.add_argument('--migration', action='store_true')
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    head = subprocess.check_output(['git', 'rev-parse', args.head], text=True).strip()
    base = ''
    content_only = []
    if args.paths_json:
        paths = json.loads(Path(args.paths_json).read_text())
    elif args.base:
        base = args.base
        if args.merge_base:
            base = subprocess.check_output(['git', 'merge-base', base, head], text=True).strip()
        paths = subprocess.check_output(['git', 'diff', '--name-only', '--no-renames', '-z', base, head]).decode().rstrip('\0').split('\0')
        paths = [p for p in paths if p]
        content_only = content_only_workflows(base, head, paths)
    else:
        paths = []
    result = select(paths, complete=args.complete, migration=args.migration, source_commit=commit, content_only_workflows=content_only, diff_base=base, diff_head=head if base else '')
    Path(args.output).write_text(json.dumps(result, indent=2) + '\n')
    if os.getenv('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a') as stream:
            for name in ('matlab', 'smoke', 'sanitized', 'cpp', 'diagnostics', 'documentation', 'analyzer', 'packaging', 'crossRelease', 'complete', 'migration'):
                stream.write(f'{name}={str(result[name]).lower()}\n')
            stream.write('matlab_matrix=' + json.dumps({'include': [dict(release=release, shard=group['id']) for release in result['releases'] for group in result['matlabShards']]}) + '\n')
            stream.write('sanitized_matrix=' + json.dumps({'include': [dict(shard=group['id']) for group in result['sanitizedShards']]}) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
