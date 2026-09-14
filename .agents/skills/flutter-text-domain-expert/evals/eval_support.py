#!/usr/bin/env python3
"""Deterministic setup, artifact collection, and fixture execution for Antigravity evals."""

import argparse
from datetime import datetime, timezone
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import sys
import subprocess
import tempfile

TEXT_SKILL = '.agents/skills/flutter-text-domain-expert'
PACKAGES_URL = 'https://github.com/flutter/packages.git'


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def command(argv, cwd=None, *, check=True):
    result = subprocess.run(argv, cwd=cwd, capture_output=True, text=True)
    if check and result.returncode:
        raise ValueError(f'{argv[0]} failed ({result.returncode}): {result.stderr.strip()}')
    return result


def git(root, *args):
    return command(['git', '-c', 'core.fsmonitor=false', *args], cwd=root).stdout.strip()


def validate_run_id(value):
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*', value):
        raise ValueError('run-id must be a single alphanumeric/underscore/dash/dot name.')


def local_path(root, relative):
    relative = Path(relative)
    if relative.is_absolute() or '..' in relative.parts:
        raise ValueError(f'Expected a relative path within {root}: {relative}')
    target = (root / relative).resolve()
    if not target.is_relative_to(root.resolve()):
        raise ValueError(f'Path escapes its root: {relative}')
    return target


def load_case(path):
    path = Path(path).resolve()
    case = json.loads(path.read_text())
    if 'candidates' in case or 'task_prompt_template' in case:
        raise ValueError('Historical version-comparison case; use cases/issue_<number>/case.json.')
    for field in ('id', 'repository', 'issue_number', 'issue_url', 'task_prompt',
                  'source_ref', 'packages_source_ref', 'acceptance', 'split', 'verification'):
        if field not in case or case[field] in ('', None):
            raise ValueError(f'Missing case field: {field}')
    validate_run_id(case['id'])
    if not re.fullmatch(r'[\w.-]+/[\w.-]+', case['repository']):
        raise ValueError('repository must be owner/name')
    if not isinstance(case['issue_number'], int) or case['issue_number'] < 1:
        raise ValueError('issue_number must be a positive integer')
    acceptance = json.loads(local_path(path.parent, case['acceptance']).read_text())
    checks = acceptance.get('checks', [])
    ids = [item['id'] for item in checks]
    if not ids or len(ids) != len(set(ids)):
        raise ValueError('Acceptance check IDs must be nonempty and unique.')
    for item in checks:
        if not isinstance(item.get('required'), bool) or not item.get('expectation'):
            raise ValueError(f'Invalid acceptance check: {item}')
        if item.get('verification') not in ('fixture', 'evidence_review'):
            raise ValueError('Each check needs fixture or evidence_review verification.')
    covered = set()
    for fixture in case['verification']:
        if not local_path(path.parent, fixture['file']).is_file():
            raise ValueError(f'Missing fixture: {fixture["file"]}')
        destination = Path(fixture['destination'])
        if (destination.is_absolute() or '..' in destination.parts
                or not destination.as_posix().startswith('packages/flutter/test/')):
            raise ValueError('Framework fixture destination must be under packages/flutter/test/.')
        if not set(fixture['checks']).issubset(ids):
            raise ValueError('Fixture references an unknown acceptance check.')
        covered.update(fixture['checks'])
    for item in checks:
        if item['verification'] == 'fixture' and item['id'] not in covered:
            raise ValueError(f"No fixture declared for {item['id']}")
    return case


def resolve_ref(root, ref):
    return git(root, 'rev-parse', '--verify', '--end-of-options', f'{ref}^{{commit}}')


def resolve_remote(url, ref):
    if re.fullmatch(r'[0-9a-fA-F]{40}', ref):
        return ref.lower()
    full_ref = ref if ref.startswith('refs/') else f'refs/heads/{ref}'
    output = command(['git', 'ls-remote', '--exit-code', url, full_ref]).stdout.splitlines()
    if len(output) != 1:
        raise ValueError(f'Expected one remote revision for {full_ref}')
    return output[0].split()[0]


def capture_guidance(repo, definition, target):
    result = {}
    for group in ('shared', 'treatment_only'):
        files = {}
        for pattern in definition[group]:
            # A /** entry includes the complete directory, including future resources.
            root = local_path(repo, pattern.removesuffix('/**'))
            if not root.exists():
                raise ValueError(f'Missing guidance: {root}')
            paths = root.rglob('*') if root.is_dir() else [root]
            for path in sorted(paths):
                relative = path.relative_to(repo).as_posix()
                if any(fnmatch.fnmatch(relative, rule) for rule in definition['exclude']):
                    continue
                if path.is_symlink():
                    raise ValueError(f'Guidance symlinks must be made self-contained: {relative}')
                if path.is_file():
                    destination = target / relative
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, destination)
                    files[relative] = digest(destination)
        if not files:
            raise ValueError(f'No guidance captured for {group}')
        result[group] = files
    return result


