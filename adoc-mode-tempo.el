;;; adoc-mode-tempo.el --- Tempo templates for adoc-mode -*- lexical-binding: t; -*-
;;
;; Copyright 2009-2016 Florian Kaufmann <sensorflo@gmail.com>
;; Copyright 2022-2026 Bozhidar Batsov <bozhidar@batsov.dev> and adoc-mode contributors
;;
;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:

;; Tempo template definitions and handlers for adoc-mode.

;;; Code:

(require 'tempo)

;; Defined in adoc-mode.el; declarations without initial values
;; silence the byte-compiler without interfering with defcustom/defconst.
(defvar adoc-title-style)
(defvar adoc-help-emphasis)
(defvar adoc-help-bold)
(defvar adoc-help-monospace)
(defvar adoc-help-single-quote)
(defvar adoc-help-double-quote)
(defvar adoc-help-attributed)
(defvar adoc-help-underline)
(defvar adoc-help-overline)
(defvar adoc-help-line-through)
(defvar adoc-help-nobreak)
(defvar adoc-help-nowrap)
(defvar adoc-help-pre-wrap)
(defvar adoc-help-line-break)
(defvar adoc-help-page-break)
(defvar adoc-help-ruler-line)
(defvar adoc-help-entity-reference)
(defvar adoc-help-literal-paragraph)
(defvar adoc-help-delimited-block-comment)
(defvar adoc-help-delimited-block-passthrouh)
(defvar adoc-help-delimited-block-listing)
(defvar adoc-help-delimited-block-literal)
(defvar adoc-help-delimited-block-quote)
(defvar adoc-help-delimited-block-example)
(defvar adoc-help-delimited-block-sidebar)
(defvar adoc-help-delimited-block-open-block)
(defvar adoc-help-list-item-continuation)
(defvar adoc-help-url)
(defvar adoc-help-anchor)
(defvar adoc-help-xref)
(defvar adoc-help-pass)
(defvar adoc-help-asciimath)
(defvar adoc-help-latexmath)
(defvar adoc-help-pass-+++)
(defvar adoc-help-pass-$$)

(declare-function adoc-make-two-line-title-underline "adoc-mode")
(declare-function adoc-insert-indented "adoc-mode")

(defcustom adoc-tempo-frwk 'tempo-vanilla
  "Tempo framework to be used by adoc's templates. "
  :type '(choice (const :tag "tempo" tempo-vanilla)
                 (const :tag "tempo-snippets" tempo-snippets))
  :group 'adoc)

;;;; tempos
;; TODO: tell user to make use of tempo-interactive
;; TODO: tell user to how to use tempo-snippets?? that there are clear methods
;; TODO: tell user to how to use tempo-snippets?? suggested customizations working best with adoc
;; TODO: after changing adoc-tempo-frwk, all adoc-tempo-define need to be
;;       evaluated again. This doesn't feel right
;; TODO: titles,block titles,blockid,... should start on a new line
;; PROBLEM: snippets don't allow empty 'field', e.g. empty caption
;;       Workaround: mark whole 'edit-field' and delete it
(if (eq adoc-tempo-frwk 'tempo-snippets)
    (require 'tempo-snippets)
  (require 'tempo))

(defun adoc-tempo-insert-template-fix (orig-fn template on-region)
  "Work around `tempo-insert-template' failing when ON-REGION is
non-nil but no mark is set.  When `tempo-insert-region' is nil,
`tempo-define-template' passes the raw prefix arg as ON-REGION,
which can be truthy even without an active region."
  (funcall orig-fn template (and on-region (mark t) on-region)))

(advice-add 'tempo-insert-template :around #'adoc-tempo-insert-template-fix)

(defun adoc-tempo-define (&rest args)
  (if (eq adoc-tempo-frwk 'tempo-snippets)
      (apply 'tempo-define-snippet args) ;; optional package, not always available
    (apply #'tempo-define-template args)))

(defun adoc-template-str-title (&optional level title-text)
  "Returns the string tempo-template-adoc-title-x would insert"
  (with-temp-buffer
    (insert (or title-text "foo"))
    (set-mark (point-min))
    (funcall (intern-soft (concat "tempo-template-adoc-title-" (number-to-string (1+ (or level 0))))))
    (replace-regexp-in-string "\n" "\\\\n"
                              (buffer-substring-no-properties (point-min) (point-max)))))

;; Text formatting - constrained quotes
(adoc-tempo-define "adoc-emphasis" '("_" (r "text" text) "_") nil (bound-and-true-p adoc-help-emphasis))
(adoc-tempo-define "adoc-bold" '("*" (r "text" text) "*") nil (bound-and-true-p adoc-help-bold))
(adoc-tempo-define "adoc-typewriter-face" '("+" (r "text" text) "+") nil (bound-and-true-p adoc-help-monospace))
(adoc-tempo-define "adoc-monospace-literal" '("`" (r "text" text) "`"))
(adoc-tempo-define "adoc-single-quote" '("`" (r "text" text) "'") nil (bound-and-true-p adoc-help-single-quote))
(adoc-tempo-define "adoc-double-quote" '("``" (r "text" text) "''") nil (bound-and-true-p adoc-help-double-quote))
(adoc-tempo-define "adoc-attributed" '("[" p "]#" (r "text" text) "#") nil (bound-and-true-p adoc-help-attributed))
(adoc-tempo-define "adoc-underline" '("[.underline]#" (r "text" text) "#") nil (bound-and-true-p adoc-help-underline))
(adoc-tempo-define "adoc-overline" '("[.overline]#" (r "text" text) "#") nil (bound-and-true-p adoc-help-overline))
(adoc-tempo-define "adoc-line-through" '("[.line-through]#" (r "text" text) "#") nil (bound-and-true-p adoc-help-line-through))
(adoc-tempo-define "adoc-nobreak" '("[.nobreak]#" (r "text" text) "#") nil (bound-and-true-p adoc-help-nobreak))
(adoc-tempo-define "adoc-nowrap" '("[.nowrap]#" (r "text" text) "#") nil (bound-and-true-p adoc-help-nowrap))
(adoc-tempo-define "adoc-pre-wrap" '("[.pre-wrap]#" (r "text" text) "#") nil (bound-and-true-p adoc-help-pre-wrap))

;; Text formatting - unconstrained quotes
(adoc-tempo-define "adoc-emphasis-uc" '("__" (r "text" text) "__") nil (bound-and-true-p adoc-help-emphasis))
(adoc-tempo-define "adoc-bold-uc" '("**" (r "text" text) "**") nil (bound-and-true-p adoc-help-bold))
(adoc-tempo-define "adoc-monospace-uc" '("++" (r "text" text) "++") nil (bound-and-true-p adoc-help-monospace))
(adoc-tempo-define "adoc-attributed-uc" '("[" p "]##" (r "text" text) "##") nil (bound-and-true-p adoc-help-attributed))
(adoc-tempo-define "adoc-superscript" '("^" (r "text" text) "^"))
(adoc-tempo-define "adoc-subscript" '("~" (r "text" text) "~"))

;; Text formatting - misc
(adoc-tempo-define "adoc-line-break" '((if (eq (char-before) ?\s) "" " ") "+" %) nil (bound-and-true-p adoc-help-line-break))
(adoc-tempo-define "adoc-page-break" '(bol "<<<" %) nil (bound-and-true-p adoc-help-page-break))
(adoc-tempo-define "adoc-ruler-line" '(bol "---" %) nil (bound-and-true-p adoc-help-ruler-line))

;; Text formatting - replacements
(adoc-tempo-define "adoc-copyright" '("(C)"))
(adoc-tempo-define "adoc-trademark" '("(T)"))
(adoc-tempo-define "adoc-registered-trademark" '("(R)"))
(adoc-tempo-define "adoc-dash" '("---"))
(adoc-tempo-define "adoc-ellipsis" '("..."))
(adoc-tempo-define "adoc-right-arrow" '("->"))
(adoc-tempo-define "adoc-left-arrow" '("<-"))
(adoc-tempo-define "adoc-right-double-arrow" '("=>"))
(adoc-tempo-define "adoc-left-double-arrow" '("<="))
(adoc-tempo-define "adoc-entity-reference" '("&" r ";") nil (bound-and-true-p adoc-help-entity-reference))

;; Titles
;; todo
;; - merge with adoc-make-title
;; - dwim:
;;   - when point is on a text line, convert that line to a title
;;   - when it is already a title .... correct underlines?
;;   - ensure n blank lines before and m blank lines after title, or unchanged if n/m nil
(dotimes (level 5) ; level starting at 0
  (let ((one-line-del (make-string (1+ level) ?\=)))

    (adoc-tempo-define
     (concat "adoc-title-" (number-to-string (1+ level)))
     ;; see adoc-tempo-handler for what the (tr ...) does.
     (list
      `(cond
        ((eq adoc-title-style 'adoc-title-style-one-line)
         '(tr bol ,one-line-del " " (r "text" text)))
        ((eq adoc-title-style 'adoc-title-style-one-line-enclosed)
         '(tr bol ,one-line-del " " (r "text" text) " " ,one-line-del))
        ;; BUG in tempo: when first thing is a tempo element which introduces a marker, that
        ;; marker is skipped
        ((eq adoc-title-style 'adoc-title-style-two-line)
         '(tr bol (r "text" text) "\n"
              (adoc-make-two-line-title-underline ,level (if (adoc-tempo-on-region) (- tempo-region-stop tempo-region-start)))))
        (t
         (error "Unknown title style"))))
     nil
     (concat
      "Inserts a level " (number-to-string (1+ level)) " (starting at 1) title.
Is influenced by customization variables such as `adoc-title-style'."))))

(adoc-tempo-define "adoc-block-title" '(bol "." (r "text" text) %))

;; Paragraphs
(adoc-tempo-define "adoc-literal-paragraph" '(bol "  " (r "text" text) %) nil (bound-and-true-p adoc-help-literal-paragraph))
(adoc-tempo-define "adoc-paragraph-tip" '(bol "TIP: " (r "text" text) %))
(adoc-tempo-define "adoc-paragraph-note" '(bol "NOTE: " (r "text" text) %))
(adoc-tempo-define "adoc-paragraph-important" '(bol "IMPORTANT: " (r "text" text) %))
(adoc-tempo-define "adoc-paragraph-warning" '(bol "WARNING: " (r "text" text) %))
(adoc-tempo-define "adoc-paragraph-caution" '(bol "CAUTION: " (r "text" text) %))

;; delimited blocks
(adoc-tempo-define "adoc-delimited-block-comment"
                   '(bol (make-string 50 ?/) n (r-or-n "text" text) bol (make-string 50 ?/) %)
                   nil (bound-and-true-p adoc-help-delimited-block-comment))
(adoc-tempo-define "adoc-delimited-block-passthrough"
                   '(bol (make-string 50 ?+) n (r-or-n "text" text) bol (make-string 50 ?+) %)
                   nil (bound-and-true-p adoc-help-delimited-block-passthrouh))
(adoc-tempo-define "adoc-delimited-block-listing"
                   '(bol (make-string 50 ?-) n (r-or-n "text" text) bol (make-string 50 ?-) %)
                   nil (bound-and-true-p adoc-help-delimited-block-listing))
(adoc-tempo-define "adoc-delimited-block-literal"
                   '(bol (make-string 50 ?.) n (r-or-n "text" text) bol (make-string 50 ?.) %)
                   nil (bound-and-true-p adoc-help-delimited-block-literal))
(adoc-tempo-define "adoc-delimited-block-quote"
                   '(bol (make-string 50 ?_) n (r-or-n "text" text) bol (make-string 50 ?_) %)
                   nil (bound-and-true-p adoc-help-delimited-block-quote))
(adoc-tempo-define "adoc-delimited-block-example"
                   '(bol (make-string 50 ?=) n (r-or-n "text" text) bol (make-string 50 ?=) %)
                   nil (bound-and-true-p adoc-help-delimited-block-example))
(adoc-tempo-define "adoc-delimited-block-sidebar"
                   '(bol (make-string 50 ?*) n (r-or-n "text" text) bol (make-string 50 ?*) %)
                   nil (bound-and-true-p adoc-help-delimited-block-sidebar))
(adoc-tempo-define "adoc-delimited-block-open-block"
                   '(bol "--" n (r-or-n "text" text) bol "--" %)
                   nil (bound-and-true-p adoc-help-delimited-block-open-block))

;; Lists
;; TODO: customize indentation
(adoc-tempo-define "adoc-bulleted-list-item-1" '(bol (adoc-insert-indented "- " 1) (r "text" text)))
(adoc-tempo-define "adoc-bulleted-list-item-2" '(bol (adoc-insert-indented "** " 2) (r "text" text)))
(adoc-tempo-define "adoc-bulleted-list-item-3" '(bol (adoc-insert-indented "*** " 3) (r "text" text)))
(adoc-tempo-define "adoc-bulleted-list-item-4" '(bol (adoc-insert-indented "**** " 4) (r "text" text)))
(adoc-tempo-define "adoc-bulleted-list-item-5" '(bol (adoc-insert-indented "***** " 5) (r "text" text)))
(adoc-tempo-define "adoc-numbered-list-item" '(bol (p "number" number) ". " (r "text" text)))
(adoc-tempo-define "adoc-numbered-list-item-roman" '(bol (p "number" number) ") " (r "text" text)))
(adoc-tempo-define "adoc-implicit-numbered-list-item-1" '(bol (adoc-insert-indented ". " 1) (r "text" text)))
(adoc-tempo-define "adoc-implicit-numbered-list-item-2" '(bol (adoc-insert-indented ".. " 2) (r "text" text)))
(adoc-tempo-define "adoc-implicit-numbered-list-item-3" '(bol (adoc-insert-indented "... " 3) (r "text" text)))
(adoc-tempo-define "adoc-implicit-numbered-list-item-4" '(bol (adoc-insert-indented ".... " 4) (r "text" text)))
(adoc-tempo-define "adoc-implicit-numbered-list-item-5" '(bol (adoc-insert-indented "..... " 5) (r "text" text)))
(adoc-tempo-define "adoc-labeled-list-item" '(bol (p "label" label) ":: " (r "text" text)))
(adoc-tempo-define "adoc-list-item-continuation" '(bol "+" %) nil (bound-and-true-p adoc-help-list-item-continuation))

;; tables
(adoc-tempo-define "adoc-example-table"
                   '(bol "|====================\n"
                         "| cell 11 | cell 12\n"
                         "| cell 21 | cell 22\n"
                         "|====================\n" % ))

;; Macros (inline & block)
(adoc-tempo-define "adoc-url" '("http://foo.com") nil (bound-and-true-p adoc-help-url))
(adoc-tempo-define "adoc-url-caption" '("http://foo.com[" (r "caption" caption) "]") nil (bound-and-true-p adoc-help-url))
(adoc-tempo-define "adoc-email" '("bob@foo.com") nil (bound-and-true-p adoc-help-url))
(adoc-tempo-define "adoc-email-caption" '("mailto:" (p "address" address) "[" (r "caption" caption) "]") nil (bound-and-true-p adoc-help-url))
(adoc-tempo-define "adoc-anchor" '("[[" (r "id" id) "]]") nil (bound-and-true-p adoc-help-anchor))
(adoc-tempo-define "adoc-anchor-default-syntax" '("anchor:" (r "id" id) "[" (p "xreflabel" xreflabel) "]") nil (bound-and-true-p adoc-help-anchor))
(adoc-tempo-define "adoc-xref" '("<<" (p "id" id) "," (r "caption" caption) ">>") nil (bound-and-true-p adoc-help-xref))
(adoc-tempo-define "adoc-xref-default-syntax" '("xref:" (p "id" id) "[" (r "caption" caption) "]") nil (bound-and-true-p adoc-help-xref))
(adoc-tempo-define "adoc-image" '("image:" (r "target-path" target-path) "[" (p "caption" caption) "]"))

;; Passthrough
(adoc-tempo-define "adoc-pass" '("pass:[" (r "text" text) "]") nil (bound-and-true-p adoc-help-pass))
(adoc-tempo-define "adoc-asciimath" '("asciimath:[" (r "text" text) "]") nil (bound-and-true-p adoc-help-asciimath))
(adoc-tempo-define "adoc-latexmath" '("latexmath:[" (r "text" text) "]") nil (bound-and-true-p adoc-help-latexmath))
(adoc-tempo-define "adoc-pass-+++" '("+++" (r "text" text) "+++") nil (bound-and-true-p adoc-help-pass-+++))
(adoc-tempo-define "adoc-pass-$$" '("$$" (r "text" text) "$$") nil (bound-and-true-p adoc-help-pass-$$))
                                        ; backticks handled in tempo-template-adoc-monospace-literal

;;;; tempo handlers

(defun adoc-tempo-handler (element)
  "Tempo user element handler, see `tempo-user-elements'."
  (let ((on-region (adoc-tempo-on-region)))
    (cond

     ;; tr / tempo-recurse : tempo-insert the remaining args of the list
     ((and (listp element)
           (memq (car element) '(tr tempo-recurse)))
      (mapc (lambda (elt) (tempo-insert elt on-region)) (cdr element))
      "")

     ;; bol: ensure point is at the beginning of a line by inserting a newline if needed
     ((eq element 'bol)
      (if (bolp) "" "\n"))

     ;; r-or-n
     ((eq element 'r-or-n)
      (if on-region 'r '(tr p n)))
     ;; (r-or-n ...)
     ((and (consp element)
           (eq (car element) 'r-or-n))
      (if on-region (cons 'r (cdr element)) '(tr p n))))))

(add-to-list 'tempo-user-elements 'adoc-tempo-handler)

(defun adoc-tempo-on-region ()
  "Guesses the on-region argument `tempo-insert' is given.

Is a workaround the problem that tempo's user handlers don't get
passed the on-region argument."
  (let* (;; try to determine the arg with which the tempo-template-xxx was
         ;; called that eventually brought us here. If we came here not by an
         ;; interactive call to tempo-template-xxx we can't have a clue - assume
         ;; nil.
         (arg (if (string-match "^tempo-template-" (symbol-name this-command))
                  current-prefix-arg
                nil))
         ;; copy from tempo-define-template
         (on-region (if tempo-insert-region
                        (not arg)
                      arg)))
    (when (region-active-p)
      (setq on-region t))
    on-region))

(provide 'adoc-mode-tempo)

;; Local Variables:
;; indent-tabs-mode: nil
;; coding: utf-8
;; End:
;;; adoc-mode-tempo.el ends here
