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
    (adoc-test-trans "lorem <ipsum> dolor" "lorem $$ipsum$$ dolor" '(tempo-template-adoc-pass-$$))))

;;; adoc-mode-tempo-test.el ends here