def snapshot(args):
    case_path = args.case.resolve()
    case = load_case(case_path)
    repo = args.repo_root.resolve()
    if Path(git(repo, 'rev-parse', '--show-toplevel')).resolve() != repo:
        raise ValueError('--repo-root must be the Flutter repository root')
    run_dir = args.run_dir.resolve()
    validate_run_id(run_dir.name)
    if run_dir.exists():
        raise ValueError(f'Run directory already exists: {run_dir}')
    if args.repetitions < 1 or args.time_limit_minutes < 1:
        raise ValueError('Repetitions and time limit must be positive.')
    source_ref = args.source_ref or case['source_ref']
    packages_ref = args.packages_ref or case['packages_source_ref']
    source_sha = resolve_ref(repo, source_ref)
    packages_sha = resolve_remote(args.packages_url, packages_ref)
    fetch = ['gh', 'issue', 'view', str(case['issue_number']), '--repo', case['repository'],
             '--json', 'number,title,body,url']
    issue = json.loads(args.issue_json.read_text() if args.issue_json else command(fetch).stdout)
    if issue.get('number') != case['issue_number'] or issue.get('url') != case['issue_url']:
        raise ValueError('Issue snapshot does not match this case.')
    # Do not retain additional fields, even when importing a previous snapshot.
    issue = {key: issue[key] for key in ('number', 'title', 'body', 'url')}
    if not isinstance(issue['title'], str) or not isinstance(issue['body'], str):
        raise ValueError('Issue title/body must be strings.')
    eval_dir = Path(__file__).resolve().parent
    definition = json.loads((eval_dir / 'guidance.json').read_text())
    run_dir.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.capture-', dir=run_dir.parent) as temp:
        captured = Path(temp) / 'run'
        captured.mkdir()
        guidance = capture_guidance(repo, definition, captured / 'guidance')
        shutil.copytree(case_path.parent, captured / 'case')
        (captured / 'tools').mkdir()
        for name in ('eval_support.py', 'analyze_benchmark.py'):
            shutil.copy2(eval_dir / name, captured / 'tools' / name)
        for name in ('rubric.md', 'REPORT_TEMPLATE.md', 'guidance.json', 'eval_harness.py'):
            shutil.copy2(eval_dir / name, captured / name)
        write_json(captured / 'issue.json', issue)
        (captured / 'issue.md').write_text(f"# {issue['title']}\n\n{issue['url']}\n\n{issue['body']}\n")
        frozen = {p.relative_to(captured).as_posix(): digest(p)
                  for p in sorted(captured.rglob('*')) if p.is_file()}
        pairs = []
        for number in range(1, args.repetitions + 1):
            conditions = ['without_text_skill', 'with_text_skill']
            if secrets.randbelow(2):
                conditions.reverse()
            pairs.append({'pair': number, 'A': conditions[0], 'B': conditions[1]})
        manifest = {
            'run_id': run_dir.name, 'created_utc': datetime.now(timezone.utc).isoformat(),
            'case_id': case['id'], 'origin_repo': str(repo),
            'configuration_revision': git(repo, 'rev-parse', 'HEAD'),
            'source_ref_requested': source_ref, 'source_sha': source_sha,
            'packages_ref_requested': packages_ref, 'packages_sha': packages_sha,
            'packages_url': args.packages_url, 'guidance': guidance,
            'frozen_files': frozen, 'pairs': pairs,
            'issue_fetch_command': fetch, 'issue_reused_from': str(args.issue_json) if args.issue_json else None,
            'requested_runtime': {'model': args.model, 'reasoning': args.reasoning,
                                  'time_limit_minutes': args.time_limit_minutes},
            'runtime': {'antigravity_version': None, 'model': None, 'reasoning': None,
                        'permissions': None, 'discovery_check': None},
        }
        write_json(captured / 'manifest.json', manifest)
        captured.rename(run_dir)
    return manifest


def read_run(run_dir):
    manifest = json.loads((run_dir / 'manifest.json').read_text())
    for relative, expected in manifest['frozen_files'].items():
        path = local_path(run_dir, relative)
        if not path.is_file() or digest(path) != expected:
            raise ValueError(f'Frozen input changed or disappeared: {relative}')
    return manifest


def candidate_record(run_dir, pair, candidate):
    return run_dir / 'prepared' / f'pair_{pair}_{candidate}.json'


