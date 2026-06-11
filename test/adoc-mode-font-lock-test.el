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
      ("****\nsidebar\n****" ("sidebar" adoc-secondary-text-face))))

  ;; ---- Tables --------------------------------------------------------

  (describe "tables"
    (when-fontifying-it "fontifies the table delimiter and cell separators"
      ("|===\n|Cell A\n|==="
       ("|===" adoc-table-face)
       ("|" adoc-table-face))))

  ;; ---- Admonitions ---------------------------------------------------

  (describe "admonitions"
    (when-fontifying-it "fontifies the admonition paragraph label"
      ("NOTE: pay attention"
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
       ("{my-attr}" adoc-replacement-face))))

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
       ("http://www.lorem.com/x.html" adoc-url-face))))

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
          (adoc-calc))))))

;;; adoc-mode-font-lock-test.el ends here
