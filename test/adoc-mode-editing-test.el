;;; adoc-mode-editing-test.el --- Editing-command tests for adoc-mode -*- lexical-binding: t; -*-

;; Copyright © 2025-2026 Bozhidar Batsov

;;; Commentary:

;; Buttercup tests for adoc-mode editing commands: title promotion/demotion,
;; list editing (promote/demote, insert, move, renumber), and the
;; region-aware text-styling commands.  Buffer transforms use the
;; `adoc-test-trans' helper (markers: `!' point, `<>' region).

;;; Code:

(require 'adoc-mode-test-helpers)

(describe "adoc-mode title editing"

  (it "promotes one-line and two-line titles"
    (adoc-test-trans "=== foo" "== foo" '(adoc-promote-title 1))
    (adoc-test-trans "====== foo" "===== foo" '(adoc-promote-title 1))
    (adoc-test-trans "==== foo" "== foo" '(adoc-promote-title 2))
    (adoc-test-trans "=== foo ===" "== foo ==" '(adoc-promote-title 1))
    (adoc-test-trans "==== foo ====" "== foo ==" '(adoc-promote-title 2))
    (let ((adoc-enable-two-line-title t))
      (adoc-test-trans "foo!\n~~~!" "foo\n---" '(adoc-promote-title 1))
      (adoc-test-trans "foo!\n^^^!" "foo\n---" '(adoc-promote-title 2))))

  (it "goes the other way with a negative argument"
    (adoc-test-trans "== f!oo\n" "=== foo\n" '(adoc-promote-title -1))
    (adoc-test-trans "=== f!oo\n" "== foo\n" '(adoc-demote-title -1))
    (adoc-test-trans "== f!oo\n" "=== foo\n" '(adoc-promote -1))
    (adoc-test-trans "=== f!oo\n" "== foo\n" '(adoc-demote -1)))

  (it "doesn't promote or demote a title past the outermost or innermost level"
    (adoc-test-trans "= f!oo\n" "= foo\n"
                     '(expect (adoc-promote-title 1) :to-throw 'user-error))
    (adoc-test-trans "=== f!oo\n" "=== foo\n"
                     '(expect (adoc-promote-title 3) :to-throw 'user-error))
    (adoc-test-trans "====== f!oo\n" "====== foo\n"
                     '(expect (adoc-demote-title 1) :to-throw 'user-error))
    (adoc-test-trans "====== f!oo ======\n" "====== foo ======\n"
                     '(expect (adoc-demote-title 1) :to-throw 'user-error))
    (let ((adoc-enable-two-line-title t))
      ;; two-line titles only go down to level 4
      (adoc-test-trans "foo!\n+++!" "foo\n+++"
                       '(expect (adoc-demote-title 1) :to-throw 'user-error))))

  (it "only promotes a section to level 0 in a book, or to make the document title"
    (adoc-test-trans "= Doc\n\n== S!ec\n" "= Doc\n\n== Sec\n"
                     '(expect (adoc-promote-title 1) :to-throw 'user-error))
    (adoc-test-trans "= Book\n:doctype: book\n\n== P!art\n"
                     "= Book\n:doctype: book\n\n= Part\n"
                     '(adoc-promote-title 1))
    ;; only the header can make a book
    (adoc-test-trans "= Doc\n\n----\n:doctype: book\n----\n\n== S!ec\n"
                     "= Doc\n\n----\n:doctype: book\n----\n\n== Sec\n"
                     '(expect (adoc-promote-title 1) :to-throw 'user-error))
    ;; the first title can always become the document title
    (adoc-test-trans "== My D!oc\n\nSome text.\n" "= My Doc\n\nSome text.\n"
                     '(adoc-promote-title 1))
    (adoc-test-trans "= D!oc\n\nText.\n" "= Doc\n\nText.\n"
                     '(progn (adoc-demote-title 1) (adoc-promote-title 1))))

  (it "keeps a title's delimiter style when it is followed by text"
    (adoc-test-trans "== Sec!tion\n\nbody\n" "=== Section\n\nbody\n"
                     '(adoc-demote-title 1))
    (adoc-test-trans "=== Sec!tion\n\nbody\n" "== Section\n\nbody\n"
                     '(adoc-promote-title 1))
    (adoc-test-trans "== Sec!tion ==\n\nbody\n" "=== Section ===\n\nbody\n"
                     '(adoc-demote-title 1))
    (adoc-test-trans "== Sec!tion\n\nbody\n" "== Section\n\nbody\n"
                     '(adoc-adjust-title-del))
    (adoc-test-trans "== Sec!tion\n\nbody\n" "== Section ==\n\nbody\n"
                     '(adoc-toggle-title-type t))
    (adoc-test-trans "== Sec!tion ==\n\nbody\n" "== Section\n\nbody\n"
                     '(adoc-toggle-title-type t)))

  (it "demotes titles"
    (adoc-test-trans "= foo" "== foo" '(adoc-demote-title 1))
    (adoc-test-trans "== foo" "==== foo" '(adoc-demote-title 2))
    (adoc-test-trans "= foo =" "== foo ==" '(adoc-demote-title 1))
    (let ((adoc-enable-two-line-title t))
      (adoc-test-trans "foo!\n===!" "foo\n---" '(adoc-demote-title 1))))

  (it "defaults to one level when called from Lisp without an argument"
    (adoc-test-trans "=== f!oo\n" "== foo\n" '(adoc-promote-title))
    (adoc-test-trans "=== f!oo\n" "==== foo\n" '(adoc-demote-title))
    (adoc-test-trans "=== f!oo\n" "== foo\n" '(adoc-promote))
    (adoc-test-trans "=== f!oo\n" "==== foo\n" '(adoc-demote)))

  (it "toggles the title type"
    (let ((adoc-enable-two-line-title t))
      (adoc-test-trans "= one" "one\n===" '(adoc-toggle-title-type))
      (adoc-test-trans "two!\n===!" "= two" '(adoc-toggle-title-type))
      (adoc-test-trans "= three!\nbar" "three\n=====\nbar" '(adoc-toggle-title-type))
      (adoc-test-trans "four!\n====!\nbar" "= four\nbar" '(adoc-toggle-title-type)))
    (adoc-test-trans "= five" "= five =" '(adoc-toggle-title-type t))
    (adoc-test-trans "= six =" "= six" '(adoc-toggle-title-type t)))

  (it "refuses to make a two-line title when they are disabled or too deep"
    (adoc-test-trans "== f!oo\n" "== foo\n"
                     '(expect (adoc-toggle-title-type) :to-throw 'user-error))
    (let ((adoc-enable-two-line-title t))
      (adoc-test-trans "====== f!oo\n" "====== foo\n"
                       '(expect (adoc-toggle-title-type) :to-throw 'user-error))))

  (it "leaves block delimiters alone when two-line titles are disabled"
    (dolist (command '(adoc-promote adoc-toggle-title-type))
      (adoc-test-trans ".Ex!ample\n-!---\ncode\n----\n" ".Example\n----\ncode\n----\n"
                       `(expect (,command) :to-throw 'user-error))
      (adoc-test-trans "Some t!ext\n====\nexample\n====\n" "Some text\n====\nexample\n====\n"
                       `(expect (,command) :to-throw 'user-error))))

  (it "honours a numeric `adoc-enable-two-line-title' when editing"
    (let ((adoc-enable-two-line-title 4))
      (adoc-test-trans ".Ex!ample\n----\ncode\n----\n" ".Example\n----\ncode\n----\n"
                       '(expect (adoc-promote) :to-throw 'user-error))
      (adoc-test-trans "foo!\n---" "== foo" '(adoc-toggle-title-type))))

  (it "signals a user-error when point is not on a title"
    (adoc-test-trans "just some pr!ose\n" "just some prose\n"
                     '(expect (adoc-promote-title 1) :to-throw 'user-error)))

  (it "adjusts the two-line title underline length"
    (let ((adoc-enable-two-line-title t))
      (adoc-test-trans "lorem!\n===!" "lorem\n=====" '(adoc-adjust-title-del))
      (adoc-test-trans "lorem!\n========!" "lorem\n=====" '(adoc-adjust-title-del))
      (adoc-test-trans "lorem!\n=====!" "lorem\n=====" '(adoc-adjust-title-del))))

  (it "builds a two-line title underline"
    (expect (adoc-make-two-line-title-underline 0 6) :to-equal "======")
    (expect (adoc-make-two-line-title-underline 2) :to-equal "~~~~"))

  (it "scales the title faces per `adoc-title-scaling'"
    (unwind-protect
        (let ((adoc-title-scaling t)
              (adoc-title-scaling-values '(2.5 2.0 1.6 1.3 1.1 1.0)))
          (adoc-update-title-faces)
          (expect (face-attribute 'adoc-title-0-face :height) :to-equal 2.5)
          (expect (face-attribute 'adoc-title-4-face :height) :to-equal 1.1)
          (setq adoc-title-scaling nil)
          (adoc-update-title-faces)
          (expect (face-attribute 'adoc-title-0-face :height) :to-equal 1.0)
          (expect (face-attribute 'adoc-title-5-face :height) :to-equal 1.0))
      (let ((adoc-title-scaling t)
            (adoc-title-scaling-values '(2.0 1.8 1.6 1.4 1.2 1.0)))
        (adoc-update-title-faces)))))

(describe "adoc-mode list editing"

  (it "promotes/demotes unordered list items"
    (adoc-test-trans "* foo!" "** foo" '(adoc-demote 1))
    (adoc-test-trans "** foo!" "* foo" '(adoc-promote 1))
    (adoc-test-trans "* foo!" "- foo" '(adoc-promote 1))
    (adoc-test-trans "- foo!" "* foo" '(adoc-demote 1))
    ;; leading indentation is preserved
    (adoc-test-trans "  ** foo!" "  *** foo" '(adoc-demote 1))
    (adoc-test-trans "* foo!" "*** foo" '(adoc-demote 2)))

  (it "promotes/demotes implicitly-numbered list items"
    (adoc-test-trans ". foo!" ".. foo" '(adoc-demote 1))
    (adoc-test-trans ".. foo!" ". foo" '(adoc-promote 1)))

  (it "doesn't promote or demote a list item past the outermost or innermost level"
    (adoc-test-trans "- foo!" "- foo"
                     '(expect (adoc-promote 1) :to-throw 'user-error))
    (adoc-test-trans "* foo!" "* foo"
                     '(expect (adoc-promote 2) :to-throw 'user-error))
    (adoc-test-trans "***** foo!" "***** foo"
                     '(expect (adoc-demote 1) :to-throw 'user-error))
    (adoc-test-trans ". foo!" ". foo"
                     '(expect (adoc-promote 1) :to-throw 'user-error))
    (adoc-test-trans "..... foo!" "..... foo"
                     '(expect (adoc-demote 1) :to-throw 'user-error)))

  (it "refuses to change the level of an explicitly-numbered item"
    (with-temp-buffer
      (adoc-mode)
      (insert "1. foo")
      (goto-char (point-min))
      (expect (adoc-promote 1) :to-throw 'user-error)
      (expect (buffer-string) :to-equal "1. foo")))

  (it "inserts a sibling list item"
    (adoc-test-trans "* foo!" "* foo\n* " '(adoc-insert-list-item))
    (adoc-test-trans "- foo!" "- foo\n- " '(adoc-insert-list-item))
    (adoc-test-trans ".. bar!" ".. bar\n.. " '(adoc-insert-list-item))
    ;; explicitly-numbered items get an incremented marker
    (adoc-test-trans "1. foo!" "1. foo\n2. " '(adoc-insert-list-item))
    (adoc-test-trans "a. foo!" "a. foo\nb. " '(adoc-insert-list-item))
    (adoc-test-trans "9. foo!" "9. foo\n10. " '(adoc-insert-list-item))
    ;; roman numerals and the last letter of the alphabet are copied verbatim
    (adoc-test-trans "i) foo!" "i) foo\ni) " '(adoc-insert-list-item))
    (adoc-test-trans "z. foo!" "z. foo\nz. " '(adoc-insert-list-item))
    ;; indentation is preserved
    (adoc-test-trans "  ** foo!" "  ** foo\n  ** " '(adoc-insert-list-item)))

  (it "errors when inserting a list item outside a list"
    (with-temp-buffer
      (adoc-mode)
      (insert "just some prose")
      (goto-char (point-min))
      (expect (adoc-insert-list-item) :to-throw 'user-error)
      (expect (buffer-string) :to-equal "just some prose")))

  (it "moves a list item down past its sibling"
    (adoc-test-trans "* a!\n* b\n" "* b\n* a\n" '(adoc-move-list-item-down))
    ;; a missing final newline must not merge the two items into one line
    (adoc-test-trans "* a!\n* b" "* b\n* a\n" '(adoc-move-list-item-down))
    ;; the item carries its nested sub-items with it
    (adoc-test-trans "* one!\n** sub\n* two\n" "* two\n* one\n** sub\n"
                     '(adoc-move-list-item-down)))

  (it "moves a list item up past its sibling"
    (adoc-test-trans "* a\n* b!\n" "* b\n* a\n" '(adoc-move-list-item-up))
    (adoc-test-trans ". one\n. two!" ". two\n. one\n" '(adoc-move-list-item-up))
    (adoc-test-trans "* one\n** sub\n* two!\n" "* two\n* one\n** sub\n"
                     '(adoc-move-list-item-up)))

  (it "does not treat a different-type item as a sibling"
    (with-temp-buffer
      (adoc-mode)
      (insert "1. alpha\n- bullet\n2. beta\n")
      (goto-char (point-min))
      (expect (adoc-move-list-item-down) :to-throw 'user-error)
      (expect (buffer-string) :to-equal "1. alpha\n- bullet\n2. beta\n")))

  (it "errors when there is no sibling to move past"
    (with-temp-buffer
      (adoc-mode)
      (insert "* only\n")
      (goto-char (point-min))
      (expect (adoc-move-list-item-down) :to-throw 'user-error)
      (expect (buffer-string) :to-equal "* only\n"))
    (with-temp-buffer
      (adoc-mode)
      (insert "** a\n* b\n")
      (goto-char (point-min))
      (expect (adoc-move-list-item-down) :to-throw 'user-error)
      (expect (buffer-string) :to-equal "** a\n* b\n")))

  (it "renumbers arabic and alphabetic lists"
    (adoc-test-trans "1. a!\n1. b\n1. c\n" "1. a\n2. b\n3. c\n" '(adoc-renumber-list))
    (adoc-test-trans "1. a\n5. b!\n9. c\n" "1. a\n2. b\n3. c\n" '(adoc-renumber-list))
    (adoc-test-trans "3. a!\n1. b\n" "3. a\n4. b\n" '(adoc-renumber-list))
    (adoc-test-trans "a. x!\na. y\n" "a. x\nb. y\n" '(adoc-renumber-list))
    ;; a missing final newline must terminate, not loop forever
    (adoc-test-trans "1. a!\n9. b" "1. a\n2. b" '(adoc-renumber-list)))

  (it "errors on alphabetic lists longer than 26 items"
    (with-temp-buffer
      (adoc-mode)
      (dotimes (_ 27) (insert "a. item\n"))
      (goto-char (point-min))
      (expect (adoc-renumber-list) :to-throw 'user-error)))

  (it "refuses to renumber roman or non-explicit lists"
    (with-temp-buffer
      (adoc-mode)
      (insert "i) a\nv) b\n")
      (goto-char (point-min))
      (expect (adoc-renumber-list) :to-throw 'user-error)
      (expect (buffer-string) :to-equal "i) a\nv) b\n"))
    (with-temp-buffer
      (adoc-mode)
      (insert "* a\n* b\n")
      (goto-char (point-min))
      (expect (adoc-renumber-list) :to-throw 'user-error)
      (expect (buffer-string) :to-equal "* a\n* b\n"))))

(describe "adoc-mode text styling"

  (it "wraps the word at point"
    (adoc-test-trans "foo!" "*foo*" '(adoc-insert-bold))
    (adoc-test-trans "foo!" "_foo_" '(adoc-insert-italic))
    (adoc-test-trans "foo!" "`foo`" '(adoc-insert-monospace))
    (adoc-test-trans "foo!" "#foo#" '(adoc-insert-highlight))
    (adoc-test-trans "foo!" "^foo^" '(adoc-insert-superscript))
    (adoc-test-trans "foo!" "~foo~" '(adoc-insert-subscript)))

  (it "inserts an empty pair when there is nothing to wrap"
    (adoc-test-trans "!" "**" '(adoc-insert-bold)))

  (it "wraps the active region"
    (with-temp-buffer
      (adoc-mode)
      (insert "foo bar baz")
      (goto-char 5) (set-mark 8) (activate-mark)
      (adoc-insert-bold)
      (expect (buffer-string) :to-equal "foo *bar* baz")))

  (it "toggles markup off when the region is already wrapped"
    ;; delimiters just outside the region
    (with-temp-buffer
      (adoc-mode)
      (insert "foo *bar* baz")
      (goto-char 6) (set-mark 9) (activate-mark)
      (adoc-insert-bold)
      (expect (buffer-string) :to-equal "foo bar baz"))
    ;; delimiters inside the region
    (with-temp-buffer
      (adoc-mode)
      (insert "foo *bar* baz")
      (goto-char 5) (set-mark 10) (activate-mark)
      (adoc-insert-bold)
      (expect (buffer-string) :to-equal "foo bar baz")))

  (it "inserts links"
    (with-temp-buffer
      (adoc-mode)
      (adoc-insert-link "https://example.com" "Example")
      (expect (buffer-string) :to-equal "https://example.com[Example]"))
    (with-temp-buffer
      (adoc-mode)
      (adoc-insert-link "https://example.com" "")
      (expect (buffer-string) :to-equal "https://example.com"))
    (with-temp-buffer
      (adoc-mode)
      (insert "see here now")
      (goto-char 5) (set-mark 9) (activate-mark)
      (adoc-insert-link "https://x.com" "here")
      (expect (buffer-string) :to-equal "see https://x.com[here] now"))))

(describe "adoc-mode indented insertion"
  (it "indents inserted text to the requested level"
    (let ((tab-width 2)
          (indent-tabs-mode nil))
      (adoc-test-trans "" " x"   '(adoc-insert-indented "x" 1))
      (adoc-test-trans "" "   x" '(adoc-insert-indented "x" 2)))
    (let ((tab-width 3)
          (indent-tabs-mode t))
      (adoc-test-trans "" "  x"   '(adoc-insert-indented "x" 1))
      (adoc-test-trans "" "\t  x" '(adoc-insert-indented "x" 2)))))

;;; adoc-mode-editing-test.el ends here
