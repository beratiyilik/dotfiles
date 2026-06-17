# Git Commit Message Convention

## Format

```
<type>(<optional scope>): <description>

<optional body>

<optional footer(s)>
```

---

## Types

| Type | When to use |
|------|-------------|
| `feat` | Adds or changes a feature in the API or UI |
| `fix` | Fixes a bug in the API or UI |
| `refactor` | Rewrites/restructures code without changing API or UI behavior |
| `perf` | Special `refactor` focused on performance improvement. Does not change the public API or UI contract — if it does, use `feat` (or `feat!` when breaking) |
| `style` | Code formatting only — whitespace, semicolons, import order, etc. No behavior change. This is **code** formatting, not visual/CSS design (visual changes are `feat` or `fix`) |
| `test` | Adds missing tests or corrects existing ones |
| `docs` | Documentation changes only |
| `build` | Build tools, dependencies, project version |
| `ops` | Infrastructure, deployment, CI/CD, backups, monitoring |
| `chore` | Miscellaneous tasks — `.gitignore`, initial commit, etc. |
| `revert` | Reverts a previous commit |

---

## Rules

1. **Subject line ≤ 50 characters**
2. **Use imperative mood** — "Add feature" not "Added feature"
3. **Do not capitalize** the first letter of the description
4. **Do not end** the subject line with a period
5. **Separate subject from body** with a blank line
6. **Wrap body at 72 characters**
7. **Body explains what and why**, not how
8. **One type per commit** — if a change is both a `feat` and a `fix`, split it into separate commits. Do not combine types (no `feat,fix:`)

---

## Breaking Changes

Append `!` after the type/scope:

```
feat(api)!: remove deprecated endpoint
```

Or add a footer:

```
BREAKING CHANGE: <description>
```

Both can be combined. `BREAKING CHANGE` in a footer **must** be uppercase.

A breaking change forces a major version bump regardless of the type
(see SemVer Mapping). `fix!` and `refactor!` are valid and also trigger a
major bump.

---

## Scope

Optional. A noun describing the area of the codebase affected, in parentheses.
Use the module or feature name — not the filename or path.

```
fix(parser): handle null input in tokenizer
feat(auth): add OAuth2 support
```

Do not use issue tracker IDs as scopes.

---

## Footer

Used for breaking changes and issue references. Follows git trailer format.

```
Reviewed-by: Jane Doe
Refs: #123
Closes: #456
Co-authored-by: Name <user@users.noreply.github.com>
```

Issue-reference keywords are not interchangeable:

- `Closes`, `Fixes`, `Resolves` auto-close the referenced issue when merged
  to the default branch on GitHub/GitLab.
- `Refs` links to an issue **without** closing it.

---

## Reverts

Use the `revert` type and reference the reverted commit hash in the body and a
footer:

```
revert: feat(auth): add OAuth2 support

This reverts commit 0123456789abcdef.

Refs: #456
```

The subject after `revert:` should reproduce the original subject line being
reverted.

---

## Examples

```
feat: add email notifications on new direct messages
```

```
fix(cart): prevent ordering with empty cart
```

```
feat(api)!: remove ticket list endpoint

BREAKING CHANGE: ticket endpoints no longer support listing all entities.
```

```
fix: add missing parameter to service call

The error occurred because the timeout value was not forwarded
to the downstream client.

Refs: #789
```

```
fix(cart): clear stale items on checkout

Closes: #321
Co-authored-by: Sam Lee <sam@users.noreply.github.com>
```

```
refactor(parser): extract token reader
```

```
perf(db): cache compiled query plans
```

```
style: format with prettier
```

```
test(auth): add token expiry cases
```

```
build: bump eslint to 9.0.0
```

```
ops: add staging deploy workflow
```

```
revert: feat(auth): add OAuth2 support

This reverts commit 0123456789abcdef.

Refs: #456
```

```
docs: correct spelling in CHANGELOG
```

```
chore: init
```

---

## Decision Flow

```
Bug fix?                                 → fix
New/changed API or UI feature?           → feat
Performance improvement (same contract)? → perf
Code restructuring (no behavior change)? → refactor
Formatting only?                         → style
Tests added/corrected?                   → test
Documentation only?                      → docs
Build tools or dependencies?             → build
Infra, deployment, CI/CD?                → ops
Reverting a prior commit?                → revert
Anything else                            → chore
```

If a commit matches more than one type, split it.

---

## SemVer Mapping

| Commit | Stable (`≥1.0.0`) | Initial dev (`0.y.z`) |
|--------|-------------------|-----------------------|
| Breaking (`!` / `BREAKING CHANGE`) | Major (`1.0.0` → `2.0.0`) | Minor (`0.1.0` → `0.2.0`) |
| `feat` | Minor (`1.0.0` → `1.1.0`) | Patch (`0.1.0` → `0.1.1`) |
| `fix`, `perf`, others | Patch (`1.0.0` → `1.0.1`) | Patch (`0.1.0` → `0.1.1`) |

The breaking flag overrides the type (`feat!`, `fix!`, `perf!`). During `0.x`
the API is unstable: breaking changes bump minor, not major — go to `1.0.0`
only when deliberately declaring the API stable.

### Pre-releases

Hyphenated suffix on the target version; lifecycle `alpha → beta → rc → stable`:

```
0.1.0-alpha.0 → 0.1.0-alpha.1   (advance within stage)
              → 0.1.0-beta.0    (promote stage, reset counter)
              → 0.1.0-rc.0
              → 0.1.0           (drop suffix to release)
```

Pick the target version (`0.1.0`) via the bump rules above; the suffix only
tracks progress toward it. Precedence: a pre-release sorts below the suffixless
version, and `alpha < beta < rc`.