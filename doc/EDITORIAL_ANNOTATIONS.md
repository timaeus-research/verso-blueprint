# Editorial annotations

Import `VersoBlueprint` to use the native annotation directives. Their bodies are ordinary
Verso blocks: references, mathematics, Lean roles and their hover information retain their
usual rendering. There is no HTML post-processing.

An annotation compares one item of the paper (a numbered statement, a clause of one, a
definition, an equation) with the formalisation. Three questions decide its kind, in order,
so the kinds are mutually exclusive and each annotation carries exactly one; one further kind,
`translation`, is a dictionary entry orthogonal to the comparison.

**Does the paper's item have a formalised counterpart?**

- `:::unformalised` renders **Unformalised**. None. The parameter `missing := statement`
  (no Lean statement) or `missing := proof` (a statement written without proof, for example
  as a challenge statement or a hypothesis structure) is required. The body says the state
  and why (untried, partial, in progress, truth uncertain) and what would settle it.
- `:::outOfScope` renders **Out of scope**. None and none owed, by a recorded decision.
  Explain what is excluded and why. This is a coverage decision, not a mathematical verdict,
  and it does not discharge any obligation. Do not exclude prerequisites of a result still
  claimed in scope.

**For an item with a counterpart of record: is the paper's claim true as printed?**

- `:::correction` renders **Correction**. False as printed (a wrong sign, factor or
  normalisation, an inconsistent display, or a hypothesis the claim needs and the paper does
  not print); the formalisation states the corrected version, and the body gives the reason.
  An added hypothesis that only the formal proof needs, while the paper's claim may hold
  without it, is a `gap`, not a correction. The label itself supplies no evidence and does not
  certify the linked proofs.
- `:::interpretation` renders **Interpretation**. Underspecified; the formalisation fixes one
  reading, and the body names the alternatives and why this one.

**For a true claim: how do the two statements compare?**

- `:::restatement` renders **Restatement**. The formal statement is a logically equivalent
  form of the paper's whole statement. Used sparingly.
- `:::strengthening` renders **Strengthening**. The formal statement implies the paper's and
  the converse is not claimed.
- `:::gap` renders **Gap**. The formal statement is weaker than or incomparable with the
  paper's (an extra hypothesis, a missing clause, hypotheses neither implying the other). The
  body says what would close it.

**The dictionary.**

- `:::translation` renders **Translation**, compactly. One entry per directive, for one
  important unit whose Lean spelling looks very different from the paper's: the Lean
  expression in code, "is the paper's" (or "is"), the paper's notation, the reference in
  parentheses where useful (`` `sliceMax A.zeroSlice ξ` is the paper's $`M(\xi)` (Main
  Theorem 6.4 (1)) ``). It is not for saying that a whole theorem is an equivalent rephrasing;
  that is a `restatement`.

One parameter renders as a small badge and qualifies an annotation without changing its kind:
`review := unreviewed` (the default) or `review := "reviewed <initials> <date>"`, on every
annotation, translations included. An annotation is an agent's or author's assessment until a
human checks it; the reviewer flips the badge. Authorship is a badge rather than a kind because
it does not change what a reader must weigh about the statement, only who has weighed it. No
effort estimate is recorded: estimates written by agents are unreliable, so such a badge would
carry no information; the body of an owing item says what would close it, not what that would
cost. Values are written as identifiers or as strings (`(missing := statement)`,
`(review := "reviewed BS 2026-09-22")`); a value with a space must be a string.

`unformalised` and `gap` owe work: a node containing one shows the warning “Formalisation
TODO” in its header (as does the framework's older `:::formalizationTodo`), and a proof block
containing one is not folded. The other kinds owe nothing. `:::meta` (**Formalisation note**)
remains available for implementation commentary.

Put a note concerning a particular theorem or definition inside that node:

````markdown
::::theorem "example"
The mathematical statement, in the paper's formulation.

:::translation
`threshold x` is the paper's $`\tau(x)` (Definition 2.1).
:::

:::gap
The paper states a local threshold; Lean currently states a global threshold. Stating the
paper's local result, with an equivalence lemma under its assumptions, would close it.
:::
::::
````

Global implementation or notation notes may be standalone. The directives are not numbered
mathematical nodes and do not change declaration proof status. A faithful statement may
deliberately have a sorried proof: missing proofs alone use the existing proof status; a
statement written without proof that the document counts as missing is `unformalised` with
`missing := proof`. A substantive change of assumptions or conclusions is a `gap`, a
`strengthening` or a `restatement`, never a `translation` or an `interpretation` merely because
an author chose it; an assertion that the paper is false is a `correction` and needs its
reason in the body. Annotations cannot serve as evidence that the
formalisation corresponds to the paper.

Implementation: `src/VersoBlueprint/Editorial.lean`. The theorem/definition renderer detects
nested owing annotations from the Verso document tree, not from rendered HTML. CSS hooks are
`.bp-editorial` with
`data-kind="meta|formalizationTodo|unformalised|outOfScope|correction|interpretation|translation|restatement|strengthening|gap"`
and `data-review="unreviewed|reviewed"`, `.bp-editorial-title`, `.bp-editorial-kind`,
`.bp-editorial-content`, the badges `.bp-badge.bp-badge-review[data-review=…]` and
`.bp-badge-missing`, and `.bp-correspondence-warning`.
