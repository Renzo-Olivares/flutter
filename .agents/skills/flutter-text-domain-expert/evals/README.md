# Flutter Text Domain Expert — Evaluation Suite

This directory contains the benchmark harness, evaluation rubrics, report templates, and test cases used to evaluate and validate the effectiveness of the `flutter-text-domain-expert` skill.

---

## Directory Structure

```text
evals/
├── README.md               # Benchmark execution guide & workflow
├── CHANGELOG.md            # Canonical skill version specification & commit SHAs
├── rubric.md               # 6-dimension 100-point scoring criteria
├── REPORT_TEMPLATE.md      # Standardized 4-part evaluation report layout
├── eval_harness.py         # Dedicated prompt generator (with --copy to clipboard)
├── analyze_benchmark.py    # Metric extractor engine (parses steps, tools, tokens)
├── cases/                  # Target benchmark test cases (grouped by issue)
│   ├── issue_162856/
│   │   ├── 01_no_skill_vs_first_iteration.json
│   │   ├── 02_no_skill_vs_selection_geometry_queries.json
│   │   └── 03_first_iteration_vs_selection_geometry_queries.json
│   └── issue_141775/
│       ├── 01_no_skill_vs_context_menu_and_decoupling.json
│       └── 02_selection_geometry_queries_vs_context_menu_and_decoupling.json
└── reports/                # Persisted evaluation reports (grouped by issue & model)
    ├── issue_162856/gemini-3.7-flash-high/
    └── issue_141775/gemini-3.7-flash-high/
```

---

## Skill Version Specification

See [`CHANGELOG.md`](CHANGELOG.md) for full documentation of each canonical version:
- **`v0`** ([`67710a5db2`](https://github.com/flutter/flutter/commit/67710a5db2adcae7e5ad606c7f5001108e037672)): Framework Baseline (No Skill)
- **`v1`** ([`19261190ba`](https://github.com/flutter/flutter/commit/19261190bad200063c67b57d550811b0f3f4773a)): First Skill Iteration (core architecture & references)
- **`v2`** ([`7bb6d97c23`](https://github.com/flutter/flutter/commit/7bb6d97c23779cb315048c4c4e8d9765f7fc8646)): Selection Geometry & Edge-Scrolling Invariants (Sample 1)
- **`v3`** ([`af158b3675`](https://github.com/flutter/flutter/commit/af158b3675a30ae8e7a6ca2a9d460e59ee30768c)): Context Menu, Decoupled Packages, Delegating Constructor Parity & Lifecycle Isolation (Sample 2)

---

## Benchmark Cases by Issue

### Issue #162856 (Sample 1: Edge Scrolling SafeArea Invariant)

| Case ID | Comparison | Baseline SHA | Treatment SHA | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **`01_no_skill_vs_first_iteration.json`** | No Skill (`v0`) vs. First Iteration (`v1`) | `67710a5db2` | `19261190ba` | Measures initial value-add of domain architecture and test location guides. |
| **`02_no_skill_vs_selection_geometry_queries.json`** | No Skill (`v0`) vs. Selection Geometry (`v2`) | `67710a5db2` | `7bb6d97c23` | Measures total value-add of the resolved skill on edge scrolling & coordinate transforms. |
| **`03_first_iteration_vs_selection_geometry_queries.json`** | First Iteration (`v1`) vs. Selection Geometry (`v2`) | `19261190ba` | `7bb6d97c23` | Measures marginal improvement of `SelectionGeometry` queries and Section 8 edge-scrolling invariants. |

### Issue #141775 (Sample 2: iOS SelectionArea Context Menu & Decoupled Packages)

| Case ID | Comparison | Baseline SHA | Treatment SHA | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **`01_no_skill_vs_context_menu_and_decoupling.json`** | No Skill (`v0`) vs. Treatment (`v3`) | `67710a5db2` | `30d7c11508` | Measures total value-add of text skill with decoupled packages workflow on iOS SelectionArea buttons. |
| **`02_selection_geometry_queries_vs_context_menu_and_decoupling.json`** | Selection Geometry (`v2`) vs. Treatment (`v3`) | `7bb6d97c23` | `30d7c11508` | Measures marginal impact of Invariant 7 delegating constructor parity and `material-cupertino-packages` split PR. |

*(Note: Issue #181169 will serve as Sample 3 for holdout zero-shot validation of v3.)*

---

## 2-Step Benchmark Workflow

### Step 1: Generate & Copy Prompt
Run `eval_harness.py` on any test case JSON with `--copy`:

```bash
python3 .agents/skills/flutter-text-domain-expert/evals/eval_harness.py \
  .agents/skills/flutter-text-domain-expert/evals/cases/issue_162856/01_no_skill_vs_first_iteration.json --copy
```

### Step 2: Paste into Antigravity 2.0 & Run
1. Open Antigravity 2.0.
2. Click **"+ New Conversation"**.
3. Press **`Cmd + V`** to paste the orchestration prompt and press **Enter**.

---

## What the Orchestrator Automates in the Session

Once submitted, the orchestrating agent handles the entire benchmark autonomously:

1. **Parallel Spawning**: Concurrently launches Candidate A and Candidate B in isolated worktree branches (`Workspace: "branch"`), using neutral role labels (`Candidate A`, `Candidate B`) to prevent semantic priming of baseline vs treatment behaviors.
2. **Reactive Waiting**: Stands by for both subagents to finish without polling loops.
3. **Metric Extraction**: Automatically executes `python3 .agents/skills/flutter-text-domain-expert/evals/analyze_benchmark.py <CONV_A> <CONV_B>` to calculate exact step counts, tool distributions, token usage, and automatic skill trigger status.
4. **Scoring & Report Saving**: Evaluates both trajectories against `rubric.md` and saves the completed report directly to `evals/reports/issue_<NUMBER>/<MODEL_SLUG>/<CASE_NAME>_report.md`.
5. **Interactive Output**: Renders the final verdict, scorecard table, and trajectory breakdown in chat.
