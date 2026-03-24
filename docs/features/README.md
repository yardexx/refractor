# Feature Docs

Feature docs are organized by lifecycle state, not by version folder.

## Folders

- [implemented/](implemented/) for released and trusted feature reference docs
- [development/](development/) for features in the next concrete release under
  active implementation
- [future/](future/) for planned, research, deferred, or later-version feature
  docs

## Lifecycle Rule

- roadmap files decide when a feature belongs to a release
- feature docs define what the feature does and how it is verified
- when a feature ships and becomes stable reference material, move it from
  `development/` to `implemented/`
- if a feature is not part of the next concrete release, keep it in `future/`
  until it becomes active again

## Current State

- `development/` should mirror the next concrete release scope
- `implemented/` may be empty if a feature has shipped in code but does not yet
  have a stable reference doc
