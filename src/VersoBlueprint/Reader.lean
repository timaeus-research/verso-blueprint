import VersoManual

namespace Informal.Reader

open Lean Verso.Output

def labelString : Name → String
  | .str .anonymous s => s
  | name => name.toString

structure Context where
  codename : String
  commit : String
  sourcePin : String := ""
  baseUrl : String
deriving Inhabited, Repr, FromJson, ToJson, Quote

structure PaperIdentity where
  label : String
  href : String
  pdfHref : String := ""
deriving Inhabited, Repr, FromJson, ToJson, Quote

def encode (text : String) : String := Id.run do
  let mut out := ""
  let hex := "0123456789ABCDEF".toList.toArray
  for byte in text.toUTF8 do
    let n := byte.toNat
    if (65 ≤ n && n ≤ 90) || (97 ≤ n && n ≤ 122) || (48 ≤ n && n ≤ 57) ||
        n == 45 || n == 46 || n == 95 || n == 126 then
      out := out.push (Char.ofNat n)
    else
      out := out ++ "%" |>.push hex[n / 16]! |>.push hex[n % 16]!
  return out

def issueUrl (ctx : Context) (name target : String) (details : String := "") : String :=
  let source := if ctx.sourcePin.isEmpty then "" else s!"\nSource rev: {ctx.sourcePin}"
  let description := s!"Node: {target}\n{details}{source}\nAnchors: timaeus-research/anchors@{ctx.commit}\n"
  "https://linear.app/resolution-org/team/ENG/new?project=b1543c40-1fd7-4627-b0e2-37bcb5930043" ++
    "&title=" ++ encode s!"{ctx.codename}/{name}: " ++ "&description=" ++ encode description

def issue (ctx : Context) (name target : String) (details : String := "")
    (label : String := "⚑ issue") : Html :=
  open Html in
  {{<a class="bp_relation_chip bp_issue_chip" href={{issueUrl ctx name target details}}
       target="_blank" rel="noopener noreferrer" title="Report an issue (opens a pre-filled Linear composer)">
      {{.text true label}}</a>}}

def paper (identity : PaperIdentity) : Html :=
  open Html in
  {{<span class="bp_paper_ref_badge">
      <span class="bp_paper_ref_key">"paper"</span>
      <a class="bp_paper_ref" href={{identity.href}} target="_blank" rel="noopener noreferrer">
        {{.text true (identity.label ++ " ↗")}}</a>
      {{if identity.pdfHref.isEmpty || identity.pdfHref == identity.href then .empty else
        {{<a class="bp_paper_ref_pdf" href={{identity.pdfHref}} target="_blank"
             rel="noopener noreferrer" title="Vendored page at the pinned anchors commit">"pdf"</a>}}}}
    </span>}}

def css : String := r##"
.bp_paper_ref_badge { display:inline-flex; align-items:baseline; gap:.5em; margin-left:.75em; font-size:.78em; font-weight:400; font-style:normal; }
.bp_heading_title_row_statement .bp_paper_ref_badge { grid-column:3; grid-row:1; margin-left:1.1rem; }
.bp_paper_ref_key { font-size:.72em; font-weight:700; letter-spacing:.08em; text-transform:uppercase; color:var(--bp-color-text-faint,#94a3b8); }
.bp_paper_ref { color:var(--bp-color-text-muted,#64748b); text-decoration:none; border-bottom:1px dotted; }
.bp_paper_ref_pdf { font-size:.72em; border:1px solid var(--bp-color-border-soft,#cbd5e1); border-radius:3px; padding:0 .4em; }
.bp_reader_paragraph { position:relative; }
.bp_reader_paragraph > .bp_issue_chip { opacity:0; font-size:.75em; margin-left:.3em; }
.bp_reader_paragraph:hover > .bp_issue_chip, .bp_reader_paragraph:focus-within > .bp_issue_chip { opacity:1; }
"##

end Informal.Reader
