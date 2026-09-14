# Flutter Text Evaluation Rubric

Evaluate both candidates against the same requested behavior and repository contribution requirements. Use submitted artifacts, independent execution results, and cited evidence. Accept alternative correct implementations. Skill consultation, investigation style, tool count, and token use are diagnostics, not quality points.

## Primary outcome

First assess every required check in the frozen case acceptance specification as **pass**, **fail**, or **unverified**, with evidence. Record required validation and delivery omissions too.

- **Passed**: All required behavior, validation, and delivery checks are verified.
- **Failed**: A required check demonstrably fails, or the candidate leaves required work incomplete within a functioning evaluation environment, including exhausting its limit. Do not hide such failures by rerunning until success.
- **Inconclusive**: No demonstrated candidate failure, but infrastructure or platform availability prevents the required assessment. List the unverified checks.
- **Setup invalid**: Wrong source/model/guidance, contamination, or another broken experimental condition. Preserve this run and its reason; exclude it from candidate-quality scoring.

A diagnostic score cannot override a failed required check. A passing candidate-authored test alone is insufficient evidence that the entire issue is fixed. A test timeout or nonzero exit requires investigation: compiler/setup failures do not establish behavioral reproduction.

## Diagnostic score: 100 points

| ID | Criterion | Max | Full credit | Half credit | No credit |
| --- | --- | ---: | --- | --- | --- |
| F1 | Requested behavior | 30 | All primary behavior checks verified | At least one independently useful requested behavior verified, with specific remaining failures | No requested behavior verified |
| F2 | Complete integration | 20 | Required capability works through all affected consumers/platforms | A required path works, but a separately identified affected path is incomplete | Required integration is absent or unverified |
| R1 | Reproduction and fixed result | 10 | Behavior-specific failure on unfixed source and pass on submitted source | Meaningful regression test passes after the change, but valid pre-change reproduction is missing | No meaningful passing regression test |
| R2 | Existing behavior protection | 10 | Relevant existing behavior and boundary checks pass without unjustified weakening | Some relevant protection verified, with a specific coverage gap | Established regressions, weakened tests masking a defect, or no protection verified |
| R3 | Test realism and control | 5 | Tests exercise the actual contracts and control variables relevant to assertions | Tests are useful but contain a demonstrated realism/timing/geometry weakness | Tests do not exercise the required behavior or cannot reliably establish it |
| A1 | Ownership and repository routing | 10 | Responsible layer corrected and applicable freeze respected | Correct main location, with an identified unjustified cross-layer dependency or misplaced secondary change | Core ownership mistake, illegal import, or prohibited semantic edit in frozen paths |
| A2 | Focus and justification | 5 | Changes are focused, understandable, and justified by the task | Necessary change mixed with identifiable unrelated or avoidable complexity | Scope is substantially unrelated or obscures the actual fix |
| V1 | Executed validation | 5 | Relevant tests, analysis, and formatting verified on the submitted artifacts | Some required validation verified, with a named omission | No relevant successful validation or unresolved introduced diagnostics |
| V2 | Reviewable deliverables | 5 | Complete usable changes, including required companion artifacts | Main change preserved but a secondary required artifact is incomplete | Required implementation is missing/unusable or temporary scaffolding contaminates delivery |

Dimensions: functional correctness/completeness F1–F2 (50); regression protection R1–R3 (25); architecture/routing A1–A2 (15); validation/delivery V1–V2 (10).

Freeze applicable criteria in `acceptance.json` before candidates start. Each of the current implementation cases uses all nine. For future non-implementation cases, omit genuinely inapplicable criteria with a written reason and compute `100 * earned / applicable_max`. Do not omit an applicable criterion because the candidate failed to address it. Use only full, half, or zero credit; cite evidence for every score. Mark missing evidence unverified and award no inferred credit. Do not interpret fine score differences as statistically reliable.

## Conditional companion-package responsibilities

When the requested behavior requires Material/Cupertino component changes, complete the affected package implementation, forwarding, integration tests, and review artifacts. Respect the applicable freeze in `flutter/flutter`. For core-only fixes, avoid unnecessary companion-package changes. An unchanged wrapper is valid when its existing forwarding already meets the required contract.

Score both candidates equally for correct results, including independent discovery of the shared companion workflow. Record skill consultation separately. The freeze rule is automatically supplied guidance; assess whether it was respected rather than requiring a tool call to "activate" it. Local review artifacts suffice; publication of PRs is not part of these evals.

## Behavioral testing criteria

Evaluate control of elapsed time, pointer kind, recognizer acceptance, coordinate spaces, and editing state when relevant to the assertion. Do not require specific pumping methods, gesture counts, font sizes, or text-input helpers when alternatives correctly exercise the behavior.

- Text tap recognizers need not use `kDoubleTapMinTime`; verify the intended consecutive-tap sequence.
- A focused blinking cursor alone does not imply `pumpAndSettle()` hangs. Investigate scheduled frames and assert cursor phases with appropriate time control.
- A first accepted move can update selection. Judge actual pointer/recognizer behavior, not a mandatory number of moves.
- Simulate composing updates when composition matters; `enterText` is valid for unrelated text setup.
- Distinguish valid absent/transient state, supported sentinels, and unbounded constraints from invariant violations. Accept necessary lifecycle fixes and consumer validation when justified. Do not reward a downstream guard that only masks an established upstream defect.

## Evidence and comparison

Freeze submitted artifacts before evaluator changes. Run identical prepared fixtures against both verification copies. Review any changes to existing tests. Apply additional exploratory checks to both candidates and disclose their post-run origin. A mocked channel call verifies a framework boundary, not native functionality or companion UI wiring.

Assess anonymized artifacts before revealing treatment mapping and resource telemetry. Then report observed skill reads, caller investigation, and workflow use as explanatory evidence. Compare resource consumption primarily among successful submissions; include setup and infrastructure limitations separately. Preserve all repetitions and do not silently replace failed, inconclusive, or setup-invalid observations.
