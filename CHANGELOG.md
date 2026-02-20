# Changelog

## master (unreleased)

### New features

- [#21](https://github.com/bbatsov/adoc-mode/pull/21): Add support for native font-locking in code blocks.
- [#48](https://github.com/bbatsov/adoc-mode/pull/48): Add support for displaying images.
- Add font-lock support for Asciidoctor inline macros: `kbd:[]`, `btn:[]`, `menu:[]`, `pass:[]`, `stem:[]`, `latexmath:[]`, `asciimath:[]`.

### Changes

- Require Emacs 28.1.
- `adoc-enable-two-line-title` now defaults to nil (Asciidoctor deprecated Setext-style titles).
- Remove deprecated AsciiDoc backtick-apostrophe quote styles (`` ``text'' `` and `` `text' ``), which are not supported in Asciidoctor.

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
