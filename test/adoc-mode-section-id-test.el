;;; adoc-mode-section-id-test.el --- Section auto-id tests -*- lexical-binding: t; -*-

;; Copyright © 2026 Bozhidar Batsov

;;; Commentary:

;; Buttercup tests for AsciiDoc section auto-ids: the id-generation algorithm
;; (validated against the real `asciidoctor' when available), id-style
;; detection (document attributes / Antora layout / `adoc-section-id-style'),
;; collecting section ids, and resolving them via the xref backend and
;; `adoc-goto-ref-label'.

;;; Code:

(require 'adoc-mode-test-helpers)
(require 'cl-lib)

(describe "adoc--section-id"
  (it "generates Asciidoctor-default (underscore) ids"
    (expect (adoc--section-id "Clojure CLI Setup" "_" "_")
            :to-equal "_clojure_cli_setup")
    (expect (adoc--section-id "Hello, World!" "_" "_") :to-equal "_hello_world")
    (expect (adoc--section-id "Foo & Bar (baz)" "_" "_") :to-equal "_foo_bar_baz")
    (expect (adoc--section-id "Dots.in.title" "_" "_") :to-equal "_dots_in_title")
    (expect (adoc--section-id "1. Numbered start" "_" "_")
            :to-equal "_1_numbered_start")
    (expect (adoc--section-id "snake_case_already" "_" "_")
            :to-equal "_snake_case_already"))

  (it "collapses separator-adjacent runs to a single separator"
    ;; a kept underscore next to a converted space must not double up
    (expect (adoc--section-id "foo_ bar" "_" "_") :to-equal "_foo_bar")
    (expect (adoc--section-id "a_-_b" "_" "_") :to-equal "_a_b"))

  (it "with an empty separator only removes spaces, keeping . and -"
    (expect (adoc--section-id "a.b-c" "" "") :to-equal "a.b-c")
    (expect (adoc--section-id "a b" "" "") :to-equal "ab"))

  (it "generates Antora-style (kebab) ids"
    (expect (adoc--section-id "Clojure CLI Setup" "" "-")
            :to-equal "clojure-cli-setup")
    (expect (adoc--section-id "kebab-already-here" "" "-")
            :to-equal "kebab-already-here")
    (expect (adoc--section-id "snake_case_already" "" "-")
            :to-equal "snake_case_already"))

  (it "matches the real asciidoctor for a range of titles"
    (assume (executable-find "asciidoctor") "asciidoctor not installed")
    (dolist (title '("Clojure CLI Setup" "Hello, World!" "C++ and C#"
                     "Trailing punctuation!!!" "UPPER lower MiXeD"
                     "1. Numbered start" "Dots.in.title"))
      (dolist (style '(("_" . "_") ("" . "-")))
        (let* ((pre (car style)) (sep (cdr style))
               (attrs (format ":idprefix: %s\n:idseparator: %s" pre sep))
               (doc (format "= D\n%s\n\n== %s\n" attrs title))
               (html (with-temp-buffer
                       (insert doc)
                       (call-process-region (point-min) (point-max)
                                            "asciidoctor" nil t nil "-s" "-o" "-" "-")
                       (buffer-string)))
               (real (when (string-match "id=\"\\([^\"]*\\)\"" html)
                       (match-string 1 html))))
          (expect (adoc--section-id title pre sep) :to-equal real))))))

(describe "adoc--section-id-params"
  (it "honours an explicit adoc-section-id-style"
    (let ((adoc-section-id-style 'antora))
      (expect (adoc--section-id-params) :to-equal '("" . "-")))
    (let ((adoc-section-id-style 'asciidoctor))
      (expect (adoc--section-id-params) :to-equal '("_" . "_"))))

  (it "reads :idprefix: / :idseparator: from the document"
    (with-temp-buffer
      (setq buffer-file-name "/tmp/adoc-section-id-fake.adoc")
      (insert ":idprefix:\n:idseparator: -\n\n= D\n")
      (let ((adoc-section-id-style 'auto))
        (expect (adoc--section-id-params) :to-equal '("" . "-")))))

  (it "defaults to the Asciidoctor style outside Antora"
    (with-temp-buffer
      (setq buffer-file-name "/tmp/adoc-section-id-plain.adoc")
      (insert "= D\n\n== A\n")
      (let ((adoc-section-id-style 'auto))
        (expect (adoc--section-id-params) :to-equal '("_" . "_"))))))

(describe "Antora layout detection"
  (it "detects an antora.yml above the file and uses the kebab style"
    (let* ((root (make-temp-file "adoc-antora-" t))
           (pages (expand-file-name "modules/ROOT/pages" root))
           (page (expand-file-name "p.adoc" pages)))
      (unwind-protect
          (progn
            (make-directory pages t)
            (with-temp-file (expand-file-name "antora.yml" root)
              (insert "name: demo\nversion: ~\n"))
            (with-temp-file page (insert "= Page\n\n== My Section\n"))
            (with-current-buffer (find-file-noselect page)
              (unwind-protect
                  (let ((adoc-section-id-style 'auto))
                    (expect (adoc--antora-p) :to-be-truthy)
                    (expect (adoc--section-id-params) :to-equal '("" . "-"))
                    (expect (adoc--collect-section-ids) :to-equal '("my-section")))
                (kill-buffer))))
        (delete-directory root t)))))

(describe "adoc--collect-sections"
  (it "collects section ids, skipping the doctitle and code blocks"
    (with-temp-buffer
      (insert "= Doc Title\n\n"
              "== First Section\n\ntext\n\n"
              "----\n== Not A Heading\n----\n\n"
              "=== Nested One\n")
      (adoc-mode)
      (expect (adoc--collect-section-ids)
              :to-equal '("_first_section" "_nested_one")))))

(describe "section ids as xref targets"
  (it "resolves a section auto-id as an xref definition"
    (with-temp-buffer
      (insert "= Doc\n\n== Clojure CLI Setup\n\ntext\n")
      (adoc-mode)
      (let ((defs (xref-backend-definitions 'adoc "_clojure_cli_setup")))
        (expect (length defs) :to-equal 1)
        (expect (xref-item-summary (car defs)) :to-equal "Clojure CLI Setup"))))

  (it "lets adoc-goto-ref-label jump to a section by its auto-id"
    (with-temp-buffer
      (insert "= Doc\n\n== First\n\ntext\n\n== Second Section\n\nmore\n")
      (adoc-mode)
      (goto-char (point-min))
      (adoc-goto-ref-label "_second_section")
      (expect (line-number-at-pos) :to-equal 7)))

  (it "offers section ids in the xref completion table"
    (with-temp-buffer
      (insert "[[explicit]]\n= Doc\n\n== A Section\n")
      (adoc-mode)
      (let ((table (xref-backend-identifier-completion-table 'adoc)))
        (expect (member "a-section" table) :to-be nil) ; default style is underscore
        (expect (member "_a_section" table) :to-be-truthy)
        (expect (member "explicit" table) :to-be-truthy)))))

(provide 'adoc-mode-section-id-test)

;;; adoc-mode-section-id-test.el ends here
