# Contributing

How to add, change, or retire a code review rule. When in doubt, ask in the team channel.

## Roles

- **Maintainer**: one per scope (GE, FE, BE). Reviews rule MRs in that scope and settles disagreements.
- **Contributor**: anyone on the team.

Current maintainers are listed in the team space.

## Add a rule

1. Discuss the idea in the team channel first.
2. Copy `rules/_TEMPLATE.md` to `rules/<SCOPE>/<ID>.md`, using the next free ID in that scope (e.g. `BE-002`).
3. Fill in the frontmatter and the sections `Description`, `Bad`, `Good`, `Exceptions`.
4. Open an MR titled `Rule <ID>: <short title>`.
5. Merge after **2 approvals, including the scope Maintainer**. The rule applies from the merge date.
6. Announce the new rule in the team channel.

If two MRs pick the same ID, the one merged first keeps it; the other renumbers.

## Change or retire a rule

- Raise it in the team channel: `[Rule <ID>]` + what is wrong + a link to an example.
- Agree on the fix there, then open an MR (same approvals as above).
- To retire a rule, set `Status: Deprecated` and add `Replaced by: <ID>` if there is a successor. Rule IDs are never reused.

Until the fix is merged, the rule still applies. If code is flagged only because of a known problem, the reviewer may approve it and link the discussion.

## MR checklist

- [ ] File is `rules/<SCOPE>/<ID>.md`, file name matches the ID
- [ ] `Title` is one imperative sentence
- [ ] `Bad` and `Good` are real, compilable examples
- [ ] `Exceptions` filled in (`None` if not applicable)
- [ ] Severity fits the table in README
- [ ] CI passes
