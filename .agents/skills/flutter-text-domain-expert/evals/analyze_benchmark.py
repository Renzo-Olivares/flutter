#!/usr/bin/env python3
"""
Lightweight Metric Extractor for Antigravity Subagent Trajectories.

Can be run standalone:
  python3 analyze_benchmark.py <conv_id_baseline> <conv_id_treatment>

Or imported as a module by benchmark_runner.py:
  from analyze_benchmark import analyze_candidate
"""

import json
import os
import sys
from collections import Counter
from pathlib import Path


def analyze_candidate(conv_id, name, verbose=True):
    base_dir = Path.home() / f".gemini/antigravity/brain/{conv_id}/.system_generated/logs"
    t_jsonl = base_dir / "transcript.jsonl"
    tf_jsonl = base_dir / "transcript_full.jsonl"
    
    if not t_jsonl.exists():
        if verbose:
            print(f"Warning: Transcript file not found at {t_jsonl}")
        return None
        
    steps = 0
    tool_calls = 0
    tools_used = []
    files_viewed = set()
    files_edited = set()
    skill_triggered = False
    
    # 1. Parse steps, tool calls, and file operations from transcript.jsonl
    with open(t_jsonl, "r", encoding="utf-8") as f:
        for line in f:
            if not line.strip():
                continue
            obj = json.loads(line)
            if obj.get("type") == "PLANNER_RESPONSE":
                steps += 1
                tcs = obj.get("tool_calls", [])
                if tcs:
                    tool_calls += len(tcs)
                    for tc in tcs:
                        if isinstance(tc, dict):
                            fn = tc.get("name") or tc.get("function", {}).get("name") or "unknown"
                            tools_used.append(fn)
                            args = tc.get("args") or tc.get("function", {}).get("arguments") or {}
                            if isinstance(args, str):
                                try:
                                    args = json.loads(args)
                                except Exception:
                                    pass
                            if isinstance(args, dict):
                                if fn == "view_file" and "AbsolutePath" in args:
                                    abs_path = str(args["AbsolutePath"])
                                    files_viewed.add(Path(abs_path).name)
                                    if "flutter-text-domain-expert" in abs_path:
                                        skill_triggered = True
                                elif fn in ("replace_file_content", "write_to_file") and "TargetFile" in args:
                                    files_edited.add(Path(args["TargetFile"]).name)
    
    # 2. Calculate character count and estimated tokens from transcript_full.jsonl
    full_chars = 0
    if tf_jsonl.exists():
        with open(tf_jsonl, "r", encoding="utf-8") as f:
            for line in f:
                if not line.strip():
                    continue
                obj = json.loads(line)
                content = obj.get("content", "") or ""
                thinking = obj.get("thinking", "") or ""
                full_chars += len(content) + len(thinking)
    
    est_tokens = full_chars // 4
    
    if verbose:
        print(f"=== {name} ({conv_id}) ===")
        print(f"Skill Triggered: {'Yes' if skill_triggered else 'No'}")
        print(f"Total Steps (PLANNER_RESPONSE): {steps}")
        print(f"Total Tool Calls: {tool_calls}")
        print(f"Estimated Tokens: {est_tokens:,} tokens (chars: {full_chars:,})")
        print("Tool call frequency:")
        for tool, count in Counter(tools_used).most_common():
            print(f"  {tool}: {count}")
        print()
    
    return {
        "conv_id": conv_id,
        "name": name,
        "skill_triggered": skill_triggered,
        "steps": steps,
        "tool_calls": tool_calls,
        "est_tokens": est_tokens,
        "full_chars": full_chars,
        "tools": Counter(tools_used),
        "files_viewed": files_viewed,
        "files_edited": files_edited,
    }


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 analyze_benchmark.py <conv_id_baseline> <conv_id_treatment>")
        sys.exit(1)
        
    res_a = analyze_candidate(sys.argv[1], "Candidate A (Baseline)", verbose=True)
    res_b = analyze_candidate(sys.argv[2], "Candidate B (Treatment)", verbose=True)
    
    if res_a and res_b:
        print("=== Comparison Summary ===")
        print(f"Skill Triggered: {'Yes' if res_a['skill_triggered'] else 'No'} vs {'Yes' if res_b['skill_triggered'] else 'No'}")
        step_delta = ((res_b["steps"] - res_a["steps"]) / res_a["steps"]) * 100 if res_a["steps"] else 0
        tool_delta = ((res_b["tool_calls"] - res_a["tool_calls"]) / res_a["tool_calls"]) * 100 if res_a["tool_calls"] else 0
        tok_delta = ((res_b["est_tokens"] - res_a["est_tokens"]) / res_a["est_tokens"]) * 100 if res_a["est_tokens"] else 0
        print(f"Steps:      {res_a['steps']} -> {res_b['steps']} ({step_delta:+.1f}%)")
        print(f"Tool Calls: {res_a['tool_calls']} -> {res_b['tool_calls']} ({tool_delta:+.1f}%)")
        print(f"Tokens:     {res_a['est_tokens']:,} -> {res_b['est_tokens']:,} ({tok_delta:+.1f}%)")
