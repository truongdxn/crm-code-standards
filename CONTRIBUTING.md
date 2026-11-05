# Code Review Standard

## Contribution Guide

This guide defines how to submit a code review rule and get it merged. Questions, problems with existing rules, and anything not covered here are discussed in the team channel.

## 1. Roles

| Role            | Responsibility                                                                                       |
| --------------- | ---------------------------------------------------------------------------------------------------- |
| **Maintainer**  | One per scope (GE, FE, BE). Owns the rules in that scope; reviews and approves rule MRs, confirms IDs. |
| **Contributor** | Any team member who creates rules or gives feedback.                                                 |

Role holders are maintained in the team space. One person may hold multiple roles, but cannot approve their own MR.

## 2. Rule lifecycle

```mermaid
flowchart LR
    A["Create<br/>Rule MR opened"] --> B{"Review /<br/>Approve"}
    B -->|Changes requested| A
    B -->|Not accepted| X["MR closed"]
    B -->|Approved| C["Merge<br/>Status: Active"]
    C --> D["Applied in<br/>code reviews"]
    D -->|No longer needed| G["Deprecated"]
    D --> E{"Change<br/>needed?"}
    %% Bottom row: declared left to right so "Change MR" sits under "Merge",
    %% then linkStyle hides the right-hand arrowhead so arrows point right to left
    B <--> F["Change MR"]
    F <-->|"Yes, discussed in<br/>team channel"| E
    linkStyle 7,8 marker-end:none
```

| Status         | Meaning                                                                    |
| -------------- | -------------------------------------------------------------------------- |
| **Active**     | Followed in code reviews.                                                  |
| **Deprecated** | No longer enforced; retained for history. Add `Replaced by` if applicable. |

**Rule IDs are never reused**, including deprecated IDs and IDs from closed MRs.

## 3. Submit a rule

### 3.1. Create

- An MR may contain one or more rules, in any scope.
- For each rule, take the next free ID in its scope (e.g. `BE-002`). If another MR merged first with the same ID, renumber only the conflicting rule.
- Create `rules/<SCOPE>/<ID>.md` from `rules/_TEMPLATE.md`, with `Status: Active`. Submit only the rule files: no build is needed, CI validates them.
- Open an MR titled `Rule <ID>: <short title>`, or `Rules <ID>, <ID>: <short summary>` for several rules.
- In **Description**, choose the template **New_rule** and tick the [MR checklist](#6-mr-checklist). Rule details are reviewed in the MR changes.

### 3.2. Review / Approve

- Get **2 approvals, including the Maintainer** of the scope.
- The Maintainer confirms the ID. Reviewers may request changes, or the Maintainer may close the MR with a reason.

### 3.3. Merge

- The rule is enforced from the merge date.
- After merge, CI publishes the updated rule set to the **All rules** wiki page.
- Announce the rule in the team channel.

## 4. Change or deprecate a rule

- Raise it in the team channel first, then open an MR with the agreed change. It follows steps 3.2 and 3.3.
- To deprecate, set `Status: Deprecated` and add `Replaced by: <ID>` if a successor exists.

## 5. Approvals

- Every rule MR (new rule, change, deprecation) requires **2 approvals, including the Maintainer** of the scope. The author's approval does not count.
- Changes to this process, closed lists, `build/`, or CI require approval from a Maintainer of each scope.

## 6. MR checklist

Included in the **New_rule** MR template. Applies to every rule in the MR.

- [ ] ID is the next free ID in its scope and matches the file name (new rules).
- [ ] File path and structure follow `rules/<SCOPE>/<ID>.md` and `rules/_TEMPLATE.md`.
- [ ] `Title` is one imperative sentence.
- [ ] `Description` explains what and why (1–3 sentences).
- [ ] `Bad` and `Good` are real, compilable code examples.
- [ ] `Exceptions` is completed (`None` if not applicable).
- [ ] Status is correct.
- [ ] Required approvals are present.
- [ ] CI pipeline passes.

## 7. Scopes

| Code | Scope |
| --- | --- |
| GE | General — applies to all code |
| FE | Frontend — JS, PCF, Canvas app |
| BE | Backend — plugin, custom API, workflow, webjob |
