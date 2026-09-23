# Timaeus fork of verso-blueprint

This repository is the Timaeus fork of
[leanprover/verso-blueprint](https://github.com/leanprover/verso-blueprint). Development
happens here, on the branch `timaeus/v4.33.1`; consumers pin a commit of that branch.

## Provenance

- Upstream base: `9dd25554` on upstream's `v4.33.0` branch (Lean 4.33.0), plus the fork's
  `doc: establish the shared Timaeus Blueprint fork` (`a5b363c6`).
- From 9 September to 22 September 2026 the package was vendored in
  `timaeus-research/anchors` under `vendor/verso-blueprint` (branch `verso-blueprint-v4.33.1`,
  head `1322e206`). Those 37 commits are replayed here on top of `a5b363c6` (the first one
  reconstructs the vendoring snapshot); the tree at the branch head is identical to the anchors
  head, and the anchors copy is now an archive.
- Toolchain: `leanprover/lean4:v4.33.1`. `verso` and `verso-slides` are pinned to their `v4.33.0`
  tags (upstream publishes no v4.33.1 tag; the patch release is source-compatible);
  ProofWidgets is pinned to the revision Mathlib v4.33.1 uses.

## What Timaeus added

- Editorial annotations (`src/VersoBlueprint/Editorial.lean`): the directives `unformalised`
  (with `missing := statement | proof`), `outOfScope`, `correction`, `interpretation`,
  `translation`, `restatement`, `strengthening`, `gap`, each with a `review` badge; the kinds are
  chosen by three questions documented at the top of that file. Native paper identities and
  badges, feedback rendering, source-PDF span links.
- Rendering of external declarations (`src/VersoBlueprint/ExternalDeclRender.lean`,
  `LeanNamesLegend.lean`, `ExternalRefSnapshot.lean`): the body of a plain definition after its
  signature (`verso.blueprint.externalCode.definitionBodies`), declaration names shown relative
  to the namespaces open in the chapter file with one legend per page, universes hidden
  (`verso.blueprint.externalCode.showUniverses`).
- Two patches to the pinned `verso` (`patches/verso-chapter-anchors.patch`,
  `patches/verso-term-universes.patch`), applied to a consumer's `.lake/packages/verso` by
  `scripts/apply-verso-patches.py <path-to-verso>` (idempotent, hash-checked). A consuming
  project needs it only if its documents put tags on page-level parts or embed native Lean
  `leanTerm` blocks (the anchor documents do; the greybook blueprint does not). Both fixes are
  candidates for upstream `leanprover/verso`.

## Consuming

```toml
[[require]]
name = "VersoBlueprint"
git = "https://github.com/timaeus-research/verso-blueprint.git"
rev = "<commit on timaeus/v4.33.1>"
```

## Syncing with upstream

Upstream keeps one branch per Lean release (`v4.33.0`, `v4.34.0`, ...). To take upstream fixes,
merge upstream's `v4.33.0` into `timaeus/v4.33.1` (upstream had advanced 101 commits past the
base by 22 September 2026); for a new Lean release, start `timaeus/v4.NN.M` from the fork's
corresponding branch and cherry-pick the Timaeus commits.
