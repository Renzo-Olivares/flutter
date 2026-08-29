#!/usr/bin/env python3
"""
Evaluation Prompt Generator for Flutter Text Domain Expert.

Reads a declarative test case JSON file and compiles the complete A/B benchmark
orchestration prompt, automatically formatting candidate instructions, rubric
guidelines, and report saving paths.

Usage:
  # Generate orchestration prompt and copy directly to clipboard:
  python3 eval_harness.py cases/issue_162856/01_edge_scrolling_invariants.json --copy

  # Or print to stdout:
  python3 eval_harness.py cases/issue_162856/01_edge_scrolling_invariants.json
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


def load_case(case_path):
    with open(case_path, "r", encoding="utf-8") as f:
        return json.load(f)


def get_report_rel_path(case_path):
    p = Path(case_path)
    parent_name = p.parent.name
    stem = p.stem
    if parent_name.startswith("issue_") or (parent_name != "cases" and parent_name != "."):
        return f"reports/{parent_name}/{stem}_report.md"
    return f"reports/{stem}_report.md"


def build_orchestrator_prompt(case, case_path=""):
    issue_url = case.get("issue_url", "")
    template = case.get("task_prompt_template", "")
    candidates = case.get("candidates", {})
    
    baseline = candidates.get("baseline", {})
    treatment = candidates.get("treatment", {})
    
    prompt_a = template.format(commit=baseline.get("commit", "HEAD"))
    prompt_b = template.format(commit=treatment.get("commit", "HEAD"))
    
    desc_a = baseline.get("description", "Baseline")
    desc_b = treatment.get("description", "Treatment")

    report_rel_path = get_report_rel_path(case_path) if case_path else f"reports/{case.get('id', 'case')}_report.md"

    prompt = f"""# Role: A/B Benchmark Orchestrator & Objective Judge
You will orchestrate and evaluate a head-to-head A/B benchmark between two autonomous subagents on the following Flutter issue:

### Target Issue:
> {issue_url}

---

## Execution Plan

### Phase 1: Parallel Subagent Spawning
Invoke two subagents concurrently using the `invoke_subagent` tool with isolated branched workspaces (`Workspace: "branch"`):

1. **Candidate A (Baseline — {desc_a})**:
   - **Role**: `Candidate A (Baseline)`
   - **Workspace**: `"branch"`
   - **Prompt**:
```
{prompt_a}
```

2. **Candidate B (Treatment — {desc_b})**:
   - **Role**: `Candidate B (With Skill)`
   - **Workspace**: `"branch"`
   - **Prompt**:
```
{prompt_b}
```

---

### Phase 2: Reactive Waiting
After launching both subagents, stop calling tools and wait for both background subagents to complete their runs and send their completion messages.

---

### Phase 3: Automated Metric Extraction & Diff Inspection
When both subagents finish:
1. Note the `conversationId` of both Candidate A and Candidate B.
2. Automatically run the metric extractor script:
   `python3 .agents/skills/flutter-text-domain-expert/evals/analyze_benchmark.py <CONVERSATION_ID_A> <CONVERSATION_ID_B>`
3. Inspect their workspace git diffs, test outputs, and analyzer compliance.

---

### Phase 4: 6-Dimension Evaluation & Report Persistence
1. Score both candidates strictly against the 100-point rubric in `.agents/skills/flutter-text-domain-expert/evals/rubric.md`.
2. Format the evaluation following `.agents/skills/flutter-text-domain-expert/evals/REPORT_TEMPLATE.md`.
3. Save the complete evaluation report directly to `.agents/skills/flutter-text-domain-expert/evals/{report_rel_path}` using `write_to_file`.
4. Output the final verdict and scorecard in your chat response.
"""
    return prompt.strip()


def main():
    parser = argparse.ArgumentParser(description="Antigravity Evaluation Prompt Generator")
    parser.add_argument("case", help="Path to test case JSON file (e.g. cases/issue_162856/01_edge_scrolling_invariants.json)")
    parser.add_argument("--copy", action="store_true", help="Copy generated prompt directly to system clipboard")
    
    args = parser.parse_args()
    
    case = load_case(args.case)
    prompt = build_orchestrator_prompt(case, case_path=args.case)
    
    print("=" * 80)
    print(f"BENCHMARK PROMPT: {case.get('id', '')}")
    print(f"Target Issue: {case.get('issue_url', '')}")
    print("=" * 80)
    print(prompt)
    print("=" * 80)
    
    if args.copy:
        try:
            if sys.platform == "darwin":
                subprocess.run(["pbcopy"], input=prompt.encode("utf-8"), check=True)
                print("\n[SUCCESS] Prompt copied to clipboard! Paste (Cmd+V) directly into Antigravity 2.0 chat.")
            elif sys.platform.startswith("linux"):
                subprocess.run(["xclip", "-selection", "clipboard"], input=prompt.encode("utf-8"), check=True)
                print("\n[SUCCESS] Prompt copied to clipboard!")
        except Exception as e:
            print(f"\n[INFO] Could not copy to clipboard automatically ({e}). Copy manually from above.")


if __name__ == "__main__":
    main()
