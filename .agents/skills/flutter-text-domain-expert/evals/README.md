# Flutter text skill evaluation

This suite measures the incremental effect of the current `flutter-text-domain-expert` skill inside Antigravity/Gemini. The baseline and treatment share the current `code-freeze.md` rule and `material-cupertino-packages` skill. Only treatment receives the text skill. Framework source, companion source, other instructions, model settings, tools, and limits are identical.

`eval_harness.py` remains a prompt generator. It does not launch agents or change worktrees. Paste its output into an interactive Antigravity CLI conversation; the orchestrator invokes the deterministic helper commands, setup subagents, and separate headless CLI candidates.

## Run from the CLI

The orchestrator is an interactive CLI conversation where you paste the generated prompt and monitor progress. The measured candidates run headlessly in their prepared worktrees; you do not open their conversations manually.

For a first paired run, generate and copy the prompt from the Flutter repository root:

```bash
python3 .agents/skills/flutter-text-domain-expert/evals/eval_harness.py \
  .agents/skills/flutter-text-domain-expert/evals/cases/issue_141775/case.json \
  --source-ref master --smoke --copy
```

Then open the interactive CLI from that same directory:

```bash
agy
```

Confirm that the Flutter checkout is attached as the workspace, select the Gemini model and reasoning setting, and paste the copied prompt. If the checkout is not attached automatically, explicitly add it when launching:

```bash
agy --add-dir "$PWD"
```

`--add-dir` adds a directory to the agent's workspace. It does not change the shell's current directory or exclude other project folders. It is unnecessary when the interactive session already has the intended checkout attached. The scripted candidate launches use explicit worktree paths because cwd alone did not attach a workspace in the tested headless launch; their effective workspace is verified separately.

The orchestrator captures the inputs, creates setup worktrees through `invoke_subagent` with `Workspace: "branch"`, and starts a fresh headless CLI process for each measured candidate using `--print`. It then collects submissions, performs independent verification and judging, and saves `manifest.json`, `evaluation.json`, `report.md`, and supporting evidence under `runs/<run-id>/`. Existing permission settings still apply to command execution.

`--smoke` runs one actual issue-fixing pair. Remove it for the default three pairs. This is separate from the small discovery-only marker check used to validate candidate isolation.

The helper checks, CLI discovery behavior, and structured usage parsing have been validated. A complete paired issue evaluation has not yet been run end to end under this protocol.

Use `--source-ref <sha>` to test older Flutter source with today's skill. A ref is resolved locally once; no implicit fetch or checkout occurs in the user's main workspace. Use `origin/master` after an intentional fetch when that is the desired source. `--packages-ref` selects a `flutter/packages` branch or full SHA and defaults to the case's `main` branch, resolved once during capture.

Other options:

- `--model` and `--reasoning` record requested settings. Their default `inherit` must be resolved to actual runtime settings by the orchestrator before launch.
- `--repetitions 3` is the default; `--smoke` generates one paired run.
- `--time-limit-minutes 60` sets each measured candidate's wall-clock limit.
- `--run-id` chooses a unique output directory; existing runs cannot be overwritten.
- `--issue-json <previous-run>/issue.json` reuses a previous frozen issue report.
- `--copy` preserves clipboard support. Without it, print the prompt to stdout.

A single-pair smoke run is different from the separate, cheap skill-discovery smoke check described below. The implementation of the generator can be tested locally without launching any Gemini task.

## Source and guidance preparation

The generated prompt first calls `eval_support.py snapshot`. This captures current guidance, including uncommitted edits, using `guidance.json`; resolves source refs; copies the case, rubric, report template, helpers, and fixtures; and hashes the captured files. It saves `manifest.json` under a unique `runs/<run-id>/` directory.

For a new issue input, setup runs exactly:

```bash
gh issue view 141775 --repo flutter/flutter --json number,title,body,url
```

