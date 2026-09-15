#!/usr/bin/env python3
"""Select routine CI from the entire change, without running scientific studies.

Rules are deliberately explicit: an unclassified test needs a reviewed routing
entry, while unclassified production gets the compact invariant/integration
matrix. The JSON plan and its reasons are printed in the Actions job summary.
"""

import argparse
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess


CORE = ("TestCoreTransformInvariants",)
INTEGRATION = ("TestWVModelIntegration", "TestExponentialTimeFunctions")
FORCING = ("TestForcingLifecycle", "TestForcingMathematicalContracts")
OPERATIONS = ("TestOperationRegistrationAndCaching", "TestPublicInterpolationContract")
QG = (
    "TestFreeSurfaceQGVerticalCalculus",
    "TestFreeSurfaceQGDiagnostics/physicalInventoriesMatchIndependentSpatialIntegrals",
)
BOUSSINESQ = (
    "TestFreeSurfaceBoussinesqTransform/pureAndMixedStatesRoundTrip",
    "TestFreeSurfaceBoussinesqTransform/linearEquationsAndEndpointsHoldForMixedState",
    "TestFreeSurfaceNonlinearStage/nonlinearTendencyMatchesDirectStudyProjection",
)
THERMAL = ("TestFreeSurfaceThermalQG", "TestThermalNonlinear", "TestThermalDiagnostics")
PERSISTENCE = ("TestWVModelOutputPersistence", "TestShouldExcludeConjugatesPersistence")
COMPILED = ("TestCompiledKernelIntegration", "TestWVCompiledBackend")
# Concrete closures also need their numerical equations checked, beyond the
# common forcing registration/persistence contract.
FORCING_REGRESSIONS = {
    "WVAdaptiveDamping": (
        "TestBoussinesqAdaptiveDamping/ratesProtectLargeScalesAndShareHorizontalFilter",
        "TestNativeThermalAdaptiveDamping",
    ),
    "WVBottomFrictionQuadratic": ("TestFreeSurfaceQGBottomFriction/nondiffusiveSignedProjection",),
    "WVHorizontalDamping": ("TestTraditionalDamping/horizontalTendencyMatchesResolvedLaplacian",),
    "WVVerticalDamping": ("TestTraditionalDamping/verticalTendencyMatchesResolvedLaplacian",),
    "WVNarrowBandGeostrophicForcing": ("TestNarrowBandGeostrophicForcing/seededSubclassMatchesCompatibilityHelper",),
    "WVPseudoTopographicWaveGeneration": ("TestWVPseudoTopographicWaveGenerationProduction/variableStratificationMatchesOracleAndIdentities",),
}
DOC_TESTS = (
    "TestCoreAPIDocumentation", "TestForcingDocumentation", "TestUserDocumentation",
    "TestDocumentationTools",
)

# These classes are short regression contracts. Only smoke/full-tagged methods
# are eligible; optional native builds and exhaustive parameters stay deferred.
ROUTINE_TESTS = {
    selector.split("/")[0]
    for selector in CORE + INTEGRATION + FORCING + OPERATIONS + THERMAL
    + PERSISTENCE + COMPILED + DOC_TESTS + QG + BOUSSINESQ
} | {"TestCoreTransformInvariantSmoke", "TestFourierTransformXY", "TestFreeSurfaceQGVerticalCalculus",
     "TestPublishedWaveVortexBenchmark", "TestThreeInterfaceBenchmark",
     "TestNativeThermalAdaptiveDamping"}

# A changed study test still gets smoke, analyzer and compact scientific checks.
# Its long evidence run belongs to Extended CI. New test names do not silently
# enter this list: authors must supply a routine or deferred mapping explicitly.
DEFERRED_TESTS = {
    "TestShortSeasonalQG", "TestShortSeasonalQGSpatialAccuracy",
    "TestSeasonalResponseAssessment", "TestFreeSurfaceQGConservation",
    "TestFreeSurfaceQGDiffusionQualification", "TestThermalReadinessDiagnostics",
    "TestThermalReadinessRestart", "TestThermalCampaignResources",
    "TestWaveVortexTransformLayoutBenchmark", "TestWaveVortexObserverCostBenchmark",
    "TestWaveVortexBuiltinStorageBenchmark",
    "TestFreeSurfaceQGPerformance",
}
# Mixed benchmark classes include external worker/performance runs. Routine CI
# exercises their parsing, validation and small synthetic-fixture contracts.
PARTIAL_TESTS = {
    "TestCompiledPreviewBenchmark": ("TestCompiledPreviewBenchmark/publicNormalizationCarriesExactAndRSSMemory",),
    "TestWaveVortexBenchmark": (
        "TestWaveVortexBenchmark/suiteRegistryIsVersionedAndTransformSpecific",
        "TestWaveVortexBenchmark/scoringUsesEqualFamilyWeights",
        "TestWaveVortexBenchmark/referenceCreationRequiresExplicitGenericDirectory",
        "TestWaveVortexBenchmark/catalogScoringPreservesReferenceCalculation",
    ),
    "TestWVFourierStorageLayoutIntegrationBenchmark": (
        "TestWVFourierStorageLayoutIntegrationBenchmark/reducedRunComparesProductionWithFrozenReference",
        "TestWVFourierStorageLayoutIntegrationBenchmark/artifactsRoundTripAndStateIsRestored",
        "TestWVFourierStorageLayoutIntegrationBenchmark/invalidCaseRestoresState",
    ),
    "TestFreeSurfaceQGCoefficientStorageBenchmark": (
        "TestFreeSurfaceQGCoefficientStorageBenchmark/selectionIsValidated",
        "TestFreeSurfaceQGCoefficientStorageBenchmark/preferenceRequiresStatisticalAndPracticalSeparation",
    ),
}
# This removed test only checked recorded website datasets/charts. Its removal
# is covered by the artifact guard and actual documentation generation check.
RETIRED_ARTIFACT_TESTS = {"UnitTests/TestBenchmarkWebsiteDocumentation.m"}


