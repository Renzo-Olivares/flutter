#!/usr/bin/env python3
"""Extract observable Antigravity metrics; do not infer model usage or activation."""

import argparse
from collections import Counter
import json
from pathlib import Path
import re

SKILLS = ('flutter-text-domain-expert', 'material-cupertino-packages')


def read_events(path, warnings):
    if not path.exists():
        warnings.append(f'Missing log: {path.name}')
        return None
    events = []
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if not line.strip():
            continue
        try:
            value = json.loads(line)
            if not isinstance(value, dict):
                raise ValueError('Expected an object')
            events.append(value)
        except (ValueError, json.JSONDecodeError):
            warnings.append(f'Malformed event at {path.name}:{number}')
    return events


def file_name(value, workspace=None):
    # The CLI sometimes JSON-encodes individual argument strings inside args.
    try:
        decoded = json.loads(value)
        if isinstance(decoded, str):
            value = decoded
    except (ValueError, TypeError):
        pass
    path = Path(value.removeprefix('file://'))
    if workspace:
        try:
            return path.resolve().relative_to(Path(workspace).resolve()).as_posix()
        except ValueError:
            pass
    # Preserve directory identity, including for files outside the main repo.
    return path.as_posix()


def skill_name(path):
    if '/evals/' in path:
        return None
    return next((name for name in SKILLS if f'/{name}/' in '/' + path), None)


def analyze_candidate(conv_id, name, *, logs_dir=None, workspace=None, artifacts=None,
                      usage_file=None, verbose=False):
    if logs_dir:
        logs = Path(logs_dir)
    else:
        roots = [Path.home() / '.gemini' / runtime / 'brain' / conv_id / '.system_generated/logs'
                 for runtime in ('antigravity', 'antigravity-cli')]
        present = [path for path in roots if path.exists()]
        if len(present) > 1:
            raise ValueError('Conversation exists in both IDE and CLI logs; specify --logs explicitly.')
        logs = present[0] if present else roots[0]
    warnings = []
    events = read_events(logs / 'transcript.jsonl', warnings)
    full = read_events(logs / 'transcript_full.jsonl', warnings)
    planner, tools = 0, Counter()
    viewed, edit_requests = set(), set()
    requested = {name: set() for name in SKILLS}
    loaded = {name: set() for name in SKILLS}
    if events is not None:
        for event in events:
            if event.get('type') == 'PLANNER_RESPONSE':
                planner += 1
                for call in event.get('tool_calls') or []:
                    if not isinstance(call, dict):
                        warnings.append('Unrecognized tool-call record')
                        continue
                    function = call.get('function') or {}
                    name_of_tool = call.get('name') or function.get('name') or 'unknown'
                    tools[name_of_tool] += 1
                    arguments = call.get('parameters') or call.get('args') or function.get('arguments') or {}
                    if isinstance(arguments, str):
                        try:
                            arguments = json.loads(arguments)
                        except ValueError:
                            arguments = {}
                    if not isinstance(arguments, dict):
                        continue
                    if name_of_tool == 'view_file' and arguments.get('AbsolutePath'):
                        path = file_name(arguments['AbsolutePath'], workspace)
                        viewed.add(path)
                        skill = skill_name(path)
                        if skill:
                            requested[skill].add(path)
                    if name_of_tool in ('replace_file_content', 'multi_replace_file_content', 'write_to_file'):
                        if arguments.get('TargetFile'):
                            edit_requests.add(file_name(arguments['TargetFile'], workspace))
            elif event.get('type') == 'GENERIC' and event.get('status') != 'ERROR':
                content = event.get('content')
                if not isinstance(content, str):
                    continue
                for value in re.findall(r'^File Path: `file://([^`]+)`', content, re.MULTILINE):
                    path = file_name(value, workspace)
                    viewed.add(path)
                    skill = skill_name(path)
                    if skill:
                        loaded[skill].add(path)
    if events is not None and not planner:
        warnings.append('No recognized PLANNER_RESPONSE events; counters are unavailable.')
    if events is not None and any('Malformed event' in warning for warning in warnings):
        warnings.append('Counts are partial because malformed events were skipped.')
    chars = None
    if full is not None:
        text = [event.get(key) for event in full for key in ('content', 'thinking')
                if isinstance(event.get(key), str)]
        if text:
            chars = sum(map(len, text))
        else:
            warnings.append('Full transcript has no recognized text fields.')
    artifact_files = None
    if artifacts:
        artifact_path = Path(artifacts) / 'artifacts.json'
        if artifact_path.exists():
            artifact_files = json.loads(artifact_path.read_text()).get('files_modified')
        else:
            warnings.append('Artifact file manifest unavailable.')
    usage = json.loads(Path(usage_file).read_text()) if usage_file else None
    if isinstance(usage, dict) and 'conversation_id' in usage and isinstance(usage.get('usage'), dict):
        if usage['conversation_id'] != conv_id:
            raise ValueError('Runtime usage belongs to a different conversation.')
        # Observed agy --output-format json schema. Do not assume descendant inclusion.
        usage = {'source': str(Path(usage_file).resolve()), 'scope': 'agy print invocation',
                 'conversation_id': conv_id, 'usage': usage['usage'],
                 'duration_seconds': usage.get('duration_seconds'),
                 'num_turns': usage.get('num_turns'), 'descendant_accounting': 'unknown'}
    if usage is not None and (not isinstance(usage, dict) or not usage.get('source') or not usage.get('scope')):
        raise ValueError('Provide agy output JSON or usage JSON identifying source and accounting scope.')
    consultation = {}
    for skill in SKILLS:
        consultation[skill] = {
            'status': 'observed' if loaded[skill] else ('not_observed' if events is not None else 'unknown'),
            'successful_reads': sorted(loaded[skill]), 'read_requests': sorted(requested[skill]),
            'automatic_activation': 'unknown',
        }
    result = {
        'conv_id': conv_id, 'name': name, 'planner_responses': planner if planner else None,
        'tool_calls': sum(tools.values()) if planner else None, 'tools': dict(tools),
        'files_viewed_observed': sorted(viewed) if events is not None else None,
        'file_edit_requests': sorted(edit_requests) if events is not None else None,
        'files_modified_from_artifacts': artifact_files, 'guidance_consultation': consultation,
        'runtime_usage': usage, 'transcript_characters': chars,
        'estimated_transcript_tokens': chars // 4 if chars is not None else None,
        'limitations': warnings + [
            'Tool-based file observations do not cover shell reads/edits or all runtime schemas.',
            'No observed read is not proof of non-use; injected skill/rule content may not be logged here.',
            'Character estimates describe recorded text size, not input/output/reasoning token consumption.',
            'This record covers one conversation; aggregate measured descendants separately exactly once.',
        ],
    }
    if verbose:
        print(json.dumps(result, indent=2))
    return result


