;;; adoc-asciidoctor.el --- Asciidoctor integration for adoc-mode -*- lexical-binding: t; -*-
;;
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

;; Preview and export support for `adoc-mode' that shells out to the
;; `asciidoctor' command-line tool.  AsciiDoc, unlike Markdown, needs the real
;; processor to render faithfully (attributes, `include::', conditionals,
;; tables), so we delegate to Asciidoctor rather than approximating in Elisp.
;;
;; The entry point is the `adoc-asciidoctor-menu' transient (bound to
;; `C-c C-c' in `adoc-mode').  From there you can render a preview in an
;; xwidget (falling back to `eww') or export to HTML, DocBook, PDF and EPUB.
;; Export runs through `compile' so Asciidoctor's warnings and errors are
;; navigable.

;;; Code:

(require 'compile)
(require 'flymake)
(require 'subr-x)
(require 'transient)

(declare-function xwidget-webkit-browse-url "xwidget" (url &optional new-session))
(declare-function eww-open-file "eww" (file &optional new-buffer))

;;; Customization

(defgroup adoc-asciidoctor nil
  "Asciidoctor integration for `adoc-mode'."
  :group 'adoc
  :prefix "adoc-")

(defcustom adoc-asciidoctor-command "asciidoctor"
  "Name of, or path to, the Asciidoctor executable."
  :type 'string
  :group 'adoc-asciidoctor)

(defcustom adoc-asciidoctor-extra-args nil
  "Extra command-line arguments passed to every Asciidoctor invocation.
Each element is a separate argument string, for example
\"-a\" followed by \"sectnums\"."
  :type '(repeat string)
  :group 'adoc-asciidoctor)

(defcustom adoc-preview-backend 'auto
  "How `adoc-preview' displays the rendered HTML.
The value is one of the following symbols:

`auto'     Use an xwidget when one is available, otherwise `eww'.
`xwidget'  Render in an embedded WebKit widget (needs xwidget support).
`eww'      Render in Emacs' built-in `eww' browser.
`browser'  Open in the external browser via `browse-url'."
  :type '(choice (const :tag "Auto-detect" auto)
                 (const :tag "Embedded WebKit (xwidget)" xwidget)
                 (const :tag "Emacs Web Wowser (eww)" eww)
                 (const :tag "External browser" browser))
  :group 'adoc-asciidoctor)

;;; Running Asciidoctor

(defun adoc--asciidoctor-ensure ()
  "Signal a `user-error' unless the Asciidoctor executable is available."
  (unless (executable-find adoc-asciidoctor-command)
    (user-error "Cannot find the Asciidoctor executable %S; \
customize `adoc-asciidoctor-command'" adoc-asciidoctor-command)))

(defun adoc--asciidoctor-source-file ()
  "Return the file the current buffer visits, or signal a `user-error'."
  (or buffer-file-name
      (user-error "Current buffer is not visiting a file")))

(defvar-local adoc--preview-file nil
  "Absolute path to the current buffer's temporary preview HTML file.")

(defun adoc--asciidoctor-render-preview ()
  "Render the current buffer to its preview HTML file.
Return the file on success, or nil on failure (so callers can avoid
displaying a blank or stale page).  The buffer contents are piped
through Asciidoctor's standard input, so unsaved edits are included and
no save is required.  The base directory and the output file both live
in `default-directory', which keeps relative `include::' and image paths
resolving correctly when the generated HTML is loaded over `file://'.

Asciidoctor exits 0 even on a recoverable ERROR when reading from
standard input, so any diagnostics on its error output are reported
regardless of the exit status."
  (adoc--asciidoctor-ensure)
  (let ((base (expand-file-name default-directory))
        (errfile (make-temp-file "adoc-asciidoctor-err")))
    (unless (and adoc--preview-file (file-exists-p adoc--preview-file))
      (setq adoc--preview-file
            (make-temp-file (expand-file-name "adoc-preview-" base) nil ".html")))
    (unwind-protect
        (let ((status (apply #'call-process-region
                             (point-min) (point-max)
                             adoc-asciidoctor-command nil
                             (list nil errfile) nil
                             (append adoc-asciidoctor-extra-args
                                     (list "-B" base
                                           "-b" "html5"
                                           "-o" adoc--preview-file
                                           "-"))))
              (errors (with-temp-buffer
                        (insert-file-contents errfile)
                        (string-trim (buffer-string)))))
          (unless (string-empty-p errors)
            (message "Asciidoctor: %s" errors))
          ;; Only hand back the file when the run actually succeeded; a
          ;; non-zero exit may leave the output empty or untouched.
          (and (integerp status) (zerop status) adoc--preview-file))
      (delete-file errfile))))

(defun adoc--asciidoctor-compile (backend-args)
  "Run Asciidoctor on the current file with BACKEND-ARGS through `compile'.
The buffer is saved first when modified so the on-disk file is current.
Asciidoctor is invoked with the file's base name from its own directory,
so the locations it reports resolve against `default-directory' in the
compilation buffer."
  (adoc--asciidoctor-ensure)
  (let ((file (adoc--asciidoctor-source-file)))
    (when (buffer-modified-p)
      (save-buffer))
    (let* ((default-directory (file-name-directory file))
           (command (mapconcat
                     #'shell-quote-argument
                     (append (list adoc-asciidoctor-command)
                             adoc-asciidoctor-extra-args
                             backend-args
                             (list (file-name-nondirectory file)))
                     " ")))
      (compilation-start
       command nil
       (lambda (_mode)
         (format "*asciidoctor: %s*" (file-name-nondirectory file)))))))

;;; Export commands

;;;###autoload
(defun adoc-export-html ()
  "Export the current AsciiDoc buffer to HTML5."
  (interactive)
  (adoc--asciidoctor-compile '("-b" "html5")))

;;;###autoload
(defun adoc-export-docbook ()
  "Export the current AsciiDoc buffer to DocBook 5."
  (interactive)
  (adoc--asciidoctor-compile '("-b" "docbook5")))

;;;###autoload
(defun adoc-export-pdf ()
  "Export the current AsciiDoc buffer to PDF.
Requires the `asciidoctor-pdf' converter to be installed."
  (interactive)
  (adoc--asciidoctor-compile '("-r" "asciidoctor-pdf" "-b" "pdf")))

;;;###autoload
(defun adoc-export-epub ()
  "Export the current AsciiDoc buffer to EPUB3.
Requires the `asciidoctor-epub3' converter to be installed."
  (interactive)
  (adoc--asciidoctor-compile '("-r" "asciidoctor-epub3" "-b" "epub3")))

;;; Preview

(defun adoc--preview-resolve-backend ()
  "Resolve `adoc-preview-backend' to a concrete backend symbol."
  (if (eq adoc-preview-backend 'auto)
      (if (and (display-graphic-p)
               (fboundp 'xwidget-webkit-browse-url))
          'xwidget
        'eww)
    adoc-preview-backend))

(defun adoc--preview-display (file)
  "Display preview FILE according to the resolved backend.
Focus stays in the source buffer so the viewer acts as a side pane."
  (let ((url (concat "file://" file))
        (backend (adoc--preview-resolve-backend)))
    (pcase backend
      ('browser (browse-url url))
      ('xwidget
       (save-selected-window
         (xwidget-webkit-browse-url url))
       (when-let* ((buf (get-buffer "*xwidget-webkit*")))
         (display-buffer-in-side-window
          buf '((side . right) (window-width . 0.5)))))
      ('eww
       (require 'eww)
       (save-window-excursion
         (eww-open-file file))
       (when-let* ((buf (get-buffer "*eww*")))
         (display-buffer-in-side-window
          buf '((side . right) (window-width . 0.5)))))
      (_ (error "Unknown `adoc-preview-backend': %S" backend)))))

(defun adoc--preview-update ()
  "Re-render the current buffer and (re)display its preview.
Does nothing visible when the render fails, leaving any previous
preview in place rather than showing a blank page."
  (when-let* ((file (adoc--asciidoctor-render-preview)))
    (adoc--preview-display file)))

(defun adoc--preview-cleanup ()
  "Delete the current buffer's temporary preview file, if any."
  (when (and adoc--preview-file (file-exists-p adoc--preview-file))
    (ignore-errors (delete-file adoc--preview-file)))
  (setq adoc--preview-file nil))

;;;###autoload
(defun adoc-preview ()
  "Render the current AsciiDoc buffer and show it in a preview pane."
  (interactive)
  (adoc--preview-update))

;;;###autoload
(define-minor-mode adoc-live-preview-mode
  "Re-render the AsciiDoc preview whenever the buffer is saved."
  :lighter " AdocPreview"
  (if adoc-live-preview-mode
      (progn
        (add-hook 'after-save-hook #'adoc--preview-update nil t)
        (add-hook 'kill-buffer-hook #'adoc--preview-cleanup nil t)
        (adoc--preview-update))
    (remove-hook 'after-save-hook #'adoc--preview-update t)
    (remove-hook 'kill-buffer-hook #'adoc--preview-cleanup t)
    (adoc--preview-cleanup)))

;;; Flymake

(defconst adoc--flymake-diagnostic-re
  "^asciidoctor: \\(ERROR\\|WARNING\\|DEPRECATED\\): <stdin>: [Ll]ine \\([0-9]+\\): \\(.*\\)$"
  "Regexp matching an Asciidoctor diagnostic about the standard input document.
Group 1 is the severity, group 2 the line number, group 3 the message.
Asciidoctor has used both `line' and `Line' across versions, hence the
case-insensitive alternative.")

(defvar-local adoc--flymake-proc nil
  "The most recent Asciidoctor Flymake process for this buffer.")

(defun adoc--flymake-parse-output (output source &optional exit-status)
  "Parse Asciidoctor OUTPUT into Flymake diagnostics for buffer SOURCE.
OUTPUT is the combined standard error/output of an Asciidoctor run over
the buffer's contents.  When EXIT-STATUS is non-zero and no per-line
diagnostics are found, the first Asciidoctor message is reported as a
buffer-level error so a fatal failure is not swallowed."
  (let ((diags '())
        (count 0))
    (with-temp-buffer
      (insert output)
      (goto-char (point-min))
      (while (re-search-forward adoc--flymake-diagnostic-re nil t)
        (let* ((type (pcase (match-string 1)
                       ("ERROR" :error)
                       ("WARNING" :warning)
                       (_ :note)))
               (line (string-to-number (match-string 2)))
               (msg (match-string 3))
               (region (flymake-diag-region source line)))
          (when region
            (setq count (1+ count))
            (push (flymake-make-diagnostic source (car region) (cdr region)
                                           type msg)
                  diags))))
      ;; Surface a fatal failure (e.g. a missing converter library) that
      ;; produced no locatable diagnostics, anchored to the top of the buffer.
      (when (and (zerop count) exit-status (not (zerop exit-status)))
        (goto-char (point-min))
        (when (re-search-forward "^asciidoctor: .+$" nil t)
          (when-let* ((region (flymake-diag-region source 1)))
            (push (flymake-make-diagnostic source (car region) (cdr region)
                                           :error (match-string 0))
                  diags)))))
    (nreverse diags)))

(defun adoc-flymake (report-fn &rest _args)
  "An AsciiDoc Flymake backend using Asciidoctor.
Runs the current buffer through `asciidoctor' and converts its parser
diagnostics into Flymake reports via REPORT-FN.  Suitable as a member of
`flymake-diagnostic-functions'."
  (unless (executable-find adoc-asciidoctor-command)
    (error "Cannot find the Asciidoctor executable %S" adoc-asciidoctor-command))
  (when (process-live-p adoc--flymake-proc)
    (kill-process adoc--flymake-proc))
  (let ((source (current-buffer))
        (base (expand-file-name default-directory)))
    (save-restriction
      (widen)
      (setq
       adoc--flymake-proc
       (make-process
        :name "adoc-flymake" :noquery t :connection-type 'pipe
        :buffer (generate-new-buffer " *adoc-flymake*")
        :command (append (list adoc-asciidoctor-command)
                         adoc-asciidoctor-extra-args
                         (list "-B" base "-o" null-device "-"))
        :sentinel
        (lambda (proc _event)
          (when (memq (process-status proc) '(exit signal))
            (unwind-protect
                (if (and (buffer-live-p source)
                         (with-current-buffer source
                           (eq proc adoc--flymake-proc)))
                    (funcall report-fn
                             (adoc--flymake-parse-output
                              (with-current-buffer (process-buffer proc)
                                (buffer-string))
                              source (process-exit-status proc)))
                  (flymake-log :warning "Canceling obsolete check %s" proc))
              (kill-buffer (process-buffer proc)))))))
      (process-send-region adoc--flymake-proc (point-min) (point-max))
      (process-send-eof adoc--flymake-proc))))

;;; Transient menu

;;;###autoload (autoload 'adoc-asciidoctor-menu "adoc-asciidoctor" nil t)
(transient-define-prefix adoc-asciidoctor-menu ()
  "Preview and export the current AsciiDoc document with Asciidoctor."
  ["Preview"
   ("p" "Preview" adoc-preview)
   ("l" "Live preview mode" adoc-live-preview-mode)]
  ["Export"
   ("h" "HTML5" adoc-export-html)
   ("d" "DocBook 5" adoc-export-docbook)
   ("f" "PDF" adoc-export-pdf)
   ("e" "EPUB3" adoc-export-epub)])

(provide 'adoc-asciidoctor)

;;; adoc-asciidoctor.el ends here
