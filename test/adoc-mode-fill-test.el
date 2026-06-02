;;; adoc-mode-fill-test.el --- Filling tests for adoc-mode -*- lexical-binding: t; -*-

;; Copyright © 2025-2026 Bozhidar Batsov

;;; Commentary:

;; Buttercup tests for `adoc-fill-paragraph', which preserves AsciiDoc
;; hard line breaks (a line ending in " +") while still filling ordinary
;; prose and list-item continuations.

;;; Code:

(require 'adoc-mode-test-helpers)

(describe "adoc-mode filling"

  (it "preserves a hard line break"
    (with-temp-buffer
      (adoc-mode)
      (setq fill-column 40)
      (insert "alpha beta gamma +\ndelta epsilon\neta theta iota\n")
      (goto-char (point-min))
      (fill-paragraph)
      (expect (buffer-string) :to-equal
              "alpha beta gamma +\ndelta epsilon eta theta iota\n")))

  (it "joins ordinary soft-wrapped lines"
    (with-temp-buffer
      (adoc-mode)
      (setq fill-column 40)
      (insert "word1 word2 word3\nword4 word5\n")
      (goto-char (point-min))
      (fill-paragraph)
      (expect (buffer-string) :to-equal "word1 word2 word3 word4 word5\n")))

  (it "indents list-item continuations"
    (with-temp-buffer
      (adoc-mode)
      (setq fill-column 40)
      (insert "* long list item that should wrap nicely when filled to a narrow width indeed yes\n")
      (goto-char (point-min))
      (fill-paragraph)
      (expect (buffer-string) :to-equal
              "* long list item that should wrap nicely\n  when filled to a narrow width indeed\n  yes\n")))

  (it "clears a stale hard break so a later refill merges the lines"
    (with-temp-buffer
      (adoc-mode)
      (setq fill-column 30)
      (insert "alpha beta gamma delta epsilon zeta eta theta iota +\nkappa lambda mu nu\n")
      (goto-char (point-min))
      (fill-paragraph)
      (goto-char (point-min))
      (re-search-forward " \\+$")
      (delete-char -2)
      (goto-char (point-min))
      (fill-paragraph)
      (expect (string-match-p "iota +\n" (buffer-string)) :not :to-be-truthy)
      (expect (string-match-p "iota kappa" (buffer-string)) :to-be-truthy))))

;;; adoc-mode-fill-test.el ends here
