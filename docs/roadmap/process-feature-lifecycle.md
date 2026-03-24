# Feature Lifecycle: From Idea to Release

How features move from idea to shipped code in Refractor.

---

## The Loop

```
Idea -> Issue -> Branch -> Code + Tests -> PR -> Review/CI -> Merge -> Release
```

One feature = one issue = one branch = one PR. Keep it small enough to ship in a few days.

---

## 1. Write the Issue First

Before writing any code, create a GitHub issue. Even for solo work — it forces clarity and creates a public record.

**Issue template:**

```markdown
## What
One sentence: what changes and why.

## Context
Link to the feature doc in `docs/` if one exists, or describe the problem.

## Scope
- [ ] Checklist of concrete deliverables
- [ ] Include test requirements
- [ ] Note what's explicitly out of scope

## Acceptance Criteria
How do we know it's done? (tests pass, E2E works, binary output unchanged, etc.)
```

**Labels:** `feature`, `bug`, `enhancement`, `infra`, `docs`
**Milestone:** Always assign to a version milestone (v0.2.0, v0.3.0, etc.)

---

## 2. Branch From the Release Branch

Follow the branching strategy:

```
main (stable, release-ready)
  └── release/0.2.0 (collects all v0.2 work)
        ├── feature/rename-overloading
        ├── feature/string-interpolation
        └── fix/dynamic-dispatch-crash
```

```bash
# Start work on a feature for v0.2.0
git checkout release/0.2.0
git pull
git checkout -b feature/my-feature
```

**Rules:**
- Feature branches target `release/X.Y.Z`, never `main` directly
- Only `release/*` branches merge into `main`
- Branch names: `feature/`, `fix/`, `refactor/`, `test/`, `chore/`

---

## 3. Write Code + Tests Together

**Before coding:**
- Read the relevant source files — understand what exists before changing it
- If the task is non-trivial (3+ steps), write a plan first (in the PR description or a todo file)

**While coding:**
- One concern per commit — don't mix a feature with a refactor
- Write tests alongside the code, not after
- Run `dart test` and `dart analyze` before pushing

**Test expectations by type:**
| Change | Required tests |
|--------|---------------|
| New AST node handler | Unit test with synthetic kernel + E2E smoke test |
| New pass | Unit tests + E2E test proving output is functionally correct |
| Bug fix | Regression test that fails without the fix |
| Refactor | Existing tests must pass unchanged |
| Config change | Config parsing test |

**Commit style:**
```
feat: add string interpolation handling to encrypt pass
fix: handle DynamicInvocation in rename transformer
test: add E2E smoke test for rename + string_encrypt
refactor: extract const-context guard to base class
chore: update analysis_options
docs: add control flow flattening design doc
```

---

## 4. Open a PR

PR targets the release branch (e.g., `release/0.2.0`).

```bash
gh pr create --base release/0.2.0 --title "feat: string interpolation encryption" --body "$(cat <<'EOF'
## Summary
- Encrypt literal segments inside StringInterpolation nodes
- Add @pragma('vm:never-inline') to decode helper

Closes #42

## Test Plan
- [ ] Unit test: interpolation parts are replaced with decode calls
- [ ] Unit test: expression segments unchanged
- [ ] E2E: obfuscated binary with interpolations produces correct output
- [ ] Unicode fixture (Czech, emoji, CJK)
EOF
)"
```

**PR checklist (mental, not enforced):**
- CI passes (format, analyze, test)
- No unrelated changes in the diff
- Issue linked (`Closes #N`)
- New code has tests

---

## 5. CI Must Pass

CI runs on every push:
- `dart format --set-exit-if-changed .`
- `dart analyze --fatal-infos`
- `dart test`
- Coverage report

If CI fails, fix it on the feature branch. Don't merge with failures.

---

## 6. Merge and Close

```bash
# Merge feature into release branch
gh pr merge --squash
```

Squash merge keeps the release branch history clean — one commit per feature.

The linked issue auto-closes when the PR merges.

---

## 7. Cut a Release

When all issues in a milestone are closed:

```bash
# On release/0.2.0, verify everything
dart test
dart analyze

# Merge release into main
git checkout main
git merge release/0.2.0

# Tag and publish
git tag v0.2.0
git push origin main --tags

# Create GitHub Release
gh release create v0.2.0 --title "v0.2.0" --notes "$(cat CHANGELOG.md | ...)"

# Publish to pub.dev
dart pub publish
```

Update `CHANGELOG.md` and `pubspec.yaml` version before merging.

---

## 8. Research Alongside Shipping

To keep understanding the platform while shipping features:

- **Read one kernel AST node type per feature** — when implementing a handler, read the full node class in the vendored kernel library. Understand its fields, semantics, and when the Dart compiler emits it.
- **Run `refractor inspect` on real apps** — periodically inspect a non-trivial Dart app to discover patterns you haven't handled.
- **Check reverse engineering tools** — run Blutter or `strings` on your test outputs to verify obfuscation is effective.
- **Read Dart SDK changelogs** — when a new Dart SDK drops, check if kernel format changed.

---

## Quick Reference

| Step | Command |
|------|---------|
| Create issue | `gh issue create --milestone v0.2.0 --label feature` |
| Start branch | `git checkout -b feature/x release/0.2.0` |
| Run tests | `dart test` |
| Run analysis | `dart analyze` |
| Open PR | `gh pr create --base release/0.2.0` |
| Merge | `gh pr merge --squash` |
| Tag release | `git tag v0.2.0 && git push --tags` |
| Publish | `dart pub publish` |