def percent_delta(before, after):
    if before in (None, 0) or after is None:
        return None
    return (after - before) * 100 / before


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('conversation_a')
    parser.add_argument('conversation_b')
    for suffix in ('a', 'b'):
        parser.add_argument(f'--logs-{suffix}', type=Path)
        parser.add_argument(f'--workspace-{suffix}', type=Path)
        parser.add_argument(f'--artifacts-{suffix}', type=Path)
        parser.add_argument(f'--usage-{suffix}', type=Path,
                            help='agy --output-format json output, or usage JSON with source/accounting scope.')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        candidates = [analyze_candidate(
            getattr(args, f'conversation_{suffix}'), f'Candidate {suffix.upper()}',
            logs_dir=getattr(args, f'logs_{suffix}'), workspace=getattr(args, f'workspace_{suffix}'),
            artifacts=getattr(args, f'artifacts_{suffix}'), usage_file=getattr(args, f'usage_{suffix}'),
        ) for suffix in ('a', 'b')]
        result = {'candidates': candidates, 'delta_percent': {
            key: percent_delta(candidates[0][key], candidates[1][key])
            for key in ('planner_responses', 'tool_calls', 'estimated_transcript_tokens')
        }}
        encoded = json.dumps(result, indent=2) + '\n'
        if args.output:
            with args.output.open('x') as stream:
                stream.write(encoded)
        print(encoded, end='')
    except (ValueError, OSError, json.JSONDecodeError) as error:
        parser.error(str(error))


if __name__ == '__main__':
    main()