DOC_TOOLS = {
    "build_website_documentation", "check_website_documentation", "compareDocumentationTrees",
    "documentationRepositoryRoot", "generateWebsiteDocumentation", "replaceDocumentationTree",
    "validateRenderedWebsite", "validateWebsiteDocumentation", "generateBenchmarkWebsiteDocumentation",
    "validateClassDocumentationDependency",
}
PACKAGE_TOOLS = {
    "configureCIEnvironment", "verifyWaveVortexModelPackage", "prepareWaveVortexModelReleaseCandidate",
}
RUNTIME_FOLDERS = {
    "ArgumentValidationFunctions", "FastTransforms", "FlowComponents", "Forcing",
    "Integrators", "ObservingSystems", "Operations",
}
CPP_SUFFIXES = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".cmake"}


def scientific_tests(path):
    """Small numerical contracts selected by the implementation's domain."""
    if "thermalgeneralizedenstrophy" in path.lower():
        return ("TestNativeThermalAdaptiveDamping",)
    if path == "+WVInternal/adaptiveSVVFilter.m":
        return FORCING + FORCING_REGRESSIONS["WVAdaptiveDamping"]
    if path.startswith("Forcing/") and PurePosixPath(path).stem in FORCING_REGRESSIONS:
        return FORCING + FORCING_REGRESSIONS[PurePosixPath(path).stem]
    if "Thermal" in path:
        return THERMAL
    if "FreeSurfaceBoussinesq" in path:
        return BOUSSINESQ
    if "FreeSurfaceQG" in path:
        return QG
    if path.startswith(("Forcing/", "WVForcing")):
        return FORCING
    if path.startswith(("Integrators/", "WVArrayIntegrator", "@WVModel/")):
        return INTEGRATION + PERSISTENCE
    if path.startswith(("ObservingSystems/", "WVObservingSystem", "WVModelOutput")):
        return PERSISTENCE + OPERATIONS
    if path.startswith(("Operations/", "WVOperation", "FlowComponents/", "WVFlowComponent")):
        return OPERATIONS + CORE
    if "Compiled" in path:
        return COMPILED
    if path.startswith(("@WVTransform", "@WVGeometry", "@WVStratification", "FastTransforms/")):
        return CORE
    return CORE + INTEGRATION


