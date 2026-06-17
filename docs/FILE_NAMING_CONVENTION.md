# File Naming Convention

## Format

```
<description>.<extension>
```

The output name is the `<description>` portion only — omit the extension.

---

## Rules

1. **Lowercase only** — no uppercase letters
2. **Underscores as separators** — use `_` between words, not spaces or hyphens
3. **Max 5 words** — keep names short and descriptive
4. **English only** — no Turkish or non-ASCII characters
5. **No special characters** — only `a-z`, `0-9`, and `_` are allowed
6. **No version or date identifiers** — no version numbers (e.g. `v2`), dates (e.g. `2024`), or sequential digits; technical terms that contain numbers as part of their standard name (e.g. `sha256`, `iso27001`) are allowed
7. **No leading or trailing underscores**

---

## Character Substitutions

When source content contains Turkish characters, substitute as follows:

| Original | Replace with |
|----------|--------------|
| `ç`      | `c`          |
| `ş`      | `s`          |
| `ğ`      | `g`          |
| `ü`      | `u`          |
| `ö`      | `o`          |
| `ı`      | `i`          |
| `İ`      | `i`          |
| `Ğ`      | `g`          |

---

## Examples

```
✓ reschedule_appointment_request
✓ aws_config_backup
✓ git_commit_convention
✓ right_to_represent_form
✓ algorithm_complexity_analysis
✓ sha256_benchmark
✓ iso27001_checklist
✗ algorithm-complexity-analysis
✗ Randevu-Yeniden-Planlama
✗ flight_reservation_v2
✗ resume_2024
✗ myFile
✗ my_file_name_that_is_too_long
```

---

## Decision Flow

```
Contains non-ASCII?                    → substitute per Turkish character table
More than 5 words?                     → drop articles, prepositions, and
                                         adjectives before nouns and verbs;
                                         if still over 5 words, keep the most
                                         semantically loaded nouns and verbs
Contains version/date/sequential       → remove numeric identifiers;
numbers?                                 retain numbers that are part of a
                                         standard technical term (e.g. sha256)
Contains uppercase?                    → convert to lowercase
Contains spaces?                       → replace with underscores
Contains hyphens?                      → replace with underscores
Contains special chars?                → remove
Contains file extension?               → remove
```

---

## Scope

### Applies to

- Downloaded files
- Generated files
- Project assets and documents

### Does not apply to

- Source code files governed by language conventions
- Configuration files with fixed names (e.g. `.zshrc`, `Brewfile`)
- Git-managed files with established names