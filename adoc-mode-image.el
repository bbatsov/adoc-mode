;;; adoc-mode-image.el --- Image display for adoc-mode -*- lexical-binding: t; -*-
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

;; Image display support for adoc-mode: inline image overlays, remote image
;; fetching, and context menus.  Most of this code is adapted from
;; `markdown-mode'.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'url-parse)

(declare-function imagep "image.c")
(declare-function image-flush "image.c")

;; Defined in adoc-mode.el
(defvar adoc-max-image-size)
(defvar adoc-display-images)

(defvar-local adoc-image-overlays nil
  "List of image overlays in the current buffer.")

(defcustom adoc-display-remote-images nil
  "If non-nil, download and display remote images.
See also `adoc-image-overlays'.

Only image URLs specified with a protocol listed in
`adoc-remote-image-protocols' are displayed."
  :group 'adoc
  :type 'boolean
  :package-version '(adoc-mode . "0.8.0"))

(defcustom adoc-remote-image-protocols '("https")
  "List of protocols to use to download remote images.
See also `adoc-display-remote-images'."
  :group 'adoc
  :type '(repeat string)
  :package-version '(adoc-mode . "0.8.0"))

(defvar adoc--remote-image-cache
  (make-hash-table :test 'equal)
  "A map from URLs to image paths.")

(defun adoc--get-remote-image (url)
  "Retrieve the image path for a given URL."
  (or (gethash url adoc--remote-image-cache)
      (let ((dl-path (make-temp-file "adoc-mode--image")))
        (require 'url)
        (url-copy-file url dl-path t)
        (puthash url dl-path adoc--remote-image-cache))))

(defconst adoc-re-image "\\<image::?\\([^]]+\\)\\(\\[[^]]*\\]\\)"
  "Regexp matching block- and inline-images.")

(defvar adoc-image-overlay-functions nil
  "Functions called after the creation of an image overlay.
Each function is called with the created overlay as argument.")

(defvar adoc-image-menu (make-sparse-keymap "Image")
  "Common menu of image links and image overlays.")

(defvar adoc-image-link-menu
  (let ((map (make-sparse-keymap "Image")))
    (set-keymap-parent map adoc-image-menu)
    (easy-menu-add-item map nil ["Generate Preview At Point"
                                 (lambda (e) (interactive "e") (adoc-display-image-at e))
                                 t])
    map)
  "Context menu of image links.")

(defvar adoc-image-link-map
  (let ((map (make-sparse-keymap "Image")))
    (define-key map (kbd "<down-mouse-3>")
                (lambda () (interactive) (popup-menu adoc-image-link-menu)))
    map)
  "Keymap for image links.")

(fset 'adoc-image-link-map adoc-image-link-map)

(defvar adoc-image-overlay-menu
  (let ((map (make-sparse-keymap "Image")))
    (set-keymap-parent map adoc-image-menu)
    (easy-menu-add-item map nil ["Remove Preview At Point"
                                 (lambda (e) (interactive "e") (adoc-remove-image-overlay-at e))
                                 t])
    map)
  "Context menu of image overlays.")

(defvar adoc-image-overlay-map
  (let ((map (make-sparse-keymap "Image")))
    (define-key map (kbd "<down-mouse-3>")
                (lambda () (interactive) (popup-menu adoc-image-overlay-menu)))
    map)
  "Keymap for image overlays.")

(defun adoc-create-image-overlay (file start end)
  "Create image overlay with START and END displaying image FILE."
  (when (not (zerop (length file)))
    (unless (file-exists-p file)
      (when adoc-display-remote-images
        (let ((url-type (ignore-errors
                          (downcase (url-type (url-generic-parse-url file))))))
          (when (member url-type adoc-remote-image-protocols)
            (setq file (adoc--get-remote-image file))))))
    (when (file-exists-p file)
      (let* ((abspath (if (file-name-absolute-p file)
                          file
                        (concat default-directory file)))
             (image
              (if (and adoc-max-image-size
                       (image-type-available-p 'imagemagick))
                  (create-image
                   abspath 'imagemagick nil
                   :max-width (car adoc-max-image-size)
                   :max-height (cdr adoc-max-image-size))
                (create-image abspath))))
        (when image
          (let ((ov (make-overlay start end)))
            (overlay-put ov 'adoc-image t)
            (overlay-put ov 'display image)
            (overlay-put ov 'face 'default)
            (overlay-put ov 'keymap adoc-image-overlay-map)
            (run-hook-with-args 'adoc-image-overlay-functions ov)))))))

(defun adoc-display-images ()
  "Add inline image overlays to image links in the buffer.
This can be toggled with `adoc-toggle-images'
or \\[adoc-toggle-images]."
  (interactive)
  (unless (display-images-p)
    (error "Cannot show images"))
  (adoc-remove-images)
  (save-excursion
    (save-restriction
      (widen)
      (goto-char (point-min))
      (while (re-search-forward adoc-re-image nil t)
        (let ((start (match-beginning 0))
              (end (match-end 0))
              (file (match-string-no-properties 1)))
          (adoc-create-image-overlay file start end)
          )))))

(defun adoc-image-overlays (&optional begin end)
  "Return list of image overlays in region from BEGIN to END.
BEGIN and END default to the buffer boundaries
ignoring any restrictions."
  (save-restriction
    (widen)
    (unless begin (setq begin (point-min)))
    (unless end (setq end (point-max)))
    (let (image-overlays)
      (dolist (ov (overlays-in begin end))
        (when (overlay-get ov 'adoc-image)
          (push ov image-overlays)))
      image-overlays)))

(defun adoc-remove-images ()
  "Remove image overlays from image links in the buffer.
This can be toggled with `adoc-toggle-images'
or \\[adoc-toggle-images]."
  (interactive)
  (let ((image-list (adoc-image-overlays)))
    (when image-list
      (dolist (ov image-list)
        (delete-overlay ov))
      t)))

(defun adoc-toggle-images ()
  "Toggle the display of images."
  (interactive)
  (unless (adoc-remove-images)
    (adoc-display-images)
    ))

(defmacro adoc-with-point-at-event (location &rest body)
  "Execute BODY like `progn'.
If LOCATION is an event run BODY in the event's buffer
and set LOCATION to the event position.

If LOCATION is number or marker just run BODY with
LOCATION untouched.

Otherwise set LOCATION to current point."
  (declare (indent 1) (debug (symbolp form body)))
  (let ((posn (make-symbol "posn")))
    `(if (mouse-event-p ,location)
         (let* ((,posn (event-start ,location)))
           (with-current-buffer (window-buffer (posn-window ,posn))
             (setq ,location (posn-point ,posn))
             ,@body))
       (unless (number-or-marker-p ,location)
         (setq ,location (point)))
       ,@body)))

(defun adoc-bounds-of-image-link-at (&optional location)
  "Get bounds of image link at LOCATION.
Return \\(START . END) giving the start and the end
positions of the image link found.

If an image link is identified `match-data' is set as follows:
0. whole link inclusive \"image::?\" and attributes
1. image path
2. bracketed attribute list."
  (adoc-with-point-at-event location
    (save-excursion
      (when location (goto-char location))
      (setq location (point))
      (if (looking-at "[[:alpha:]]*::?\\_<")
          (skip-chars-backward "[:alpha:]")
        (re-search-backward "\\_<image:" (line-beginning-position) t))
      (when (looking-at adoc-re-image)
        (cons (match-beginning 0) (match-end 0))))))

(cl-defstruct adoc-image-link
  "Data from an image link."
  begin end uri begin-uri end-uri begin-attributes end-attributes)

(defun adoc-image-link-at (&optional location)
  "Return image link at LOCATION if there is one.
LOCATION can be a buffer position or a mouse event.
It defaults to \\(point)."
  (adoc-with-point-at-event location
    (when (adoc-bounds-of-image-link-at location)
      (make-adoc-image-link
       :begin (match-beginning 0)
       :end (match-end 0)
       :begin-uri (match-beginning 1)
       :end-uri (match-end 1)
       :begin-attributes (match-beginning 2)
       :end-attributes (match-end 2)
       :uri (match-string 1)))))

(put 'adoc-image 'bounds-of-thing-at-point #'adoc-bounds-of-image-link-at)

(defun adoc-display-image-at (&optional location)
  "Create image overlay at LOCATION.
LOCATION can be a buffer position like `point'
or an event.  It defaults to \\(point)."
  (interactive "d")
  (adoc-with-point-at-event location
    (when-let* ((link (adoc-image-link-at location)))
      (adoc-create-image-overlay
       (adoc-image-link-uri link)
       (adoc-image-link-begin link)
       (adoc-image-link-end link)
       ))))

(defun adoc-image-overlay-at (location)
  "Get image overlay at LOCATION."
  (adoc-with-point-at-event location
    (seq-find (lambda (ov) (overlay-get ov 'adoc-image))
              (overlays-in (1- location) (1+ location)))))

(defun adoc-remove-image-overlay-at (&optional location flush)
  "Delete overlay at LOCATION.
POINT defaults to `point'.
POINT can also be a mouse event.
If FLUSH is non-nil also flush the cache for this image."
  (interactive "d")
  (adoc-with-point-at-event location
    (let ((ov (adoc-image-overlay-at location)))
      (when ov
        (when-let* ((image (and flush (overlay-get ov 'display)))
                   ((imagep image)))
          (image-flush image))
        (delete-overlay ov)))))

(provide 'adoc-mode-image)

;; Local Variables:
;; indent-tabs-mode: nil
;; coding: utf-8
;; End:
;;; adoc-mode-image.el ends here
