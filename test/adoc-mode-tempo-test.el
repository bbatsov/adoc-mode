;;; adoc-mode-tempo-test.el --- tests for adoc-mode tempo templates -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests for tempo template insertion in adoc-mode.

;;; Code:

(require 'ert)
(require 'adoc-mode)
(require 'adoc-mode-test)

(defun adoctest-quotes (start-del end-del transform)
  "Todo document adoctest-quotes START-DEL END-DEL TRANSFORM."
  (adoctest-trans "lorem ! ipsum"
                  (concat "lorem " start-del end-del " ipsum") transform)
  (adoctest-trans "lorem <ipsum> dolor"
                  (concat "lorem " start-del "ipsum" end-del " dolor") transform))

;; FIXME
;; todo: test templates also with tempo-snippets
(ert-deftest adoctest-test-tempo-quotes ()
  (adoctest-quotes "_" "_" '(tempo-template-adoc-emphasis))
  (adoctest-quotes "*" "*" '(tempo-template-adoc-bold))
  (adoctest-quotes "+" "+" '(tempo-template-adoc-typewriter-face))
  (adoctest-quotes "`" "`" '(tempo-template-adoc-monospace-literal))
  (adoctest-quotes "__" "__" '(tempo-template-adoc-emphasis-uc))
  (adoctest-quotes "**" "**" '(tempo-template-adoc-bold-uc))
  (adoctest-quotes "++" "++" '(tempo-template-adoc-monospace-uc))
  (adoctest-quotes "^" "^" '(tempo-template-adoc-superscript))
  (adoctest-quotes "~" "~" '(tempo-template-adoc-subscript)))

(ert-deftest adoctest-test-tempo-formatting-misc ()

  (adoctest-trans "" " +" '(tempo-template-adoc-line-break))
  (adoctest-trans "lor!em" "lor +\nem" '(tempo-template-adoc-line-break))
  ;; dont change only white sequence between point and end of line
  (adoctest-trans "lorem! \nipsum" "lorem + \nipsum" '(tempo-template-adoc-line-break))
  ;; if befor point already a space is, dont insert a new one
  (adoctest-trans "lorem !\nipsum" "lorem +\nipsum" '(tempo-template-adoc-line-break))

  (adoctest-trans "" "<<<" '(tempo-template-adoc-page-break))
  (adoctest-trans "lorem\n!\nipsum" "lorem\n<<<\nipsum" '(tempo-template-adoc-page-break))
  (adoctest-trans "lor!em\nipsum" "lor\n<<<\nem\nipsum" '(tempo-template-adoc-page-break))

  (adoctest-trans "" "---" '(tempo-template-adoc-ruler-line))
  (adoctest-trans "lorem\n!\nipsum" "lorem\n---\nipsum" '(tempo-template-adoc-ruler-line))
  (adoctest-trans "lor!em\nipsum" "lor\n---\nem\nipsum" '(tempo-template-adoc-ruler-line)))

;; TODO: check buffer position after insertion (aka transionsion). Probably
;; factor out from adoctest-trans a defun which translates a string containing
;; !s into one with the ! stripped and a buffer-position-list
(ert-deftest adoctest-test-tempo-title ()
  (let ((adoc-title-style 'adoc-title-style-one-line))
    (adoctest-trans "" "= " '(tempo-template-adoc-title-1))
    (adoctest-trans "" "=== " '(tempo-template-adoc-title-3))
    (adoctest-trans "lorem\n!\nipsum" "lorem\n= \nipsum" '(tempo-template-adoc-title-1)))

  (let ((adoc-title-style 'adoc-title-style-one-line-enclosed))
    (adoctest-trans "" "=  =" '(tempo-template-adoc-title-1))
    (adoctest-trans "" "===  ===" '(tempo-template-adoc-title-3))
    (adoctest-trans "lorem\n!\nipsum" "lorem\n=  =\nipsum" '(tempo-template-adoc-title-1)))

  (let ((adoc-title-style 'adoc-title-style-two-line))
    (adoctest-trans "" "\n====" '(tempo-template-adoc-title-1))
    (adoctest-trans "" "\n~~~~" '(tempo-template-adoc-title-3))
    (adoctest-trans "lorem\n!\nipsum" "lorem\n\n====\nipsum" '(tempo-template-adoc-title-1))))

(ert-deftest adoctest-test-tempo-paragraphs ()
  (adoctest-trans "" "  " '(tempo-template-adoc-literal-paragraph))
  (adoctest-trans "lorem<ipsum>" "lorem\n  ipsum" '(tempo-template-adoc-literal-paragraph))
  (adoctest-trans "" "TIP: " '(tempo-template-adoc-paragraph-tip))
  (adoctest-trans "lorem<ipsum>" "lorem\nTIP: ipsum" '(tempo-template-adoc-paragraph-tip)))

(defun adoctest-delimited-block (del transform)
  "Todo document adoctest-delimited-block DEL TRANSFORM."
  (let ((del-line (if (integerp del) (make-string 50 del) del)))
    (adoctest-trans
     "" (concat del-line "\n\n" del-line) transform)
    (adoctest-trans
     "lorem\n!\nipsum" (concat "lorem\n" del-line "\n\n" del-line "\nipsum") transform)
    (adoctest-trans
     "lorem\n<ipsum>\ndolor" (concat "lorem\n" del-line "\nipsum\n" del-line "\ndolor") transform)
    (adoctest-trans
     "lorem !dolor" (concat "lorem \n" del-line "\n\n" del-line "\ndolor") transform)
    (adoctest-trans
     "lorem <ipsum >dolor" (concat "lorem \n" del-line "\nipsum \n" del-line "\ndolor") transform)))

(ert-deftest adoctest-test-tempo-delimited-blocks ()
  (adoctest-delimited-block ?/ '(tempo-template-adoc-delimited-block-comment))
  (adoctest-delimited-block ?+ '(tempo-template-adoc-delimited-block-passthrough))
  (adoctest-delimited-block ?- '(tempo-template-adoc-delimited-block-listing))
  (adoctest-delimited-block ?. '(tempo-template-adoc-delimited-block-literal))
  (adoctest-delimited-block ?_ '(tempo-template-adoc-delimited-block-quote))
  (adoctest-delimited-block ?= '(tempo-template-adoc-delimited-block-example))
  (adoctest-delimited-block ?* '(tempo-template-adoc-delimited-block-sidebar))
  (adoctest-delimited-block "--" '(tempo-template-adoc-delimited-block-open-block)))

(ert-deftest adoctest-test-tempo-lists ()
  (let ((tab-width 2)
        (indent-tabs-mode nil))
    (adoctest-trans "" "- " '(tempo-template-adoc-bulleted-list-item-1))
    (adoctest-trans "" " ** " '(tempo-template-adoc-bulleted-list-item-2))
    (adoctest-trans "<foo>" "- foo" '(tempo-template-adoc-bulleted-list-item-1))
    (adoctest-trans "" ":: " '(tempo-template-adoc-labeled-list-item))
    (adoctest-trans "<foo>" ":: foo" '(tempo-template-adoc-labeled-list-item))))

(ert-deftest adoctest-test-tempo-macros ()
  (adoctest-trans "" "http://foo.com[]" '(tempo-template-adoc-url-caption))
  (adoctest-trans "see <here> for" "see http://foo.com[here] for" '(tempo-template-adoc-url-caption))
  (adoctest-trans "" "mailto:[]" '(tempo-template-adoc-email-caption))
  (adoctest-trans "ask <bob> for" "ask mailto:[bob] for" '(tempo-template-adoc-email-caption))
  (adoctest-trans "" "[[]]" '(tempo-template-adoc-anchor))
  (adoctest-trans "lorem <ipsum> dolor" "lorem [[ipsum]] dolor" '(tempo-template-adoc-anchor))
  (adoctest-trans "" "anchor:[]" '(tempo-template-adoc-anchor-default-syntax))
  (adoctest-trans "lorem <ipsum> dolor" "lorem anchor:ipsum[] dolor" '(tempo-template-adoc-anchor-default-syntax))
  (adoctest-trans "" "<<,>>" '(tempo-template-adoc-xref))
  (adoctest-trans "see <here> for" "see <<,here>> for" '(tempo-template-adoc-xref))
  (adoctest-trans "" "xref:[]" '(tempo-template-adoc-xref-default-syntax))
  (adoctest-trans "see <here> for" "see xref:[here] for" '(tempo-template-adoc-xref-default-syntax))
  (adoctest-trans "" "image:[]" '(tempo-template-adoc-image)))

(ert-deftest adoctest-test-tempo-passthrough-macros ()
  ;; backticks are tested in adoctest-test-tempo-quotes
  (adoctest-trans "" "pass:[]" '(tempo-template-adoc-pass))
  (adoctest-trans "lorem <ipsum> dolor" "lorem pass:[ipsum] dolor" '(tempo-template-adoc-pass))
  (adoctest-trans "" "asciimath:[]" '(tempo-template-adoc-asciimath))
  (adoctest-trans "lorem <ipsum> dolor" "lorem asciimath:[ipsum] dolor" '(tempo-template-adoc-asciimath))
  (adoctest-trans "" "latexmath:[]" '(tempo-template-adoc-latexmath))
  (adoctest-trans "lorem <ipsum> dolor" "lorem latexmath:[ipsum] dolor" '(tempo-template-adoc-latexmath))
  (adoctest-trans "" "++++++" '(tempo-template-adoc-pass-+++))
  (adoctest-trans "lorem <ipsum> dolor" "lorem +++ipsum+++ dolor" '(tempo-template-adoc-pass-+++))
  (adoctest-trans "" "$$$$" '(tempo-template-adoc-pass-$$))
  (adoctest-trans "lorem <ipsum> dolor" "lorem $$ipsum$$ dolor" '(tempo-template-adoc-pass-$$)))

;;; adoc-mode-tempo-test.el ends here
