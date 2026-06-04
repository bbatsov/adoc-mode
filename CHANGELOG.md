# Changelog

## main (unreleased)

### New features

- Add Asciidoctor integration for previewing and exporting documents, reachable from the new `adoc-asciidoctor-menu` transient on `C-c C-c` (and the AsciiDoc menu). `adoc-preview` renders the current buffer with `asciidoctor` and shows the HTML in a side pane - an xwidget WebKit widget when available, otherwise `eww`, configurable via `adoc-preview-backend` - and `adoc-live-preview-mode` re-renders on every save. The preview feeds the buffer to `asciidoctor` through its standard input, so unsaved edits and relative `include::` / image paths both keep working. Export commands `adoc-export-html`, `adoc-export-docbook`, `adoc-export-pdf`, and `adoc-export-epub` run through `compile`, so Asciidoctor's warnings and errors are navigable.
- Add context-aware completion via `completion-at-point` (kbd:[M-TAB], or any of corfu/company/built-in completion). Inside `<<` or `xref:` it completes cross-reference ids from the explicit anchors defined in the buffer (`[[id]]`, `[#id]`, `[[[biblio]]]`); inside `{` it completes attribute names (the ones defined with `:name:` plus a set of common built-ins); after `include::` it completes file paths; and inside `[source,` it completes source-block language names. It stays out of the way in plain prose.
- Add a Flymake backend (`adoc-flymake`) that runs the buffer through Asciidoctor and reports its parser errors and warnings inline. It's registered automatically, so enabling `flymake-mode` is enough. The check feeds the buffer to Asciidoctor over its standard input, so it works on unsaved edits.
- Make references clickable. Cross-references (`<<id>>`, `xref:id[]`), links and URLs (`link:`, `https:`, `mailto:`, ...), and `include::` macros now highlight on hover and follow with a `mouse-1` (or `mouse-2`) click - the same action as `C-c C-o` / `M-.`. As part of this, `adoc-follow-thing-at-point` now also follows `link:` macros (opening a local target or a URL) and no longer passes the `[label]` along when opening a URL macro.
- Add an `xref` backend over AsciiDoc anchors. In an `adoc-mode` buffer, `M-?` (`xref-find-references`) lists every cross-reference to the anchor at point, and the standard xref machinery (the marker stack, the completion-read prompt, `consult-xref`, ...) now works for AsciiDoc ids. Definitions are anchors (`[[id]]`, `[#id]`, `[[[biblio]]]`) and references are `<<id>>` / `xref:id[]` usages, resolved within the current buffer. `M-.` keeps following URLs and `include::` too, via `adoc-follow-thing-at-point`.

### Changes

- `adoc-goto-ref-label` (`C-c C-a`) now completes over the anchors defined in the buffer instead of asking you to type the id blind. It stays permissive, so an id that isn't defined yet can still be entered, and the cross-reference at point is still offered as the default.
- The compilation error matcher now also recognises modern `asciidoctor:` diagnostics, not just the legacy AsciiDoc.py `asciidoc:` format, so jumping to warnings and errors works with current Asciidoctor output.
- `[source,ocaml]` code blocks now fontify with `neocaml-mode` when it is available, falling back to `tuareg-mode` and then `caml-mode`. To support this, a value in `adoc-code-lang-modes` may now be either a single major mode or a list of candidate modes tried in order (the first defined one wins).

### Bugs fixed

- Following a cross-reference at point (`C-c C-o` / `M-.`, and the new `xref` commands) now works for a plain `<<id>>` even when a captioned `<<id,caption>>` appears later on the same or an adjacent line, and ignores the whitespace in forms like `<<id >>`. Previously `adoc-xref-id-at-point` could return nil or an id with a trailing space in those cases.
- Heading navigation (`C-c C-n` and friends) and the imenu index no longer get confused by code and other delimited blocks. A `==`-style line inside a listing, source, literal, example, sidebar, quote, or open block, or a code line followed by `----` (which looks just like a two-line title underline), is no longer mistaken for a section title. Navigation and imenu now stay in step with what is actually highlighted as a title.
- Heading navigation and imenu now honour `adoc-enable-two-line-title`. It is nil by default, so two-line (setext) titles are no longer picked up unless you opt in, matching their fontification. Previously they were always recognised, which was the main source of the code-block confusion above.

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
