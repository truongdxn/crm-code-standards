# Code Review Standard

The team's code review standard for CRM development. Each rule lives in its own Markdown file under `rules/<SCOPE>/<ID>.md`. On every merge to the default branch, CI validates the rules and publishes them as one page in the project wiki.

## Wiki

- [All rules][all-rules] — every active rule, grouped by scope (generated, do not edit)
- [Contributing][contributing] — how to submit, change, or deprecate a rule

## Contribute

Read [CONTRIBUTING.md](CONTRIBUTING.md). In short: copy `rules/_TEMPLATE.md`, fill it in, and open an MR with the **New_rule** template. No local build is needed.

## Repository layout

| Path | Content |
| --- | --- |
| `rules/<SCOPE>/<ID>.md` | One file per rule; `rules/_TEMPLATE.md` is the starting point |
| `.gitlab/merge_request_templates/` | MR description templates |
| `build/` | CI scripts: validate rules, build the All rules page, publish to the wiki |

<!-- Wiki links: replace GITLAB_HOST/GROUP with the real project path -->
[all-rules]: https://GITLAB_HOST/GROUP/crm-code-standards/-/wikis/All-rules
[contributing]: https://GITLAB_HOST/GROUP/crm-code-standards/-/wikis/Contributing
