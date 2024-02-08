# Changelog

## master (unreleased)

### New features

- [#21](https://github.com/bbatsov/adoc-mode/pull/21): Add support for native font-locking in code blocks.

### Bugs fixed

- [#49](https://github.com/bbatsov/adoc-mode/issues/49) Flyspell generates overlays for links and alike

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