Do not pass `--comments`. The helper retains only those four fields and writes `issue.json` and `issue.md` in the run directory. All repetitions use the same snapshot. Reproduction attachments needed beyond the body must be captured and hashed before candidates start. No issue snapshot is silently refreshed in an existing run.

The orchestrator uses `invoke_subagent` with `Workspace: "branch"` to create two Antigravity-managed SETUP worktrees for each pair. In each one it calls the captured helper's `prepare` command. The helper:

1. Checks the worktree is clean and separate from the original checkout.
2. Runs `git checkout --quiet <resolved-source-sha>` and verifies HEAD.
3. Replaces historical evaluated guidance with the current captured configuration, excluding eval files.
4. Supplies only the frozen issue report under `.eval-input/`.
5. Creates a local setup commit. Submission diffs are relative to that commit, so setup changes do not count as candidate changes.
6. Preprovisions `packages_repo` at the same pinned companion SHA in both worktrees.

Companion checkout is shared environment provisioning and is excluded from measured task costs. Tell both candidates it is available if needed; no instruction says their fix must modify it. This avoids different on-demand clones picking up moving remote source. The companion skill's cloning step is satisfied by this provisioning.

The orchestrator then launches independent measured Antigravity conversations attached to the prepared worktrees, keeping setup workers alive until collection. Their task is only `Fix flutter/flutter#<number>.`, with the issue report attached. Common environment information identifies the supplied issue as authoritative, the local-only scope, and the existing companion checkout.

## Antigravity preflight

Before trusting measured runs, use a throwaway smoke check to verify that an independent conversation discovers the prepared worktree's skills and rules. Check workspace/global/legacy locations and inherited system instructions. Baseline must not discover the text skill; both must receive the shared guidance. A fresh history or a `branch` option alone does not prove effective isolation.

A local Antigravity CLI smoke check on 2026-09-14 found that `TypeName: "self"` with `Workspace: "inherit"` retained the parent's skill catalog after setup removed the treatment skill. A custom subagent omitted the shared rule. A separate CLI invocation with `--add-dir <prepared-worktree>` discovered the prepared baseline and treatment correctly, including the shared rule in both. Use independent conversations by default; repeat this check after runtime updates before choosing another launch mode.

For CLI measured runs, invoke `agy` from the prepared worktree with `--add-dir <prepared-worktree>`, the resolved `--model` and `--effort`, `--output-format json`, `--print`, and an appropriate `--print-timeout`. Save the JSON result for its `conversation_id`, status, duration, and reported token usage. Omit `--conversation` and `--continue` to start fresh. Cwd alone did not attach a workspace in the tested headless launch. App-only automatic candidate launching has not been established; do not treat the CLI discovery result as validation of that path. Keep identical permission and reasoning settings, and record what the runtime actually used. This preserves `invoke_subagent` for Antigravity-managed worktree setup without assuming its child-context behavior is suitable for measurement.

Record actual Antigravity version, model/reasoning settings, permission/tool scopes, and discovery evidence under `runtime` in the manifest. Configure candidate access to exclude evaluator files, original/sibling workspaces, and other transcripts. Do not give measured candidates a discovery probe, rubric, historical reports, or solution hints. If these runtime conditions cannot be established, report setup invalid rather than making an unsupported comparison.

The case's source applicability and required SDK/native environment must also be checked. A source revision where the issue is already resolved is unsuitable. Native-platform checks that cannot run remain unverified, even if framework mocks pass.

## Verification and evidence

`acceptance.json` contains evaluator-only behavior requirements. Checks identify whether a prepared fixture or evidence review verifies them. `rubric.md` defines primary outcomes and anchored quality scoring. Skill reads and resource usage are separate diagnostics, with identical outcome criteria for both candidates.

The #141775 fixture exercises real `SelectableRegion` state-generated actions. It verifies requested iOS actions and outgoing selected-text payloads, changes selection to check current content, and includes Android Share as a positive control. It does not establish public companion toolbar wiring or native iPad presentation. It accepts the existing scalar Share payload and a structured payload with a `text` field; any different proposed native contract requires a justified check applied symmetrically to both candidates. Record post-run adapters as exploratory verification.

