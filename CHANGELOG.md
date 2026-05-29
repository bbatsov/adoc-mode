# Changelog

## main (unreleased)

### New features

- New `adoc-title-scaling` defcustom (default `t`) and `adoc-title-scaling-values` list let users disable the variable-height title faces or pick their own scale factors. Set the boolean to nil for uniformly-sized headings, or customise the list to control the level-0..5 heights. Mirrors `markdown-header-scaling`.
- New `adoc-blockquote-face` for the body of `[quote]` and `[verse]` delimited blocks (inherits `font-lock-doc-face`); previously the body was left unfontified.
- New `adoc-highlight-face` for `#text#` / `##text##` highlighted spans (inherits the standard `highlight` face); previously these reused `adoc-gen-face`.
- New `adoc-url-face` (inherits `font-lock-string-face`) for URL targets and standalone URLs / email addresses. Link text inside `[…]` still uses `adoc-reference-face`. URL targets previously reused `adoc-internal-reference-face` (for `http://…[label]` form) or `adoc-reference-face` (for bare URLs), conflating link text and link target.
- New `adoc-metadata-key-face` (inherits `font-lock-variable-name-face`) and `adoc-metadata-value-face` (inherits `font-lock-string-face`) for document attribute entries like `:author: Bozhidar Batsov`. Previously the key used `adoc-meta-face` (the generic markup face) and the value reused `adoc-secondary-text-face`; both now have dedicated semantic faces.
- New `adoc-footnote-marker-face` (inherits `adoc-command-face`) and `adoc-footnote-text-face` (inherits `font-lock-comment-face`) for `footnote:[…]` and `footnoteref:[…]` macros. The marker name (`footnote`, `footnoteref`) previously reused the generic `adoc-command-face` and the body text reused `adoc-secondary-text-face`.
- New `adoc-strike-through-face`, `adoc-underline-face`, `adoc-overline-face`, and an `adoc-role-face-alist` defcustom. `[.line-through]#text#`, `[.underline]#text#`, and `[.overline]#text#` (plus the legacy `[role]#text#` and `[role#id]#text#` shapes, and combinations like `[.line-through]*bold*`) now fontify the span with the matching role face layered on top of the surrounding quote's default face. Add entries to `adoc-role-face-alist` to fontify custom roles defined in your stylesheet.

### Changes

- `adoc-gen-face`, `adoc-verbatim-face`, `adoc-secondary-text-face`, and `adoc-replacement-face` now inherit from `font-lock-*` faces instead of hardcoding literal colours. Themes that style the font-lock palette will now style AsciiDoc buffers consistently. Users who relied on the old defaults can restore them via `M-x customize-face`.
- Simplify `adoc-meta-face` to `(:inherit shadow :slant normal :weight normal)` instead of overriding eleven attributes including `:family "Monospace"`. AsciiDoc markup characters now respect the user's font choices and theme `shadow` colour rather than being forced into a monospace family with hardcoded grays.
- Drop the dated 3D button decoration (`:box (:style released-button)`) and hardcoded hex colours from `adoc-command-face` and `adoc-complex-replacement-face`; inherit from `font-lock-builtin-face` instead.
- `adoc-meta-hide-face` no longer hardcodes `gray75`/`gray25` foregrounds; it simply inherits from `adoc-meta-face` so the colour tracks the theme. Customise the face if you want hidden markup to fade further into the background.
- Drop the self-referencing `(defvar adoc-X-face 'adoc-X-face)` boilerplate and the `adoc-delimiter` / `adoc-hide-delimiter` aliases. Font-lock keyword specs now quote face symbols directly. No user-visible change; this is purely an internal cleanup.
- `adoc-show-version` is now a deprecated alias for `adoc-mode-version`, which is itself the interactive command (still also a `defconst` carrying the version string). The previous `defalias 'adoc-mode-version → adoc-show-version` indirection is gone.
- `adoc-default-title-type` and `adoc-default-title-sub-type` now use a `choice` widget restricted to 1 or 2, replacing the open-ended `integer` type that allowed nonsensical values.
- Internal cleanup: `(adoc-calc)` runs from the mode initialization function rather than at file load. `(require 'adoc-mode-tempo)` and `(require 'compile)` moved to the top of the file. Dead `(boundp …)` guards around the `compilation-error-regexp-alist` integration removed. Stale `;; TODO` comments cleaned up. No user-visible change.

### Bugs fixed

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
