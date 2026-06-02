;;; adoc-mode-smoke-test.el --- Font-lock smoke test for adoc-mode -*- lexical-binding: t; -*-

;; Copyright © 2025-2026 Bozhidar Batsov

;;; Commentary:

;; A smoke test that fontifies a large, construct-dense real-world-style
;; document (test/resources/sample.adoc) and checks that adoc-mode handles
;; it without error, produces a stable (idempotent) fontification, and
;; actually applies the expected faces.  This guards against regressions
;; that only show up on complex documents (runaway multiline state,
;; under-fontification, errors in keyword matchers).

;;; Code:

(require 'adoc-mode-test-helpers)

(describe "adoc-mode font-lock smoke test"

  (defun adoc-test--sample-buffer ()
    "Return a fontified `adoc-mode' buffer with the sample document."
    (let ((buf (generate-new-buffer " *adoc-sample*")))
      (with-current-buffer buf
        (insert-file-contents (adoc-test-resource "sample.adoc"))
        (adoc-mode)
        (font-lock-ensure))
      buf))

  (it "fontifies the whole sample document without error"
    (let ((buf (adoc-test--sample-buffer)))
      (unwind-protect
          (with-current-buffer buf
            ;; re-fontifying an already-fontified buffer must not error either
            (expect (font-lock-ensure) :not :to-throw)
            (expect (> (point-max) 1000) :to-be-truthy))
        (kill-buffer buf))))

  (it "produces a stable (idempotent) fontification"
    (let ((buf (adoc-test--sample-buffer)))
      (unwind-protect
          (with-current-buffer buf
            (cl-flet ((face-vector ()
                        (let (acc (pos (point-min)))
                          (while (< pos (point-max))
                            (push (get-text-property pos 'face) acc)
                            (setq pos (1+ pos)))
                          (nreverse acc))))
              (let ((faces-before (face-vector)))
                (font-lock-flush)
                (font-lock-ensure)
                (expect (face-vector) :to-equal faces-before))))
        (kill-buffer buf))))

  (it "applies the expected faces across the document"
    (let ((buf (adoc-test--sample-buffer)))
      (unwind-protect
          (with-current-buffer buf
            (let ((faces (adoc-test-buffer-faces)))
              ;; structural + inline + block + macro faces should all appear
              (dolist (expected '(adoc-title-0-face
                                  adoc-title-1-face
                                  adoc-bold-face
                                  adoc-emphasis-face
                                  adoc-highlight-face
                                  adoc-list-face
                                  adoc-checkbox-face
                                  adoc-table-face
                                  adoc-anchor-face
                                  adoc-complex-replacement-face
                                  adoc-metadata-key-face
                                  adoc-command-face
                                  adoc-comment-face))
                (expect (member expected (mapcar (lambda (f) (if (listp f) (car f) f))
                                                 faces))
                        :to-be-truthy))
              ;; native code-block fontification should be present (ruby/shell)
              (expect (seq-find (lambda (f) (and (listp f) (memq 'adoc-native-code-face f)))
                                faces)
                      :not :to-be nil)))
        (kill-buffer buf)))))

;;; adoc-mode-smoke-test.el ends here