#162856 currently has evidence-review acceptance checks, not a prewritten universal fix test. The evaluator must reproduce the actual touch interaction, run relevant existing/regression tests, and cite outputs. Never claim that a JSON expectation alone executed a test. Future prepared fixtures belong in the case's `verification/` directory and must be declared in `case.json`.

Before terminating agents, invoke `collect` and preserve raw logs, final responses, command outputs, and conversation IDs. Collection includes added files and companion changes or exported artifacts. If the companion checkout was removed by its workflow, apply the exported patches against the pinned companion source and enumerate changed files during review.

Apply each submission to a separate verification copy of its setup state. Invoke the captured helper:

```bash
python3 <run-dir>/tools/eval_support.py verify \
  --case <run-dir>/case/case.json --workspace <verification-worktree> \
  --output <candidate-evidence-dir>/fixture-results.json
```

This copies evaluator fixtures into the verification checkout temporarily, executes its local `bin/flutter test --reporter json`, records commands, exit statuses, logs, and hashes, and removes the injected files. Inspect individual test events: a nonzero exit may be compilation/setup failure rather than a demonstrated regression. It does not execute evidence-review requirements automatically or decide the overall outcome. Any additional exploratory checks must be applied to both candidates and disclosed.

Use a fresh Gemini evaluator to assess neutral Candidate A/B copies of submission diffs and verification evidence before revealing the treatment mapping or resource metrics. Remove identifying workspace paths from those copies; exclude setup metadata, raw candidate transcripts, and manifest.json. Preserve the complete original evidence separately. Preserve all repetitions, including timeouts, failures, inconclusive results, and setup-invalid runs. A single pair is one observation. Compare resource use primarily among successful submissions.

## Metrics

```bash
python3 <run-dir>/tools/analyze_benchmark.py <candidate-A-id> <candidate-B-id> \
  --workspace-a <worktree-A> --workspace-b <worktree-B> \
  --artifacts-a <artifacts-A> --artifacts-b <artifacts-B> \
  --output <metrics.json>
```

Use `--logs-a/--logs-b` for exported logs or a different installed-runtime layout. The adapter searches both `~/.gemini/antigravity/brain/<id>/.system_generated/logs` (2.0 app) and `~/.gemini/antigravity-cli/brain/<id>/.system_generated/logs` (CLI). If both exist, specify the log directory explicitly. The CLI record layout and JSON-encoded argument strings were checked with a fresh smoke conversation; recheck after runtime updates. Optional `--usage-a/--usage-b` accepts saved `agy --output-format json` results and verifies their conversation IDs, or an actual usage JSON record identifying its source and accounting scope. The CLI usage schema was checked in the same local smoke test; whether those totals include descendants remains unknown.

Paths retain directory identity. Modified files come from collected artifacts rather than edit-tool guesses. Successful file reads demonstrate consultation; absence of a read is not proof of non-use. Shell reads and injected context are not reliably detected by the current log adapter. Missing metrics are null. Character-based estimates measure transcript size, not actual token consumption. Establish whether runtime usage includes descendants before adding their costs; if unknown, report per-conversation usage and that limitation. Exclude setup and judging.

## Cases and results

Both current cases are development cases used during skill iteration. Neither is held out. Expand later with independent core-only, package-only, and combined cases, without revising their criteria after seeing candidate outcomes.

New runs live under `runs/` and follow `REPORT_TEMPLATE.md`; keep large generated artifacts out of ordinary source commits. Historical reports under `reports/` remain unchanged and use the earlier protocol. They are excluded from current comparisons. `CHANGELOG.md` records protocol changes, not a catalog of skill versions.

## Local checks

```bash
python3 -m unittest discover -s .agents/skills/flutter-text-domain-expert/evals/tests -v
```

These tests use temporary Git repositories and synthetic log records. They validate actual source/guidance isolation, frozen inputs, patch completeness, and missing-log accounting without launching Antigravity or accessing GitHub.