def prepare(args):
    run_dir = args.run_dir.resolve()
    manifest = read_run(run_dir)
    workspace = args.workspace.resolve()
    origin = Path(manifest['origin_repo']).resolve()
    if workspace == origin or workspace.is_relative_to(origin) or origin.is_relative_to(workspace):
        raise ValueError('Use an isolated Antigravity branch worktree outside the original checkout.')
    if Path(git(workspace, 'rev-parse', '--show-toplevel')).resolve() != workspace:
        raise ValueError('--workspace must be a worktree root.')
    if git(workspace, 'status', '--porcelain'):
        raise ValueError('Setup requires a clean, newly created worktree.')
    pair = next((item for item in manifest['pairs'] if item['pair'] == args.pair), None)
    if pair is None:
        raise ValueError('Pair is not declared in the manifest.')
    record_path = candidate_record(run_dir, args.pair, args.candidate)
    if record_path.exists():
        raise ValueError('Candidate already prepared; do not overwrite its starting state.')
    git(workspace, 'checkout', '--quiet', manifest['source_sha'])
    if git(workspace, 'rev-parse', 'HEAD') != manifest['source_sha']:
        raise ValueError('Checkout did not select the recorded source SHA.')
    definition = json.loads((run_dir / 'guidance.json').read_text())
    for pattern in definition['shared'] + definition['treatment_only']:
        path = local_path(workspace, pattern.removesuffix('/**'))
        if path.is_dir():
            shutil.rmtree(path)
        elif path.exists():
            path.unlink()
    condition = pair[args.candidate]
    groups = ['shared'] + (['treatment_only'] if condition == 'with_text_skill' else [])
    for group in groups:
        for relative in manifest['guidance'][group]:
            destination = local_path(workspace, relative)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(run_dir / 'guidance' / relative, destination)
    inputs = workspace / '.eval-input'
    inputs.mkdir()
    shutil.copy2(run_dir / 'issue.md', inputs / 'issue.md')
    # Record only setup changes. Candidate work is collected relative to this commit.
    git(workspace, 'add', '--all')
    git(workspace, '-c', 'user.name=Eval Setup', '-c', 'user.email=eval@localhost',
        '-c', 'commit.gpgsign=false', '-c', f'core.hooksPath={os.devnull}',
        'commit', '--quiet', '--allow-empty', '-m', 'Prepare isolated evaluation inputs')
    setup_sha = git(workspace, 'rev-parse', 'HEAD')
    packages = workspace / 'packages_repo'
    if packages.exists():
        raise ValueError('packages_repo already exists; refusing to overwrite it.')
    packages.mkdir()
    git(packages, 'init', '--quiet')
    git(packages, 'remote', 'add', 'origin', manifest['packages_url'])
    git(packages, 'fetch', '--quiet', '--depth', '1', 'origin', manifest['packages_sha'])
    git(packages, 'checkout', '--quiet', manifest['packages_sha'])
    record = {'workspace': str(workspace), 'setup_sha': setup_sha, 'condition': condition,
              'source_sha': manifest['source_sha'], 'packages_sha': manifest['packages_sha'],
              'pair': args.pair, 'candidate': args.candidate}
    record_path.parent.mkdir(exist_ok=True)
    write_json(record_path, record)
    return record


def export_patch(root, base, target, *, exclude=()):
    """Include staged, unstaged, committed, and added files without changing the index."""
    pathspecs = ['.', *[f':(exclude){path}' for path in exclude]]
    patch = command(['git', '-c', 'core.fsmonitor=false', 'diff', '--binary', base,
                     '--', *pathspecs], cwd=root).stdout
    added = command(['git', 'ls-files', '--others', '--exclude-standard', '-z'], cwd=root).stdout
    untracked_files = []
    for relative in filter(None, added.split('\0')):
        if any(relative == name or relative.startswith(name.rstrip('/') + '/') for name in exclude):
            continue
        path = root / relative
        if path.is_dir():  # A nested checkout is collected separately.
            continue
        result = command(['git', 'diff', '--no-index', '--binary', '--', os.devnull, relative],
                         cwd=root, check=False)
        if result.returncode not in (0, 1):
            raise ValueError(result.stderr)
        patch += result.stdout
        untracked_files.append(relative)
    target.write_text(patch)
    tracked = command(['git', 'diff', '--name-only', '-z', base, '--', *pathspecs], cwd=root).stdout
    return sorted(set(filter(None, tracked.split('\0'))) | set(untracked_files))


