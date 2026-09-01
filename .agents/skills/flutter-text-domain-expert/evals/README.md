# Flutter Text Domain Expert — Evaluation Suite

This directory contains the benchmark harness, evaluation rubrics, report templates, and test cases used to evaluate and validate the effectiveness of the `flutter-text-domain-expert` skill.

---

## Directory Structure

```text
evals/
├── README.md               # Benchmark execution guide & workflow
├── rubric.md               # 6-dimension 100-point scoring criteria
├── REPORT_TEMPLATE.md      # Standardized 4-part evaluation report layout
├── eval_harness.py         # Dedicated prompt generator (with --copy to clipboard)
├── analyze_benchmark.py    # Metric extractor engine (parses steps, tools, tokens)
├── cases/                  # Target benchmark test cases (grouped by issue)
│   ├── issue_141775/
│   │   ├── 01_no_skill_vs_treatment.json
│   │   └── 02_selection_geometry_queries_vs_treatment.json
│   ├── issue_162856/
│   │   ├── 01_no_skill_vs_first_iteration.json
│   │   ├── 02_no_skill_vs_edge_scrolling_invariants.json
│   │   └── 03_first_iteration_vs_edge_scrolling_invariants.json
│   └── issue_181169/
│       └── 01_no_skill_vs_treatment.json
└── reports/                # Persisted evaluation reports (grouped by issue & model)
    ├── issue_141775/
    ├── issue_162856/
    └── issue_181169/
```

---

## Benchmark Cases by Issue

### Issue #181169 (Two-Dimensional Scrollable Selection Assertion Error)
| Case ID | Comparison | Baseline SHA | Treatment SHA | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **`01_no_skill_vs_treatment.json`** | No Skill vs. v4 Treatment | `67710a5db2` *(No Skill)* | `fd18dd04e4` *(v4 Skill)* | Measures ability to diagnose `EdgeDraggingAutoScroller` / `_ScrollableSelectionContainerDelegate` drag target size assertion errors during nested TableView selection. |

### Issue #141775 (iOS SelectionArea Default Context Menu Buttons)
| Case ID | Comparison | Baseline SHA | Treatment SHA | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **`01_no_skill_vs_treatment.json`** | No Skill vs. v4 Treatment | `67710a5db2` *(No Skill)* | `fd18dd04e4` *(v4 Skill)* | Measures baseline effectiveness of Context Menu Matrix & SystemChannels Map on iOS selection buttons. |
| **`02_selection_geometry_queries_vs_treatment.json`** | v3 vs. v4 Treatment | `7bb6d97c23` *(v3 Skill)* | `fd18dd04e4` *(v4 Skill)* | Measures marginal impact of context menu action callbacks vs exploratory search. |

### Issue #162856 (Edge Scrolling SafeArea Invariant)

Chronological test suite evaluating the skill's inception and subsequent iterations:

| Case ID | Comparison | Baseline SHA | Treatment SHA | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **`01_no_skill_vs_first_iteration.json`** | No Skill vs. Iteration 1 | `67710a5db2` *(No Skill)* | `19261190ba` *(First Skill)* | Measures the baseline effectiveness of the initial skill against raw framework baseline. |
| **`02_no_skill_vs_edge_scrolling_invariants.json`** | No Skill vs. Iteration 2 | `67710a5db2` *(No Skill)* | `418dc62853` *(Edge Scrolling Skill)* | Measures the total effectiveness of the full skill against raw framework baseline. |
| **`03_first_iteration_vs_edge_scrolling_invariants.json`** | Iteration 1 vs. Iteration 2 | `19261190ba` *(First Skill)* | `418dc62853` *(Edge Scrolling Skill)* | Measures the marginal improvement of adding Section 8 edge-scrolling & handle geometry guidelines. |

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
