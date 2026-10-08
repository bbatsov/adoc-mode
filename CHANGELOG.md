# Changelog

## main (unreleased)

### New features

- Recognise CSV and DSV tables written with the modern delimiter shorthands `,===` (comma-separated) and `:===` (colon-separated). The delimiter lines and the cell separators inside the block are highlighted with `adoc-table-face`, just like the `|` cells of a regular PSV table. Separators are only highlighted between matching delimiters, so commas and colons in ordinary prose are left alone.
- Recognise the counter and set reference macros `{counter:name}`, `{counter2:name}`, and `{set:name:value}`. These were previously left unhighlighted because the `:` in them broke the attribute-reference matcher; they now fontify with `adoc-replacement-face` like other attribute references, while plain `{key: value}` prose (JSON, CSS, etc.) is deliberately left alone.
- [#74](https://github.com/bbatsov/adoc-mode/pull/74): Add Asciidoctor integration for previewing and exporting documents, reachable from the new `adoc-asciidoctor-menu` transient on `C-c C-c` (and the AsciiDoc menu). `adoc-preview` renders the current buffer with `asciidoctor` and shows the HTML in a side pane - an xwidget WebKit widget when available, otherwise `eww`, configurable via `adoc-preview-backend` - and `adoc-live-preview-mode` re-renders on every save. The preview feeds the buffer to `asciidoctor` through its standard input, so unsaved edits and relative `include::` / image paths both keep working. Export commands `adoc-export-html`, `adoc-export-docbook`, `adoc-export-pdf`, and `adoc-export-epub` run through `compile`, so Asciidoctor's warnings and errors are navigable.
- [#75](https://github.com/bbatsov/adoc-mode/pull/75): Add context-aware completion via `completion-at-point` (`M-TAB`, or any of corfu/company/built-in completion). Inside `<<` or `xref:` it completes cross-reference ids from the explicit anchors defined in the buffer (`[[id]]`, `[#id]`, `[[[biblio]]]`); inside `{` it completes attribute names (the ones defined with `:name:` plus a set of common built-ins); after `include::` it completes file paths; and inside `[source,` it completes source-block language names. It stays out of the way in plain prose.
- [#76](https://github.com/bbatsov/adoc-mode/pull/76): Add a Flymake backend (`adoc-flymake`) that runs the buffer through Asciidoctor and reports its parser errors and warnings inline. It's registered automatically, so enabling `flymake-mode` is enough. The check feeds the buffer to Asciidoctor over its standard input, so it works on unsaved edits.
- [#77](https://github.com/bbatsov/adoc-mode/pull/77), [#85](https://github.com/bbatsov/adoc-mode/pull/85): Make references clickable. Cross-references (`<<id>>`, `xref:id[]`), links and URLs (`link:`, `https:`, `mailto:`, ...), and `include::` macros now highlight and underline on hover (via the new `adoc-link-mouse-face`) and follow with a `mouse-1` (or `mouse-2`) click - the same action as `C-c C-o` / `M-.`. As part of this, `adoc-follow-thing-at-point` now also follows `link:` macros (opening a local target or a URL) and no longer passes the `[label]` along when opening a URL macro.
- [#78](https://github.com/bbatsov/adoc-mode/pull/78): Add an `xref` backend over AsciiDoc anchors. In an `adoc-mode` buffer, `M-?` (`xref-find-references`) lists every cross-reference to the anchor at point, and the standard xref machinery (the marker stack, the completion-read prompt, `consult-xref`, ...) now works for AsciiDoc ids. Definitions are anchors (`[[id]]`, `[#id]`, `[[[biblio]]]`) and references are `<<id>>` / `xref:id[]` usages, resolved within the current buffer. `M-.` keeps following URLs and `include::` too, via `adoc-follow-thing-at-point`.
- [#81](https://github.com/bbatsov/adoc-mode/pull/81): Follow Antora cross-file cross-references. In a file inside an Antora component (one with an `antora.yml` above it), following an `xref:` that targets a page - e.g. `xref:basics/install.adoc[]` or `xref:other.adoc#a-section[]`, including a `module:` prefix - now opens the resolved page (under the target module's `pages/` directory) and jumps to the `#fragment` section. Works from `C-c C-o` / `M-.` and a mouse click, and `M-,` (`xref-go-back`) returns. Resolution is limited to the current component.
- [#82](https://github.com/bbatsov/adoc-mode/pull/82): Complete Antora `xref:` targets. Inside an `xref:` in an Antora component, completion offers the component's pages as targets (pages in other modules prefixed with `module:`), and after a `#` it offers the target page's section ids and anchors. A same-page `xref:#` completes against the current buffer.
- [#84](https://github.com/bbatsov/adoc-mode/pull/84): Find cross-references project-wide in an Antora component. `M-?` (`xref-find-references`) on an id now searches the whole component (not just the current buffer) and lists every cross-page `xref:this/page.adoc#id[]` as well as the same-page `<<id>>` / `xref:id[]` usages.
- [#80](https://github.com/bbatsov/adoc-mode/pull/80): Treat section titles as cross-reference targets. `adoc-mode` now derives each section's auto-id the way Asciidoctor does, so completion (`<<` / `xref:`), the `xref` backend, and `adoc-goto-ref-label` offer and resolve section ids - not just explicit anchors. The id style is detected automatically: a document's own `:idprefix:` / `:idseparator:` win, otherwise files inside an Antora component (an `antora.yml` above them) use Antora's kebab-case style (`My Title` -> `my-title`) and everything else uses Asciidoctor's default (`_my_title`). The new `adoc-section-id-style` option forces a specific style.
- [#104](https://github.com/bbatsov/adoc-mode/pull/104): Recognise Markdown-style fenced code blocks (`` ```ruby ``), which are fontified natively like `[source,ruby]` listings and whose lines are no longer taken for section titles, list items, attribute entries or anchors.

### Changes

- [#99](https://github.com/bbatsov/adoc-mode/pull/99): `adoc-promote` / `adoc-demote` (`M-left` / `M-right`) and `adoc-promote-title` / `adoc-demote-title` now go the way Org mode's do: promoting moves a title or list item up the outline (`===` to `==`, `**` to `*`) and demoting moves it down, the reverse of before.
  - They stop with an error at either end instead of wrapping around.
  - Only the document title, or a part in a book (`:doctype: book`), can be promoted to level 0, which Asciidoctor reserves for those.
  - Demoting the first item of a list is refused, as in Org, since its siblings would end up nested under it.
  - Away from a title or list item, `M-left` / `M-right` move by word as they do elsewhere in Emacs, instead of signalling an error.
- [#100](https://github.com/bbatsov/adoc-mode/pull/100): Two-line (setext) titles are deprecated, as they are in Asciidoctor and the AsciiDoc spec, and support for them will be removed in a future release.
  - `adoc-enable-two-line-title`, `adoc-two-line-title-del` and the unused `adoc-default-title-type` are obsolete.
  - Enabling two-line titles shows a warning once per session.
  - While they're enabled, `C-c C-t` converts a two-line title to the one-line style.
- [#79](https://github.com/bbatsov/adoc-mode/pull/79): `adoc-goto-ref-label` (`C-c C-a`) now completes over the anchors defined in the buffer instead of asking you to type the id blind. It stays permissive, so an id that isn't defined yet can still be entered, and the cross-reference at point is still offered as the default.
- [#74](https://github.com/bbatsov/adoc-mode/pull/74): The compilation error matcher now also recognises modern `asciidoctor:` diagnostics, not just the legacy AsciiDoc.py `asciidoc:` format, so jumping to warnings and errors works with current Asciidoctor output.
- [#71](https://github.com/bbatsov/adoc-mode/pull/71): `[source,ocaml]` code blocks now fontify with `neocaml-mode` when it is available, falling back to `tuareg-mode` and then `caml-mode`. To support this, a value in `adoc-code-lang-modes` may now be either a single major mode or a list of candidate modes tried in order (the first defined one wins).
- [#86](https://github.com/bbatsov/adoc-mode/pull/86): Bold and emphasized text now use plain `bold` / `italic` faces instead of tinting the text with `adoc-gen-face`. This matches `asciidoc-mode` (and the convention in `markdown-mode` / `org-mode`), so switching between the modes is less jarring. Customize `adoc-bold-face` / `adoc-emphasis-face` if you preferred the tint.
- The example-table tempo template now inserts the modern `|===` delimiter instead of the dated `|====================` run of equals.
- [#110](https://github.com/bbatsov/adoc-mode/pull/110): List editing nests items the way Asciidoctor does, by the order their markers turn up in, instead of a fixed depth per marker.
  - `M-up` / `M-down` move an item with the items nested in it, whatever their markers (`* a` then `- b`, or `* a` then `. b`), and across blank lines.
  - `M-left` gives an item the marker of the item it was in, and `M-right` the marker of its new siblings, or one that isn't in use around it. They work on explicitly numbered items too, and as in Org mode, an item with items nested in it isn't promoted on its own.
  - A list takes in what Asciidoctor attaches to its items, such as literal paragraphs, description lists and thematic breaks after a blank line, and blocks and tables attached with `+`. It ends at a paragraph after a blank line, a block that isn't attached or a table cell, so an item no longer moves into another list or out of its block.
- [#108](https://github.com/bbatsov/adoc-mode/pull/108): `adoc-font-lock-extend-after-change-max` is obsolete, as a code block is now fontified again as a whole after a change in it, however long it is.

### Bugs fixed

- [#78](https://github.com/bbatsov/adoc-mode/pull/78): Following a cross-reference at point (`C-c C-o` / `M-.`, and the new `xref` commands) now works for a plain `<<id>>` even when a captioned `<<id,caption>>` appears later on the same or an adjacent line, and ignores the whitespace in forms like `<<id >>`. Previously `adoc-xref-id-at-point` could return nil or an id with a trailing space in those cases.
- [#73](https://github.com/bbatsov/adoc-mode/pull/73): Heading navigation (`C-c C-n` and friends) and the imenu index no longer get confused by code and other delimited blocks. A `==`-style line inside a listing, source, literal, example, sidebar, quote, or open block, or a code line followed by `----` (which looks just like a two-line title underline), is no longer mistaken for a section title. Navigation and imenu now stay in step with what is actually highlighted as a title.
- [#73](https://github.com/bbatsov/adoc-mode/pull/73): Heading navigation and imenu now honour `adoc-enable-two-line-title`. It is nil by default, so two-line (setext) titles are no longer picked up unless you opt in, matching their fontification. Previously they were always recognised, which was the main source of the code-block confusion above.
- [#89](https://github.com/bbatsov/adoc-mode/pull/89): Promoting, demoting or toggling a one-line title (`M-left` / `M-right`, `C-c C-t`) no longer turns it into the enclosed form when it's followed by a newline. `== Section` used to become `=== Section ===`.
- [#89](https://github.com/bbatsov/adoc-mode/pull/89): `adoc-promote-title` and `adoc-demote-title` default to one level when called from Lisp without an argument (`adoc-demote-title` used to signal an error), and the title commands signal a `user-error` instead of an `error` when point isn't on a title.
- [#89](https://github.com/bbatsov/adoc-mode/pull/89): Title editing commands now honour `adoc-enable-two-line-title`, like highlighting, navigation and imenu already did.
  - With two-line titles disabled (the default), `M-left` / `M-right` and `C-c C-t` no longer mistake a line above a `----` or `====` delimiter for a title and overwrite the delimiter.
  - `C-c C-t` won't convert to a two-line title while they're disabled, or past level 4 (where it used to crash).
  - A numeric value now skips underlines of that length, as documented. It used to compare the length of the title text instead.
- [#90](https://github.com/bbatsov/adoc-mode/pull/90): A construct that is rejected once no longer stops the same construct from being highlighted further down. A `NOTE:` inside a listing block, for instance, used to leave every later admonition paragraph unhighlighted; literal paragraphs, the alignment of indented lines and two-line titles had the same problem.
- [#90](https://github.com/bbatsov/adoc-mode/pull/90): Delimited blocks are highlighted correctly when Emacs fontifies the buffer a piece at a time, as it does while you scroll.
  - A long listing, literal, example or other block crossing the edge of a piece used to lose track of where it began, so code could come out bold or as table cells.
  - A block now ends at the first line that repeats its opening delimiter exactly, as in Asciidoctor. It used to need a non-blank last line, and any longer run of the same character closed it.
  - A delimiter line inside a listing or literal block is just content.
- [#90](https://github.com/bbatsov/adoc-mode/pull/90): Example, open, quote and sidebar blocks keep the highlighting of what's inside them (list markers, comments, `include::` lines, nested code), and section titles inside a delimited block are no longer highlighted as titles, since Asciidoctor reads them as plain text.
- [#66](https://github.com/bbatsov/adoc-mode/issues/66): Links, `xref:` and footnote macros and the like are recognised (and clickable) again when their text holds an apostrophe, an ellipsis, an arrow or other inline markup, as in `https://example.org[Bob's page]`. Bare URLs no longer run into a following `[`.
- [#91](https://github.com/bbatsov/adoc-mode/pull/91): Two cross-references on one line, as in `<<foo>>, <<bar>>`, are highlighted as two instead of one with the id `foo>>`, and an xref to a section's auto-id like `<<_installation>>` is highlighted at all.
- [#91](https://github.com/bbatsov/adoc-mode/pull/91): Superscripts and subscripts can't span whitespace anymore, as in Asciidoctor, so `~/.emacs.d/init.el to ~/backup` and `C-^ to join and M-^` stay plain text.
- [#91](https://github.com/bbatsov/adoc-mode/pull/91): Superscripts are raised by their own `adoc-script-raise` value. They checked the subscript's, so setting that to 0 stopped superscripts from being raised.
- [#92](https://github.com/bbatsov/adoc-mode/pull/92): Looking up an anchor or section id is case-sensitive, as ids are in Asciidoctor. Following `<<foo>>` used to land on `[[FOO]]`, and `M-?` in an Antora component counted `#Deep-Section` as a reference to `deep-section`.
- [#92](https://github.com/bbatsov/adoc-mode/pull/92): A same-page `xref:#id[]` can be followed and is found by `M-?`, like `<<id>>`.
- [#92](https://github.com/bbatsov/adoc-mode/pull/92): An inline anchor with reftext, `[[id,Reftext]]`, can be found and followed by its id. It was offered in completion but nothing could resolve it.
- [#92](https://github.com/bbatsov/adoc-mode/pull/92): `M-?` on a section title lists the references to that section instead of prompting for an id. A section with an explicit id (`[[id]]` or `[#id]` above it, or an anchor at the end of the title) uses that id, and no longer offers an auto-id in completion, since Asciidoctor doesn't generate one for it.
- [#93](https://github.com/bbatsov/adoc-mode/pull/93): Warnings and errors in the output of the Asciidoctor export commands are navigable (`next-error` and friends). The matcher was only set up in the AsciiDoc buffer, never in the export's compilation buffer, and it now also takes the capitalised `Line` some Asciidoctor versions print.
- [#93](https://github.com/bbatsov/adoc-mode/pull/93): `adoc-preview` deletes the HTML file it writes next to the document when the buffer is killed or Emacs exits, live preview or not. It used to be left behind unless `adoc-live-preview-mode` was on.
- [#93](https://github.com/bbatsov/adoc-mode/pull/93): The `auto` preview backend only picks the xwidget pane when Emacs has xwidget support, and falls back to `eww` otherwise. It used to pick it on any graphical Emacs and then fail.
- [#93](https://github.com/bbatsov/adoc-mode/pull/93): In an Antora component, Flymake no longer reports `include::partial$x.adoc[]` and other Antora resource includes as missing files. Asciidoctor can't resolve those on its own.
- [#94](https://github.com/bbatsov/adoc-mode/pull/94): Fix the AsciiDoc menu entries that pointed at commands that don't exist (the xref, image and comment ones). The comment entry is backed by the new `adoc-insert-comment`, which comments out every line of the region at column 0, and the "Passthrough macros" submenu shows its help text.
- [#94](https://github.com/bbatsov/adoc-mode/pull/94): The tempo templates are documented with the AsciiDoc help text again (see `C-h f tempo-template-adoc-emphasis`), instead of a bare "Insert a adoc-emphasis."
- [#94](https://github.com/bbatsov/adoc-mode/pull/94): The trademark and dash templates insert `(TM)` and `--`, which Asciidoctor replaces with ™ and an em dash, as their menu entries say. They inserted `(T)` and `---`, which stay as they are.
- [#94](https://github.com/bbatsov/adoc-mode/pull/94): Tempo templates, and loading `adoc-mode` itself, no longer fail with `wrong-type-argument symbolp` when the current command is a lambda (a key bound to one, a hydra, or a transient).
- [#97](https://github.com/bbatsov/adoc-mode/pull/97): The nested imenu index (the default) no longer leaves out sections that skip a level, which also left a document without a level 0 title with an empty index.
- [#97](https://github.com/bbatsov/adoc-mode/pull/97): Outline folding (`TAB` / `S-TAB`) no longer takes a `==` line inside a listing or other delimited block for a section title (on Emacs 28 only `TAB` on that line itself is fixed).
- [#99](https://github.com/bbatsov/adoc-mode/pull/99): Title and list editing (`M-left` / `M-right`, `C-c C-t`, `M-RET`, `M-up` / `M-down`) no longer takes a `== ...` or `* ...` line inside a listing or other code block for a title or list item and rewrites it.
- [#98](https://github.com/bbatsov/adoc-mode/pull/98): Section auto-ids take the document attributes into account the way Asciidoctor does: attribute references in a title are substituted before its id is derived (`== {product} Setup`), `:sectids!:` turns auto-ids off, and `:idprefix:` / `:idseparator:` apply from the line that sets them, including in buffers that aren't visiting a file.
- [#98](https://github.com/bbatsov/adoc-mode/pull/98): Repeated section titles get numbered ids (`_foo`, `_foo_2`, ...) as in Asciidoctor, skipping the ids explicit anchors above them already use, so a reference to `_foo_2` leads to the second section instead of nowhere.
- [#98](https://github.com/bbatsov/adoc-mode/pull/98): Section auto-ids of titles with markup match Asciidoctor's: link and xref macros contribute their text, images and anchors nothing, built-in attributes like `{nbsp}` and replacements like `--` or `(C)` disappear the way their entities do, and emphasis loses its underscores even with an Antora-style `-` separator.
- [#102](https://github.com/bbatsov/adoc-mode/pull/102): Markdown-style thematic breaks (`---`, `* * *` and the like) are highlighted like `'''`, and the list commands no longer take `* * *` for a list item, unless it continues a list using `*`, where Asciidoctor reads it as one.
- [#104](https://github.com/bbatsov/adoc-mode/pull/104): Blocks nested in an example, sidebar, quote or open block are recognised as blocks of their own.
  - The list commands leave the lines of a nested listing or other verbatim block alone, and its attribute entries and anchors no longer affect section ids.
  - A nested block or table left unclosed is no longer highlighted as running past the end of the block it's in.
  - The delimiter that closes a CSV or DSV table no longer opens another table, as in Asciidoctor.
- [#101](https://github.com/bbatsov/adoc-mode/pull/101): A `file://` link in a section title gives the section's auto-id its text, like the other links do.
- [#103](https://github.com/bbatsov/adoc-mode/pull/103): Completion, the `xref` backend and section ids agree on what's an anchor, and go by what Asciidoctor takes for one.
  - `anchor:id[]`, `[id=...]` and ids with `.` or `:` in them count, and anchors in comments, code blocks, literal paragraphs and `[source]` or other verbatim paragraphs don't.
  - A section takes its id from the closest `[[id]]` or `[#id]` above it, even past blank lines, comments or a block title, and prefers it to an anchor at the end of the title.
  - Only the anchors Asciidoctor registers before it reaches a section count as taking its auto-id, so one in a block title or in the middle of a list item no longer turns `_foo` into `_foo_2`.
- [#106](https://github.com/bbatsov/adoc-mode/pull/106): Section ids and the attribute references in image paths only take the attribute entries Asciidoctor applies into account.
  - Entries in the text of a paragraph or list item, or in a table, no longer count.
  - `ifdef` and `ifndef` branches count only when their condition holds, so the common `ifdef::env-github[]` block no longer changes the ids.
  - The attributes Asciidoctor and Antora set by default, like `backend-html5` or `env-site`, count as set.
  - Image paths resolve their references the way titles do: by the entries above them, case-insensitively, and through attributes that refer to other attributes.
- [#111](https://github.com/bbatsov/adoc-mode/pull/111): Section ids and image paths apply the attribute entries in more of the places Asciidoctor does.
  - Entries below the author and revision lines of the document header, a value continued with ` \`, a block macro or thematic break, or an `ifdef` branch that doesn't hold count.
  - Attribute names are stored the way Asciidoctor stores them, so `:a.b:` sets `ab`, and the document header sets `doctitle`, `author`, `revnumber` and the like.
  - `ifdef` separates the attributes at whichever of `,` and `+` comes first and ignores an `endif` for another attribute, as Asciidoctor does, and the explicit id above a section title is found past `ifdef` lines but not past `include::` ones.
- [#105](https://github.com/bbatsov/adoc-mode/pull/105): Section auto-ids follow Asciidoctor's substitution order, so titles with passthroughs (`+{x}+`, `pass:[...]`), escaped quoted text (`\__x__`) or attribute values holding markup get the ids Asciidoctor gives them, and so do titles with icons, index terms or links under `:hide-uri-scheme:`.
- [#107](https://github.com/bbatsov/adoc-mode/pull/107): An attribute entry that refers to the attribute it sets, as in `:product: {product} Pro`, gets its earlier value for section ids instead of leaving the reference as it is.
- [#107](https://github.com/bbatsov/adoc-mode/pull/107): Counters (`{counter:step}`, `{counter2:step}`) in section titles, attribute entries and the document title count as they do in Asciidoctor, so the auto-ids of the titles that use them match.
- [#108](https://github.com/bbatsov/adoc-mode/pull/108): The list commands and section ids leave the lines of more blocks alone, as Asciidoctor does.
  - An open block styled `[source]`, `[listing]`, `[literal]`, `[pass]`, `[comment]` or `[verse]`, or a quote block styled `[verse]`, is verbatim, also when blank lines, comments or a block title come between the style and the block.
  - A block left open in another block runs to the end of that block.

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
