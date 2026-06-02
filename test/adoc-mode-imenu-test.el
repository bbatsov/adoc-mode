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
      (insert "= document title\n"
              "== chapter 1\n"
              "[IMPORTANT]\n"
              ".Important announcement\n"
              "====\n"
              "This should not be a title\n"
              "====\n"
              "=== sub chapter 1.1\n"
              "[source,rust]\n"
              "----\n"
              "// here is a comment\n"
              "----\n"
              "chapter 2\n"
              "----------\n"
              "[latexmath#einstein]\n"
              "++++\n"
              "\begin{equation}\n"
              "e = mc^{2}\n"
              "\end{equation}\n"
              "++++\n"
              "sub chapter 2.1\n"
              "~~~~~~~~~~~~~~\n")
      (expect (adoc-imenu-create-index)
              :to-equal
              (list (cons "document title" 1)
                    (cons "chapter 1" 18)
                    (cons "sub chapter 1.1" 104)
                    (cons "chapter 2" 169)
                    (cons "sub chapter 2.1" 262)))))

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
