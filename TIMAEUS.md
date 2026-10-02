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
- Annotations taken from docstrings (`src/VersoBlueprint/SourceRelation.lean`,
  `SourceAnnotations.lean`, `ReviewLedger.lean`): the "Relation to the source." section of an
  embedded declaration's docstring is rendered as annotation boxes at the node, with review
  badges from a review ledger; see [Annotations from docstrings](#annotations-from-docstrings).
- Two patches to the pinned `verso` (`patches/verso-chapter-anchors.patch`,
  `patches/verso-term-universes.patch`), applied to a consumer's `.lake/packages/verso` by
  `scripts/apply-verso-patches.py <path-to-verso>` (idempotent, hash-checked). A consuming
  project needs it only if its documents put tags on page-level parts or embed native Lean
  `leanTerm` blocks (the anchor documents do; the greybook blueprint does not). Both fixes are
  candidates for upstream `leanprover/verso`.

## Annotations from docstrings

A declaration's docstring can say how its statement relates to the source it formalises. The
docstring is then the single place where this is written; the blueprint renders it.

### Format

```
Relation to the source.
* **Translation.** `S.weakTransformSeq J i` is Hironaka's $J_i$, and `S.boundarySeq E₀ i` his $E_i$.
* **Interpretation.** Hironaka's "non-singular" is read as smooth over `k`; for a scheme of finite
  type over the perfect field `k` the two agree.
* **Gap.** The source's theorem holds over any local ring of its class; here the base is a field.
```

- The heading is the first line whose text, without surrounding whitespace, is exactly
  `Relation to the source.`; its indentation is the section's base indentation.
- After it (blank lines allowed) comes a list of bullets: lines indented at most three columns
  more than the heading whose text starts with `* ` (also `- ` or `+ `).
- An item continues on the following lines indented more than its bullet; a blank line inside an
  item separates paragraphs. The section ends before the first non-blank line that is neither a
  bullet nor a continuation, or at the end of the docstring.
- Each item begins with exactly one of the bold labels `**Translation.**`, `**Unformalised.**`,
  `**Out of scope.**`, `**Correction.**`, `**Interpretation.**`, `**Restatement.**`,
  `**Strengthening.**`, `**Gap.**`, `**Formalisation note.**`, the period inside the bold. The
  item's text is everything after the label; it is Markdown with inline code, emphasis and inline
  LaTeX `$...$` (`$$...$$` for display math).
- Kinds: the editorial kinds of `src/VersoBlueprint/Editorial.lean`, chosen by its three
  questions. Does the source's item have a formalised counterpart? If not, *Unformalised* (a
  statement or proof is missing) or *Out of scope* (none owed, by decision). Is the source's claim
  true as printed? If not, *Correction* (false; the needed hypothesis is added and the corrected
  version stated); if underspecified, *Interpretation* (one reading is fixed). For a true claim,
  how do the statements compare? *Restatement* (a logically equivalent form, used sparingly),
  *Strengthening* (the formal statement implies the source's) or *Gap* (weaker or incomparable).
  A *Translation* is a dictionary entry (this Lean expression is the source's such-and-such),
  orthogonal to the three questions; a *Formalisation note* is the fallback for a remark that is
  none of these. Each label renders as the directive of the same name does (a formalisation note
  as `meta`). Unlike those directives, an item from a docstring never marks its node's header
  "Owes work" and carries no `missing` badge: it records a difference from the source, not work
  owed.

### Rendering

At a node with `(lean := "A, B")`, the items of the docstrings of `A` and `B` become annotation
boxes appended to the node's statement, in `(lean := ...)` order and then docstring order; when
the node embeds several declarations, each box names its declaration. The embedded declarations'
plain docstring display leaves the section out. An item's Markdown is parsed by MD4Lean with
LaTeX math spans (CommonMark, no raw HTML) and converted to Verso blocks by VersoManual's
`Markdown.blockFromMarkdown`, the conversion verso-literate also uses: `$...$` becomes
`Inline.math`, rendered (KaTeX in HTML, `$...$` in TeX) exactly like `` $`...` `` written in the
document. Inline code is plain code (not elaborated). Each box carries `data-decl` and `data-hash`
attributes, the values a ledger entry needs.

A bullet without a label, or with a label other than these (including `**Translation**.`), is
reported as a warning at the node when the chapter is elaborated, once for each node, declaration
and distinct problem, and stays in the plain docstring display under the heading. `lake exe vbp
build` prints a chapter's warnings once: its two generator stages run Lake with
`--log-level=error`, so they do not replay the warnings that its first stage, the package build,
has printed. Nodes made with the `@[blueprint]` attribute show the docstring unchanged and no
boxes. The hand-written directives keep working as before.

### Review ledger

Review status is not written in docstrings. The ledger is a JSON array of entries

```json
[{"decl": "AlgebraicGeometry.exists_blowUpSequence_ord_weakTransformSeq_lt",
  "kind": "Translation", "hash": "d78b9d85c3d102a0", "reviewer": "BS", "date": "2026-10-02"}]
```

`decl` is the declaration's full name, `kind` the item's label without its period
(`Translation`, `Unformalised`, `Out of scope`, `Correction`, `Interpretation`, `Restatement`,
`Strengthening`, `Gap` or `Formalisation note`), `hash` the item hash (16 lowercase hexadecimal digits) and
`date` `YYYY-MM-DD`. The items of one declaration and one kind are compared with the ledger
together:

- An item is *reviewed* when an entry with its declaration, kind and hash exists; the badge names
  the reviewer and the date of the latest one.
- A *stale version* of a declaration and kind is a hash that the entries for that declaration and
  kind name and that none of its current items of that kind has: the reviewed text of an item
  edited (or deleted) since. Several entries with one hash count as one version.
- An item with no entry for its hash is *changed since review* when the declaration and kind have
  at least as many stale versions as the item's position among their items with no entry for
  their hash, counted from 1 in docstring order; otherwise it is *unreviewed*.

So when one of three reviewed items of a kind is edited, exactly one of the three shows "changed
since review", and an item added next to reviewed ones shows "unreviewed". Items have no identity
beyond their text, so stale versions are paired by position with the items that have no entry for
their hash: if a new item stands before an edited one in the docstring, the new item is the one
marked "changed since review". When an edited item is reviewed again, replace its entry rather
than adding one: an entry kept for its old text still counts as a stale version. The rule is
`Informal.ReviewLedger.status`.

The ledger is `reviews.json` in the directory the site is generated from (the package root, where
`lake exe vbp build` runs); `set_option verso.blueprint.reviewLedger "<path>"` in a chapter file
names another file, relative to the same directory. It is read when the HTML or TeX is generated,
so editing it needs no rebuild of the chapters. A missing ledger means every item is unreviewed; a
malformed ledger or entry is a build error.

The item hash is 64-bit FNV-1a (offset basis `0xcbf29ce484222325`, prime `0x100000001b3`) over
the UTF-8 bytes of the item's text after the label, with every run of whitespace (space, tab,
line feed, carriage return; no other character) replaced by one space and none at either end,
written as 16 lowercase hexadecimal digits. Rewrapping or reindenting an item keeps its hash; any
other edit changes it and withdraws its review, leaving a stale version in the ledger. In Python:

```python
import re

def item_hash(text: str) -> str:
    h = 0xcbf29ce484222325
    for b in re.sub(r"[ \t\n\r]+", " ", text).strip(" ").encode("utf-8"):
        h = ((h ^ b) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    return f"{h:016x}"

assert item_hash("`S.boundarySeq E₀ i` is his $E_i$.") == "d78b9d85c3d102a0"
```

The Lean implementation is `Informal.SourceRelation.itemHash`; the test
`tests/VersoBlueprintTests/SourceAnnotations.lean` checks it against the published FNV-1a test
vectors and the value above.

### Hiding review badges

`lake exe vbp build --hide-review` renders every annotation box, hand-written or from a
docstring, without its review badge. The generator accepts the same flag
(`lake lean Main.lean -- --run Main.lean --output _out/site --hide-review`), and the environment
variable `VERSO_BLUEPRINT_HIDE_REVIEW=1` has the same effect.

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
