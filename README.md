# Code Review Standard

Team code review standard. Each rule lives in its own file under `rules/<SCOPE>/<ID>.md`.

## Scopes

| Code | Scope |
| --- | --- |
| GE | General — applies to all code |
| FE | Frontend — JS, PCF, Canvas app |
| BE | Backend — plugin, custom API, workflow, webjob |

## Severity

| Level | Meaning | In review |
| --- | --- | --- |
| Blocker | Security hole, data loss, production crash | Must fix before merge |
| Major | Measurable impact on performance, stability, maintainability | Fix, or follow-up ticket approved by lead |
| Minor | Readability, convention | Should fix, non-blocking |
| Info | Suggestion | Optional |

## How to contribute

1. Copy `rules/_TEMPLATE.md` to `rules/<SCOPE>/<ID>.md` (next free number in that scope).
2. Fill in the frontmatter and the sections `Description`, `Bad`, `Good`, `Exceptions`.
3. Run `build\build_rules.cmd` (or double-click it) and commit the updated `README.md` with your rule.
4. Open a merge request. CI fails if a rule is invalid or `README.md` is out of date.

<!-- RULES:START -->
_Auto-generated from `rules/` by `build/build_rules.ps1`. Do not edit this section by hand._

**1 active** · 0 draft · 0 deprecated

## Table of contents

- **BE — Backend**
    - [BE-001](#be-001-do-not-use-columnsettrue-in-retrieve) · Do not use ColumnSet(true) in Retrieve · Major

## BE — Backend

### BE-001: Do not use ColumnSet(true) in Retrieve

- **Severity:** Major
- **Applied to:** plugin, custom-api, workflow, webjob

#### Description
Retrieve / RetrieveMultiple must fetch only the columns actually used. ColumnSet(true) pulls every column, which increases query time and payload size and can push synchronous plugins into a timeout.

#### Bad
```csharp
var account = service.Retrieve("account", id, new ColumnSet(true));
```

#### Good
```csharp
// Only fetch the columns this logic needs
var account = service.Retrieve("account", id,
    new ColumnSet("name", "creditlimit"));
```

#### Exceptions
Copying / cloning an entire record — add a comment explaining why.
<!-- RULES:END -->
