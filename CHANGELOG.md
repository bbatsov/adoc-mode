# Changelog

## main (unreleased)

### New features

- [#74](https://github.com/bbatsov/adoc-mode/pull/74): Preview and export documents with Asciidoctor, from the new `adoc-asciidoctor-menu` transient on `C-c C-c`.
  - `adoc-preview` renders the buffer, unsaved edits included, in a side pane (an xwidget WebKit widget when Emacs has one, `eww` otherwise, see `adoc-preview-backend`), and `adoc-live-preview-mode` renders it again on every save.
  - `adoc-export-html`, `adoc-export-docbook`, `adoc-export-pdf` and `adoc-export-epub` run through `compile`, so Asciidoctor's warnings and errors are navigable.
- [#76](https://github.com/bbatsov/adoc-mode/pull/76): Add a Flymake backend, `adoc-flymake`, that reports Asciidoctor's errors and warnings for the buffer as you edit; enabling `flymake-mode` is enough.
- [#75](https://github.com/bbatsov/adoc-mode/pull/75): Complete cross-reference ids after `<<` and `xref:`, attribute names after `{`, file paths after `include::` and source languages after `[source,` with `completion-at-point`.
- [#78](https://github.com/bbatsov/adoc-mode/pull/78): Add an `xref` backend over anchors and sections, so `M-.` follows the reference at point and `M-?` lists the references to the id at point.
- [#77](https://github.com/bbatsov/adoc-mode/pull/77), [#85](https://github.com/bbatsov/adoc-mode/pull/85): Make cross-references, links, URLs and `include::` lines clickable, underlined on hover with the new `adoc-link-mouse-face`; `adoc-follow-thing-at-point` (`C-c C-o`) also follows `link:` macros now.
- [#81](https://github.com/bbatsov/adoc-mode/pull/81), [#82](https://github.com/bbatsov/adoc-mode/pull/82), [#84](https://github.com/bbatsov/adoc-mode/pull/84): Support cross-references between the pages of an Antora component (a directory with an `antora.yml` above it): follow them, complete their pages and sections, and find them across the component with `M-?`.
- [#80](https://github.com/bbatsov/adoc-mode/pull/80): Section titles are cross-reference targets too, with the auto-ids Asciidoctor gives them, for completion, the `xref` backend and `adoc-goto-ref-label`.
  - The id style follows a document's `:idprefix:` and `:idseparator:`, Antora's kebab case in an Antora component, or the new `adoc-section-id-style`.
  - [#98](https://github.com/bbatsov/adoc-mode/pull/98), [#101](https://github.com/bbatsov/adoc-mode/pull/101), [#105](https://github.com/bbatsov/adoc-mode/pull/105), [#107](https://github.com/bbatsov/adoc-mode/pull/107), [#112](https://github.com/bbatsov/adoc-mode/pull/112): A title is rendered the way Asciidoctor renders it before its id is derived, with its attribute references, counters, passthroughs, markup and macros.
  - [#106](https://github.com/bbatsov/adoc-mode/pull/106), [#111](https://github.com/bbatsov/adoc-mode/pull/111): The attribute entries count where Asciidoctor applies them: in the header and between blocks, in `ifdef` branches that hold, along with the attributes it sets by default.
  - [#98](https://github.com/bbatsov/adoc-mode/pull/98), [#103](https://github.com/bbatsov/adoc-mode/pull/103), [#113](https://github.com/bbatsov/adoc-mode/pull/113): Repeated titles get numbered ids (`_foo_2`), past the ids of the anchors Asciidoctor registers before them, and a section takes its explicit id from the anchor above it or at the end of its title.
- [#104](https://github.com/bbatsov/adoc-mode/pull/104): Recognise Markdown-style fenced code blocks (`` ```ruby ``), highlighted natively like `[source,ruby]` listings.
- [#102](https://github.com/bbatsov/adoc-mode/pull/102): Highlight Markdown-style thematic breaks (`---`, `* * *` and the like) like `'''`.
- Recognise CSV and DSV tables written with the `,===` and `:===` delimiters, highlighting their delimiters and cell separators like a `|===` table's.
- Highlight the counter and set references `{counter:name}`, `{counter2:name}` and `{set:name:value}` like other attribute references.

### Changes

- [#99](https://github.com/bbatsov/adoc-mode/pull/99): `adoc-promote` / `adoc-demote` (`M-left` / `M-right`) and `adoc-promote-title` / `adoc-demote-title` go the way Org mode's do: promoting moves a title or list item up the outline (`===` to `==`, `**` to `*`) and demoting moves it down, the reverse of before.
  - They stop with an error at either end instead of wrapping around.
  - Only the document title, or a part in a book (`:doctype: book`), can be promoted to level 0, which Asciidoctor reserves for those.
  - Demoting the first item of a list is refused, as in Org, since its siblings would end up nested under it.
  - Away from a title or list item, `M-left` / `M-right` move by word as they do elsewhere in Emacs.
- [#110](https://github.com/bbatsov/adoc-mode/pull/110): List editing nests items the way Asciidoctor does, by the order their markers turn up in, instead of a fixed depth per marker.
  - `M-up` / `M-down` move an item with the items nested in it, whatever their markers (`* a` then `- b`, or `* a` then `. b`), and across blank lines.
  - `M-left` gives an item the marker of the item it was in, and `M-right` the marker of its new siblings, or one that isn't in use around it. They work on explicitly numbered items too, and as in Org mode, an item with items nested in it isn't promoted on its own.
  - A list takes in what Asciidoctor attaches to its items, such as literal paragraphs, description lists and thematic breaks after a blank line, and blocks and tables attached with `+`. It ends at a paragraph after a blank line, a block that isn't attached or a table cell, so an item no longer moves into another list or out of its block.
- [#100](https://github.com/bbatsov/adoc-mode/pull/100): Two-line (setext) titles are deprecated, as they are in Asciidoctor and the AsciiDoc spec, and support for them will be removed in a future release.
  - `adoc-enable-two-line-title`, `adoc-two-line-title-del` and the unused `adoc-default-title-type` are obsolete.
  - Enabling two-line titles shows a warning once per session.
  - While they're enabled, `C-c C-t` converts a two-line title to the one-line style.
- [#79](https://github.com/bbatsov/adoc-mode/pull/79): `adoc-goto-ref-label` (`C-c C-a`) completes over the anchors and sections in the buffer, still taking an id that isn't defined yet and offering the cross-reference at point as the default.
- [#86](https://github.com/bbatsov/adoc-mode/pull/86): Bold and emphasized text use plain `bold` / `italic` faces instead of tinting the text with `adoc-gen-face`, as `asciidoc-mode`, `markdown-mode` and `org-mode` do; customize `adoc-bold-face` / `adoc-emphasis-face` to bring the tint back.
- [#71](https://github.com/bbatsov/adoc-mode/pull/71): `[source,ocaml]` code blocks are fontified with `neocaml-mode` when it's available, falling back to `tuareg-mode` and then `caml-mode`, as a value in `adoc-code-lang-modes` can now be a list of modes to try in order.
- [#74](https://github.com/bbatsov/adoc-mode/pull/74): The compilation error matcher also recognises Asciidoctor's `asciidoctor:` diagnostics, not just AsciiDoc.py's `asciidoc:` ones.
- [#108](https://github.com/bbatsov/adoc-mode/pull/108): `adoc-font-lock-extend-after-change-max` and `adoc-font-lock-extend-after-change-region` are obsolete, as a code block is now fontified again as a whole after a change in it, however long it is.
- The example-table tempo template inserts the modern `|===` delimiter instead of a long run of equals.

### Bugs fixed

- [#73](https://github.com/bbatsov/adoc-mode/pull/73): Heading navigation (`C-c C-n` and friends) and the imenu index no longer take a `==` line in a listing or other delimited block, or a code line followed by `----`, for a section title.
- [#73](https://github.com/bbatsov/adoc-mode/pull/73): Heading navigation and imenu honour `adoc-enable-two-line-title`, so two-line titles are only picked up when it's set, as for highlighting.
- [#97](https://github.com/bbatsov/adoc-mode/pull/97): The nested imenu index (the default) no longer leaves out sections that skip a level, which left a document without a level 0 title with an empty index.
- [#97](https://github.com/bbatsov/adoc-mode/pull/97): Outline folding (`TAB` / `S-TAB`) no longer takes a `==` line in a listing or other delimited block for a section title (on Emacs 28, only `TAB` on that line itself is fixed).
- [#89](https://github.com/bbatsov/adoc-mode/pull/89): Promoting, demoting or toggling a one-line title followed by a newline no longer turns it into the enclosed form, as in `== Section` becoming `=== Section ===`.
- [#89](https://github.com/bbatsov/adoc-mode/pull/89): `adoc-promote-title` and `adoc-demote-title` default to one level when called from Lisp without an argument, and the title commands signal a `user-error` when point isn't on a title.
- [#89](https://github.com/bbatsov/adoc-mode/pull/89): Title editing commands honour `adoc-enable-two-line-title`, like highlighting, navigation and imenu.
  - With two-line titles disabled (the default), they no longer take the line above a `----` or `====` delimiter for a title and overwrite the delimiter.
  - `C-c C-t` doesn't convert to a two-line title while they're disabled, or past level 4, where it used to crash.
  - A numeric value skips underlines of that length, as documented, instead of comparing the length of the title.
- [#99](https://github.com/bbatsov/adoc-mode/pull/99): Title and list editing (`M-left` / `M-right`, `C-c C-t`, `M-RET`, `M-up` / `M-down`) no longer takes a `== ...` or `* ...` line in a listing or other code block for a title or list item and rewrites it.
- [#102](https://github.com/bbatsov/adoc-mode/pull/102): The list commands no longer take a thematic break like `* * *` for a list item, unless it continues a list using `*`, where Asciidoctor reads it as one.
- [#90](https://github.com/bbatsov/adoc-mode/pull/90): A construct that's rejected once no longer stops the same construct from being highlighted further down; a `NOTE:` in a listing block, for instance, left every later admonition paragraph unhighlighted.
- [#90](https://github.com/bbatsov/adoc-mode/pull/90): Delimited blocks are highlighted correctly when Emacs fontifies the buffer a piece at a time, as it does while you scroll.
  - A long block crossing the edge of a piece used to lose track of where it began, so code could come out bold or as table cells.
  - A block ends at the first line that repeats its opening delimiter exactly, as in Asciidoctor.
  - A delimiter line in a listing or literal block is just content.
- [#90](https://github.com/bbatsov/adoc-mode/pull/90): Example, open, quote and sidebar blocks keep the highlighting of what's in them, and a section title in a delimited block is no longer highlighted as one, as Asciidoctor reads it as plain text.
- [#104](https://github.com/bbatsov/adoc-mode/pull/104), [#108](https://github.com/bbatsov/adoc-mode/pull/108): Blocks nested in an example, sidebar, quote or open block are recognised as blocks of their own, and the list commands leave the lines of more verbatim blocks alone, as Asciidoctor does.
  - That includes an open block styled `[source]`, `[listing]`, `[literal]`, `[pass]`, `[comment]` or `[verse]`, and a quote block styled `[verse]`, even with blank lines, comments or a block title between the style and the block.
  - A block left open in another block runs to the end of that block, and isn't highlighted as running past it.
  - The delimiter that closes a CSV or DSV table no longer opens another table.
- [#66](https://github.com/bbatsov/adoc-mode/issues/66): Links, `xref:` and footnote macros are recognised (and clickable) again when their text holds an apostrophe, an ellipsis, an arrow or other inline markup, as in `https://example.org[Bob's page]`, and bare URLs no longer run into a following `[`.
- [#91](https://github.com/bbatsov/adoc-mode/pull/91): Two cross-references on one line, as in `<<foo>>, <<bar>>`, are highlighted as two instead of one with the id `foo>>`, and an xref to a section's auto-id, like `<<_installation>>`, is highlighted at all.
- [#91](https://github.com/bbatsov/adoc-mode/pull/91): Superscripts and subscripts can't span whitespace anymore, as in Asciidoctor, so `~/.emacs.d/init.el to ~/backup` stays plain text.
- [#91](https://github.com/bbatsov/adoc-mode/pull/91): Superscripts are raised by their own `adoc-script-raise` value instead of the subscript's.
- [#78](https://github.com/bbatsov/adoc-mode/pull/78): Following a cross-reference at point works for a plain `<<id>>` with a captioned `<<id,caption>>` later on the same or an adjacent line, and ignores the whitespace in forms like `<<id >>`.
- [#92](https://github.com/bbatsov/adoc-mode/pull/92): Looking up an anchor is case-sensitive, as ids are in Asciidoctor, so following `<<foo>>` no longer lands on `[[FOO]]`.
- [#92](https://github.com/bbatsov/adoc-mode/pull/92): A same-page `xref:#id[]` can be followed, like `<<id>>`, and an inline anchor with reftext, `[[id,Reftext]]`, can be followed by its id.
- [#94](https://github.com/bbatsov/adoc-mode/pull/94): The AsciiDoc menu entries that pointed at commands that don't exist work, the comment one through the new `adoc-insert-comment`, which comments out every line of the region.
- [#94](https://github.com/bbatsov/adoc-mode/pull/94): The tempo templates are documented with the AsciiDoc help text again (see `C-h f tempo-template-adoc-emphasis`).
- [#94](https://github.com/bbatsov/adoc-mode/pull/94): The trademark and dash templates insert `(TM)` and `--`, which Asciidoctor replaces with ™ and an em dash, as their menu entries say.
- [#94](https://github.com/bbatsov/adoc-mode/pull/94): Tempo templates, and loading `adoc-mode` itself, no longer fail with `wrong-type-argument symbolp` when the current command is a lambda (a key bound to one, a hydra, or a transient).

## 0.9.0 (2026-06-02)

### New features

- Recognise the modern curved-quote syntax `"`text`"` (double) and `'`text`'` (single). The delimiters are de-emphasised and the enclosed text is shown as normal text; previously the inner backticks were mis-highlighted as inline monospace.
- Recognise the `icon:target[attrlist]` inline macro (e.g. `icon:heart[2x]`), highlighting the macro name, the icon name/path, and its attribute list like the other inline macros.
- Recognise the modern block ID shorthand `[#id]`. The id in a `[#id]` / `[#id.role%opt]` block-attribute line is now highlighted like an anchor (`adoc-anchor-face`), and cross-reference following (`adoc-goto-ref-label`, `M-.`) jumps to `[#id]` block IDs - including the `[style#id]` form, e.g. `[source#id]` - not just `[[id]]` anchors.
- Highlight checklist items. An unordered list item whose text begins with `[ ]` (unchecked), `[x]`/`[X]`, or `[*]` (checked) now fontifies the checkbox with the new `adoc-checkbox-face` (inherits `font-lock-constant-face`).
- Honour backslash escapes in inline formatting: a backslash before a formatting delimiter (e.g. `\*not bold*`, `\**nor this**`, `` \`nor code` ``) now de-emphasises the backslash and leaves the escaped span as literal text instead of fontifying it as markup. Previously the unconstrained forms still leaked an inner constrained match (`\**x**` highlighted `x`).
- `fill-paragraph` (and auto-fill) now preserve AsciiDoc hard line breaks: a line ending in a space and a `+` is no longer merged with the following line. Filling still joins ordinary soft-wrapped lines and indents list-item continuations.
- Add region-aware text-styling commands under the `C-c C-s` prefix, modelled on `markdown-mode`: `adoc-insert-bold` (`C-c C-s b`, `*text*`), `adoc-insert-italic` (`i`, `_text_`), `adoc-insert-monospace` (`m`, `` `text` ``), `adoc-insert-highlight` (`h`, `#text#`), `adoc-insert-superscript` (`^`, `^text^`), `adoc-insert-subscript` (`~`, `~text~`), and `adoc-insert-link` (`l`). Each wraps the active region or the word at point, removes the markup again when it is already wrapped, and inserts an empty pair when there is nothing to wrap.
- Add outline cycling commands modelled on `org-mode` and `markdown-mode`: `adoc-cycle` (`TAB`) rotates the visibility of the section subtree at point (folded / child titles / fully shown) when point is on a one-line title, and otherwise indents as usual; `adoc-cycle-buffer` (`S-TAB`) rotates the whole buffer between overview, contents, and show-all. Both build on the `outline-cycle` / `outline-cycle-buffer` primitives.
- Add list editing: `adoc-promote` (`M-left`) and `adoc-demote` (`M-right`) now nest the list item at point one level deeper or shallower (for unordered `*`/`-` and implicitly-numbered `.` lists) in addition to acting on section titles, and the new `adoc-insert-list-item` (`M-RET`) inserts a sibling item below the current one, keeping its indentation and marker and incrementing the number/letter of explicitly-numbered items.
- Add `adoc-move-list-item-up` (`M-up`) and `adoc-move-list-item-down` (`M-down`), which move the list item at point (together with its nested sub-items) past its previous/next sibling, and `adoc-renumber-list`, which renumbers a contiguous arabic (`1.`) or alphabetic (`a.`/`A.`) explicitly-numbered list starting from its first item's value.
- Add heading navigation commands modelled on `markdown-mode` and `org-mode`: `adoc-next-visible-heading` (`C-c C-n`), `adoc-previous-visible-heading` (`C-c C-p`), `adoc-forward-same-level` (`C-c C-f`), `adoc-backward-same-level` (`C-c C-b`), and `adoc-up-heading` (`C-c C-u`). They understand both one-line (`== Title`) and two-line (underlined) titles and skip headings hidden by folding. `outline-minor-mode` is now enabled by default so the folding commands are available out of the box.
- New `adoc-title-scaling` defcustom (default `t`) and `adoc-title-scaling-values` list let users disable the variable-height title faces or pick their own scale factors. Set the boolean to nil for uniformly-sized headings, or customise the list to control the level-0..5 heights. Mirrors `markdown-header-scaling`.
- New `adoc-blockquote-face` for the body of `[quote]` and `[verse]` delimited blocks (inherits `font-lock-doc-face`); previously the body was left unfontified.
- New `adoc-highlight-face` for `#text#` / `##text##` highlighted spans (inherits the standard `highlight` face); previously these reused `adoc-gen-face`.
- New `adoc-url-face` (inherits `font-lock-string-face`) for URL targets and standalone URLs / email addresses. Link text inside `[…]` still uses `adoc-reference-face`. URL targets previously reused `adoc-internal-reference-face` (for `http://…[label]` form) or `adoc-reference-face` (for bare URLs), conflating link text and link target.
- New `adoc-metadata-key-face` (inherits `font-lock-variable-name-face`) and `adoc-metadata-value-face` (inherits `font-lock-string-face`) for document attribute entries like `:author: Bozhidar Batsov`. Previously the key used `adoc-meta-face` (the generic markup face) and the value reused `adoc-secondary-text-face`; both now have dedicated semantic faces.
- New `adoc-footnote-marker-face` (inherits `adoc-command-face`) and `adoc-footnote-text-face` (inherits `font-lock-comment-face`) for `footnote:[…]` and `footnoteref:[…]` macros. The marker name (`footnote`, `footnoteref`) previously reused the generic `adoc-command-face` and the body text reused `adoc-secondary-text-face`.
- New `adoc-strike-through-face`, `adoc-underline-face`, `adoc-overline-face`, and an `adoc-role-face-alist` defcustom. `[.line-through]#text#`, `[.underline]#text#`, and `[.overline]#text#` (plus the legacy `[role]#text#` and `[role#id]#text#` shapes, and combinations like `[.line-through]*bold*`) now fontify the span with the matching role face layered on top of the surrounding quote's default face. Add entries to `adoc-role-face-alist` to fontify custom roles defined in your stylesheet.

### Changes

- Bring the AsciiDoc menu and tempo templates in line with modern AsciiDoc. The deprecated AsciiDoc.py curved-quote templates `` `text' `` and `` ``text'' `` are replaced by the modern `` "`text`" `` and `` '`text`' `` ones (`adoc-double-curved-quote` / `adoc-single-curved-quote`); `` `text` `` is labelled simply "Monospaced"; and the `+text+` / `++text++` templates are relabelled as passthroughs rather than monospace. This also fixes three menu entries that referenced non-existent templates (`tempo-template-adoc-monospace`, `tempo-template-monospace-literal`, and `tempo-template-pass-$$`), which previously errored when invoked.
- Title promotion and demotion move to `M-left` and `M-right` (org-style), freeing up `C-c C-p` and `C-c C-d` for the new heading-navigation commands. Previously `adoc-promote` lived on `C-c C-p` and `adoc-demote` on `C-c C-d`.
- `adoc-gen-face`, `adoc-verbatim-face`, `adoc-secondary-text-face`, and `adoc-replacement-face` now inherit from `font-lock-*` faces instead of hardcoding literal colours. Themes that style the font-lock palette will now style AsciiDoc buffers consistently. Users who relied on the old defaults can restore them via `M-x customize-face`.
- Simplify `adoc-meta-face` to `(:inherit shadow :slant normal :weight normal)` instead of overriding eleven attributes including `:family "Monospace"`. AsciiDoc markup characters now respect the user's font choices and theme `shadow` colour rather than being forced into a monospace family with hardcoded grays.
- Drop the dated 3D button decoration (`:box (:style released-button)`) and hardcoded hex colours from `adoc-command-face` and `adoc-complex-replacement-face`; inherit from `font-lock-builtin-face` instead.
- `adoc-meta-hide-face` no longer hardcodes `gray75`/`gray25` foregrounds; it simply inherits from `adoc-meta-face` so the colour tracks the theme. Customise the face if you want hidden markup to fade further into the background.
- Drop the self-referencing `(defvar adoc-X-face 'adoc-X-face)` boilerplate and the `adoc-delimiter` / `adoc-hide-delimiter` aliases. Font-lock keyword specs now quote face symbols directly. No user-visible change; this is purely an internal cleanup.
- `adoc-show-version` is now a deprecated alias for `adoc-mode-version`, which is itself the interactive command (still also a `defconst` carrying the version string). The previous `defalias 'adoc-mode-version → adoc-show-version` indirection is gone.
- `adoc-default-title-type` and `adoc-default-title-sub-type` now use a `choice` widget restricted to 1 or 2, replacing the open-ended `integer` type that allowed nonsensical values.
- Internal cleanup: `(adoc-calc)` runs from the mode initialization function rather than at file load. `(require 'adoc-mode-tempo)` and `(require 'compile)` moved to the top of the file. Dead `(boundp …)` guards around the `compilation-error-regexp-alist` integration removed. Stale `;; TODO` comments cleaned up. No user-visible change.

### Bugs fixed

- [#65](https://github.com/bbatsov/adoc-mode/issues/65): Image previews now resolve attribute references in the image path (e.g. `image:{my-badge}[]`) against the document's `:name: value` attribute entries before displaying the image.
- `+text+` and `++text++` are no longer highlighted as monospace. In modern AsciiDoc the backtick is the only monospace delimiter; the single and double plus are *inline passthroughs* (constrained and unconstrained), rendered as normal text with inline formatting suppressed. They are now fontified as passthroughs - the delimiters are de-emphasised and the enclosed text keeps the default face with formatting suppressed - rather than reusing the monospace face left over from the old AsciiDoc.py "compat-mode" syntax.
- Recognize level-5 section titles (`====== Title`). Previously `adoc-title-max-level` was off by one, so the deepest heading level supported by AsciiDoc was treated as ordinary text. Title promotion/demotion now cycles through all six one-line levels and the five two-line levels independently.

## 0.8.0 (2026-02-21)

### New features

- [#21](https://github.com/bbatsov/adoc-mode/pull/21): Add support for native font-locking in code blocks.
- [#48](https://github.com/bbatsov/adoc-mode/pull/48): Add support for displaying images.
- Add font-lock support for Asciidoctor inline macros: `kbd:[]`, `btn:[]`, `menu:[]`, `pass:[]`, `stem:[]`, `latexmath:[]`, `asciimath:[]`.
- [#59](https://github.com/bbatsov/adoc-mode/issues/59): Add nested `imenu` index support (enabled by default via `adoc-imenu-create-index-function`).
- [#29](https://github.com/bbatsov/adoc-mode/issues/29): Add `adoc-follow-thing-at-point` to follow URLs, `include::` macros, and xrefs (bound to `C-c C-o` and `M-.`).
- Add tempo templates for role-based text decorations (`[.underline]#text#`, `[.overline]#text#`, `[.line-through]#text#`, `[.nobreak]#text#`, `[.nowrap]#text#`, `[.pre-wrap]#text#`).

### Changes

- Require Emacs 28.1.
- `adoc-enable-two-line-title` now defaults to nil (Asciidoctor deprecated Setext-style titles).
- Remove deprecated AsciiDoc backtick-apostrophe quote styles (`` ``text'' `` and `` `text' ``), which are not supported in Asciidoctor.
- Extract image display code into `adoc-mode-image.el`.
- Extract tempo templates into `adoc-mode-tempo.el`.

### Bugs fixed

- [#33](https://github.com/bbatsov/adoc-mode/issues/33): Address noticeable lag when typing in code blocks.
- [#39](https://github.com/bbatsov/adoc-mode/issues/39): Support spaces in the attributes of code blocks.
- [#41](https://github.com/bbatsov/adoc-mode/issues/41): Fix unconstrained monospace delimiters.
- [#49](https://github.com/bbatsov/adoc-mode/issues/49): Prevent Flyspell from generating overlays for links and alike.
- Fix `outline-level` calculation for headings with extra whitespace after `=`.
- Fix forced line break (`+`) highlighting inside reserved regions.
- Fix backquote/comma usage in `adoc-kw-inline-macro` so `textprops` is properly substituted.
- Fix duplicate `face` key in `adoc-kw-delimited-block` plist.
- [#57](https://github.com/bbatsov/adoc-mode/issues/57): Fix Emacs hang on escaped curly braces in attribute reference regex.
- [#54](https://github.com/bbatsov/adoc-mode/issues/54): Fix multiline font-lock for inline formatting by extending fontification region to paragraph boundaries.
- [#52](https://github.com/bbatsov/adoc-mode/issues/52): Prevent `auto-fill-mode` from breaking section title lines.
- [#36](https://github.com/bbatsov/adoc-mode/issues/36): Remove `unichars.el` dependency; use built-in `sgml-char-names` instead.
- [#26](https://github.com/bbatsov/adoc-mode/issues/26): Fix `Wrong type argument: number-or-marker-p` when calling tempo templates with a prefix argument.
- [#24](https://github.com/bbatsov/adoc-mode/issues/24): Fix table delimiter highlighting to support any number of columns (was limited to 4).
- [#9](https://github.com/bbatsov/adoc-mode/issues/9): Fix broken tempo tests and title template compatibility with lexical-binding `tempo.el`.
- [#62](https://github.com/bbatsov/adoc-mode/issues/62): Fix image display regex to match paths starting with `.` or `/`.
- Fix broken menu entries for role-based text decoration templates (wrong `doc-` prefix instead of `adoc-`).

## 0.7.0 (2023-03-09)

### New features

- Added `imenu` support.
- Associate with `.adoc` and `.asciidoc` files automatically.

### Changes

- Require Emacs 26.
- Respect `mode-require-final-newline`.
- [#25](https://github.com/bbatsov/adoc-mode/issues/25): Remove `markup-faces` dependency.

### Bugs fixed

- Handle `unichars.el` properly.
- Add missing quote before `adoc-reserved` in `adoc-kw-verbatim-paragraph-sequence`.
- [#17](https://github.com/bbatsov/adoc-mode/issues/17): Show only titles in `imenu`.
