# Flutter Text Domain Expert — Skill Version Specification & Changelog

This document tracks the canonical evolutionary versions of the `flutter-text-domain-expert` skill and its companion rules across progressive benchmark sampling iterations.

---

## Canonical Skill Versions

| Version | Commit SHA | Milestone / Theme | Primary Focus & Capabilities Added | Benchmark Role |
| :--- | :--- | :--- | :--- | :--- |
| **`v0`** | [`67710a5db2`](https://github.com/flutter/flutter/commit/67710a5db2adcae7e5ad606c7f5001108e037672) | **Framework Baseline** *(No Skill)* | Standard Flutter repository without any specialized text domain expert skill or custom agent instructions. | Baseline for Sample 1 ([#162856](https://github.com/flutter/flutter/issues/162856)) & Sample 2 ([#141775](https://github.com/flutter/flutter/issues/141775)) |
| **`v1`** | [`19261190ba`](https://github.com/flutter/flutter/commit/19261190bad200063c67b57d550811b0f3f4773a) | **First Iteration** | Initial text domain expert architecture: reference guides (`common_text_primitives.md`, `editable_text_pipeline.md`, `static_text_pipeline.md`, `testing_text_stack.md`), subsystem routing, and testing invariants. | Initial draft for #162856 |
| **`v2`** | [`7bb6d97c23`](https://github.com/flutter/flutter/commit/7bb6d97c23779cb315048c4c4e8d9765f7fc8646) | **Selection Geometry Changes** | Edge-scrolling invariants, coordinate transformation rules, and `SelectionGeometry` querying patterns within `SelectionContainerDelegate` (preventing naive bounding box math). | Treatment for Sample 1 ([#162856](https://github.com/flutter/flutter/issues/162856))<br>Baseline for Sample 2 ([#141775](https://github.com/flutter/flutter/issues/141775)) |
| **`v3`** | [`30d7c11508`](https://github.com/flutter/flutter/commit/30d7c115080a66baa45427f32cf795a5abd02c4a) | **Context Menu & Decoupled Packages** | Decoupled multi-repo workflow (`material-cupertino-packages`), minimal `code-freeze.md` redirect, and Invariant 7 enforcing delegating constructor parity (zero parameter dropping) for companion wrappers in `material_ui` and `cupertino_ui`. | Treatment for Sample 2 ([#141775](https://github.com/flutter/flutter/issues/141775)) |
| **`v4`** | [`5e5cb9af9c`](https://github.com/flutter/flutter/commit/5e5cb9af9c7caddb31daa67aa2c4646498ee6430) | **Lifecycle Investigation & Modular Test Isolation** | Generalized prompt harness enforcing upfront interaction/lifecycle contract inspection and structural vs. interactive test isolation; validated across multi-session consistency runs. | Prompt Refinement & Multi-Run Consistency Validation for Sample 2 ([#141775](https://github.com/flutter/flutter/issues/141775)) |

---

## Detailed Version Specifications

### v4 — Lifecycle Investigation & Modular Test Isolation
- **Commit**: [`5e5cb9af9c7caddb31daa67aa2c4646498ee6430`](https://github.com/flutter/flutter/commit/5e5cb9af9c7caddb31daa67aa2c4646498ee6430)
- **Trigger Issue**: [flutter/flutter#141775](https://github.com/flutter/flutter/issues/141775) (`[iOS] Add default buttons to SelectionArea context menu`)
- **Key Capabilities & Architectural Rules Added**:
  1. **Subsystem-Agnostic Lifecycle Investigation**:
     - Explicitly directs agents in the pre-fix investigation phase to analyze adjacent callback contracts, state transitions, dismissals, and platform channels before drafting tests.
  2. **Modular Test Isolation**:
     - Directs agents to separate static/structural configuration verification from interactive gesture sequences, avoiding fragile multi-action chained taps across dismissed component overlays.
  3. **Multi-Session Determinism**:
     - Validated across independent evaluation runs to achieve consistent turn reduction (~26%, 160 $\to$ 118 turns) and 100% first-pass green verification on post-fix test suites.

### v3 — Context Menu, Decoupled Packages & Delegating Constructor Parity
- **Commit**: [`30d7c115080a66baa45427f32cf795a5abd02c4a`](https://github.com/flutter/flutter/commit/30d7c115080a66baa45427f32cf795a5abd02c4a)
- **Trigger Issue**: [flutter/flutter#141775](https://github.com/flutter/flutter/issues/141775) (`[iOS] Add default buttons to SelectionArea context menu`)
- **Key Capabilities & Architectural Rules Added**:
  1. **Delegating Constructor Parity (Invariant 7)**:
     - Explicitly mandates that when a core primitive or helper function adds or extends parameters, callbacks, or supported capabilities, downstream callers and delegating constructors (e.g. `AdaptiveTextSelectionToolbar.selectable`, `CupertinoAdaptiveTextSelectionToolbar.selectable`) must expose and forward them.
     - Enforces **Zero Parameter Dropping**: Prohibits delegating constructors from dropping parameters or defaulting them to `null` simply because Dart optional parameter rules allow it.
  2. **Multi-Repo Decoupled Packages Skill (`material-cupertino-packages`)**:
     - Guides the agent through the complete multi-repo split PR workflow when companion text wrappers reside in `material_ui` or `cupertino_ui` under `flutter/packages`.
     - Standardizes local on-demand shallow checkouts (`git clone --depth 1 https://github.com/flutter/packages.git packages_repo`), local SDK `dependency_overrides`, dual-channel CI testing (master framework override vs stable SDK), patch generation, and mandatory clone teardown (`rm -rf packages_repo flutter_stable`).
  3. **Lean Code Freeze Rule**:
     - Stripped rule bloat from `.agents/rules/code-freeze.md` to keep it strictly focused as a binary stop sign on frozen paths (`packages/flutter/lib/src/{material,cupertino}/`), directly redirecting to `flutter/packages`.

### v2 — Selection Geometry & Edge Scrolling
- **Commit**: [`7bb6d97c23779cb315048c4c4e8d9765f7fc8646`](https://github.com/flutter/flutter/commit/7bb6d97c23779cb315048c4c4e8d9765f7fc8646)
- **Trigger Issue**: [flutter/flutter#162856](https://github.com/flutter/flutter/issues/162856) (`Edge scrolling of selection area not working when scroll view not wrapped by SafeArea`)
- **Key Capabilities & Architectural Rules Added**:
  1. **SelectionGeometry Queries**:
     - Documented the canonical pattern for querying selection geometry and line heights via `SelectionContainerDelegate` and `SelectionGeometry` rather than relying on raw global transforms or bounding box estimates.
  2. **Section 8 Edge-Scrolling Guidelines**:
     - Added comprehensive autoscroll and gesture guidelines to `references/static_text_pipeline.md`.
     - Established testing invariants preventing test hangs on focused inputs (`pumpAndSettle()` hang trap) and multi-move requirements for `kTouchSlop` / `kPanSlop`.

### v1 — First Iteration
- **Commit**: [`19261190bad200063c67b57d550811b0f3f4773a`](https://github.com/flutter/flutter/commit/19261190bad200063c67b57d550811b0f3f4773a)
- **Trigger Issue**: Initial establishment of the Flutter text domain expert skill
- **Key Capabilities Added**:
  1. Initial modular reference architecture: `common_text_primitives.md`, `editable_text_pipeline.md`, `static_text_pipeline.md`, `testing_text_stack.md`, and `text_debugging_playbooks.md`.
  2. Subsystem routing table and core architectural invariants (layer boundary imports, IME composing range preservation, BiDi/TextAffinity).
  3. Test location guide mapping Flutter text tests across `packages/flutter/test/`.

### v0 — Baseline (No Skill)
- **Commit**: [`67710a5db2adcae7e5ad606c7f5001108e037672`](https://github.com/flutter/flutter/commit/67710a5db2adcae7e5ad606c7f5001108e037672)
- Unmodified Flutter repository commit prior to the introduction of `.agents/skills/flutter-text-domain-expert/`.
