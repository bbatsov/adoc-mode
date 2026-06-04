;;; adoc-mode-asciidoctor-test.el --- Asciidoctor integration tests -*- lexical-binding: t; -*-

;; Copyright © 2026 Bozhidar Batsov

;;; Commentary:

;; Buttercup tests for the Asciidoctor integration layer: the executable
;; guard, export command-line construction, preview backend resolution, and
;; the compilation error regexp that makes Asciidoctor diagnostics navigable.
;; These tests mock out the actual shelling out, so they need no `asciidoctor'
;; on PATH.

;;; Code:

(require 'adoc-mode-test-helpers)
(require 'adoc-asciidoctor)
(require 'cl-lib)

(describe "adoc--asciidoctor-ensure"
  (it "throws a user-error when the executable is missing"
    (spy-on 'executable-find :and-return-value nil)
    (expect (adoc--asciidoctor-ensure) :to-throw 'user-error))

  (it "returns normally when the executable is found"
    (spy-on 'executable-find :and-return-value "/usr/bin/asciidoctor")
    (expect (adoc--asciidoctor-ensure) :not :to-throw)))

(describe "adoc--asciidoctor-source-file"
  (it "throws a user-error for a non-file buffer"
    (with-temp-buffer
      (expect (adoc--asciidoctor-source-file) :to-throw 'user-error))))

(describe "adoc-export commands"
  (before-each
    (spy-on 'executable-find :and-return-value "/usr/bin/asciidoctor")
    (spy-on 'compilation-start))

  (cl-flet ((command-for (export-fn)
              ;; Visit a real temp file so `adoc--asciidoctor-compile' has a
              ;; file to operate on, run the export, and return the command
              ;; string handed to `compilation-start'.
              (let ((file (make-temp-file "adoc-export-" nil ".adoc")))
                (unwind-protect
                    (with-current-buffer (find-file-noselect file)
                      (funcall export-fn)
                      (spy-calls-most-recent 'compilation-start))
                  (when (get-file-buffer file)
                    (kill-buffer (get-file-buffer file)))
                  (delete-file file)))))

    (it "builds an HTML5 command"
      (let ((args (spy-context-args (command-for #'adoc-export-html))))
        (expect (car args) :to-match "asciidoctor")
        (expect (car args) :to-match "-b html5")))

    (it "builds a DocBook command"
      (let ((args (spy-context-args (command-for #'adoc-export-docbook))))
        (expect (car args) :to-match "-b docbook5")))

    (it "builds a PDF command requiring asciidoctor-pdf"
      (let ((args (spy-context-args (command-for #'adoc-export-pdf))))
        (expect (car args) :to-match "-r asciidoctor-pdf")
        (expect (car args) :to-match "-b pdf")))

    (it "builds an EPUB3 command requiring asciidoctor-epub3"
      (let ((args (spy-context-args (command-for #'adoc-export-epub))))
        (expect (car args) :to-match "-r asciidoctor-epub3")
        (expect (car args) :to-match "-b epub3")))))

(describe "adoc--preview-resolve-backend"
  (it "passes explicit backends through unchanged"
    (dolist (backend '(xwidget eww browser))
      (let ((adoc-preview-backend backend))
        (expect (adoc--preview-resolve-backend) :to-be backend))))

  (it "auto resolves to eww on a terminal"
    (let ((adoc-preview-backend 'auto))
      (spy-on 'display-graphic-p :and-return-value nil)
      (expect (adoc--preview-resolve-backend) :to-be 'eww)))

  (it "auto resolves to xwidget when graphical with xwidget support"
    (let ((adoc-preview-backend 'auto))
      (spy-on 'display-graphic-p :and-return-value t)
      (cl-letf (((symbol-function 'xwidget-webkit-browse-url) #'ignore))
        (expect (adoc--preview-resolve-backend) :to-be 'xwidget)))))

(describe "adoc--preview-update"
  (it "displays the rendered file on success"
    (spy-on 'adoc--asciidoctor-render-preview :and-return-value "/tmp/x.html")
    (spy-on 'adoc--preview-display)
    (adoc--preview-update)
    (expect 'adoc--preview-display :to-have-been-called-with "/tmp/x.html"))

  (it "does not display anything when the render fails"
    (spy-on 'adoc--asciidoctor-render-preview :and-return-value nil)
    (spy-on 'adoc--preview-display)
    (adoc--preview-update)
    (expect 'adoc--preview-display :not :to-have-been-called)))

(describe "the asciidoc compilation regexp"
  ;; The entry is registered in `compilation-error-regexp-alist-alist' by
  ;; `adoc-mode', so spin up an adoc buffer to populate it.
  (let (re)
    (before-all
      (with-adoc-buffer "= Title\n"
        (setq re (car (alist-get 'asciidoc compilation-error-regexp-alist-alist)))))

    (it "matches modern Asciidoctor errors"
      (let ((line "asciidoctor: ERROR: doc.adoc: line 5: include file not found"))
        (expect (string-match re line) :to-be 0)
        (expect (match-string 2 line) :to-equal "doc.adoc")
        (expect (match-string 3 line) :to-equal "5")))

    (it "matches modern Asciidoctor warnings"
      (let ((line "asciidoctor: WARNING: doc.adoc: line 1: unterminated table block"))
        (expect (string-match re line) :to-be 0)
        (expect (match-string 2 line) :to-equal "doc.adoc")
        (expect (match-string 3 line) :to-equal "1")))

    (it "still matches the legacy Python asciidoc format"
      (let ((line "asciidoc: WARNING: doc.txt: line 9: missing"))
        (expect (string-match re line) :to-be 0)
        (expect (match-string 2 line) :to-equal "doc.txt")
        (expect (match-string 3 line) :to-equal "9")))))

(provide 'adoc-mode-asciidoctor-test)

;;; adoc-mode-asciidoctor-test.el ends here
