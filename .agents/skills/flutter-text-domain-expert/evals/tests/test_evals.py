"""Behavioral checks for eval input isolation, artifact export, and telemetry."""

import argparse
import json
from pathlib import Path
import sys
import tempfile
import unittest

EVAL_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(EVAL_DIR))
import analyze_benchmark
import eval_harness
import eval_support


class EvaluationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def repository(self, name):
        root = self.root / name
        root.mkdir()
        eval_support.git(root, 'init', '--quiet')
        eval_support.git(root, 'config', 'user.name', 'Eval Test')
        eval_support.git(root, 'config', 'user.email', 'eval-test@localhost')
        (root / 'source.dart').write_text('original source\n')
        eval_support.git(root, 'add', '.')
        eval_support.git(root, '-c', 'commit.gpgsign=false', 'commit', '--quiet', '-m', 'source')
        return root

    def snapshot(self):
        repo = self.repository('origin')
        package = self.repository('packages')
        stale = repo / '.agents/skills/flutter-text-domain-expert/evals/old_answer.md'
        stale.parent.mkdir(parents=True)
        stale.write_text('old evaluator answer')
        (stale.parent.parent / 'SKILL.md').write_text('historical skill')
        eval_support.git(repo, 'add', '.')
        eval_support.git(repo, '-c', 'commit.gpgsign=false', 'commit', '--quiet', '-m', 'old guidance')
        for relative, text in {
            '.agents/rules/code-freeze.md': 'shared current rule',
            '.agents/skills/material-cupertino-packages/SKILL.md': 'shared current skill',
            '.agents/skills/flutter-text-domain-expert/SKILL.md': 'current uncommitted skill',
            '.agents/skills/flutter-text-domain-expert/references/notes.md': 'reference',
            '.agents/skills/flutter-text-domain-expert/evals/secret.md': 'evaluator answer',
        }.items():
            path = repo / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        issue = self.root / 'issue.json'
        issue.write_text(json.dumps({'number': 141775, 'title': 'Issue', 'body': 'Report',
                                    'url': 'https://github.com/flutter/flutter/issues/141775',
                                    'comments': ['must not leak']}))
        run = self.root / 'run'
        args = argparse.Namespace(
            case=EVAL_DIR / 'cases/issue_141775/case.json', repo_root=repo, run_dir=run,
            source_ref='HEAD', packages_ref=eval_support.git(package, 'rev-parse', 'HEAD'),
            packages_url=str(package), issue_json=issue, model='test-model', reasoning='test',
            repetitions=1, time_limit_minutes=1,
        )
        manifest = eval_support.snapshot(args)
        return repo, run, manifest, args

    def test_two_prepared_worktrees_differ_only_in_text_guidance(self):
        repo, run, manifest, _ = self.snapshot()
        prepared = {}
        for candidate in ('A', 'B'):
            workspace = self.root / candidate
            eval_support.git(repo, 'worktree', 'add', '--quiet', '--detach', str(workspace), manifest['source_sha'])
            record = eval_support.prepare(argparse.Namespace(
                run_dir=run, workspace=workspace, pair=1, candidate=candidate))
            prepared[record['condition']] = workspace
            self.assertEqual((workspace / 'source.dart').read_text(), 'original source\n')
            self.assertEqual((workspace / '.agents/rules/code-freeze.md').read_text(), 'shared current rule')
            self.assertEqual((workspace / 'packages_repo/source.dart').read_text(), 'original source\n')
            self.assertNotIn('comments', json.loads((run / 'issue.json').read_text()))
            self.assertEqual((workspace / '.eval-input/issue.md').read_text(), (run / 'issue.md').read_text())
            self.assertFalse((workspace / '.agents/skills/flutter-text-domain-expert/evals').exists())
            out = eval_support.collect(argparse.Namespace(run_dir=run, pair=1, candidate=candidate))
            self.assertEqual(out['files_modified']['flutter/flutter'], [])
        self.assertFalse((prepared['without_text_skill'] / eval_support.TEXT_SKILL).exists())
        self.assertEqual((prepared['with_text_skill'] / eval_support.TEXT_SKILL / 'SKILL.md').read_text(),
                         'current uncommitted skill')
        self.assertEqual(eval_support.git(repo, 'rev-parse', 'HEAD'), manifest['source_sha'])

    def test_input_mutation_and_overwriting_are_rejected(self):
        _, run, _, args = self.snapshot()
        with self.assertRaisesRegex(ValueError, 'already exists'):
            eval_support.snapshot(args)
        (run / 'issue.md').write_text('modified input')
        with self.assertRaisesRegex(ValueError, 'Frozen input changed'):
            eval_support.read_run(run)

    def test_original_workspace_is_never_prepared(self):
        repo, run, manifest, _ = self.snapshot()
        with self.assertRaisesRegex(ValueError, 'isolated Antigravity'):
            eval_support.prepare(argparse.Namespace(run_dir=run, workspace=repo, pair=1, candidate='A'))
        self.assertEqual(eval_support.git(repo, 'rev-parse', 'HEAD'), manifest['source_sha'])

    def test_fixture_runner_preserves_failure_evidence_and_removes_injection(self):
        workspace = self.root / 'verification'
        executable = workspace / 'bin/flutter'
        executable.parent.mkdir(parents=True)
        executable.write_text('#!/bin/sh\necho fixture-failed\nexit 1\n')
        executable.chmod(0o755)
        output = self.root / 'verification-results.json'
        result = eval_support.verify(argparse.Namespace(
            case=EVAL_DIR / 'cases/issue_141775/case.json', workspace=workspace,
            output=output, timeout_seconds=10))
        self.assertEqual(result['fixtures'][0]['exit_code'], 1)
        self.assertFalse((workspace / 'packages/flutter/test/widgets/eval_selection_actions_test.dart').exists())
        self.assertEqual(Path(result['fixtures'][0]['log']).read_text(), 'fixture-failed\n')
        self.assertIn('native_support', result['unautomated_checks'])

    def test_ref_and_run_validation(self):
        case_path = EVAL_DIR / 'cases/issue_141775/case.json'
        case = eval_support.load_case(case_path)
        prompt = eval_harness.build_orchestrator_prompt(
            case, case_path, source_ref='ref with spaces; $(touch surprise)', run_id='unit-run')
        # Shell-parse the actual setup command to verify the ref remains one argument.
        import shlex
        argv = shlex.split(next(line for line in prompt.splitlines() if line.startswith('python3 ') and ' snapshot ' in line))
        self.assertEqual(argv[argv.index('--source-ref') + 1], 'ref with spaces; $(touch surprise)')
        with self.assertRaises(ValueError):
            eval_harness.build_orchestrator_prompt(case, case_path, run_id='../escape')
        with self.assertRaises(ValueError):
            eval_harness.build_orchestrator_prompt(case, case_path, repetitions=0)
        malformed = self.root / 'legacy.json'
        malformed.write_text('{"candidates": {}}')
        with self.assertRaisesRegex(ValueError, 'Historical'):
            eval_support.load_case(malformed)

    def test_exported_patch_includes_added_files_without_staging_them(self):
        repo = self.repository('patch-source')
        base = eval_support.git(repo, 'rev-parse', 'HEAD')
        (repo / 'source.dart').write_text('fixed source\n')
        (repo / 'new test.dart').write_text('new test\n')
        before = eval_support.git(repo, 'status', '--porcelain')
        patch = self.root / 'submission.patch'
        files = eval_support.export_patch(repo, base, patch)
        self.assertEqual(files, ['new test.dart', 'source.dart'])
        self.assertEqual(eval_support.git(repo, 'status', '--porcelain'), before)
        verify = self.root / 'verification'
        eval_support.git(repo, 'worktree', 'add', '--quiet', '--detach', str(verify), base)
        eval_support.git(verify, 'apply', str(patch))
        self.assertEqual((verify / 'new test.dart').read_text(), 'new test\n')
        self.assertEqual((verify / 'source.dart').read_text(), 'fixed source\n')

    def test_missing_logs_do_not_become_zero_usage(self):
        result = analyze_benchmark.analyze_candidate('id', 'candidate', logs_dir=self.root)
        self.assertIsNone(result['planner_responses'])
        self.assertIsNone(result['estimated_transcript_tokens'])
        self.assertIsNone(result['runtime_usage'])
        self.assertEqual(result['guidance_consultation']['flutter-text-domain-expert']['status'], 'unknown')
        self.assertIsNone(analyze_benchmark.percent_delta(0, 100))

    def test_cli_usage_is_preserved_and_attributed_to_its_conversation(self):
        usage_path = self.root / 'cli-output.json'
        usage = {'input_tokens': 100, 'output_tokens': 20, 'thinking_tokens': 8,
                 'cache_read_tokens': 0, 'total_tokens': 120}
        usage_path.write_text(json.dumps({'conversation_id': 'candidate-id', 'usage': usage,
                                         'duration_seconds': 6.5, 'num_turns': 1}))
        result = analyze_benchmark.analyze_candidate(
            'candidate-id', 'candidate', logs_dir=self.root, usage_file=usage_path)
        self.assertEqual(result['runtime_usage']['usage'], usage)
        self.assertEqual(result['runtime_usage']['duration_seconds'], 6.5)
        self.assertEqual(result['runtime_usage']['descendant_accounting'], 'unknown')
        with self.assertRaisesRegex(ValueError, 'different conversation'):
            analyze_benchmark.analyze_candidate(
                'wrong-id', 'candidate', logs_dir=self.root, usage_file=usage_path)

    def test_paths_skill_reads_and_partial_logs(self):
        workspace = self.root / 'workspace'
        skill = workspace / '.agents/skills/material-cupertino-packages/SKILL.md'
        events = [
            {'type': 'PLANNER_RESPONSE', 'tool_calls': [
                {'name': 'view_file', 'parameters': {'AbsolutePath': str(workspace / 'widgets/shared_test.dart')}},
                {'name': 'view_file', 'parameters': {'AbsolutePath': json.dumps(str(workspace / 'material/shared_test.dart'))}},
                {'name': 'view_file', 'parameters': {'AbsolutePath': str(skill)}},
            ]},
            {'type': 'GENERIC', 'content': f'File Path: `file://{skill}`\ncontent'},
        ]
        (self.root / 'transcript.jsonl').write_text('\n'.join(map(json.dumps, events)) + '\n{bad json\n')
        result = analyze_benchmark.analyze_candidate('id', 'candidate', logs_dir=self.root, workspace=workspace)
        self.assertEqual(result['tool_calls'], 3)
        self.assertIn('widgets/shared_test.dart', result['files_viewed_observed'])
        self.assertIn('material/shared_test.dart', result['files_viewed_observed'])
        self.assertIsNone(result['estimated_transcript_tokens'])
        consultation = result['guidance_consultation']['material-cupertino-packages']
        self.assertEqual(consultation['status'], 'observed')
        self.assertEqual(consultation['automatic_activation'], 'unknown')
        self.assertTrue(any('partial' in message for message in result['limitations']))


if __name__ == '__main__':
    unittest.main()
