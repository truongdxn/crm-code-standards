# Contributing to the Code Review Standard

This document defines **how a rule is proposed, reviewed, trialled, activated and retired**.
It names roles, not people: who holds each role is kept outside this repo (see [Roles](#roles)).

## Roles

| Role | Responsibilities |
| --- | --- |
| **Standard Owner** | Owns this process and the closed lists (scopes, severities, statuses, build). Final approver for promoting a rule to Active, deprecating it, or making a substantive change to an Active rule. Decides when reviewers disagree. |
| **Scope Maintainer** (one per scope: GE, FE, BE) | Triages proposals in their scope, reserves rule IDs, reviews rule MRs, collects Draft feedback. |
| **Contributor** | Anyone on the team. Proposes rules, gives feedback on Draft rules. |

- Current role holders are listed in the team space, not in this file, because they change over time.
- One person may hold several roles, but **nobody approves their own MR**.

## Rule lifecycle

```
Proposal (issue) --> Draft (1 week trial) --> Active --> Deprecated
                          |
                          +--> Rejected (file removed, ID retired)
```

| Status | Meaning in code review |
| --- | --- |
| Draft | Trial. Reviewers comment `[Draft <ID>]`, **never blocks a merge**. |
| Active | Enforced according to its severity (see README). |
| Deprecated | No longer enforced. Kept for history; `Replaced by` points to the successor if any. |

### 1. Propose

1. Open an issue "Rule proposal: <short title>" with: problem, proposed rule, scope, severity, one Bad/Good example.
2. The Scope Maintainer triages it:
   - **accept**: reserves the next free ID in a comment on the issue (e.g. `Reserved: BE-002`), or
   - **decline**: closes the issue with the reason.
3. Only a reserved ID may be used. **IDs are never reused**, including IDs of rejected or deprecated rules.

### 2. Add as Draft

1. Create `rules/<SCOPE>/<ID>.md` from `rules/_TEMPLATE.md`, with `Status: Draft`.
2. Open an MR that links the issue and follow the [MR checklist](#mr-checklist).
3. Merge needs **2 approvals**, one of which is the Scope Maintainer.
4. After merge, announce the Draft in the team channel (rule ID, link, end date of the trial).

### 3. Trial (1 week)

- The trial lasts **1 week from the merge date** of the Draft MR.
- Reviewers apply the rule as a non-blocking comment `[Draft <ID>]`.
- Feedback (false positives, unclear wording, missing exceptions) goes to the proposal issue.
- The Scope Maintainer updates the rule during the trial if needed. Changes made during the trial do not restart it unless the Standard Owner says so.

### 4. Promote to Active, extend, or reject

At the end of the trial, the Scope Maintainer opens one of these MRs:

| Outcome | When | MR content |
| --- | --- | --- |
| **Promote** | Feedback addressed, no open objection | `Status: Active` |
| **Extend** | Feedback still being addressed | No MR; comment on the issue with the new end date (+1 week, at most once) |
| **Reject** | Rule does not work in practice | Delete the rule file, close the issue with the reason |

Promote and Reject need **2 approvals, one of which is the Standard Owner**.
After merge, announce the outcome in the team channel.

### 5. Change an Active rule

| Change type | Examples | Approvals | Takes effect |
| --- | --- | --- | --- |
| Editorial | Typo, clearer wording, better example, new exception | 2 | On merge |
| Substantive | What the rule requires changes, severity raised, `Applied to` widened | 2, including the Standard Owner | **1 week after merge** (grace period), announced in the team channel |

A severity downgrade or narrowed `Applied to` is editorial: it takes effect on merge.

### 6. Deprecate

1. MR setting `Status: Deprecated`, plus `Replaced by: <ID>` if a successor exists.
2. **2 approvals, one of which is the Standard Owner.**
3. Announce in the team channel.

## Approvals at a glance

| Change | Approvals | Must include |
| --- | --- | --- |
| New Draft rule | 2 | Scope Maintainer |
| Draft → Active, reject Draft | 2 | Standard Owner |
| Editorial change to a rule | 2 | Scope Maintainer |
| Substantive change to an Active rule | 2 | Standard Owner |
| Deprecate | 2 | Standard Owner |
| This process, closed lists, `build/`, CI | 2 | Standard Owner |

The author's own approval never counts.

## MR checklist

- [ ] Linked to the proposal issue; the ID matches the one reserved there
- [ ] File is `rules/<SCOPE>/<ID>.md` and follows `_TEMPLATE.md`
- [ ] `Title` is one imperative sentence
- [ ] `Description` says what and **why** (1-3 sentences)
- [ ] `Bad` and `Good` are real, compilable snippets for this codebase
- [ ] `Exceptions` filled in (write "None" if there are none)
- [ ] Severity chosen per the table in README
- [ ] Status matches the lifecycle step of this MR
- [ ] CI pipeline is green

## Review expectations

- Reviewers respond to a rule MR within **3 working days** (proposed default, adjust if needed).
- Disagreement that is not settled in the MR thread goes to the Standard Owner, whose decision is final.

## Communication

Announce in the team channel every time a rule becomes Draft, Active, Rejected or Deprecated, and when a substantive change will take effect.
Each announcement includes the rule ID, its title, a link, and the effective date.

## Not yet in place

These items support the process above but are not implemented in the repo yet:

- `CODEOWNERS` and GitLab approval rules enforcing the approval table
- Issue template for rule proposals and MR template with the checklist
- Publishing the rule set from `main` (instead of committing the generated README in each MR)
- Merged results pipelines, so a duplicate ID is caught before merge

Until then, reviewers check approvals and the MR checklist by hand.
