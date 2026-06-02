;;; adoc-mode-navigation-test.el --- Navigation tests for adoc-mode -*- lexical-binding: t; -*-

;; Copyright © 2025-2026 Bozhidar Batsov

;;; Commentary:

;; Buttercup tests for adoc-mode heading navigation, outline cycling,
;; and cross-reference following.

;;; Code:

(require 'adoc-mode-test-helpers)

(defun adoc-test--insert-nav-doc ()
  "Insert a small multi-level document used by the navigation tests."
  (insert "= Doc Title\n\n"
          "intro\n\n"
          "== Section A\n\n"
          "text a\n\n"
          "=== Sub A1\n\n"
          "text\n\n"
          "=== Sub A2\n\n"
          "more\n\n"
          "== Section B\n\n"
          "end\n"))

(defun adoc-test--goto-heading (text)
  "Move point to the beginning of the line containing TEXT."
  (goto-char (point-min))
  (search-forward text)
  (beginning-of-line))

(describe "adoc-mode heading navigation"

  (describe "next/previous visible heading"
    (it "moves to the next heading of any level"
      (with-temp-buffer
        (adoc-mode)
        (adoc-test--insert-nav-doc)
        (goto-char (point-min))
        (adoc-next-visible-heading 1)
        (expect (looking-at-p "== Section A$") :to-be-truthy)
        (adoc-next-visible-heading 1)
        (expect (looking-at-p "=== Sub A1$") :to-be-truthy)
        (adoc-next-visible-heading 2)
        (expect (looking-at-p "== Section B$") :to-be-truthy)
        (let ((pos (point)))
          (expect (adoc-next-visible-heading 1) :to-throw 'user-error)
          (expect (point) :to-equal pos))))

    (it "moves to the previous heading and climbs out of bodies"
      (with-temp-buffer
        (adoc-mode)
        (adoc-test--insert-nav-doc)
        (adoc-test--goto-heading "Section B")
        (adoc-previous-visible-heading 1)
        (expect (looking-at-p "=== Sub A2$") :to-be-truthy)
        (adoc-previous-visible-heading 2)
        (expect (looking-at-p "== Section A$") :to-be-truthy)
        (adoc-test--goto-heading "text a")
        (adoc-previous-visible-heading 1)
        (expect (looking-at-p "== Section A$") :to-be-truthy)
        ;; a negative argument moves forward
        (adoc-previous-visible-heading -1)
        (expect (looking-at-p "=== Sub A1$") :to-be-truthy))))

  (describe "same-level navigation"
    (it "moves forward at the same level, skipping deeper headings"
      (with-temp-buffer
        (adoc-mode)
        (adoc-test--insert-nav-doc)
        (adoc-test--goto-heading "Section A")
        (adoc-forward-same-level 1)
        (expect (looking-at-p "== Section B$") :to-be-truthy)
        (adoc-test--goto-heading "Sub A1")
        (adoc-forward-same-level 1)
        (expect (looking-at-p "=== Sub A2$") :to-be-truthy)
        (adoc-test--goto-heading "Sub A2")
        (let ((pos (point)))
          (expect (adoc-forward-same-level 1) :to-throw 'user-error)
          (expect (point) :to-equal pos))))

    (it "moves backward at the same level"
      (with-temp-buffer
        (adoc-mode)
        (adoc-test--insert-nav-doc)
        (adoc-test--goto-heading "Section B")
        (adoc-backward-same-level 1)
        (expect (looking-at-p "== Section A$") :to-be-truthy)
        (adoc-test--goto-heading "Sub A2")
        (adoc-backward-same-level 1)
        (expect (looking-at-p "=== Sub A1$") :to-be-truthy)
        (adoc-test--goto-heading "Sub A1")
        (let ((pos (point)))
          (expect (adoc-backward-same-level 1) :to-throw 'user-error)
          (expect (point) :to-equal pos)))))

  (describe "up-heading"
    (it "moves to the parent heading"
      (with-temp-buffer
        (adoc-mode)
        (adoc-test--insert-nav-doc)
        (adoc-test--goto-heading "Sub A1")
        (adoc-up-heading 1)
        (expect (looking-at-p "== Section A$") :to-be-truthy)
        (adoc-test--goto-heading "Sub A2")
        (adoc-up-heading 2)
        (expect (looking-at-p "= Doc Title$") :to-be-truthy)
        (adoc-test--goto-heading "Doc Title")
        (let ((pos (point)))
          (expect (adoc-up-heading 1) :to-throw 'user-error)
          (expect (point) :to-equal pos)))))

  (describe "two-line titles"
    (it "navigates two-line (setext) titles"
      (with-temp-buffer
        (adoc-mode)
        (insert "Doc Title\n=========\n\n"
                "intro\n\n"
                "Section A\n---------\n\n"
                "text\n\n"
                "Section B\n---------\n\n"
                "end\n")
        (goto-char (point-min))
        (adoc-next-visible-heading 1)
        (expect (looking-at-p "Section A$") :to-be-truthy)
        (adoc-forward-same-level 1)
        (expect (looking-at-p "Section B$") :to-be-truthy)
        (adoc-up-heading 1)
        (expect (looking-at-p "Doc Title$") :to-be-truthy)))))

(describe "adoc-mode outline cycling"

  (defun adoc-test--cycle-buffer ()
    (adoc-mode)
    (insert "= Top\n\n== A\n\nbody a\n\n== B\n\nbody b\n")
    (font-lock-ensure)
    (goto-char (point-min)))

  (it "cycles a subtree folded then shown"
    (with-temp-buffer
      (adoc-test--cycle-buffer)
      (let ((body (save-excursion (search-forward "body a") (point))))
        (search-forward "== A") (beginning-of-line)
        (expect (outline-invisible-p body) :not :to-be-truthy)
        (adoc-cycle)
        (expect (outline-invisible-p body) :to-be-truthy)
        (adoc-cycle)
        (expect (outline-invisible-p body) :not :to-be-truthy))))

  (it "does not fold when point is off a heading"
    (with-temp-buffer
      (adoc-test--cycle-buffer)
      (let ((body (save-excursion (search-forward "body a") (point))))
        (goto-char body)
        (adoc-cycle)
        (expect (outline-invisible-p body) :not :to-be-truthy))))

  (it "cycles the whole buffer with a prefix argument"
    (with-temp-buffer
      (adoc-test--cycle-buffer)
      (let ((body (save-excursion (search-forward "body a") (point))))
        (expect (outline-invisible-p body) :not :to-be-truthy)
        (adoc-cycle '(4))
        (expect (outline-invisible-p body) :to-be-truthy)
        (adoc-cycle-buffer)
        (adoc-cycle-buffer)
        (expect (outline-invisible-p body) :not :to-be-truthy)))))

(describe "adoc-mode cross-reference following"

  (it "jumps to the anchor defining an id"
    (with-temp-buffer
      (adoc-mode)
      (insert "[[foo]]\n"
              "lorem ipsum\n"
              "[[bar]]\n"
              "dolor [[geil]]sit amen\n"
              "anchor:cool[]\n")
      (adoc-goto-ref-label "cool")
      (expect (line-number-at-pos) :to-equal 5)
      (adoc-goto-ref-label "geil")
      (expect (line-number-at-pos) :to-equal 4)
      (adoc-goto-ref-label "bar")
      (expect (line-number-at-pos) :to-equal 3)))

  (it "follows the block id shorthand, including the style#id form"
    (with-temp-buffer
      (adoc-mode)
      (insert "[#sect2]\n== Two\n\n[source#sid]\n----\ncode\n----\n")
      (adoc-goto-ref-label "sect2")
      (expect (line-number-at-pos) :to-equal 1)
      (adoc-goto-ref-label "sid")
      (expect (line-number-at-pos) :to-equal 4)))

  (it "finds the xref id at point (<<id>> and xref: forms)"
    (with-temp-buffer
      (adoc-mode)
      (insert "lorem xref:bogous1[] ipsum xref:foo[bla\nbli] dolor xref:bogous2[]")
      (re-search-backward "bli")
      (expect (adoc-xref-id-at-point) :to-equal "foo"))
    (with-temp-buffer
      (adoc-mode)
      (insert "lorem <<bogous1,caption>> ipsum <<foo,bla\nbli>> dolor <<bogous2>>")
      (re-search-backward "bli")
      (expect (adoc-xref-id-at-point) :to-equal "foo"))))

;;; adoc-mode-navigation-test.el ends here
