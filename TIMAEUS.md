# Timaeus fork of verso-blueprint

This repository is the Timaeus fork of
[leanprover/verso-blueprint](https://github.com/leanprover/verso-blueprint). Development
happens here, on one branch per Lean release, `timaeus/v4.34.0` the newest; consumers pin a commit
of the branch for their toolchain. `timaeus/v4.33.1` is kept for consumers on Lean 4.33.1.

## Provenance

- Upstream base: `9dd25554` on upstream's `v4.33.0` branch (Lean 4.33.0), plus the fork's
  `doc: establish the shared Timaeus Blueprint fork` (`a5b363c6`).
- From 9 September to 22 September 2026 the package was vendored in
  `timaeus-research/anchors` under `vendor/verso-blueprint` (branch `verso-blueprint-v4.33.1`,
  head `1322e206`). Those 37 commits are replayed here on top of `a5b363c6` (the first one
  reconstructs the vendoring snapshot); the tree at the branch head is identical to the anchors
  head, and the anchors copy is now an archive.
- `timaeus/v4.34.0` is the fork rebased onto upstream's `v4.34.0` branch at `a1cf7066`
  (9 October 2026). Before the rebase the 51 fork commits of `timaeus/v4.33.1` (`a1144583`) were
  grouped into 9 commits, each listing the commits it replaces; the originals stay on
  `timaeus/v4.33.1`. Upstream had meanwhile split the block model into node metadata
  (`BlockMetadata`, from the environment) and occurrences (`BlockOccurrence`, the directive's
  data), so the fork's per-block fields (paper identity, reader context, formalisation TODO,
  `legendInKicker`) are now occurrence fields (`BlockPresentation`), and the open-namespace
  legend reads external declarations from the captured render model.
