# Changelog

## master (unreleased)

### New features

- [#21](https://github.com/bbatsov/adoc-mode/pull/21): Add support for native font-locking in code blocks.
- [#48](https://github.com/bbatsov/adoc-mode/pull/48): Add support for displaying images.

### Bugs fixed

- [#33](https://github.com/bbatsov/adoc-mode/issues/33): Address noticeable lag when typing in code blocks.
- [#39](https://github.com/bbatsov/adoc-mode/issues/39): Support spaces in the attributes of code blocks.
- [#41](https://github.com/bbatsov/adoc-mode/issues/41): Fix unconstrained monospace delimiters.
- [#49](https://github.com/bbatsov/adoc-mode/issues/49): Prevent Flyspell from generating overlays for links and alike.
- [#52](https://github.com/bbatsov/adoc-mode/issues/52): Prevent auto-fill-mode from breaking one-line titles and alike.

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
