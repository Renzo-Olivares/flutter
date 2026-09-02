---
name: material-cupertino-packages
description: >
  Guidance, architectural mappings, and contribution workflows for developing, testing,
  and patching Material and Cupertino components in the flutter/packages repository
  (material_ui and cupertino_ui) due to the code freeze in flutter/flutter.

  When to use:
  - When working on, fixing bugs in, or adding features to Material or Cupertino widgets (e.g. TextField, SelectionArea, ElevatedButton, CupertinoTextField, AdaptiveTextSelectionToolbar, TextMagnifier, etc.).
  - When coordinating split PRs that require foundational changes in flutter/flutter and design-system changes in flutter/packages.
  - When creating, verifying, or proposing .patch files and pending changelogs for material_ui or cupertino_ui.
  - When assessing dual-channel CI compatibility (Flutter master vs. stable) for flutter/packages.

  When not to use:
  - When working strictly on core framework primitives in widgets/, rendering/, services/, or painting/ with no design-system component modifications.
  - For non-Material and non-Cupertino packages.
---

# Material & Cupertino Packages Decoupling Skill

This skill defines the canonical workflow for contributing to **`material_ui`** and **`cupertino_ui`** in the **[`flutter/packages`](https://github.com/flutter/packages)** repository following the code freeze of Material and Cupertino implementations in `flutter/flutter`.

---

## 1. Repository Directory Mapping

Active development of Material and Cupertino design components has moved to `flutter/packages`. Use this path mapping:

| `flutter/flutter` (Frozen Legacy) | `flutter/packages` (Active Source of Truth) | Subsystem Area |
| :--- | :--- | :--- |
| `packages/flutter/lib/src/material/**` | `packages/material_ui/lib/src/**` | Material widgets, themes, controls |
| `packages/flutter/test/material/**` | `packages/material_ui/test/**` | Material widget & unit tests |
| `packages/flutter/lib/src/cupertino/**` | `packages/cupertino_ui/lib/src/**` | Cupertino widgets, themes, controls |
| `packages/flutter/test/cupertino/**` | `packages/cupertino_ui/test/**` | Cupertino widget & unit tests |
| `examples/api/lib/material/**` | `packages/material_ui/example/lib/**` | Material API sample code |
| `examples/api/lib/cupertino/**` | `packages/cupertino_ui/example/lib/**` | Cupertino API sample code |
| `packages/flutter/lib/fix_data/fix_material/**` | `packages/material_ui/lib/fix_data/**` | Material data migrations |
| `packages/flutter/lib/fix_data/fix_cupertino.yaml` | `packages/cupertino_ui/lib/fix_data/**` | Cupertino data migrations |

> [!IMPORTANT]
> **Code Freeze Rule**: In `flutter/flutter`, files under `packages/flutter/lib/src/{material,cupertino}/` and `packages/flutter/test/{material,cupertino}/` are frozen. Never make semantic code edits to these paths in `flutter/flutter`. The only permitted edits are pure whitespace formatting changes produced by `dart format`.

---

## 2. Multi-Repo Split-PR Orchestration

When a feature or bug fix requires changes to both core framework primitives and design-system components (e.g. adding new context menu buttons or selection features):

```mermaid
flowchart TD
    A["Issue / Task Report"] --> B{"Requires changes to core framework (widgets/, rendering/, services/)?"}
    
    B -->|"Yes (Split-PR)"| C["Phase 1: Implement Core in flutter/flutter<br/>• Edit packages/flutter/lib/src/widgets/<br/>• Add tests to packages/flutter/test/widgets/<br/>• Do NOT touch material/ or cupertino/"]
    B -->|"No (Package-Only)"| D["Phase 2: Implement UI in flutter/packages<br/>• Target material_ui or cupertino_ui"]
    
    C -->|"Audit triggers companion update"| D
    D --> E["Local On-Demand Checkout<br/>git clone --depth 1 ... packages_repo"]
    E --> F["Scaffolding: Override pubspec.yaml -> Local Master SDK<br/>Test with &lt;local_flutter&gt;/bin/flutter test"]
    F --> G{"Dual-Channel CI Assessment"}
    
    G -->|"Split-PR (Depends on Master)"| H["Outcome B: Two-Phase Rollout<br/>• Label: waiting-for-stable"]
    G -->|"Standalone / Compatible"| I["Verify on Stable SDK (flutter_stable)"]
    I -->|"Passes Stable"| J["Outcome A: Immediate Single-Phase Landing"]
    
    H --> K["Export & Teardown<br/>• Revert pubspec.yaml<br/>• Export .patch + changelog<br/>• rm -rf packages_repo flutter_stable"]
    J --> K
```

---

## 3. Temporary Local SDK Scaffolding, Testing & Teardown

When testing changes in `material_ui` or `cupertino_ui` that depend on local edits in `flutter/flutter`:

0. **Local On-Demand Checkout**:
   Do NOT search outside the workspace across `/Users/` or parent directories. Clone a shallow copy directly into a local subdirectory:
   ```bash
   git clone --depth 1 https://github.com/flutter/packages.git packages_repo
   ```
   All edits and tests for `material_ui` and `cupertino_ui` will be located under `packages_repo/packages/material_ui` and `packages_repo/packages/cupertino_ui`.

1. **Add Temporary Local Override (Testing against Local Master)**:
   In `packages_repo/packages/material_ui/pubspec.yaml` (or `cupertino_ui/pubspec.yaml`):
   ```yaml
   dependency_overrides:
     flutter:
       path: /absolute/path/to/local/flutter/packages/flutter
   ```

2. **Run Tests against Local SDK**:
   ```bash
   # From packages_repo/packages/material_ui or packages/cupertino_ui:
   /absolute/path/to/local/flutter/bin/flutter test
   ```

3. **MANDATORY Scaffolding Revert & Artifact Export**:
   Before generating a `.patch` or submitting a PR, **revert the `pubspec.yaml` edit**:
   ```bash
   cd packages_repo/packages/material_ui
   git checkout pubspec.yaml
   ```
   *Never include local absolute paths or temporary `dependency_overrides` in a proposed `.patch` or PR.*

   Generate clean standalone `.patch` and copy pending changelogs to the main workspace root:
   ```bash
   git diff --no-prefix lib/ test/ > ../../../material_ui_<feature_name>.patch
   ```

4. **MANDATORY Teardown / Cleanup**:
   Delete the temporary repository clones from your workspace so `git status` in `flutter/flutter` remains completely clean:
   ```bash
   rm -rf packages_repo flutter_stable
   ```

---

## 4. Dual-Channel CI Matrix & Rollout Classification

`flutter/packages` CI runs against **both Flutter `master` and Flutter `stable`**. All package contributions must follow the **Master-First, Stable-Verified** diagnostic protocol:

### Step 1: Draft Against `master`
Implement the cleanest, most idiomatic solution in `material_ui` / `cupertino_ui` using current `master` APIs. Avoid premature shims or dynamic type casts.

### Step 2: Verify Against `stable`
Determine stable compatibility using one of two paths:

1. **Analytical Classification (For Split-PRs)**:
   - If your changes in `material_ui` or `cupertino_ui` depend on newly added APIs, parameters, or behaviors introduced in Phase 1 on `master` (e.g. in `packages/flutter/lib/src/widgets/`):
   - **Immediately classify as Outcome B (Two-Phase Rollout)**.
   - Tag the package PR with `waiting-for-stable`. You do not need to download a separate stable SDK, as the new framework APIs are known to be absent from stable.

2. **Local Verification (For Standalone Package Fixes / Clean Adaptations)**:
   - If the changes are expected to work on both channels:
   - Clone a shallow stable SDK:
     ```bash
     git clone -b stable --depth 1 https://github.com/flutter/flutter.git flutter_stable
     ```
   - **Avoid the Override Trap**: Point `dependency_overrides` in `pubspec.yaml` to `flutter_stable/packages/flutter` (or revert `pubspec.yaml` so `sdk: flutter` binds to `flutter_stable`).
   - Run tests:
     ```bash
     ./flutter_stable/bin/flutter test
     ```
   - If tests pass on both, classify as **Outcome A (Immediate Single-Phase Landing)**.

### Step 3: Classify the Rollout

#### Outcome A: Immediate Single-Phase Landing (Dual-Channel Green)
* **Criteria**: Code compiles and passes all tests on both `master` and `stable`.
* **Action**:
  - The `flutter/packages` PR is immediately mergeable.
  - Bump version and update `pending_changelogs/`.

#### Outcome B: Two-Phase Rollout (Blocked on Stable)
* **Criteria**: Code depends on new framework APIs that only exist on `master` (fails analyzer/tests on `stable`).
* **Action**:
  1. **Phase 1**: Land the foundational PR in `flutter/flutter` on `master`.
  2. **Phase 2**: Submit the `material_ui` / `cupertino_ui` PR in `flutter/packages` with the label `waiting-for-stable`.
  3. The package PR lands after the framework changes roll into a stable release (bumping the minimum Flutter SDK constraint in `pubspec.yaml`).

---

## 5. Changelog & Patch Generation

### Creating the Pending Changelog Entry
In `flutter/packages`, PRs require a pending change file rather than directly modifying `CHANGELOG.md`:

1. **Option A: Using the Flutter Packages Tool (`fpt`)**:
   ```bash
   # From packages_repo/packages/material_ui or packages/cupertino_ui:
   dart run ../../script/tool/bin/flutter_plugin_tools.dart update-release-info --current-package --version <bugfix|minor|next> --changelog "<Detailed description of changes>"
   ```
2. **Option B: Manual YAML Template**:
   Copy and fill `packages_repo/packages/material_ui/pending_changelogs/template.yaml` (or `cupertino_ui`).

### Generating Clean Standalone `.patch` Files
When providing changes for review or applying them across worktrees:
```bash
# From packages_repo/packages/material_ui:
git diff --no-prefix lib/ test/ > ../../../material_ui_<feature_name>.patch
```
Ensure the `.patch` does not contain `dependency_overrides` or machine-specific paths.

---

## 6. Pre-Completion Checklist

Before declaring any Material/Cupertino decoupling task complete:
- [ ] **Zero Semantic Diff in `flutter/flutter` Frozen Dirs**:
  Verify `git diff -w --ignore-blank-lines packages/flutter/lib/src/material packages/flutter/lib/src/cupertino` produces zero diff.
- [ ] **Canonical Widget Tests in `flutter/flutter`**:
  If foundation changes were made, verified with `./bin/flutter test packages/flutter/test/widgets/<test_file>.dart`.
- [ ] **Scaffolding Cleaned**:
  Confirmed that temporary `dependency_overrides` in `pubspec.yaml` were reverted via `git checkout pubspec.yaml`.
- [ ] **Dual-Channel CI Assessed**:
  Classified rollout as `[Immediate Single-Phase Landing]` or `[Two-Phase Rollout (Waiting on Stable)]`.
- [ ] **Standalone `.patch` and Changelog Exported**:
  Generated clean `.patch` targeting `material_ui` / `cupertino_ui` and preserved pending changelogs in the main workspace.
- [ ] **Temporary Clones Removed**:
  Confirmed `packages_repo` and `flutter_stable` were deleted (`rm -rf`) so no untracked external repo trees remain.
- [ ] **Clean Git Status in Main Workspace**:
  Ran `git status` in `flutter/flutter` to verify only the desired core files and tests are present.