def classify_changes(paths, *, deleted=(), api_changed=(), dependency_changed=False):
    deleted, api_changed = set(deleted), set(api_changed)
    plan = dict(matlab=False, cpp=False, documentation=False, package=False,
                tests=[], analyzer_files=[], reasons=[], errors=[])
    tests, analyzer = set(), set()
    for path in sorted(set(paths)):
        p = PurePosixPath(path)
        first = p.parts[0]
        reason = "repository policy, study material, or authoring tooling: lightweight checks"
        runtime = first.startswith(("@", "+")) or first in RUNTIME_FOLDERS or (len(p.parts) == 1 and p.suffix == ".m")
        if path == "resources/mpackage.json" or (first == "tools" and p.stem in PACKAGE_TOOLS) or path == ".github/workflows/release-mpm.yml":
            plan["package"] = plan["matlab"] = True
            tests.update(CORE + INTEGRATION)
            if p.suffix == ".m" and path not in deleted:
                analyzer.add(path)
            reason = "package/install contract: clean installation, export and compact scientific regressions"
        elif first in {"PortableRuntime", "CompiledKernel"} or path.startswith("tools/compiled-kernel/") or p.suffix in CPP_SUFFIXES:
            if p.suffix not in {".md", ".png", ".svg"}:
                plan["cpp"] = True
                reason = "native implementation/build contract: C++ contracts and sanitizers"
        elif path.startswith(("Documentation/WebsiteDocumentation/", "docs/")) or path == "CHANGELOG.md" or (first == "tools" and p.stem in DOC_TOOLS) or (runtime and p.suffix == ".md"):
            plan["documentation"] = True
            reason = "canonical API/site documentation or generator: docs:check"
        elif path in RETIRED_ARTIFACT_TESTS and path in deleted:
            reason = "removed recorded-dataset publication check: artifact policy and documentation checks"
        elif first == "UnitTests" and p.suffix == ".m":
            plan["matlab"] = True
            name = p.stem
            if path in deleted:
                tests.update(CORE + INTEGRATION)
                reason = "removed test/helper: compact invariant and integration regressions"
            elif name in ROUTINE_TESTS:
                tests.add(name)
                reason = "changed regression class: its smoke/full methods plus smoke"
            elif name in PARTIAL_TESTS:
                tests.update(PARTIAL_TESTS[name])
                reason = "changed mixed-size regression class: reviewed compact methods plus smoke"
            elif name in DEFERRED_TESTS:
                tests.update(scientific_tests(path))
                reason = "changed long study: compact domain checks now; study remains scheduled/manual/release"
            elif name.startswith("Test"):
                plan["errors"].append(f"{path}: add a reviewed ROUTINE_TESTS, PARTIAL_TESTS or DEFERRED_TESTS entry in tools/ci/classify_changes.py")
            else:
                tests.update(CORE + INTEGRATION)
                reason = "shared test helper: conservative compact invariant and integration regressions"
            if name in DOC_TESTS:
                plan["documentation"] = True
        elif runtime or path == "buildfile.m":
            plan["matlab"] = True
            tests.update(scientific_tests(path))
            plan["documentation"] |= path in api_changed and path != "buildfile.m"
            reason = "MATLAB implementation: smoke, domain scientific regressions and changed-file analyzer"
        elif first in {"tools", "Documentation", "Benchmarks", "DeveloperExperiments", ".github"} or p.suffix in {".md", ".txt", ".png", ".svg", ".pdf"} or p.name in {".gitignore", ".gitattributes", "LICENSE"}:
            pass
        else:
            plan["matlab"] = True
            tests.update(CORE + INTEGRATION)
            reason = "unclassified production path: conservative compact invariant and integration regressions"
        if plan["matlab"] and p.suffix == ".m" and path not in deleted and not path.startswith(("tools/", "Documentation/", "Benchmarks/", "DeveloperExperiments/")):
            analyzer.add(path)
        plan["reasons"].append(f"{path}: {reason}")
    if dependency_changed:
        plan["package"] = plan["matlab"] = True
        tests.update(CORE + INTEGRATION)
        plan["reasons"].append("OceanKit dependency pin changed: clean installation, export and compact scientific regressions")
    plan["tests"], plan["analyzer_files"] = sorted(tests), sorted(analyzer)
    return plan


def parse_name_status(data):
    """Consume git diff --name-status -z, retaining both sides of renames."""
    fields = data.decode("utf-8").split("\0")
    paths, deleted = set(), set()
    index = 0
    while index < len(fields) and fields[index]:
        status, path = fields[index:index + 2]
        index += 2
        paths.add(path)
        if status.startswith(("R", "C")):
            new_path = fields[index]
            index += 1
            paths.add(new_path)
            if status.startswith("R"):
                deleted.add(path)
        elif status == "D":
            deleted.add(path)
    return paths, deleted


def git(*arguments):
    return subprocess.check_output([os.environ.get("GIT", "git"), *arguments])


def read_change(base, head):
    paths, deleted = parse_name_status(git("diff", "--name-status", "-z", "--find-renames", base, head))
    api_changed = set()
    dependency_changed = False
    for path in paths:
        # Signature/help edits can change generated API output. Implementation-
        # only changes need no documentation generation. Treat new/deleted APIs
        # conservatively; sidecar and website paths are classified above.
        if path.endswith(".m") or path.startswith(".github/workflows/"):
            patch = git("diff", "--no-ext-diff", "--unified=0", base, head, "--", path).decode("utf-8")
            changed_lines = [line[1:] for line in patch.splitlines() if line.startswith(("+", "-")) and not line.startswith(("+++", "---"))]
            class_definition = PurePosixPath(path).parent.name == "@" + PurePosixPath(path).stem
            if class_definition or any(re.match(r"\s*(%|function\b|classdef\b|properties\b|methods\b|arguments\b)", line) for line in changed_lines):
                api_changed.add(path)
            if path.startswith(".github/workflows/") and any("OCEANKIT_COMMIT:" in line for line in changed_lines):
                dependency_changed = True
    return classify_changes(paths, deleted=deleted, api_changed=api_changed, dependency_changed=dependency_changed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--plan", type=Path, required=True)
    args = parser.parse_args()
    plan = read_change(args.base, args.head)
    args.plan.write_text(json.dumps(plan, indent=2) + "\n")
    print(json.dumps(plan, indent=2))
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as output:
            for key in ("matlab", "cpp", "documentation", "package"):
                print(f"{key}={str(plan[key]).lower()}", file=output)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as summary:
            print("### Change-based CI selection\n\n```json", file=summary)
            print(json.dumps(plan, indent=2), file=summary)
            print("```\n\nFull, exhaustive and optional study suites run only through scheduled, manual or release validation.", file=summary)
    if plan["errors"]:
        raise SystemExit("\n".join(plan["errors"]))


if __name__ == "__main__":
    main()