- Toolchain: `leanprover/lean4:v4.34.0`. Upstream's branch moved from 4.34.0-rc2 straight to
  4.34.1; its dependency pins (`verso` at the post-rc2 split-page anchor fix `52c8c955`,
  `verso-slides` `v4.34.0-rc2`, `subverso` `fda188f7`) build on 4.34.0 and are kept. ProofWidgets
  is pinned to the revision Mathlib v4.34.0 uses (`v0.0.111`), BibtexQuery to the revision
  doc-gen4 v4.34.0 uses.

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
- Declaration links (`src/VersoBlueprint/ExternalDeclRender.lean`, `Informal/DeclRef.lean`): the
  constants in rendered declaration code link to the node that presents them, and the inline role
  `{decl}` links a declaration named in prose; see [Declaration links](#declaration-links).
- BibTeX citations (`src/VersoBlueprint/BibTeX.lean`, `Cite.lean`, `Commands/Bibliography.lean`,
  `SourceAnnotations.lean`, `MarkdownTerms.lean`, `DocstringHtml.lean`):
  `blueprint_bibliography_file "references.bib"` registers a BibTeX file, formatted by BibtexQuery
  as doc-gen4 formats an API documentation's references page; `{cite Kol07}[Definition 29]` cites
  an entry in prose, `[Kol07, Definition 29]` in a docstring is the same citation, and
  `blueprint_bibliography` lists the cited entries with their "Cited from" backlinks; see
  [BibTeX citations](#bibtex-citations).
- Docstrings of embedded declarations rendered as Markdown (`src/VersoBlueprint/DocstringHtml.lean`,
  `ExternalDeclRender.lean`): paragraphs, lists, code, emphasis, links and `$...$` math, where
  upstream shows the docstring verbatim in a `<pre>` (kept for Markdown the renderer does not
  handle: tables, raw HTML).
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

## Declaration links

### In rendered declarations

The declarations of a node's `(lean := "A, B")` are rendered with syntax highlighting. Every
constant in that code (signature, definition body, structure fields, constructors) is a link:

- to the node that presents the constant, if one does: the anchor of that node's rendering of the
  declaration. When several nodes present it, the *canonical* node is used: the first node in
  document order whose `(lean := ...)` list names the declaration, except that a `definition`
  node takes precedence over a theorem, lemma, proposition or corollary node. So the constant
  `CommutesWithSmoothMorphisms` in the statement of Theorem 36 links to the definition node
  that presents it, even if a theorem node earlier in the document lists it too.
  (`Resolve.canonicalDeclDomainName`, filled during traversal by `CanonicalDecls.register`);
- otherwise, for a public constant of Lean core, Std, Lake, Mathlib or one of Mathlib's
  dependencies (`docsModuleRoots`), to its entry in Mathlib's published API documentation,
  `<docsBaseUrl><Module/Path>.html#<Name>`. The base is
  `set_option verso.blueprint.externalCode.docsBaseUrl "..."`, by default
  `https://leanprover-community.github.io/mathlib4_docs/`; the empty string turns these links
  off. That site follows Mathlib's master branch, so a declaration that has moved or been renamed
  since the Mathlib the project pins links to a page without its anchor, or to no page;
- otherwise nowhere: the token keeps its hover and nothing else.

Links have the class `bp_decl_link` (documentation links also `bp_decl_link_docs`). The same
links appear wherever the renderer is used: on the chapter pages, in the hover previews of nodes
and declarations, and in grafted previews. The annotation boxes taken from docstrings render their
inline code as plain code, not highlighted code, and get no links.

Declarations are rendered when their chapter is elaborated, but which node presents a constant is
known only once the whole document has been traversed. The rendered HTML therefore wraps each
constant token in a pair of comment markers (`bp-decl:NAME|DOCS` and `/bp-decl`), and the page
renderer resolves them (`rewriteDeclLinks`). The generated `blueprint-manifest.json` keeps the
unresolved markup in its `codeData` copies of the rendered declarations, as it keeps the hover
markers there.

### In prose: the `{decl}` role

```
Clause (1) is {decl}`HasRegularIrreducibleCenters`, and clause (4) is
{decl}`CommutesWithSmoothMorphisms`; the map {decl ResolutionAssignment.map}`map` ...
```

`{decl}`Name`` renders `Name` as inline code that links where a constant token for that
declaration would link: to the canonical node presenting it (with the declaration's code as hover
preview), or to the API documentation. `{decl Other.name}`text`` resolves `Other.name` and displays
`text`. The name is resolved, in order:

0. Inside a node's statement or proof: among the declarations of that node, the one whose full name
   is the name or ends with `.` followed by it, if exactly one does. So `map` inside the node
   presenting `AnalyticSpace.ResolutionAssignment.map` is that field, whatever `map` means in the
   chapter.
1. As Lean resolves an identifier in the chapter: relative to the namespaces the file opens, or
   fully qualified. Of the constants it denotes, the one presented at some node is taken.
2. If it denotes no constant at all: against the declarations presented at nodes, by suffix (the
   full name is the name or ends with `.` followed by it). If several match, those inside a
   namespace the file opens are kept. Dot notation such as `D.blowUp` (for a variable `D`) is not
   resolved.
3. If it denotes exactly one constant that no node presents and that is in the API
   documentation: a link there.

Anything else is an error reported, with the source position, when the HTML is generated (only
then are all nodes known): a name that denotes several declarations presented at nodes, matches
several by suffix, or names a declaration that no node presents and the documentation does not
cover. `lake exe vbp build` then fails, so prose cannot go on naming a declaration that the
blueprint no longer presents. A code span that is not a Lean name (`h : Y ⟶ X`) is an elaboration
error unless the name is given as argument. The role registers no dependency (use `{uses}` for
that). In TeX the role is plain inline code. The tests are
`tests/VersoBlueprintTests/BlueprintDeclLinks.lean`.

## BibTeX citations

Upstream's citations are Lean values of Verso's `Citable` (`[bib "label"]`, `{Informal.citep}`),
which has no book or miscellaneous kind and no reader of BibTeX. A project that keeps its sources
in a BibTeX file, as one does for doc-gen4's references page, cites that file instead.

### Registering the file

```lean
import VersoBlueprint

blueprint_bibliography_file "../../references.bib"
```

The path is relative to the directory of the file holding the command. The entries are
registered in a persistent environment extension, so the command goes in a module that every
citing chapter imports (a registry module). Lake does not see that the module reads the file:
declare the file as an `input_file` and a `needs` of the library holding the module, so that a
change to the file rebuilds the registry and the chapters:

```toml
[[input_file]]
name = "references"
path = "../references.bib"
text = true

[[lean_lib]]
name = "BlueprintReferences"
roots = ["Blueprint.References"]
needs = ["references"]
```

`blueprint_bibliography_bibtex "@book{...}"` registers BibTeX text itself (for tests). A key
registered twice is an error; two entries with the same generated tag, or two keys differing only
in case (their anchors coincide), are warnings.

BibtexQuery reads `@type{key, field = {value}, ...}` with values in braces or bare numbers, keys of
ASCII letters, digits, `:`, `-` and `_`, accents as TeX commands or Unicode; not `@string`, `#`
concatenation or quoted values. Its parser stops silently at the first malformed entry; the
command reports that as an error. Each entry gets an alpha-style tag from its authors and year
(`Kol07`; `BM97`; `BM97a`, `BM97b` when two coincide; `TSPA` for `{{The Stacks Project Authors}}`),
the entry's HTML in the `unsrt` style, and its plain text.

### Citing

`{cite Kol07}[Definition 29]` renders as `[Kol07, Definition 29]`, linked to the entry in the
bibliography, with a hover preview titled `[Kol07, Definition 29]` showing the entry;
`{cite Kol07}[]` renders as `[Kol07]`. The text in brackets is the entry's *tag*, not the key: an entry keyed `Sta` whose
tag is `TSPA` renders as `[TSPA, Tag 01WQ]`. The content of the role is the locator, as plain
text with its white space normalized. One key per role; an unknown key is an error. A key that
is not a Lean identifier is given as a string: `{cite "a-b"}[]`.

`{citeAs Ati70}[Atiyah's Resolution Theorem]` shows the content as the link's text instead of the
bracketed tag; its hover preview is titled `Atiyah's Resolution Theorem [Ati70]`.

In a docstring's "Relation to the source." items (see [Annotations from
docstrings](#annotations-from-docstrings)), the bracketed citations `[Kol07]` and
`[Kol07, Definition 29]` whose key is registered are the same inlines: the key is the text
before the first comma, the locator the rest; and `[Atiyah's Resolution Theorem][Ati70]`, the
form doc-gen4 also reads, is `{citeAs}`. A citation whose key is not registered stays as written.

The docstring of an embedded declaration, rendered as Markdown in the node's panel, links its
citations `[Kol07, Definition 29]` and `[text][Kol07]` the same way (with no hover preview; the
panel is rendered before the previews are collected).

In TeX output a citation is its text, `[Kol07, Definition 29]`.

### The bibliography

`{blueprint_bibliography}` adds the "Blueprint Bibliography" part, listing the `[bib]` entries and
the BibTeX entries that the document cites (an entry nothing cites is left out;
`{blueprint_bibliography_all}` lists every registered entry). A BibTeX entry shows its tag, the
formatted entry, and "Cited from", the links to its citations with each citation's locator.
Entries are ordered as BibtexQuery sorts them (author, year, title), after the `[bib]` entries.
The anchor of the entry `Kol07` is `bp-bib-kol07`.

Tests: `tests/VersoBlueprintTests/BlueprintBibtex.lean` (fixture `tests/VersoBlueprintTests/fixtures/sample.bib`).

## Consuming

```toml
[[require]]
name = "VersoBlueprint"
git = "https://github.com/timaeus-research/verso-blueprint.git"
rev = "<commit on timaeus/v4.34.0>"
```

## Syncing with upstream

Upstream keeps one branch per Lean release (`v4.33.0`, `v4.34.0`, ...). For a new Lean release,
start `timaeus/v4.NN.M` from upstream's branch for that release and rebase the fork's commits onto
it, as `timaeus/v4.34.0` was (see Provenance); a fork branch that is already published is not
rewritten.

Known test failures, also on `timaeus/v4.33.1`: `ReaderImported` (uses the dropped
`clarification` directive) and `BlueprintPreviewWiring/Summary` (its fixture namespace starts with
`Verso`, which `ExternalRef.displayOpenNamespaces` filters out).
