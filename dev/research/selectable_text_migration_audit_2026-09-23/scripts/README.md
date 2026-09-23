# Re-baselining the audit numbers

All numbers in REPORT.md §1 and §3 and in per_test_index.md are a snapshot of commit ece56299239.
To refresh after test or implementation changes:

1. Run the suite with the expanded reporter from the repo root:
   `bin/flutter test --no-pub --reporter expanded packages/flutter/test/material/selectable_text_test.dart > run.log`
2. Extract failing entries (lines ending in ` [E]`); `extract_failures.py <run.log> <summary.json> <outdir>`
   writes one file per failing test/variant plus `failures.json`. `summary.json` comes from
   `split_tests.py <base_test_file> <head_test_file> <outdir>`, which splits both versions into
   per-test blocks and classifies each as UNCHANGED/MODIFIED/ADDED/REMOVED (base commit:
   5c94360655fe8ba6d29427f58479e0bd96d913dd).
3. Compare the new `failures.json` against `baseline_failures_ece56299239.json` (name + variant) to get
   newly failing / newly passing lists; skipped tests (`skip:`) no longer appear as passing.
4. `merge_reports.py` re-parses `groups/*.md` into the per-test table; verdict text lives in REPORT.md §7
   and is not regenerated.

Scripts assume the scratchpad layout described at the top of each file; adjust the `S` path constant.
