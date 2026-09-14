# Evaluation protocol changes

## 2026-09-14

- Replace historical skill-version comparisons with one case per issue: without the text skill versus its current working-tree revision. Share the current freeze rule and companion-package skill between conditions.
- Separate source refs from guidance snapshots. Antigravity setup agents create branch worktrees, run `git checkout --quiet`, and install current guidance before launching fresh measured children.
- Fetch each issue once using `gh issue view --json number,title,body,url` without `--comments`, then reuse the frozen report across repetitions.
- Add immutable input manifests, local preparation/collection/verification helpers, behavioral acceptance criteria, a focused selection-action fixture, outcome-based scoring, and explicit runtime/isolation checks.
- Preserve raw logs and historical reports. Reports under `reports/` use the previous protocol and are not comparable with new runs under `runs/`.

## 2026-09-13

Moved reusable contribution guidance from candidate task prompts into the text skill and its testing reference. Retained the old rubric structure at that time. Existing historical reports predate that prompt revision as well; consult their recorded provenance rather than treating them as results of the current protocol.
