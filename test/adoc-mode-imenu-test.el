;;; adoc-mode-imenu-test.el --- imenu tests for adoc-mode -*- lexical-binding: t; -*-

;; Copyright © 2025-2026 Bozhidar Batsov

;;; Commentary:

;; Buttercup tests for the flat and nested imenu indexes.

;;; Code:

(require 'adoc-mode-test-helpers)

(describe "adoc-mode imenu"

  (it "builds a flat index, ignoring non-title content"
    (with-temp-buffer
      (adoc-mode)
      ;; The `==' lines inside the example and source blocks must not be
      ;; picked up as titles.
      (insert "= document title\n"
              "== chapter 1\n"
              "[IMPORTANT]\n"
              ".Important announcement\n"
              "====\n"
              "== this should not be a title\n"
              "====\n"
              "=== sub chapter 1.1\n"
              "[source,rust]\n"
              "----\n"
              "// here is a comment\n"
              "----\n"
              "== chapter 2\n"
              "=== sub chapter 2.1\n")
      (expect (adoc-imenu-create-index)
              :to-equal
              (list (cons "document title" 1)
                    (cons "chapter 1" 18)
                    (cons "sub chapter 1.1" 107)
                    (cons "chapter 2" 172)
                    (cons "sub chapter 2.1" 185)))))

  (it "indexes two-line titles only when they are enabled"
    (with-temp-buffer
      (adoc-mode)
      (insert "= One-line Doc\n\nintro\n\nTwo Line\n========\n\nbody\n")
      ;; Off by default: the setext title is not fontified, so not indexed.
      (expect (adoc-imenu-create-index)
              :to-equal (list (cons "One-line Doc" 1)))
      (setq-local adoc-enable-two-line-title t)
      (expect (adoc-imenu-create-index)
              :to-equal (list (cons "One-line Doc" 1)
                              (cons "Two Line" 24)))))

  (it "builds a nested index reflecting the heading hierarchy"
    (with-temp-buffer
      (adoc-mode)
      (insert "= document title\n"
              "== chapter 1\n"
              "=== sub chapter 1.1\n"
              "== chapter 2\n"
              "=== sub chapter 2.1\n"
              "=== sub chapter 2.2\n")
      (expect (adoc-imenu-create-nested-index)
              :to-equal
              '(("document title"
                 (nil . 1)
                 ("chapter 1"
                  (nil . 18)
                  ("sub chapter 1.1" . 31))
                 ("chapter 2"
                  (nil . 51)
                  ("sub chapter 2.1" . 64)
                  ("sub chapter 2.2" . 84))))))))

;;; adoc-mode-imenu-test.el ends here
