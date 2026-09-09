# Timaeus Blueprint fork

This fork is the shared document framework for
[all Timaeus anchors](https://github.com/timaeus-research/anchors).
The maintained branch is `timaeus/v4.33.0`, initially based on upstream
`9dd255542ad41ba66492051395c0fd6cacd9f7a9` (Lean 4.33.0).
The bootstrap changes documentation only; rendering matches that upstream
revision. Anchors pin an exact commit, never the moving branch head.

## Development

Use `origin` for `timaeus-research/verso-blueprint` and `upstream` for
`leanprover/verso-blueprint`. Keep upstream history intact and put our changes
on the Timaeus branch. Use the repository's worktree harness with an explicit
`--base timaeus/v4.33.0` for new work. The branch policy and contributor guide
describe upstream's release process; our fork can land changes directly on
its maintained branch without an upstream PR or paired upstream backport.

Choose the extension mechanism per feature. New directives, roles, and block
extensions can live in this package; changes to existing node metadata,
traversal, rendering, CSS, and JavaScript also belong here when appropriate.
Preserve semantic ownership: commentary attached to a theorem need not become
a separately numbered node in the dependency graph. Upstream contributions
are optional, not a prerequisite for using a change in the anchors.

When updating upstream, inspect the toolchain and dependency changes, integrate
them deliberately on the Timaeus branch, and validate before updating anchors.
Do not automatically follow upstream's default branch: it can target a newer
Lean release. Avoid rewriting commits already pinned by anchors.

## Current integration and migration work

The anchors repository owns mathematical documents and paper-specific data.
It currently also owns two HTML post-processors:

- `scripts/inject-paper-chips.py` renders a paper identity badge immediately
  after the node heading, using `paper-refs.json` and `paper-labels.json`.
- `scripts/inject-issue-chips.py` adds reader feedback links.

These remain active at bootstrap. The paper badge is separate from Blueprint's
existing source-provenance panel in `Informal/Block/Render.lean`. Moving the
badge into native rendering should preserve its title-row placement and
computed numbering. Keep paper-specific reference resolution with the anchors;
define the structured input and its rendering in this package. Remove the
corresponding injector only when the native path covers the same cases.

Formalization commentary (including the proposed fidelity annotation) is
another pending extension. Its schema and presentation are not yet implemented.

The anchors' `scripts/blueprint-pin.json` records the shared package URL and
revision; `scripts/check-blueprint-pin.py` verifies every Lake configuration
and lockfile agrees. After a framework change, push the fork commit first,
update that pin and all anchor dependencies together, and check a rendered
anchor before rolling out. Dependency changes also require Lake to resolve
the updated transitive lockfiles.
