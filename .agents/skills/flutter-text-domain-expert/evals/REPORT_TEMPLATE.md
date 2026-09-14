# Evaluation: [case ID] — [run ID]

## Configuration

- Issue and snapshot hash: [URL; hash]
- Requested source ref and resolved Flutter SHA: [ref; SHA]
- Companion source SHA: [SHA]
- Shared guidance and treatment text-skill hashes: [manifest reference]
- Eval configuration: [revision; frozen configuration hashes including uncommitted content]
- Antigravity version, actual Gemini model and reasoning setting: [values; evidence]
- Tools, permissions, SDK/platform availability, execution limit: [values]
- Discovery smoke check and isolation evidence: [references]
- Paired repetitions attempted: [number; list interruptions/retries explicitly]

## Acceptance results

For each pair, report every required check with evidence. Distinguish failed, unverified, and inapplicable behavior. Setup-invalid runs remain in the report but are not scored.

| Pair | Check | Without text skill | Evidence | With text skill | Evidence |
| --- | --- | --- | --- | --- | --- |
| | [check ID] | pass / fail / unverified | [test event, command/log, artifact] | | |

| Pair | Without text skill outcome | With text skill outcome | Unverified behavior / setup limitation |
| --- | --- | --- | --- |
| | Passed / Failed / Inconclusive / Setup invalid | | |

## Diagnostic scorecard

Quality assessment is performed using neutral candidate IDs before revealing the condition mapping. Preserve the original assessment in evaluation.json. Use full/half/zero anchors from rubric.md with per-criterion evidence; list applicability and normalization.

| Criterion | Max | Without text skill | With text skill | Evidence and deductions |
| --- | ---: | ---: | ---: | --- |
| F1 Requested behavior | 30 | | | |
| F2 Complete integration | 20 | | | |
| R1 Reproduction and fixed result | 10 | | | |
| R2 Existing behavior protection | 10 | | | |
| R3 Test realism and control | 5 | | | |
| A1 Ownership and repository routing | 10 | | | |
| A2 Focus and justification | 5 | | | |
| V1 Executed validation | 5 | | | |
| V2 Reviewable deliverables | 5 | | | |
| Total | 100 | | | |

## Guidance diagnostics

| Observation | Without text skill | With text skill | Evidence |
| --- | --- | --- | --- |
| Text skill consulted | unavailable | observed / not observed / unknown | |
| Companion skill needed | yes / no; reason | | |
| Companion skill consulted | observed / not observed / unknown | | |
| Required companion work completed | yes / no / unverified / N/A | | |
| Freeze rule automatically supplied | confirmed / unconfirmed | | |
| Applicable freeze respected | yes / no / unverified / N/A | | |

Successful reads establish consultation. Do not infer automatic activation or non-use from incomplete logs.

## Resource measurements

List measured candidate IDs and descendants, without double counting. Exclude setup and evaluator work from candidate totals. Prefer actual runtime usage; mark unavailable values explicitly. Character-based token estimates are transcript-size proxies, not actual consumption.

| Metric | Without text skill | With text skill | Source / limitations |
| --- | ---: | ---: | --- |
| Elapsed candidate time | | | |
| Planner responses | | | |
| Tool calls, including descendants | | | |
| Runtime token usage | | | |
| Transcript character estimate, if needed | | | |
| Distinct files viewed (observed) | | | |
| Files modified (artifact-derived, by repository) | | | |

## Assessment

Report success counts with denominators, paired outcomes, and all inconclusive/setup-invalid counts. Compare efficiency among successful submissions. Explain the observed incremental effect of the text skill and concrete remaining limitations. A single pair supports only a description of that observation.

## Machine-readable record

Save evaluation.json alongside this report. Include manifest/run ID; per-pair candidate IDs and conditions; per-check status/evidence; per-criterion applicable/max/earned/evidence; primary outcome; guidance diagnostics; resource measurements; and limitations. Use null for unavailable measurements. Preserve the anonymized quality assessment and record any checks introduced after candidate execution.
