;;; adoc-mode-font-lock-test.el --- Font-lock tests for adoc-mode -*- lexical-binding: t; -*-

;; Copyright © 2025-2026 Bozhidar Batsov

;;; Commentary:

;; Buttercup tests for adoc-mode font-lock rules, organised by construct.
;; Assertions use the `when-fontifying-it' helper: write AsciiDoc source
;; and assert the face of a substring or position range.

;;; Code:

(require 'adoc-mode-test-helpers)

(describe "adoc-mode font-lock"

  ;; ---- Titles --------------------------------------------------------

  (describe "titles"
    (when-fontifying-it "fontifies a one-line document title"
      ("= Document Title"
       ("= " adoc-meta-hide-face)
       ("Document Title" adoc-title-0-face)))

    (when-fontifying-it "fontifies one-line section titles by level"
      ("== Section One"
       ("Section One" adoc-title-1-face))
      ("=== Section Two"
       ("Section Two" adoc-title-2-face))
      ("====== Section Five"
       ("Section Five" adoc-title-5-face)))

    (when-fontifying-it "fontifies an enclosed one-line title"
      ("== Section =="
       ("Section" adoc-title-1-face)))

    (it "fontifies a two-line (setext) title when enabled"
      ;; two-line title highlighting is off by default
      (let ((adoc-enable-two-line-title t))
        (adoc-test--check-face-specs
         "Document Title\n=============="
         '(("Document Title" adoc-title-0-face)))))

    (it "doesn't take a block title or attribute line for a two-line title"
      (let ((adoc-enable-two-line-title t))
        (adoc-test--check-face-specs ".Example\n--------\ncode\n--------\n"
                                     '(("Example" adoc-gen-face)
                                       ("code" adoc-code-face)))
        (adoc-test--check-face-specs "[abcd]\n----\ncode\n----\n"
                                     '(("code" adoc-code-face)))))

    (it "fontifies a two-line title after a rejected one"
      (let ((adoc-enable-two-line-title t))
        (adoc-test--check-face-specs "Hi\n------------\n\nTitle\n-----\n"
                                     '(("Title" adoc-title-1-face)))))

    (it "skips two-line titles whose underline has the excluded length"
      (let ((adoc-enable-two-line-title 5))
        (adoc-test--check-face-specs "Titles\n-----\n" '(("Titles" nil)))
        (adoc-test--check-face-specs "Title\n------\n" '(("Title" adoc-title-1-face)))))

    (when-fontifying-it "fontifies a block title"
      (".Block Title\nsome text"
       ("Block Title" adoc-gen-face))))

  ;; ---- Inline text formatting ---------------------------------------

  (describe "inline formatting"
    (when-fontifying-it "fontifies constrained and unconstrained bold"
      ("a *bold* word"
       ("bold" adoc-bold-face)
       ("*" adoc-meta-hide-face))
      ("a **bold** word"
       ("bold" adoc-bold-face)))

    (when-fontifying-it "fontifies emphasis"
      ("a _emph_ word"
       ("emph" adoc-emphasis-face))
      ("a __emph__ word"
       ("emph" adoc-emphasis-face)))

    (it "keeps the bold and emphasis faces plain (no tint)"
      (expect (face-attribute 'adoc-bold-face :inherit) :to-equal 'bold)
      (expect (face-attribute 'adoc-emphasis-face :inherit) :to-equal 'italic))

    (when-fontifying-it "fontifies monospace via backticks"
      ("a `mono` word"
       ("mono" (adoc-typewriter-face adoc-verbatim-face))))

    (when-fontifying-it "fontifies highlight"
      ("a #marked# word"
       ("marked" adoc-highlight-face)))

    (when-fontifying-it "fontifies superscript and subscript"
      ("a ^super^ word"
       ("super" adoc-superscript-face))
      ("a ~sub~ word"
       ("sub" adoc-subscript-face))))

  ;; ---- Passthroughs --------------------------------------------------

  (describe "passthroughs"
    (when-fontifying-it "treats +text+ / ++text++ as passthroughs, not monospace"
      ("a +plain+ word"
       ("plain" nil)
       ("+" adoc-meta-hide-face))
      ("a ++plain++ word"
       ("plain" nil)))

    (when-fontifying-it "suppresses inline formatting inside a passthrough"
      ("a +no *bold* here+ word"
       ("no *bold* here" nil)))

    (when-fontifying-it "fontifies +++...+++ and $$...$$ passthroughs"
      ("a +++raw+++ word"
       ("raw" (adoc-typewriter-face adoc-verbatim-face)))
      ("a $$raw$$ word"
       ("raw" (adoc-typewriter-face adoc-verbatim-face)))))

  ;; ---- Curved quotes -------------------------------------------------

  (describe "curved quotes"
    (when-fontifying-it "fontifies double and single curved quotes"
      ("\"`hello`\""
       ("\"`" adoc-meta-hide-face)
       ("hello" nil))
      ("'`world`'"
       ("'`" adoc-meta-hide-face)
       ("world" nil)))

    (when-fontifying-it "leaves plain straight quotes untouched"
      ("say \"text\" here"
       ("text" nil))))

  ;; ---- Escaped formatting -------------------------------------------

  (describe "escaped formatting"
    (when-fontifying-it "de-emphasises the backslash and leaves markup literal"
      ("\\*foo*"
       ("\\" adoc-meta-hide-face)
       ("*foo*" nil))
      ("\\**foo**"
       ("foo" nil)))

    (when-fontifying-it "leaves a backslash before a non-formatting char alone"
      ("a\\b"
       ("a\\b" nil))))

  ;; ---- Lists ---------------------------------------------------------

  (describe "lists"
    (when-fontifying-it "fontifies unordered list markers"
      ("* item" ("*" adoc-list-face))
      ("- item" ("-" adoc-list-face))
      ("*** nested" ("***" adoc-list-face)))

    (when-fontifying-it "fontifies numbered and callout list markers"
      ("1. first" ("1." adoc-list-face))
      (". implicit" ("." adoc-list-face))
      ("<1> callout" ("<1>" adoc-list-face)))

    (when-fontifying-it "fontifies checklist checkboxes"
      ("* [x] done" ("*" adoc-list-face) ("[x]" adoc-checkbox-face))
      ("* [ ] todo" ("[ ]" adoc-checkbox-face))
      ("- [*] also" ("[*]" adoc-checkbox-face)))

    (when-fontifying-it "fontifies labeled list items"
      ("term:: definition"
       ("term" adoc-gen-face)
       ("::" adoc-list-face))))

  ;; ---- Delimited blocks ----------------------------------------------

  (describe "delimited blocks"
    (when-fontifying-it "fontifies a listing block body"
      ("----\ncode line\n----" ("code line" adoc-code-face)))

    (when-fontifying-it "fontifies a literal block body"
      ("....\nliteral\n...." ("literal" adoc-verbatim-face)))

    (when-fontifying-it "fontifies a comment block body"
      ("////\ncomment\n////" ("comment" adoc-comment-face)))

    (when-fontifying-it "fontifies a passthrough block body"
      ("++++\nraw\n++++" ("raw" adoc-passthrough-face)))

    (when-fontifying-it "fontifies a quote block body"
      ("____\nquoted\n____" ("quoted" adoc-blockquote-face)))

    (when-fontifying-it "fontifies a sidebar block body"
      ("****\nsidebar\n****" ("sidebar" adoc-secondary-text-face)))

    (when-fontifying-it "keeps the highlighting inside example and open blocks"
      ("[NOTE]\n====\n* item\n// a comment\n===="
       ("*" adoc-list-face)
       ("// a comment" adoc-comment-face))
      ("--\n* item\n// a comment\n--"
       ("*" adoc-list-face)
       ("// a comment" adoc-comment-face)))

    (when-fontifying-it "keeps list markers in a quote block"
      ("____\n* quoted item\n____" ("*" adoc-list-face)))

    (when-fontifying-it "doesn't highlight section titles inside a block"
      ;; Asciidoctor reads them as plain paragraphs
      ("====\n== Not a title\n====\n\n--\n=== Nor this\n--\n\n== Real"
       ("Not a title" nil)
       ("Nor this" nil)
       ("Real" adoc-title-1-face)))

    (it "keeps the indentation of nested code as code"
      (with-temp-buffer
        (insert "****\n----\nif x\n  indented code\n----\n****\n")
        (adoc-mode)
        (font-lock-ensure)
        (goto-char (point-min))
        (search-forward "  indented")
        (expect (get-text-property (match-beginning 0) 'face)
                :not :to-contain 'adoc-align-face)))

    (when-fontifying-it "keeps going after a literal paragraph inside a listing block"
      ("----\ncode\n\n  indented in listing\n----\n\nText\n\n  literal paragraph\n"
       ("indented in listing" adoc-code-face)
       ("literal paragraph" adoc-typewriter-face))))

  ;; ---- Chunked fontification ------------------------------------------

  (describe "chunked fontification"
    ;; jit-lock fontifies a chunk at a time during redisplay, and a chunk
    ;; can begin or end inside a delimited block.

    (it "keeps a long listing block's body as code"
      (with-temp-buffer
        (insert "= Doc\n\nintro\n\n----\n"
                (apply #'concat (make-list 30 "a line of code to fill the chunk\n"))
                "*star* inside the listing\n"
                (apply #'concat (make-list 10 "more code\n"))
                "----\n\nAfter the block, *bold* text.\n")
        (adoc-mode)
        (adoc-test-fontify-in-chunks 200)
        (goto-char (point-min))
        (search-forward "*star*")
        (expect (adoc-test-face-at-range (match-beginning 0) (1- (match-end 0)))
                :to-equal 'adoc-code-face)
        (search-forward "bold")
        (expect (adoc-test-face-at-range (match-beginning 0) (1- (match-end 0)))
                :to-equal 'adoc-bold-face)))

    (it "fontifies blocks the same chunk by chunk as in one go"
      (let ((text (concat
                   "= Doc\n\n== Section\n\n"
                   "[source,adoctest-lang]\n----\nif x\n"
                   (apply #'concat (make-list 12 "  do something\n"))
                   "----\n\n"
                   "[NOTE]\n====\n* item one\n* item two\n\n"
                   "----\nnested listing\n\n== not a title\n----\n\n"
                   (apply #'concat (make-list 8 "Example text with *bold* words.\n"))
                   "====\n\n"
                   "....\nliteral\n\n*not bold*\n....\n\n"
                   "****\nsidebar _text_\n\n// a comment\n****\n\n"
                   "____\nquoted\n\nNOTE: inside\n____\n\n"
                   "NOTE: an admonition\n\n"
                   "|===\n|a |b\n\n|c |d\n|===\n\n"
                   "== Another *section*\n\nThe end.\n")))
        (dolist (chunk-size '(37 64 101 250))
          (expect (adoc-test-chunked-fontification-difference text chunk-size)
                  :to-be nil))))

    (when-fontifying-it "ends a block at the first exact repeat of its delimiter"
      ("----\ncode\n\n----\n\nprose with *bold*\n\n----\nmore\n----\n"
       ("code" adoc-code-face)
       ("prose" nil)
       ("bold" adoc-bold-face)
       ("more" adoc-code-face)))

    (it "pairs block delimiters from the start of the buffer when narrowed"
      (with-temp-buffer
        (insert "= Doc\n\n----\ncode\n----\n\n== Real Title\n\n----\nmore\n----\n")
        (adoc-mode)
        (goto-char (point-min))
        (search-forward "code")
        (narrow-to-region (line-beginning-position) (point-max))
        (adoc--ensure-block-extents (point-max))
        (widen)
        (font-lock-ensure)
        (goto-char (point-min))
        (search-forward "Real Title")
        (expect (get-text-property (match-beginning 0) 'face) :to-be 'adoc-title-1-face)))

    (it "updates the block extents after an edit"
      (with-temp-buffer
        (insert "----\ncode\n\n== Title\n")
        (adoc-mode)
        (adoc--ensure-block-extents (point-max))
        (goto-char (point-min))
        (search-forward "Title")
        (expect (get-text-property (point) 'adoc-delimited-block) :to-be nil)
        ;; closing the block puts the title inside it
        (goto-char (point-max))
        (insert "----\n")
        (adoc--ensure-block-extents (point-max))
        (goto-char (point-min))
        (search-forward "Title")
        (expect (car (get-text-property (point) 'adoc-delimited-block)) :to-equal 1)))

    (it "closes a block when its closing delimiter is typed after more text"
      (with-temp-buffer
        (insert "----\ncode\n\n== Title\n\n----\nother\n----\n")
        (adoc-mode)
        (adoc--ensure-block-extents (point-max))
        ;; the first `----' pairs with the second, so the title is inside
        (goto-char (point-min))
        (search-forward "Title")
        (expect (car (get-text-property (point) 'adoc-delimited-block)) :to-equal 1)
        ;; and the last one opens a block that never closes
        (goto-char (point-max))
        (insert "\nmore\n----\n")
        (adoc--ensure-block-extents (point-max))
        (goto-char (point-min))
        (search-forward "more")
        (expect (get-text-property (point) 'adoc-delimited-block) :not :to-be nil)))

    (when-fontifying-it "takes a delimiter line in a literal block as content"
      ;; the listing keyword runs first, and used to pair the `----' in the
      ;; literal block with the next listing's opening delimiter
      ("Type:\n\n....\n----\n....\n\n== Next\n\nProse.\n\n----\ncode\n----\n"
       ("Next" adoc-title-1-face)
       ("Prose" nil)
       ("code" adoc-code-face)))

    (it "keeps the block extents right through edits"
      ;; each edit is checked against a fresh scan of the result
      (cl-flet ((extents ()
                  (adoc--ensure-block-extents (point-max))
                  (let (res)
                    (dotimes (i (1- (point-max)))
                      (push (get-text-property (1+ i) 'adoc-delimited-block) res))
                    res))
                (fresh-extents (text)
                  (with-temp-buffer
                    (insert text)
                    (adoc-mode)
                    (adoc--ensure-block-extents (point-max))
                    (let (res)
                      (dotimes (i (1- (point-max)))
                        (push (get-text-property (1+ i) 'adoc-delimited-block) res))
                      res))))
        (dolist (case
                 '(;; yanked text carries the properties of where it came from
                   ("= Doc\n\n----\ncode\n----\n\n== Title\n\n----\nmore\n----\n"
                    (search "code") (yank "pasted "))
                   ;; typing a whole block above others
                   ("Intro.\n\n----\na\n----\n\nText.\n\n----\nb\n----\n\n== Title\n"
                    (search "Intro.\n\n") (type "----\nnew\n----\n\n"))
                   ;; joining a closing delimiter with the next line
                   ("====\na\n====\nmore\n\n== Title\n\n====\nb\n====\n"
                    (line 3) (delete-newline))
                   ;; extending a closing delimiter at the end of the buffer
                   ("++++\ncode\n++++" (end) (type "."))
                   ;; a line turning into a delimiter takes the title above
                   ("text\n.Title\n---\ncode\n----\n" (line 3) (type "-"))))
          (with-temp-buffer
            (insert (car case))
            (adoc-mode)
            (adoc--ensure-block-extents (point-max))
            (goto-char (point-min))
            (dolist (op (cdr case))
              (pcase op
                (`(search ,s) (search-forward s))
                (`(line ,n) (goto-char (point-min)) (forward-line (1- n)) (end-of-line))
                ('(end) (goto-char (point-max)))
                (`(yank ,s) (insert-for-yank
                             (propertize s 'adoc-delimited-block (list 1 1 t))))
                (`(type ,s) (dolist (c (string-to-list s))
                              (insert-and-inherit c)
                              (adoc--ensure-block-extents (line-end-position))))
                ('(delete-newline) (delete-char 1))))
            (expect (extents) :to-equal (fresh-extents (buffer-string)))))))

    (it "starts the block extents over when the settings change"
      (with-temp-buffer
        (insert "Hello\n=====\n\n== Section\n\n=====\ntext\n=====\n")
        (adoc-mode)
        (setq-local adoc-enable-two-line-title t)
        (font-lock-ensure)
        (setq-local adoc-enable-two-line-title nil)
        (adoc-calc)
        (font-lock-flush)
        (font-lock-ensure)
        (goto-char (point-min))
        (search-forward "Section")
        (expect (get-text-property (match-beginning 0) 'face) :to-be nil)))

    (it "fontifies the sample document the same chunk by chunk as in one go"
      (let ((text (with-temp-buffer
                    (insert-file-contents (adoc-test-resource "sample.adoc"))
                    (buffer-string))))
        (dolist (chunk-size '(300 1500))
          (expect (adoc-test-chunked-fontification-difference text chunk-size)
                  :to-be nil)))))

  ;; ---- Tables --------------------------------------------------------

  (describe "tables"
    (when-fontifying-it "fontifies the table delimiter and cell separators"
      ("|===\n|Cell A\n|==="
       ("|===" adoc-table-face)
       ("|" adoc-table-face)))

    (when-fontifying-it "fontifies CSV table delimiters and comma separators"
      (",===\nApple,Red\nGrape,Green\n,==="
       (",===" adoc-table-face)
       ("," adoc-table-face)))

    (when-fontifying-it "fontifies DSV table delimiters and colon separators"
      (":===\nkey:value\n:==="
       (":===" adoc-table-face)
       (":" adoc-table-face)))

    (when-fontifying-it "leaves commas and colons in ordinary prose alone"
      ("See a, b and c"
       ("," nil))
      ("plain: text here"
       (":" nil)))

    (when-fontifying-it "does not let CSV separators bleed into prose between tables"
      (",===\nx,y\n,===\n\nmid, prose\n\n,===\nu,v\n,==="
       (",===" adoc-table-face)
       ("mid" nil)
       ("," nil)))

    ;; An unclosed table must not reach across a paragraph and claim a
    ;; later table's opening delimiter as its own close.
    (when-fontifying-it "does not let an unclosed CSV table swallow a later one"
      (",===\nName,Age\n\nprose, here\n\n,===\nCity,Pop\n,==="
       ("Name" nil)
       ("," nil)
       ("prose" nil)
       ("," nil)
       ("City" nil)
       ("," adoc-table-face))))

  ;; ---- Admonitions ---------------------------------------------------

  (describe "admonitions"
    (when-fontifying-it "fontifies the admonition paragraph label"
      ("NOTE: pay attention"
       ("NOTE:" adoc-complex-replacement-face)))

    (when-fontifying-it "fontifies an admonition after one inside a listing block"
      ("----\nNOTE: x\n----\n\nNOTE: real"
       ("NOTE:" adoc-code-face)
       ("NOTE:" adoc-complex-replacement-face)))

    (when-fontifying-it "fontifies the admonition block label"
      ("[NOTE]"
       ("[NOTE]" adoc-complex-replacement-face))))

  ;; ---- Attributes ----------------------------------------------------

  (describe "attributes"
    (when-fontifying-it "fontifies attribute entries with dedicated faces"
      (":author: Bozhidar"
       (":author:" adoc-metadata-key-face)
       ("Bozhidar" adoc-metadata-value-face)))

    (when-fontifying-it "fontifies attribute references"
      ("see {my-attr} here"
       ("{my-attr}" adoc-replacement-face)))

    (when-fontifying-it "fontifies counter and set reference macros"
      ("Item {counter:items}"
       ("{counter:items}" adoc-replacement-face))
      ("Item {counter2:items}"
       ("{counter2:items}" adoc-replacement-face))
      ("{set:foo:bar} done"
       ("{set:foo:bar}" adoc-replacement-face)))

    (when-fontifying-it "leaves brace-colon prose alone"
      ("Send {type: error} to the server"
       ("{type: error}" nil))))

  ;; ---- Directives ----------------------------------------------------

  (describe "directives"
    (when-fontifying-it "fontifies the include directive"
      ("include::file.adoc[]"
       ("include::" adoc-preprocessor-face)
       ("file.adoc" adoc-meta-face)))

    (when-fontifying-it "fontifies an ifdef conditional with content"
      ("ifdef::env[shown text]"
       ("ifdef::" adoc-preprocessor-face)
       ("env" adoc-meta-face))))

  ;; ---- Breaks and comments -------------------------------------------

  (describe "breaks and comments"
    (when-fontifying-it "fontifies a thematic break (ruler)"
      ("'''" ("'''" adoc-complex-replacement-face)))

    (when-fontifying-it "fontifies a page break"
      ("<<<" ("<<<" adoc-meta-face)))

    (when-fontifying-it "fontifies a hard line break marker"
      ("first line +"
       ("first line " nil)
       ("+" adoc-meta-face)))

    (when-fontifying-it "fontifies a line comment"
      ("// a comment"
       ("// a comment" adoc-comment-face))))

  ;; ---- Macros --------------------------------------------------------

  (describe "macros"
    (when-fontifying-it "fontifies a generic block macro"
      ("lorem::ipsum[]"
       ("lorem" adoc-command-face)))

    (when-fontifying-it "fontifies a generic inline macro"
      ("a mymacro:target[attrs] b"
       ("mymacro" adoc-command-face)
       ("attrs" adoc-value-face)))

    (when-fontifying-it "fontifies image block macros"
      ("image::./foo/bar.png[]"
       ("image" adoc-complex-replacement-face)
       ("./foo/bar.png" adoc-internal-reference-face))
      ;; the first positional attribute is the alt text
      ("image::./foo/bar.png[lorem ipsum]"
       ("lorem ipsum" adoc-secondary-text-face))
      ;; named alt / title attributes
      ("image::./foo/bar.png[alt=lorem,title=dolor]"
       ("alt" adoc-attribute-face)
       ("lorem" adoc-secondary-text-face)
       ("title" adoc-attribute-face)
       ("dolor" adoc-secondary-text-face)))

    (when-fontifying-it "fontifies footnotes"
      ("footnote:[lorem ipsum]"
       ("footnote" adoc-footnote-marker-face)
       ("lorem ipsum" adoc-footnote-text-face)))

    (when-fontifying-it "fontifies UI macros"
      ("kbd:[Ctrl+C]"
       ("kbd" adoc-command-face)
       ("Ctrl+C" adoc-value-face))
      ("btn:[OK]"
       ("btn" adoc-command-face))
      ("menu:File[Save]"
       ("menu" adoc-command-face)
       ("Save" adoc-value-face)))

    (when-fontifying-it "fontifies the icon macro"
      ("icon:heart[2x]"
       ("icon" adoc-command-face)
       ("heart" adoc-internal-reference-face)))

    (when-fontifying-it "fontifies STEM macros"
      ("stem:[x^2]"
       ("stem" adoc-command-face)
       ("x^2" adoc-value-face))
      ("latexmath:[C]"
       ("latexmath" adoc-command-face))
      ("asciimath:[x]"
       ("asciimath" adoc-command-face)))

    (when-fontifying-it "fontifies an indexterm"
      ("(((index term)))"
       ("(((index term)))" adoc-meta-face))))

  ;; ---- Cross references and anchors ----------------------------------

  (describe "cross references and anchors"
    (when-fontifying-it "fontifies an inline xref without a caption"
      ("see <<sect-id>> end"
       ("<<" adoc-meta-hide-face)
       ("sect-id" adoc-reference-face)))

    (when-fontifying-it "fontifies an inline xref with a caption"
      ("see <<sect-id,the caption>> end"
       ("sect-id" adoc-meta-face)
       ("the caption" adoc-reference-face)))

    (when-fontifying-it "fontifies an xref caption with an apostrophe"
      ("<<id,Bob's page>>"
       ("Bob" adoc-reference-face)
       ("s page" adoc-reference-face)))

    (when-fontifying-it "fontifies the xref macro"
      ("xref:foo[]"
       ("xref" adoc-command-face)
       ("foo" adoc-reference-face))
      ("xref:foo[caption]"
       ("foo" adoc-internal-reference-face)
       ("caption" adoc-reference-face)))

    (when-fontifying-it "fontifies a block anchor"
      ("[[foo]]"
       ("[[" adoc-meta-face)
       ("foo" adoc-anchor-face)))

    (when-fontifying-it "fontifies a bibliography anchor"
      ("[[[biblio1]]]"
       ("[[biblio1]]" adoc-value-face)))

    (when-fontifying-it "fontifies the block id shorthand"
      ("[#myid]"
       ("myid" adoc-anchor-face))))

  ;; ---- URLs ----------------------------------------------------------

  (describe "URLs"
    (when-fontifying-it "fontifies a URL macro with a caption"
      ("foo http://www.lorem.com/x.html[sit amet] bar"
       ("http://www.lorem.com/x.html" adoc-url-face)
       ("sit amet" adoc-reference-face)))

    (when-fontifying-it "fontifies a bare URL"
      ("see http://www.lorem.com/x.html here"
       ("http://www.lorem.com/x.html" adoc-url-face)))

    (when-fontifying-it "fontifies links whose text has replacements in it"
      ;; an apostrophe, an ellipsis or an arrow used to stop the link
      ;; from being recognised at all
      ("https://example.org/a[Bob's page]"
       ("https://example.org/a" adoc-url-face)
       ("Bob's page" adoc-reference-face))
      ("https://example.org[A -> B...]"
       ("A -> B..." adoc-reference-face))
      ("see footnote:[it's here] and xref:a.adoc[Bob's]"
       ("it's here" adoc-footnote-text-face)
       ("Bob's" adoc-reference-face)))

    (it "fontifies links whose text has other markup in it"
      (dolist (text '("https://example.org[the *bold* text]"
                      "https://example.org[the `code` text]"))
        (with-temp-buffer
          (insert text)
          (adoc-mode)
          (font-lock-ensure)
          (goto-char (point-min))
          (search-forward "the")
          (expect (get-text-property (point) 'keymap) :to-be 'adoc-link-keymap)
          (expect (get-text-property (match-beginning 0) 'face)
                  :to-equal 'adoc-reference-face))))

    (when-fontifying-it "fontifies a URL with a double dash in it"
      ("https://example.org/a--b[link]"
       ("https://example.org/a--b" adoc-url-face)))

    (when-fontifying-it "ends a bare URL at a bracket"
      ("see https://example.org[oops"
       ("https://example.org" adoc-url-face)
       ("oops" nil)))

    (it "makes a link with an apostrophe in its text clickable"
      (with-temp-buffer
        (insert "https://example.org/a[Bob's page]")
        (adoc-mode)
        (font-lock-ensure)
        (goto-char (point-min))
        (search-forward "Bob")
        (expect (get-text-property (point) 'keymap) :to-be 'adoc-link-keymap))))

  ;; ---- Role-based spans ----------------------------------------------

  (describe "role-based spans"
    (when-fontifying-it "layers the role face over the surrounding quote face"
      ("Lorem [.line-through]#ipsum# dolor"
       ("[.line-through]" adoc-meta-face)
       ("ipsum" (adoc-strike-through-face adoc-highlight-face)))
      ("Lorem [.underline]#ipsum# dolor"
       ("ipsum" (adoc-underline-face adoc-highlight-face)))
      ("Lorem [.overline]#ipsum# dolor"
       ("ipsum" (adoc-overline-face adoc-highlight-face)))))

  ;; ---- Footnote references -------------------------------------------

  (describe "footnote references"
    (when-fontifying-it "fontifies a footnoteref"
      ("footnoteref:[myid]"
       ("footnoteref" adoc-footnote-marker-face)
       ("myid" adoc-internal-reference-face)))

    (when-fontifying-it "fontifies a defining footnoteref with text"
      ("footnoteref:[myid,lorem ipsum]"
       ("myid" adoc-anchor-face)
       ("lorem ipsum" adoc-footnote-text-face))))

  ;; ---- Attribute lists -----------------------------------------------

  (describe "attribute lists"
    (when-fontifying-it "fontifies positional attributes"
      ("[hello]"
       ("hello" adoc-value-face))
      ("[hello world]"
       ("hello world" adoc-value-face))
      ("[hello,world]"
       ("hello" adoc-value-face)
       ("world" adoc-value-face))))

  ;; ---- Nested quotes / meta-face cleanup -----------------------------

  (describe "nested quotes"
    (when-fontifying-it "applies both faces to text nested in two quotes"
      ;; the inner text gets both faces; the meta delimiters stay meta-hide
      ("*lorem _ipsum_ dolor*"
       ("lorem " adoc-bold-face)
       ("ipsum" (adoc-bold-face adoc-emphasis-face)))
      ("_lorem *ipsum* dolor_"
       ("ipsum" (adoc-bold-face adoc-emphasis-face)))))

  ;; ---- URLs enclosed in a quote --------------------------------------

  (describe "URL enclosed in a quote"
    (when-fontifying-it "layers the quote face over the URL face"
      ("foo __ http://www.lorem.com/x.html __"
       ("http://www.lorem.com/x.html" (adoc-emphasis-face adoc-url-face)))))

  ;; ---- Native code-block fontification -------------------------------

  (describe "native code blocks"
    (it "fontifies a source block with the language's major mode"
      (with-temp-buffer
        (insert "[source,adoctest-lang]\n----\nif\n----\n")
        (adoc-mode)
        (font-lock-ensure)
        (goto-char (point-min))
        (search-forward "if")
        (expect (adoc-test-face-at-range (match-beginning 0) (1- (match-end 0)))
                :to-equal '(font-lock-keyword-face adoc-native-code-face))))

    (it "fontifies a plain source block as verbatim code"
      (with-temp-buffer
        (insert "[source]\n----\nif\n----\n")
        (adoc-mode)
        (font-lock-ensure)
        (goto-char (point-min))
        (search-forward "if")
        (expect (adoc-test-face-at-range (match-beginning 0) (1- (match-end 0)))
                :to-equal '(adoc-verbatim-face adoc-code-face)))))

  ;; ---- Language -> major mode resolution -----------------------------

  (describe "language mode resolution"
    (it "uses a single mapped mode"
      (let ((adoc-code-lang-modes '(("demo" . emacs-lisp-mode))))
        (expect (adoc-get-lang-mode "demo") :to-equal 'emacs-lisp-mode)))

    (it "tries a list of candidate modes in order, first defined wins"
      (let ((adoc-code-lang-modes
             '(("demo" . (adoc-no-such-mode-1 adoc-no-such-mode-2 emacs-lisp-mode)))))
        (expect (adoc-get-lang-mode "demo") :to-equal 'emacs-lisp-mode)))

    (it "falls back to <lang>-mode when there is no mapping"
      (expect (adoc-get-lang-mode "emacs-lisp") :to-equal 'emacs-lisp-mode))

    (it "returns nil when no candidate mode is available"
      (let ((adoc-code-lang-modes '(("demo" . (adoc-no-such-mode-1 adoc-no-such-mode-2)))))
        (expect (adoc-get-lang-mode "demo") :to-be nil))))

  ;; ---- Character replacements (display overlays) ---------------------

  (describe "character replacements"
    (it "renders replacement overlays for symbols and arrows"
      (let ((adoc-insert-replacement t))
        (unwind-protect
            (progn
              (adoc-calc)
              (dolist (case '(("(C)" . "©") ("(R)" . "®") ("(TM)" . "™")
                              ("..." . "…") ("->" . "→") ("=>" . "⇒")
                              ("<-" . "←") ("<=" . "⇐")))
                (with-temp-buffer
                  (adoc-mode)
                  (insert (car case))
                  (font-lock-ensure)
                  (let ((ov (seq-find (lambda (o) (overlay-get o 'after-string))
                                      (overlays-in (point-min) (point-max)))))
                    (expect ov :not :to-be nil)
                    (expect (overlay-get ov 'after-string) :to-equal (cdr case))))))
          (adoc-calc))))

    (it "doesn't put replacement overlays in link text or URLs"
      (let ((adoc-insert-replacement t))
        (unwind-protect
            (progn
              (adoc-calc)
              (with-temp-buffer
                (adoc-mode)
                (insert "https://example.org/a--b[Bob's page]")
                (font-lock-ensure)
                (expect (seq-filter (lambda (o) (overlay-get o 'adoc-kw-replacement))
                                    (overlays-in (point-min) (point-max)))
                        :to-be nil)))
          (adoc-calc))))))

;;; adoc-mode-font-lock-test.el ends here
