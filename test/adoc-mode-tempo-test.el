;;; adoc-mode-tempo-test.el --- Tempo-template tests for adoc-mode -*- lexical-binding: t; -*-

;; Copyright © 2025-2026 Bozhidar Batsov

;;; Commentary:

;; Buttercup tests for tempo template insertion in adoc-mode.

;;; Code:

(require 'adoc-mode-test-helpers)

(defun adoc-test--tempo-quotes (start-del end-del transform)
  "Assert TRANSFORM wraps point/region with START-DEL and END-DEL."
  (adoc-test-trans "lorem ! ipsum"
                   (concat "lorem " start-del end-del " ipsum") transform)
  (adoc-test-trans "lorem <ipsum> dolor"
                   (concat "lorem " start-del "ipsum" end-del " dolor") transform))

(defun adoc-test--tempo-delimited-block (del transform)
  "Assert TRANSFORM inserts a delimited block using delimiter DEL."
  (let ((del-line (if (integerp del) (make-string 50 del) del)))
    (adoc-test-trans
     "" (concat del-line "\n\n" del-line) transform)
    (adoc-test-trans
     "lorem\n!\nipsum" (concat "lorem\n" del-line "\n\n" del-line "\nipsum") transform)
    (adoc-test-trans
     "lorem\n<ipsum>\ndolor" (concat "lorem\n" del-line "\nipsum\n" del-line "\ndolor") transform)
    (adoc-test-trans
     "lorem !dolor" (concat "lorem \n" del-line "\n\n" del-line "\ndolor") transform)
    (adoc-test-trans
     "lorem <ipsum >dolor" (concat "lorem \n" del-line "\nipsum \n" del-line "\ndolor") transform)))

(describe "adoc-mode tempo templates"

  (it "wraps text with the quote/passthrough delimiters"
    (adoc-test--tempo-quotes "_" "_" '(tempo-template-adoc-emphasis))
    (adoc-test--tempo-quotes "*" "*" '(tempo-template-adoc-bold))
    (adoc-test--tempo-quotes "+" "+" '(tempo-template-adoc-typewriter-face))
    (adoc-test--tempo-quotes "`" "`" '(tempo-template-adoc-monospace-literal))
    (adoc-test--tempo-quotes "__" "__" '(tempo-template-adoc-emphasis-uc))
    (adoc-test--tempo-quotes "**" "**" '(tempo-template-adoc-bold-uc))
    (adoc-test--tempo-quotes "++" "++" '(tempo-template-adoc-monospace-uc))
    (adoc-test--tempo-quotes "^" "^" '(tempo-template-adoc-superscript))
    (adoc-test--tempo-quotes "~" "~" '(tempo-template-adoc-subscript))
    ;; modern curved (smart) quotes
    (adoc-test--tempo-quotes "\"`" "`\"" '(tempo-template-adoc-double-curved-quote))
    (adoc-test--tempo-quotes "'`" "`'" '(tempo-template-adoc-single-curved-quote)))

  (it "inserts misc formatting (line / page / ruler breaks)"
    (adoc-test-trans "" " +" '(tempo-template-adoc-line-break))
    (adoc-test-trans "lor!em" "lor +\nem" '(tempo-template-adoc-line-break))
    (adoc-test-trans "lorem! \nipsum" "lorem + \nipsum" '(tempo-template-adoc-line-break))
    (adoc-test-trans "lorem !\nipsum" "lorem +\nipsum" '(tempo-template-adoc-line-break))
    (adoc-test-trans "" "<<<" '(tempo-template-adoc-page-break))
    (adoc-test-trans "lorem\n!\nipsum" "lorem\n<<<\nipsum" '(tempo-template-adoc-page-break))
    (adoc-test-trans "lor!em\nipsum" "lor\n<<<\nem\nipsum" '(tempo-template-adoc-page-break))
    (adoc-test-trans "" "---" '(tempo-template-adoc-ruler-line))
    (adoc-test-trans "lorem\n!\nipsum" "lorem\n---\nipsum" '(tempo-template-adoc-ruler-line))
    (adoc-test-trans "lor!em\nipsum" "lor\n---\nem\nipsum" '(tempo-template-adoc-ruler-line)))

  (it "inserts titles in the configured style"
    (let ((adoc-title-style 'adoc-title-style-one-line))
      (adoc-test-trans "" "= " '(tempo-template-adoc-title-1))
      (adoc-test-trans "" "=== " '(tempo-template-adoc-title-3))
      (adoc-test-trans "lorem\n!\nipsum" "lorem\n= \nipsum" '(tempo-template-adoc-title-1)))
    (let ((adoc-title-style 'adoc-title-style-one-line-enclosed))
      (adoc-test-trans "" "=  =" '(tempo-template-adoc-title-1))
      (adoc-test-trans "" "===  ===" '(tempo-template-adoc-title-3))
      (adoc-test-trans "lorem\n!\nipsum" "lorem\n=  =\nipsum" '(tempo-template-adoc-title-1)))
    (let ((adoc-title-style 'adoc-title-style-two-line))
      (adoc-test-trans "" "\n====" '(tempo-template-adoc-title-1))
      (adoc-test-trans "" "\n~~~~" '(tempo-template-adoc-title-3))
      (adoc-test-trans "lorem\n!\nipsum" "lorem\n\n====\nipsum" '(tempo-template-adoc-title-1))))

  (it "inserts paragraphs"
    (adoc-test-trans "" "  " '(tempo-template-adoc-literal-paragraph))
    (adoc-test-trans "lorem<ipsum>" "lorem\n  ipsum" '(tempo-template-adoc-literal-paragraph))
    (adoc-test-trans "" "TIP: " '(tempo-template-adoc-paragraph-tip))
    (adoc-test-trans "lorem<ipsum>" "lorem\nTIP: ipsum" '(tempo-template-adoc-paragraph-tip)))

  (it "inserts delimited blocks"
    (adoc-test--tempo-delimited-block ?/ '(tempo-template-adoc-delimited-block-comment))
    (adoc-test--tempo-delimited-block ?+ '(tempo-template-adoc-delimited-block-passthrough))
    (adoc-test--tempo-delimited-block ?- '(tempo-template-adoc-delimited-block-listing))
    (adoc-test--tempo-delimited-block ?. '(tempo-template-adoc-delimited-block-literal))
    (adoc-test--tempo-delimited-block ?_ '(tempo-template-adoc-delimited-block-quote))
    (adoc-test--tempo-delimited-block ?= '(tempo-template-adoc-delimited-block-example))
    (adoc-test--tempo-delimited-block ?* '(tempo-template-adoc-delimited-block-sidebar))
    (adoc-test--tempo-delimited-block "--" '(tempo-template-adoc-delimited-block-open-block)))

  (it "inserts a table"
    (adoc-test-trans
     ""
     "|===\n| cell 11 | cell 12\n| cell 21 | cell 22\n|===\n"
     '(tempo-template-adoc-example-table)))

  (it "inserts list items"
    (let ((tab-width 2)
          (indent-tabs-mode nil))
      (adoc-test-trans "" "- " '(tempo-template-adoc-bulleted-list-item-1))
      (adoc-test-trans "" " ** " '(tempo-template-adoc-bulleted-list-item-2))
      (adoc-test-trans "<foo>" "- foo" '(tempo-template-adoc-bulleted-list-item-1))
      (adoc-test-trans "" ":: " '(tempo-template-adoc-labeled-list-item))
      (adoc-test-trans "<foo>" ":: foo" '(tempo-template-adoc-labeled-list-item))))

  (it "inserts macros"
    (adoc-test-trans "" "http://foo.com[]" '(tempo-template-adoc-url-caption))
    (adoc-test-trans "see <here> for" "see http://foo.com[here] for" '(tempo-template-adoc-url-caption))
    (adoc-test-trans "" "mailto:[]" '(tempo-template-adoc-email-caption))
    (adoc-test-trans "ask <bob> for" "ask mailto:[bob] for" '(tempo-template-adoc-email-caption))
    (adoc-test-trans "" "[[]]" '(tempo-template-adoc-anchor))
    (adoc-test-trans "lorem <ipsum> dolor" "lorem [[ipsum]] dolor" '(tempo-template-adoc-anchor))
    (adoc-test-trans "" "anchor:[]" '(tempo-template-adoc-anchor-default-syntax))
    (adoc-test-trans "lorem <ipsum> dolor" "lorem anchor:ipsum[] dolor" '(tempo-template-adoc-anchor-default-syntax))
    (adoc-test-trans "" "<<,>>" '(tempo-template-adoc-xref))
    (adoc-test-trans "see <here> for" "see <<,here>> for" '(tempo-template-adoc-xref))
    (adoc-test-trans "" "xref:[]" '(tempo-template-adoc-xref-default-syntax))
    (adoc-test-trans "see <here> for" "see xref:[here] for" '(tempo-template-adoc-xref-default-syntax))
    (adoc-test-trans "" "image:[]" '(tempo-template-adoc-image)))

  (it "inserts passthrough macros"
    (adoc-test-trans "" "pass:[]" '(tempo-template-adoc-pass))
    (adoc-test-trans "lorem <ipsum> dolor" "lorem pass:[ipsum] dolor" '(tempo-template-adoc-pass))
    (adoc-test-trans "" "asciimath:[]" '(tempo-template-adoc-asciimath))
    (adoc-test-trans "lorem <ipsum> dolor" "lorem asciimath:[ipsum] dolor" '(tempo-template-adoc-asciimath))
    (adoc-test-trans "" "latexmath:[]" '(tempo-template-adoc-latexmath))
    (adoc-test-trans "lorem <ipsum> dolor" "lorem latexmath:[ipsum] dolor" '(tempo-template-adoc-latexmath))
    (adoc-test-trans "" "++++++" '(tempo-template-adoc-pass-+++))
    (adoc-test-trans "lorem <ipsum> dolor" "lorem +++ipsum+++ dolor" '(tempo-template-adoc-pass-+++))
    (adoc-test-trans "" "$$$$" '(tempo-template-adoc-pass-$$))
    (adoc-test-trans "lorem <ipsum> dolor" "lorem $$ipsum$$ dolor" '(tempo-template-adoc-pass-$$)))

  (it "inserts the replacements the menu advertises"
    (adoc-test-trans "" "(TM)" '(tempo-template-adoc-trademark))
    (adoc-test-trans "" "--" '(tempo-template-adoc-dash)))

  (it "inserts a comment line"
    (adoc-test-trans "" "// " '(adoc-insert-comment))
    (adoc-test-trans "lorem!" "lorem\n// " '(adoc-insert-comment)))

  (it "comments out every line of the region"
    (dolist (case '(("a\nb\nc" 1 6 "// a\n// b\n// c")
                    ;; partly selected lines are commented whole
                    ("xx a\n  b\nc" 4 9 "// xx a\n//   b\nc")))
      (with-temp-buffer
        (adoc-mode)
        (insert (nth 0 case))
        (adoc-insert-comment (nth 1 case) (nth 2 case))
        (expect (buffer-string) :to-equal (nth 3 case)))))

  (it "documents the templates with the AsciiDoc help text"
    (expect (documentation 'tempo-template-adoc-emphasis)
            :to-match (regexp-quote adoc-help-emphasis)))

  (it "works when the current command is a lambda"
    ;; e.g. a template run from a key bound to a lambda, or from a hydra
    (with-temp-buffer
      (adoc-mode)
      (let ((this-command (lambda () (interactive))))
        (expect (tempo-template-adoc-title-2) :not :to-throw)))))

(defun adoc-test--menu-items (keymap)
  "Return the (BINDING . HELP) of every item in the menu KEYMAP.
Submenus are included."
  (let (items)
    (map-keymap
     (lambda (_event item)
       (when (eq (car-safe item) 'menu-item)
         (let ((binding (nth 2 item))
               (help (plist-get (nthcdr 3 item) :help)))
           (if (keymapp binding)
               (setq items (append (adoc-test--menu-items binding) items))
             (push (cons binding help) items)))))
     keymap)
    items))

(describe "the AsciiDoc menu"
  (let ((items (adoc-test--menu-items (lookup-key adoc-mode-map [menu-bar]))))
    (it "only offers commands that exist"
      (expect items :not :to-be nil)
      (expect (cl-remove-if (lambda (item) (or (null (car item)) (commandp (car item))))
                            items)
              :to-be nil))

    (it "has help text, not symbols, as help"
      (expect (cl-remove-if (lambda (item) (or (null (cdr item)) (stringp (cdr item))))
                            items)
              :to-be nil))))

;;; adoc-mode-tempo-test.el ends here
