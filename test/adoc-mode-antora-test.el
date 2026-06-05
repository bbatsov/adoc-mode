;;; adoc-mode-antora-test.el --- Antora cross-reference tests -*- lexical-binding: t; -*-

;; Copyright © 2026 Bozhidar Batsov

;;; Commentary:

;; Buttercup tests for Antora cross-file xref support: resolving a page xref
;; target to a file within the component, detecting a page xref at point, and
;; following one to the target page (and its `#fragment' section).

;;; Code:

(require 'adoc-mode-test-helpers)

(defun adoc-test--make-antora (files)
  "Create a temp Antora component and return its root.
FILES is an alist of (RELPATH . CONTENT) created under
`modules/ROOT/pages/'."
  (let* ((root (make-temp-file "adoc-antora-" t))
         (pages (expand-file-name "modules/ROOT/pages" root)))
    (make-directory pages t)
    (with-temp-file (expand-file-name "antora.yml" root)
      (insert "name: demo\nversion: ~\n"))
    (dolist (f files)
      (let ((file (expand-file-name (car f) pages)))
        (make-directory (file-name-directory file) t)
        (with-temp-file file (insert (cdr f)))))
    root))

(describe "adoc--antora-resolve-page"
  (it "resolves page targets within the component"
    (let ((root (adoc-test--make-antora '(("a.adoc" . "= A\n")))))
      (unwind-protect
          (with-current-buffer
              (find-file-noselect (expand-file-name "modules/ROOT/pages/a.adoc" root))
            (unwind-protect
                (progn
                  ;; bare path, no fragment
                  (expect (adoc--antora-resolve-page "basics/install.adoc")
                          :to-equal
                          (cons (expand-file-name
                                 "modules/ROOT/pages/basics/install.adoc" root)
                                nil))
                  ;; path + fragment
                  (expect (cdr (adoc--antora-resolve-page "p.adoc#frag"))
                          :to-equal "frag")
                  ;; module: prefix selects another module
                  (expect (car (adoc--antora-resolve-page "other:p.adoc"))
                          :to-equal
                          (expand-file-name "modules/other/pages/p.adoc" root))
                  ;; version@ before a coordinate is stripped
                  (expect (car (adoc--antora-resolve-page "2.0@other:p.adoc"))
                          :to-equal
                          (expand-file-name "modules/other/pages/p.adoc" root))
                  ;; an `@' in a bare filename is NOT treated as a version
                  (expect (car (adoc--antora-resolve-page "pa@ge.adoc"))
                          :to-equal
                          (expand-file-name "modules/ROOT/pages/pa@ge.adoc" root))
                  ;; an empty fragment counts as none
                  (expect (cdr (adoc--antora-resolve-page "p.adoc#")) :to-be nil)
                  ;; cross-component (component:module:path) is out of scope
                  (expect (adoc--antora-resolve-page "comp:mod:p.adoc") :to-be nil))
              (kill-buffer)))
        (delete-directory root t))))

  (it "returns nil outside an Antora component"
    (with-temp-buffer
      (setq buffer-file-name "/tmp/not-antora.adoc")
      (expect (adoc--antora-resolve-page "p.adoc") :to-be nil))))

(describe "following a .adoc xref outside an Antora component"
  (it "does not hijack the in-buffer xref handling"
    ;; A plain `.adoc' xref in a non-Antora buffer must fall through to the
    ;; in-buffer xref branch (which then can't find the id), not raise the
    ;; Antora \"Cannot resolve\" error.
    (with-temp-buffer
      (setq buffer-file-name "/tmp/plain-not-antora.adoc")
      (adoc-mode)
      (insert "see xref:foo.adoc[x] here")
      (goto-char (point-min))
      (search-forward "foo")
      (let (err)
        (condition-case e (adoc-follow-thing-at-point)
          (user-error (setq err (error-message-string e))))
        (expect err :not :to-match "Antora")))))

(describe "adoc--antora-page-xref-at-point"
  (it "detects a .adoc page xref at point"
    (with-temp-buffer
      (adoc-mode)
      (insert "see xref:sub/target.adoc#sec[label] here")
      (goto-char (point-min))
      (search-forward "target")
      (expect (adoc--antora-page-xref-at-point)
              :to-equal "sub/target.adoc#sec")))

  (it "ignores an in-buffer xref to a plain id"
    (with-temp-buffer
      (adoc-mode)
      (insert "see xref:some-section-id[label] here")
      (goto-char (point-min))
      (search-forward "some")
      (expect (adoc--antora-page-xref-at-point) :to-be nil)))

  (it "returns nil away from any xref"
    (with-temp-buffer
      (adoc-mode)
      (insert "just prose")
      (goto-char (point-min))
      (expect (adoc--antora-page-xref-at-point) :to-be nil))))

(describe "following an Antora page xref"
  (it "opens the target page and jumps to the fragment section"
    (let ((root (adoc-test--make-antora
                 '(("sub/target.adoc" . "= Target\n\n== Deep Section\n\nhi\n")
                   ("src.adoc" . "= Src\n\nSee xref:sub/target.adoc#deep-section[x].\n")))))
      (unwind-protect
          (let ((src (find-file-noselect
                      (expand-file-name "modules/ROOT/pages/src.adoc" root))))
            (unwind-protect
                (with-current-buffer src
                  (goto-char (point-min))
                  (search-forward "xref:")
                  (adoc-follow-thing-at-point)
                  ;; now visiting the target page, point on the fragment heading
                  (expect (file-name-nondirectory (buffer-file-name))
                          :to-equal "target.adoc")
                  (expect (buffer-substring-no-properties
                           (line-beginning-position) (line-end-position))
                          :to-equal "== Deep Section")
                  (kill-buffer))
              (when (buffer-live-p src) (kill-buffer src))))
        (delete-directory root t))))

  (it "errors when the target page does not exist"
    (let ((root (adoc-test--make-antora
                 '(("src.adoc" . "= Src\n\nSee xref:nope.adoc[x].\n")))))
      (unwind-protect
          (with-current-buffer
              (find-file-noselect (expand-file-name "modules/ROOT/pages/src.adoc" root))
            (unwind-protect
                (progn
                  (goto-char (point-min))
                  (search-forward "xref:")
                  (expect (adoc-follow-thing-at-point) :to-throw 'user-error))
              (kill-buffer)))
        (delete-directory root t)))))

(defun adoc-test--antora-capf (root relpath line)
  "Return the capf candidates with point after LINE in component page RELPATH.
LINE is inserted at end of the page (under ROOT's ROOT module) first."
  (let ((file (expand-file-name (concat "modules/ROOT/pages/" relpath) root)))
    (with-current-buffer (find-file-noselect file)
      (unwind-protect
          (progn
            (goto-char (point-max))
            (insert "\n" line)
            (goto-char (point-max))
            (let ((capf (adoc-completion-at-point)))
              (when capf (all-completions "" (nth 2 capf)))))
        (set-buffer-modified-p nil)
        (kill-buffer)))))

(describe "Antora xref completion"
  (it "lists component pages as xref targets, other modules prefixed"
    (let ((root (adoc-test--make-antora
                 '(("src.adoc" . "= Src\n")
                   ("sub/target.adoc" . "= T\n")))))
      (unwind-protect
          (progn
            ;; add a page in another module
            (let ((other (expand-file-name "modules/extra/pages/o.adoc" root)))
              (make-directory (file-name-directory other) t)
              (with-temp-file other (insert "= O\n")))
            (let ((cands (adoc-test--antora-capf root "src.adoc" "see xref:")))
              (expect (member "sub/target.adoc" cands) :to-be-truthy)
              (expect (member "extra:o.adoc" cands) :to-be-truthy)))
        (delete-directory root t))))

  (it "completes #fragments from the target page"
    (let ((root (adoc-test--make-antora
                 '(("src.adoc" . "= Src\n")
                   ("target.adoc" . "= T\n\n== Deep Section\n\n[[explicit]]\nx\n")))))
      (unwind-protect
          (let ((cands (adoc-test--antora-capf
                        root "src.adoc" "see xref:target.adoc#")))
            (expect (member "deep-section" cands) :to-be-truthy) ; section auto-id
            (expect (member "explicit" cands) :to-be-truthy))    ; explicit anchor
        (delete-directory root t))))

  (it "does not offer lock files, dotfiles, or pages in hidden dirs"
    (let ((root (adoc-test--make-antora
                 '(("src.adoc" . "= Src\n")
                   (".hidden/buried.adoc" . "= H\n")))))
      (unwind-protect
          (progn
            ;; simulate an editor lock file next to a page
            (with-temp-file (expand-file-name "modules/ROOT/pages/.#busy.adoc" root)
              (insert "x"))
            (let ((cands (adoc-test--antora-capf root "src.adoc" "see xref:")))
              (expect (cl-find-if (lambda (c) (string-match-p "\\(?:\\`\\|/\\)\\." c))
                                  cands)
                      :to-be nil)))
        (delete-directory root t))))

  (it "completes a same-page #fragment against the current buffer"
    (let ((root (adoc-test--make-antora '(("src.adoc" . "= Src\n")))))
      (unwind-protect
          (let ((cands (adoc-test--antora-capf
                        root "src.adoc"
                        "== Local Bit\n\nsee xref:#")))
            (expect (member "local-bit" cands) :to-be-truthy))
        (delete-directory root t)))))

(provide 'adoc-mode-antora-test)

;;; adoc-mode-antora-test.el ends here
