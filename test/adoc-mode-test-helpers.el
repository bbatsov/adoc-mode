;;; adoc-mode-test-helpers.el --- Shared test helpers for adoc-mode -*- lexical-binding: t; -*-

;; Copyright © 2025-2026 Bozhidar Batsov

;;; Commentary:

;; Shared macros and functions used across the adoc-mode buttercup test
;; suites.  Provides buffer setup, font-lock assertion helpers (modelled
;; on neocaml's `when-fontifying-it'), and a buffer-transform helper used
;; by the editing tests.

;;; Code:

(require 'buttercup)
(require 'adoc-mode)
(require 'cl-lib)

;;;; Test resources

(defconst adoc-test-resources-directory
  (expand-file-name
   "resources"
   (file-name-directory (or load-file-name buffer-file-name default-directory)))
  "Absolute path to the test resources directory (test/resources/).")

(defun adoc-test-resource (name)
  "Return the absolute path of resource file NAME under test/resources/."
  (expand-file-name name adoc-test-resources-directory))

(defun adoc-test-buffer-faces ()
  "Return the set of distinct `face' values present in the current buffer."
  (let ((faces '())
        (pos (point-min)))
    (while (< pos (point-max))
      (let ((f (get-text-property pos 'face)))
        (when (and f (not (member f faces)))
          (push f faces)))
      (setq pos (1+ pos)))
    faces))

;;;; String helpers

(defun adoc-test--dedent (string)
  "Remove common leading whitespace from all non-empty lines in STRING.
A single leading newline is stripped (so the string can start on the
line after the opening quote), and a single trailing newline followed
by only whitespace is stripped (so the closing quote can sit on its
own indented line).  Interior blank lines are preserved."
  (if (not (string-search "\n" string))
      string
    (let* ((str (if (string-prefix-p "\n" string)
                    (substring string 1)
                  string))
           (str (if (string-match "\n[ \t]*\\'" str)
                    (substring str 0 (match-beginning 0))
                  str))
           (lines (split-string str "\n"))
           (non-empty (seq-filter (lambda (l) (not (string-blank-p l))) lines))
           (min-indent (if non-empty
                           (apply #'min (mapcar (lambda (l)
                                                  (- (length l) (length (string-trim-left l))))
                                                non-empty))
                         0)))
      (mapconcat (lambda (l)
                   (if (string-blank-p l) ""
                     (substring l min-indent)))
                 lines "\n"))))

;;;; Buffer setup

(defmacro with-adoc-buffer (content &rest body)
  "Set up a temporary buffer with CONTENT in `adoc-mode', run BODY.
CONTENT is dedented via `adoc-test--dedent' and point starts at
`point-min'."
  (declare (indent 1))
  `(with-temp-buffer
     (insert (adoc-test--dedent ,content))
     (adoc-mode)
     (goto-char (point-min))
     ,@body))

;;;; Font-lock helpers

(defun adoc-test--normalise-face (face)
  "Normalise a `face' text property value FACE for comparison.
adoc-mode keywords frequently apply a face with `append', which
yields a single-element list like (adoc-bold-face); unwrap such
lists to the bare symbol so specs can be written plainly.  Multi-element
face lists are returned unchanged."
  (if (and (consp face) (null (cdr face)))
      (car face)
    face))

(defun adoc-test-face-at-range (start end)
  "Return the (normalised) face over the range [START, END].
If every position shares the same face, return it; otherwise
return the symbol `various-faces'."
  (let ((face (adoc-test--normalise-face (get-text-property start 'face))))
    (if (= start end)
        face
      (let ((pos (1+ start))
            (consistent t))
        (while (and consistent (<= pos end))
          (unless (equal (adoc-test--normalise-face (get-text-property pos 'face)) face)
            (setq consistent nil))
          (setq pos (1+ pos)))
        (if consistent face 'various-faces)))))

(defun adoc-test--check-face-specs (content face-specs)
  "Fontify CONTENT in `adoc-mode' and assert FACE-SPECS.
Each element of FACE-SPECS is either:
  (\"text\" EXPECTED-FACE) — search forward for \"text\" and check its face
  (START END EXPECTED-FACE) — check the face over the range [START, END]
EXPECTED-FACE is a face symbol, nil (no face), a face list, or the
symbol `various-faces'."
  (with-temp-buffer
    (insert (adoc-test--dedent content))
    (adoc-mode)
    (font-lock-ensure)
    (goto-char (point-min))
    (dolist (spec face-specs)
      (if (stringp (car spec))
          (let* ((text (nth 0 spec))
                 (expected (nth 1 spec))
                 (case-fold-search nil)
                 (found (if (string-match-p "\\`[a-zA-Z_][a-zA-Z0-9_]*\\'" text)
                            (re-search-forward
                             (concat "\\_<" (regexp-quote text) "\\_>") nil t)
                          (search-forward text nil t))))
            (expect found :not :to-be nil)
            (when found
              (expect (adoc-test-face-at-range (match-beginning 0) (1- (match-end 0)))
                      :to-equal expected)))
        (expect (adoc-test-face-at-range (nth 0 spec) (nth 1 spec))
                :to-equal (nth 2 spec))))))

(defmacro when-fontifying-it (description &rest tests)
  "Create a buttercup test asserting font-lock faces.
DESCRIPTION is the test name.  Each element of TESTS is
  (CODE SPEC ...)
where each SPEC is either (\"text\" FACE) for text-based matching
or (START END FACE) for position-based matching.  CODE is dedented
before fontification."
  (declare (indent 1))
  `(it ,description
     (dolist (test (quote ,tests))
       (adoc-test--check-face-specs (car test) (cdr test)))))

;;;; Buffer-transform helper (editing commands)

;; Ported from the original ERT suite.  ORIGINAL-TEXT may contain markers
;; that are stripped before TRANSFORM runs:
;;   !   position of point
;;   <>  region: mark at `<', point at `>'
;; TRANSFORM is evaluated and the resulting buffer is compared to
;; EXPECTED-TEXT.

(defun adoc-test--trans-1 (original-text expected-text transform &optional pos)
  "Run one transform check.  See `adoc-test-trans' for ORIGINAL-TEXT,
EXPECTED-TEXT, TRANSFORM and POS."
  (let ((font-lock-support-mode))
    (with-temp-buffer
      (adoc-mode)
      (insert original-text)
      (cond
       ((consp pos)
        (goto-char (1+ (car pos)))
        (set-mark (1+ (cdr pos))))
       (pos
        (goto-char (1+ pos))))
      (if (consp pos)
          (let ((this-command (car transform))
                (current-prefix-arg t))
            (funcall (car transform) t))
        (eval transform t))
      (expect (buffer-substring-no-properties (point-min) (point-max))
              :to-equal expected-text))))

(defun adoc-test-trans (original-text expected-text transform)
  "Assert that TRANSFORM turns ORIGINAL-TEXT into EXPECTED-TEXT.
ORIGINAL-TEXT may contain the markers `!' (point) and `<'/`>'
(region); each is stripped and TRANSFORM run once per marker set."
  (if (string-match "[!<>]" original-text)
      (let ((pos 0)
            (pos-old 0)
            (pos-in-new-region-start 0)
            (pos-new-list)
            (new-original-text ""))
        (while (and (< pos (length original-text))
                    (setq pos (string-match "[!<>]" original-text pos)))
          (setq new-original-text (concat new-original-text (substring original-text pos-old pos)))
          (cond
           ((eq (aref original-text pos) ?<)
            (setq pos-in-new-region-start (length new-original-text)))
           ((eq (aref original-text pos) ?>)
            (setq pos-new-list (cons (cons pos-in-new-region-start (length new-original-text)) pos-new-list)))
           (t
            (setq pos-new-list (cons (length new-original-text) pos-new-list))))
          (setq pos (1+ pos))
          (setq pos-old pos))
        (setq new-original-text (concat new-original-text (substring original-text pos-old pos)))
        (while pos-new-list
          (adoc-test--trans-1 new-original-text expected-text transform (car pos-new-list))
          (setq pos-new-list (cdr pos-new-list))))
    (adoc-test--trans-1 original-text expected-text transform)))

;;;; Generic mode for testing native code-block fontification

;; A tiny C-like mode used to verify that source blocks are fontified
;; with the language's own major mode.  Other languages can change their
;; fontification without us noticing; this one is under our control.
(define-generic-mode adoctest-lang-mode
  '(("//" . nil) ("/*" . "*/"))         ; cpp-like comment syntax
  '("if" "else" "for" "while" "do" "break" "continue" "throw" "catch")
  nil nil nil
  "Mode for testing code blocks in `adoc-mode'.
Don't use it for anything real.")

(provide 'adoc-mode-test-helpers)

;;; adoc-mode-test-helpers.el ends here