def collect(args):
    run_dir = args.run_dir.resolve()
    manifest = read_run(run_dir)
    record = json.loads(candidate_record(run_dir, args.pair, args.candidate).read_text())
    workspace = Path(record['workspace'])
    out = run_dir / f"pair_{args.pair}" / f"candidate_{args.candidate}" / 'artifacts'
    if out.exists():
        raise ValueError('Artifacts already captured; refusing to overwrite a submission.')
    out.mkdir(parents=True)
    files = {'flutter/flutter': export_patch(workspace, record['setup_sha'], out / 'flutter.patch',
                                             exclude=('packages_repo', 'flutter_stable'))}
    packages = workspace / 'packages_repo'
    if (packages / '.git').exists():
        files['flutter/packages'] = export_patch(packages, manifest['packages_sha'], out / 'packages.patch')
    else:
        files['flutter/packages'] = None
    exports = out / 'exports'
    exports.mkdir()
    for relative in files['flutter/flutter']:
        path = workspace / relative
        if path.is_file() and (path.suffix in ('.patch', '.yaml', '.yml') or 'changelog' in relative.lower()):
            destination = exports / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, destination)
    summary = {'files_modified': files,
               'prepared_state': {key: value for key, value in record.items() if key != 'condition'},
               'companion_checkout_present': (packages / '.git').exists(),
               'export_note': 'If companion checkout was removed, inspect exported patches to enumerate its changed files.'}
    write_json(out / 'artifacts.json', summary)
    return summary


def verify(args):
    case_path = args.case.resolve()
    case = load_case(case_path)
    workspace = args.workspace.resolve()
    output = args.output.resolve()
    if output.exists():
        raise ValueError('Verification output already exists.')
    output.parent.mkdir(parents=True, exist_ok=True)
    results = []
    for fixture in case['verification']:
        destination = local_path(workspace, fixture['destination'])
        if destination.exists():
            raise ValueError(f'Fixture destination already exists: {destination}')
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(local_path(case_path.parent, fixture['file']), destination)
        log = output.parent / f"{destination.stem}.jsonl"
        if log.exists():
            destination.unlink()
            raise ValueError(f'Fixture log already exists: {log}')
        argv = [str(workspace / 'bin/flutter'), 'test', '--reporter', 'json', fixture['destination']]
        try:
            with log.open('w') as stream:
                completed = subprocess.run(argv, cwd=workspace, stdout=stream, stderr=subprocess.STDOUT,
                                           timeout=args.timeout_seconds)
            exit_code = completed.returncode
            error = None
        except (subprocess.TimeoutExpired, OSError) as exception:
            exit_code, error = None, str(exception)
        finally:
            destination.unlink()
        results.append({'fixture': fixture['file'], 'checks': fixture['checks'],
                        'command': argv, 'exit_code': exit_code, 'error': error,
                        'log': str(log), 'log_sha256': digest(log)})
    result = {'fixtures': results,
              'unautomated_checks': [check['id'] for check in json.loads(
                  local_path(case_path.parent, case['acceptance']).read_text())['checks']
                  if check['verification'] == 'evidence_review'],
              'note': 'Inspect machine events; nonzero exit alone does not distinguish behavioral from setup failure.'}
    write_json(output, result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='operation', required=True)
    snap = sub.add_parser('snapshot', help='Capture inputs once; fetch issue without comments.')
    snap.add_argument('--case', type=Path, required=True)
    snap.add_argument('--run-dir', type=Path, required=True)
    snap.add_argument('--repo-root', type=Path, default=Path.cwd())
    snap.add_argument('--source-ref')
    snap.add_argument('--packages-ref')
    snap.add_argument('--packages-url', default=PACKAGES_URL)
    snap.add_argument('--issue-json', type=Path)
    snap.add_argument('--model', default='inherit')
    snap.add_argument('--reasoning', default='inherit')
    snap.add_argument('--repetitions', type=int, default=3)
    snap.add_argument('--time-limit-minutes', type=int, default=60)
    for name in ('prepare', 'collect'):
        item = sub.add_parser(name)
        item.add_argument('--run-dir', type=Path, required=True)
        item.add_argument('--pair', type=int, required=True)
        item.add_argument('--candidate', choices=('A', 'B'), required=True)
        if name == 'prepare':
            item.add_argument('--workspace', type=Path, required=True)
    verification = sub.add_parser('verify')
    verification.add_argument('--case', type=Path, required=True)
    verification.add_argument('--workspace', type=Path, required=True)
    verification.add_argument('--output', type=Path, required=True)
    verification.add_argument('--timeout-seconds', type=int, default=600)
    args = parser.parse_args()
    try:
        result = globals()[args.operation](args)
    except (ValueError, OSError, KeyError, json.JSONDecodeError) as error:
        parser.error(str(error))
    print(json.dumps(result, indent=2, sort_keys=True))
    if args.operation == 'verify' and any(item['exit_code'] != 0 for item in result['fixtures']):
        sys.exit(1)


if __name__ == '__main__':
    main()
