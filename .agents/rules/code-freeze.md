---
trigger: always_on
---

# Material and Cupertino Code Freeze Rule

All code and tests in Material and Cupertino in the `flutter/flutter` repository are **FROZEN**:
- `packages/flutter/lib/src/material/**`
- `packages/flutter/lib/src/cupertino/**`
- `packages/flutter/test/material/**`
- `packages/flutter/test/cupertino/**`
- `packages/flutter/examples/api/lib/material/**`
- `packages/flutter/examples/api/lib/cupertino/**`
- `packages/flutter/examples/api/test/material/**`
- `packages/flutter/examples/api/test/cupertino/**`
- `packages/flutter/lib/fix_data/fix_cupertino.yaml`
- `packages/flutter/lib/fix_data/fix_material/**`
- `packages/flutter/test_fixes/material/**`
- `packages/flutter/test_fixes/cupertino/**`

---

## 1. Strict Formatting-Only Exemption

Modifications to frozen directories in `flutter/flutter` are **strictly permitted ONLY if they are mechanical formatting changes produced by `dart format`** (e.g. during repo-wide formatting passes or Dart SDK formatter upgrades).

### Invariant for Formatting Changes in Frozen Folders:
* Running `git diff -w --ignore-blank-lines <frozen_paths>` MUST produce **zero diff** (confirming zero AST or semantic changes, and no logic, comments, types, or imports were altered).

---

## 2. Prohibition on Semantic & Behavioral Changes

* **NEVER** add new features, bug fixes, refactors, API signatures, or widget modifications to frozen Material/Cupertino files in `flutter/flutter`.
* All active development, bug fixes, and feature additions for Material and Cupertino components belong in **`material_ui`** and **`cupertino_ui`** under the **`flutter/packages`** repository (`https://github.com/flutter/packages`).
* When handling tasks, issues, or PRs involving Material or Cupertino components, activate and follow the **`material-cupertino-packages`** skill to orchestrate multi-repo split PRs, local verification, and `.patch` generation.

---

## 3. Companion Design-System Wrapper Audit

Whenever adding, updating, or extending APIs, parameters, callbacks, or properties in core framework primitives (`widgets/`, `rendering/`, `services/`, `painting/`) that have corresponding design-system wrappers or adapters:
* **Mandatory Audit**: Check whether consumer widgets or adapters in Material or Cupertino forward or expose those properties.
* **Trigger Split-PR**: If the design-system wrappers require companion updates, do NOT stop at the framework boundary. Follow the split-PR workflow using **`material-cupertino-packages`** to patch `material_ui` and/or `cupertino_ui` in the `flutter/packages` repository.
