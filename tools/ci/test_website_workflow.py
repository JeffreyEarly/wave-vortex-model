"""Publication preserves download contracts without storing generated payloads."""
import unittest

from check_artifact_policy import publication_output_errors
from route import select
from test_workflows import workflow


class WebsitePublicationContracts(unittest.TestCase):
    def test_download_payloads_cannot_be_reintroduced_or_registered(self):
        for prefix in ('docs/benchmarks/data/', 'docs/benchmarks/raw/'):
            for name in ('existing.json', 'new-unregistered-output.json'):
                path = prefix + name
                with self.subTest(path=path):
                    self.assertTrue(publication_output_errors([path], {}))
                    self.assertTrue(publication_output_errors([path], {path: 'published-asset'}))
                    self.assertTrue(publication_output_errors([], {path: 'published-asset'}))
        self.assertEqual(publication_output_errors(['docs/benchmarks/downloads.json'],
                         {'docs/benchmarks/downloads.json': 'source-configuration'}), [])

    def test_publication_builds_before_main_only_deploy(self):
        page = workflow('website.yml')
        self.assertNotIn('schedule', page['on'])
        self.assertEqual(page['on']['push']['branches'], ['main'])
        self.assertIn('workflow_dispatch', page['on'])
        self.assertEqual(page['permissions'], {'contents': 'read'})
        build = page['jobs']['build']
        self.assertNotIn('matlab', str(build).lower())
        steps = build['steps']
        stage = next(i for i,s in enumerate(steps) if s.get('name') == 'Stage website downloads')
        render = next(i for i,s in enumerate(steps) if s.get('uses') == 'actions/jekyll-build-pages@v1')
        verify = next(i for i,s in enumerate(steps) if '--verify-staged' in s.get('run', ''))
        upload = next(i for i,s in enumerate(steps) if s.get('uses') == 'actions/upload-pages-artifact@v4')
        self.assertLess(stage, render)
        self.assertLess(render, verify)
        self.assertLess(verify, upload)
        self.assertIn('cp source/docs/CNAME rendered-site/CNAME', steps[verify]['run'])
        self.assertIn('cmp source/docs/CNAME rendered-site/CNAME', steps[verify]['run'])
        deploy = page['jobs']['deploy']
        self.assertEqual(deploy['needs'], 'build')
        self.assertEqual(deploy['if'], "github.ref == 'refs/heads/main' && github.event_name != 'pull_request'")
        self.assertEqual(deploy['permissions'], {'pages': 'write', 'id-token': 'write'})
        self.assertEqual(deploy['environment']['name'], 'github-pages')

    def test_ci_and_publication_stage_outside_source_checkout(self):
        for name in ('website.yml', 'ci-matlab.yml'):
            job = next(j for j in workflow(name)['jobs'].values() if 'steps' in j)
            stage = next(s for s in job['steps'] if s.get('name') == 'Stage website downloads')
            self.assertIn('cp -R source/docs website-source', stage['run'])
            self.assertIn('source/tools/website_downloads.py', stage['run'])
            render = next(s for s in job['steps'] if s.get('uses') == 'actions/jekyll-build-pages@v1')
            self.assertEqual(render['with']['source'], './website-source')
            self.assertTrue(any('--verify-staged' in s.get('run', '') for s in job['steps']))

    def test_staging_tools_select_documentation_contracts(self):
        for path in ('tools/website_downloads.py', 'tools/stageBenchmarkWebsiteDownloads.m'):
            selection = select([path])
            self.assertTrue(selection['documentation'])
            self.assertIn('TestBenchmarkWebsiteDocumentation', selection['matlabTests'])
