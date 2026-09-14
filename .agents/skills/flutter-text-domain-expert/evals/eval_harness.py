#!/usr/bin/env python3
"""Generate an Antigravity orchestration prompt; this does not launch agents."""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import secrets
import shlex
import subprocess
import sys

from eval_support import load_case, validate_run_id

EVAL_REL = Path('.agents/skills/flutter-text-domain-expert/evals')


def build_orchestrator_prompt(case, case_path, *, source_ref=None,
                              packages_ref=None, model='inherit', reasoning='inherit',
                              repetitions=3, time_limit_minutes=60, run_id=None,
                              issue_json=None):
    if repetitions < 1 or time_limit_minutes < 1:
        raise ValueError('Repetitions and time limit must be positive.')
    run_id = run_id or (
        f"{case['id']}_{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}_{secrets.token_hex(3)}"
    )
    validate_run_id(run_id)
    run_dir = EVAL_REL / 'runs' / run_id
    command = [
        'python3', str(EVAL_REL / 'eval_support.py'), 'snapshot',
        '--case', str(Path(case_path).resolve()), '--run-dir', str(run_dir),
        '--source-ref', source_ref or case['source_ref'],
        '--packages-ref', packages_ref or case['packages_source_ref'],
        '--model', model, '--reasoning', reasoning, '--repetitions', str(repetitions),
        '--time-limit-minutes', str(time_limit_minutes),
    ]
    if issue_json:
        command.extend(['--issue-json', str(Path(issue_json).resolve())])
    fetch = shlex.join([
        'gh', 'issue', 'view', str(case['issue_number']), '--repo', case['repository'],
        '--json', 'number,title,body,url',
    ])
    return f'''Run the {case['id']} evaluation in Antigravity.

Compare WITHOUT the text skill against WITH its current revision. Both conditions
retain the same current code-freeze rule and material-cupertino-packages skill.
This measures the incremental benefit of flutter-text-domain-expert.

Run setup commands from the main Flutter repository. Do not change the user's main
checkout. Keep this protocol and evaluator material out of candidate context.

1. Capture inputs before starting setup agents

Run:
{shlex.join(command)}

This creates {run_dir}/manifest.json, freezes current guidance including uncommitted
edits, resolves source refs once, and captures the issue report. For new input the
helper executes exactly:
{fetch}
Do not pass --comments. Include only the title/body and necessary reproduction
artifacts, not comments or timeline discussions. Reuse issue.md/issue.json across
all repetitions. With --issue-json, reuse that previous snapshot instead of fetching.
Freeze necessary attachments before launch and record their hashes in the manifest.

Use the manifest's resolved source SHAs, not moving branch names. Source checkout
selects Flutter code; guidance comes from the captured current working tree.
Verify the issue still applies and the companion source is compatible. An already
resolved case is unsuitable. Complete equivalent SDK/dependency preparation before candidate timers start.
Record Antigravity version, actual Gemini model and
reasoning setting, tool/permission configuration, and SDK/platform availability.
Requested model: {model}; reasoning: {reasoning}. Resolve "inherit" to the actual
selection before launch. Do not infer settings from a report name or assume API-only
controls such as seeds exist. Use identical candidate settings.

2. Prepare Antigravity-managed worktrees

For each of {repetitions} paired repetitions, invoke two SETUP subagents using
invoke_subagent with Workspace: "branch". These are not measured candidates.
Use the manifest's neutral Candidate A / Candidate B mapping for that repetition.

In each setup worktree run the snapshotted helper by absolute path:
python3 <absolute-run-dir>/tools/eval_support.py prepare --run-dir <absolute-run-dir> --workspace <setup-worktree> --pair <pair-number> --candidate <A-or-B>

The helper executes git checkout --quiet <resolved-source-sha> and verifies HEAD.
It replaces historical guidance with the captured shared guidance and includes the
text skill only for treatment. It prepares identical pinned companion source and
records a local setup commit so setup edits are excluded from submitted changes.
Treat checkout failures as setup errors; never continue on the wrong revision.

Before real cases, perform a separate throwaway discovery smoke check in the installed
Antigravity version. Confirm independent conversations attached to the prepared workspaces discover
their skill catalogs and rules: shared guidance in both, text skill only in treatment. Check global/legacy
skill locations and inherited system instructions for contamination. Fresh history
alone is insufficient. Record evidence under runtime.discovery_check in the manifest.
If the runtime cannot provide the intended setup, report a setup error.
Do not ask measured candidates to enumerate skills or give them the smoke-check task.

Configure candidate read scopes to exclude the evaluator/run directory, original
checkout, sibling worktrees, and other agents' transcripts. Use neutral candidate
instructions without evaluator expectations or preferred solutions.

3. Launch fresh measured candidates

After setup, launch each measured candidate as an independent Antigravity conversation
attached to its prepared worktree. Keep the setup workers alive until collection.
For the CLI, start a new invocation from that worktree with --add-dir <prepared-worktree>,
--model <resolved-model>, --effort <resolved-effort>, --output-format json, --print,
and a matching --print-timeout; omit --conversation. Save each invocation's JSON output
for conversation_id, completion status, duration, and reported usage.
Use the installed CLI's supported model identifiers and equal permission settings.
CLI cwd alone does not attach a workspace. An IDE conversation must likewise attach
only the prepared worktree. Verify actual model/reasoning settings after launch.

Do not assume invoke_subagent TypeName "self" with Workspace "inherit" refreshes skill
or rule discovery: the installed-runtime smoke test retained a deleted treatment skill
in that child's catalog. A custom subagent also omitted the shared rule. Use either
alternative only if a new smoke check demonstrates the correct effective context.
Do not reuse the setup conversation. Give both candidates exactly this task, attaching
the identical report from .eval-input/issue.md:

{case['task_prompt']}

Common environment information for both: use the supplied issue snapshot without
fetching comments, issue timeline, or linked fix PRs; work is local; packages_repo is a preprovisioned checkout available if needed. Do not
replace it with a moving remote revision. Do not add package-routing, skill-activation,
implementation, or testing hints.

Allow {time_limit_minutes} wall-clock minutes per candidate. Record actual candidate
conversation IDs and start/end times. Allow independent investigation without coaching
or cross-candidate assistance. Use completion notifications/reactive waiting rather
than active polling. Record timeouts and interruptions; do not silently retry failures.
Count candidate-spawned descendants, excluding setup and judging, in resource totals.

4. Preserve submissions before terminating agents

For each candidate run:
python3 <absolute-run-dir>/tools/eval_support.py collect --run-dir <absolute-run-dir> --pair <pair-number> --candidate <A-or-B>

Preserve final responses, raw logs, conversation IDs, and test/analyzer/format/native
outputs too. The helper captures tracked and untracked changes and companion changes
or exported patches relative to the prepared state. Never terminate setup/candidate
agents before collection: Antigravity may clean up their worktrees. Freeze submissions;
evaluator changes belong only in separate verification copies.

5. Verify and judge independently

Read the frozen acceptance.json and rubric.md. Apply each submission to a separate
verification copy of its prepared state. Verify exported companion patches apply to
the pinned companion source and include added files and pending changelogs.

Run prepared framework fixtures in each verification copy:
python3 <absolute-run-dir>/tools/eval_support.py verify --case <absolute-run-dir>/case/case.json --workspace <verification-worktree> --output <candidate-evidence-dir>/fixture-results.json

The helper installs frozen fixtures only in the verification copy and runs the local
./bin/flutter test. Inspect individual machine test events and failure reasons.
Compilation/setup errors are not behavioral reproduction. Framework fixture success
does not establish companion UI or native correctness. Complete evidence-review checks
as well, citing commands and outputs. Apply any additional exploratory check to both
submissions and disclose that it was introduced after the runs.

Use a fresh Gemini evaluator with anonymized artifacts, issue report, acceptance checks,
rubric, and independent verification results. Supply neutral Candidate A/B copies of
diffs and verification evidence with identifying workspace paths removed. Exclude
setup metadata, manifest.json, and raw candidate transcripts from the judge context;
preserve the original evidence separately. Withhold the treatment mapping and
skill/resource telemetry until quality assessment is recorded. Accept alternative
correct implementations. Do not infer correctness from completion claims, preferred
patterns, or file names. Grade required checks pass/fail/unverified with evidence.
Report Passed, Failed, or Inconclusive separately from the diagnostic score. Setup-invalid
runs are not scored as candidate failures.

6. Persist results

Run the snapshotted analyze_benchmark.py on measured candidate conversation IDs with
--workspace-a/--workspace-b and --artifacts-a/--artifacts-b pointing to collected evidence.
Pass saved agy JSON via --usage-a/--usage-b when available. Preserve JSON output.
Establish whether runtime totals include descendants before summing them; otherwise
report per-conversation usage and the unresolved accounting scope. Unsupported
or missing metrics are unavailable, not zero. Reads show consultation, not necessarily
automatic activation.

Save evaluation.json and report.md following the frozen REPORT_TEMPLATE.md under
{run_dir}. Preserve per-pair acceptance results, evidence, scores, guidance diagnostics,
and resource measurements. Include all failed, inconclusive, and setup-invalid runs.
Compare efficiency primarily among successful submissions. Historical reports are
excluded; a single pair is one observation, not evidence of general effectiveness.
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', type=Path)
    parser.add_argument('--source-ref', help='Local Flutter ref or SHA; does not fetch.')
    parser.add_argument('--packages-ref', help='flutter/packages branch or SHA.')
    parser.add_argument('--model', default='inherit')
    parser.add_argument('--reasoning', default='inherit')
    parser.add_argument('--repetitions', type=int, default=3)
    parser.add_argument('--time-limit-minutes', type=int, default=60)
    parser.add_argument('--smoke', action='store_true', help='Generate one paired run.')
    parser.add_argument('--run-id')
    parser.add_argument('--issue-json', type=Path, help='Reuse a no-comments issue snapshot.')
    parser.add_argument('--copy', action='store_true')
    args = parser.parse_args()
    try:
        prompt = build_orchestrator_prompt(
            load_case(args.case), args.case, source_ref=args.source_ref,
            packages_ref=args.packages_ref, model=args.model, reasoning=args.reasoning,
            repetitions=1 if args.smoke else args.repetitions,
            time_limit_minutes=args.time_limit_minutes, run_id=args.run_id,
            issue_json=args.issue_json,
        )
    except (ValueError, OSError, json.JSONDecodeError) as error:
        parser.error(str(error))
    print(prompt)
    if args.copy:
        clipboard = ['pbcopy'] if sys.platform == 'darwin' else ['xclip', '-selection', 'clipboard']
        try:
            subprocess.run(clipboard, input=prompt, text=True, check=True)
        except (OSError, subprocess.CalledProcessError) as error:
            print(f'Clipboard unavailable: {error}. Copy the printed prompt.', file=sys.stderr)


if __name__ == '__main__':
    main()
