;;; adoc-mode-test.el --- test suite for adoc-mode.el
;;;
;;; Commentary:
;;
;; Call adoc-test-run to run the test suite
;;
;;; Todo:
;; - test for font lock multiline property
;; - test for presence of adoc-reserved (we do white-box testing here)
;; - test also with multiple versions of (X)Emacs
;; - compare adoc-mode fontification with actuall output from AsciiDoc, being
;;   almost the ultimative test for correctness
;;

;;; Code:
(require 'ert)
(require 'adoc-mode)

;; todo:
;; - auto-create different contexts like
;;   - beginning/end of buffer
;;   - beginning/end of paragraph
;;   - side-to-side yes/no with next same construct
(defun adoctest-faces (name &rest args)
  "Todo document adoctest-faces NAME ARGS."
  (let ((not-done t)
	(font-lock-support-mode))
    (with-temp-buffer
      ;; setup
      (while args
	(insert (propertize (car args) 'adoctest (cadr args)))
	(setq args (cddr args)))

      ;; exercise
      (adoc-mode)
      (font-lock-fontify-buffer)

      ;; verify
      (goto-char (point-min))
      (while not-done
	(let* ((tmp (get-text-property (point) 'adoctest))
	       (tmp2 (get-text-property (point) 'face)))
	  (cond
	   ((null tmp)) ; nop
	   ((eq tmp 'no-face)
	    (should (null tmp2)))
	   (t
	    (if (and (listp tmp2) (not (listp tmp)))
		(should (and (= 1 (length tmp2)) (equal tmp (car tmp2))))
	      (should (equal tmp tmp2)))))
	  (if (< (point) (point-max))
	      (forward-char 1)
	    (setq not-done nil)))))))

(defun adoctest-trans (original-text expected-text transform)
  "Calling TRANSFORM on ORIGINAL-TEXT `should' result in EXPECTED-TEXT.
ORIGINAL-TEXT is put in an temporary buffer and TRANSFORM is
evaluated using `eval'.  The resulting buffer content is compared
to EXPECTED-TEXT.

ORIGINAL-TEXT optionaly may contain the following special
charachters.  Escaping them is not (yet) supported.  They are
removed before TRANSFORM is evaluated.

!  Position of point before TRANSFORM is evaluated

<> Position of mark (<) and point (>) before TRANSFORM is
   evaluatred"
  (if (string-match "[!<>]" original-text)
      ;; original-text has ! markers
      (let ((pos 0)      ; pos in original-text
	    (pos-old 0)	 ; pos of the last iteration
	    (pos-in-new-region-start 0)
	    (pos-new-list) ; list of positions in new-original-text
	    (new-original-text "")) ; as original-text, but with < > ! stripped
	;; original-text -> new-original-text by removing ! and remembering their positions
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
	;; run adoctest-trans-inner for each remembered pos
	(while pos-new-list
	  (adoctest-trans-inner new-original-text expected-text transform (car pos-new-list))
	  (setq pos-new-list (cdr pos-new-list))))
    ;; original-text has no ! markers
    (adoctest-trans-inner original-text expected-text transform)))

(defun adoctest-trans-inner (original-text expected-text transform &optional pos)
  "Todo document adoctest-trans-inner ORIGINAL-TEXT EXPECTED-TEXT TRANSFORM POS."
  (let ((not-done t)
	(font-lock-support-mode))
    (with-temp-buffer
      ;; setup
      (adoc-mode)
      (insert original-text)
      (cond ; 1+: buffer pos starts at 1, but string pos at 0
       ((consp pos)
	(goto-char (1+ (car pos)))
	(set-mark (1+ (cdr pos))))
       (pos
	(goto-char (1+ pos))))
      ;; exercise
      (eval transform)
      ;; verify
      (should (string-equal (buffer-substring (point-min) (point-max)) expected-text)))))

(ert-deftest adoctest-test-titles-simple-one-line-before ()
  (adoctest-faces "titles-simple-one-line-before"
   "= " markup-meta-hide-face "document title" markup-title-0-face "\n" nil
   "\n" nil
   "== " markup-meta-hide-face "chapter 1" markup-title-1-face "\n" nil
   "\n" nil
   "=== " markup-meta-hide-face "chapter 2" markup-title-2-face "\n" nil
   "\n" nil
   "==== " markup-meta-hide-face "chapter 3" markup-title-3-face "\n" nil
   "\n" nil
   "===== " markup-meta-hide-face "chapter 4" markup-title-4-face))

(ert-deftest adoctest-test-titles-simple-one-line-enclosed ()
  (adoctest-faces "titles-simple-one-line-enclosed"
   "= " markup-meta-hide-face "document title" markup-title-0-face " =" markup-meta-hide-face "\n" nil
   "\n" nil
   "== " markup-meta-hide-face "chapter 1" markup-title-1-face " ==" markup-meta-hide-face "\n" nil
   "\n" nil
   "=== " markup-meta-hide-face "chapter 2" markup-title-2-face " ===" markup-meta-hide-face "\n" nil
   "\n" nil
   "==== " markup-meta-hide-face "chapter 3" markup-title-3-face " ====" markup-meta-hide-face "\n" nil
   "\n" nil
   "===== " markup-meta-hide-face "chapter 4" markup-title-4-face " =====" markup-meta-hide-face))

(ert-deftest adoctest-test-titles-simple-two-line ()
  (adoctest-faces "titles-simple-two-line"
   ;; todo
   ;; ensure somehow adoc-enable-two-line-title is t
   "document title" markup-title-0-face "\n" nil
   "==============" markup-meta-hide-face "\n" nil
   "\n" nil
   "chapter 1" markup-title-1-face "\n" nil
   "---------" markup-meta-hide-face "\n" nil
   "\n" nil
   "chapter 2" markup-title-2-face "\n" nil
   "~~~~~~~~~" markup-meta-hide-face "\n" nil
   "\n" nil
   "chapter 3" markup-title-3-face "\n" nil
   "^^^^^^^^^" markup-meta-hide-face "\n" nil
   "\n" nil
   "chapter 4" markup-title-4-face "\n" nil
   "+++++++++" markup-meta-hide-face))

(ert-deftest adoctest-test-titles-simple-block-title ()
  (adoctest-faces "titles-simple-block-title"
   "." markup-meta-face "Block title" markup-gen-face))

(ert-deftest adoctest-test-delimited-blocks-simple ()
  (adoctest-faces "delimited-blocks-simple"

   ;; note that the leading spaces are NOT allowed to have adoc-align face
   "////////" markup-meta-hide-face "\n" nil
   " comment line 1\n comment line 2" markup-comment-face "\n" nil
   "////////" markup-meta-hide-face "\n" nil
   "\n" nil
   "++++++++" markup-meta-hide-face "\n" nil
   " passthrouh line 1\n passthrouh line 2" markup-passthrough-face "\n" nil
   "++++++++" markup-meta-hide-face "\n" nil
   "\n" nil
   "--------" markup-meta-hide-face "\n" nil
   " listing line 1\n listing line 2" markup-code-face "\n" nil
   "--------" markup-meta-hide-face "\n" nil
   "\n" nil
   "........" markup-meta-hide-face "\n" nil
   " literal line 1\n literal line 2" markup-verbatim-face "\n" nil
   "........" markup-meta-hide-face "\n" nil
   "\n" nil

   "________" markup-meta-hide-face "\n" nil
   "quote line 1\nquote line 2" nil "\n" nil
   "________" markup-meta-hide-face "\n" nil
   "\n" nil
   "========" markup-meta-hide-face "\n" nil
   "example line 1\nexample line 2" nil "\n" nil
   "========" markup-meta-hide-face "\n" nil
   "\n" nil
   "********" markup-meta-hide-face "\n" nil
   "sidebar line 1\nsidebar line 2" markup-secondary-text-face "\n" nil
   "********" markup-meta-hide-face "\n"))

;; Don't mistake text between two same delimited blocks as a delimited block,
;; i.e. wrongly treating the end of block 1 as a beginning and wrongly
;; treating the beginning of block 2 as ending.
(ert-deftest adoctest-test-delimited-blocks-simple ()
  (adoctest-faces "delimited-blocks-special-case"

   "--------" markup-meta-hide-face "\n" nil
   "11\n12\n13\n14" markup-code-face "\n" nil
   "--------" markup-meta-hide-face "\n" nil
   "\n" nil
   "lorem" 'no-face "\n" nil
   "\n" nil
   "--------" markup-meta-hide-face "\n" nil
   "21\n22\n23\n24" markup-code-face "\n" nil
   "--------" markup-meta-hide-face "\n" nil
   "\n" nil
   "ipsum" 'no-face "\n" nil))

(ert-deftest adoctest-test-delimited-blocks-simple ()
  (adoctest-faces "delimited-blocks-empty"
    "////////" markup-meta-hide-face "\n" nil
    "////////" markup-meta-hide-face "\n" nil
    "\n" nil
    "++++++++" markup-meta-hide-face "\n" nil
    "++++++++" markup-meta-hide-face "\n" nil
    "\n" nil
    "--------" markup-meta-hide-face "\n" nil
    "--------" markup-meta-hide-face "\n" nil
    "\n" nil
    "........" markup-meta-hide-face "\n" nil
    "........" markup-meta-hide-face "\n" nil
    "\n" nil
    "________" markup-meta-hide-face "\n" nil
    "________" markup-meta-hide-face "\n" nil
    "\n" nil
    "========" markup-meta-hide-face "\n" nil
    "========" markup-meta-hide-face "\n" nil
    "\n" nil
    "********" markup-meta-hide-face "\n" nil
    "********" markup-meta-hide-face "\n"))

(ert-deftest adoctest-test-open-block ()
  (adoctest-faces "open-block"
   "--" markup-meta-hide-face "\n" nil
   "open block line 1\nopen block line 2" nil "\n" nil
   "--" markup-meta-hide-face))

(ert-deftest adoctest-test-comments ()
  (adoctest-faces "comments"
    ;; as block macro
    "// lorem ipsum\n" markup-comment-face
    "\n" nil
    ;; as inline macro
    "lorem ipsum\n" 'no-face
    "// dolor sit\n" markup-comment-face
    "amen\n" 'no-face
    "\n" nil
    ;; block macro and end of buffer
    "// lorem ipsum" markup-comment-face
    ;; as delimited block it's tested in delimited-blocks-simple
    ))

(ert-deftest adoctest-test-anchors ()
  (adoctest-faces "anchors"
    ;; block id
    "[[" markup-meta-face "foo" markup-anchor-face "]]" markup-meta-face "\n" nil
    "[[" markup-meta-face "foo" markup-anchor-face "," markup-meta-face
      "bar" markup-secondary-text-face "]]" markup-meta-face "\n" nil

    ;; special inline syntax: [[id]] [[id,xreftext]]
    "lorem " 'no-face "[[" markup-meta-face "foo" markup-anchor-face "]]"
      markup-meta-face "ipsum" 'no-face "\n" nil
    "lorem " 'no-face "[[" markup-meta-face "foo" markup-anchor-face "," markup-meta-face
      "bla bli bla blu" markup-secondary-text-face "]]" markup-meta-face "ipsum" 'no-face "\n" nil

    ;; general inline macro syntax
    "lorem " 'no-face "anchor" markup-command-face ":" markup-meta-face
      "foo" markup-anchor-face
      "[]" markup-meta-face "ipsum" 'no-face "\n" nil
    "lorem " 'no-face "anchor" markup-command-face ":" markup-meta-face
      "foo" markup-anchor-face
      "[" markup-meta-face "bla bli bla blu" markup-secondary-text-face "]" markup-meta-face
      "ipsum" 'no-face "\n" nil

    ;; biblio
    "lorem " 'no-face "[[" markup-meta-face "[foo]" markup-gen-face "]]" markup-meta-face
      " ipsum" 'no-face
    ))

(ert-deftest adoctest-test-references ()
  (adoctest-faces "references"
     "lorem " 'no-face "xref" markup-command-face ":" markup-meta-face
       "foo" markup-reference-face "[]" markup-meta-face "\n" nil
     "lorem " 'no-face "xref" markup-command-face ":" markup-meta-face
       "foo" markup-internal-reference-face "[" markup-meta-face
       "bla bli bla blu" markup-reference-face "]" markup-meta-face "\n" nil

     ;; caption spawns multiple lines
     "xref" markup-command-face ":" markup-meta-face
       "foo" markup-internal-reference-face "[" markup-meta-face
       "bla\nbli\nbla\nblu" markup-reference-face "]" markup-meta-face "\n" nil
       ))

(ert-deftest adoctest-test-footnotes ()
  (adoctest-faces "footnotes"
     ;; simple example
     "footnote" markup-command-face ":" markup-meta-face
     "[" markup-meta-face "lorem ipsum" markup-secondary-text-face
     "]" markup-meta-face "\n" nil

     ;; footnote can be hard up against the preceding word
     "lorem" 'no-face "footnote" markup-command-face ":" markup-meta-face
     "[" markup-meta-face "ipsum" markup-secondary-text-face
     "]" markup-meta-face "\n" nil

     ;; attribute-list is not really an attribute list but normal text,
     ;; i.e. comma, equal, double quotes are not fontified as meta characters
     "footnote" markup-command-face ":" markup-meta-face
     "[" markup-meta-face
     "lorem, ipsum=dolor, sit=\"amen\"" markup-secondary-text-face
     "]" markup-meta-face "\n" nil

     ;; multiline attribute list
     "footnote" markup-command-face ":" markup-meta-face
     "[" markup-meta-face
     "lorem\nipsum\ndolor\nsit\namen" markup-secondary-text-face
     "]" markup-meta-face "\n" nil
     ))

(ert-deftest adoctest-test-footnoterefs ()
  (adoctest-faces "footnoterefs"
     ;; simple example
     "footnoteref" markup-command-face ":" markup-meta-face
     "[" markup-meta-face
     "myid" markup-internal-reference-face
     "]" markup-meta-face "\n" nil

     "footnoteref" markup-command-face ":" markup-meta-face
     "[" markup-meta-face
     "myid" markup-anchor-face
     "," markup-meta-face
     "lorem ipsum" markup-secondary-text-face
     "]" markup-meta-face "\n" nil

     ;; footnoteref can be hard up against the preceding word
     "lorem" 'no-face
     "footnoteref" markup-command-face ":" markup-meta-face
     "[" markup-meta-face
     "myid" markup-internal-reference-face
     "]" markup-meta-face "\n" nil

     "lorem" 'no-face
     "footnoteref" markup-command-face ":" markup-meta-face
     "[" markup-meta-face
     "myid" markup-anchor-face
     "," markup-meta-face
     "lorem ipsum" markup-secondary-text-face
     "]" markup-meta-face "\n" nil

     ;; multiline text
     "lorem" 'no-face
     "footnoteref" markup-command-face ":" markup-meta-face
     "[" markup-meta-face
     "myid" markup-anchor-face
     "," markup-meta-face
     "lorem\nipsum\ndolor\nsit" markup-secondary-text-face
     "]" markup-meta-face "\n" nil
     ))

(ert-deftest adoctest-test-images ()
  (adoctest-faces "images"
     ;; block macros
     ;; empty arglist
     "image" markup-complex-replacement-face "::" markup-meta-face
       "./foo/bar.png" markup-internal-reference-face
       "[]" markup-meta-face "\n" nil
     ;; pos attribute 0 = alternate text
     "image" markup-complex-replacement-face "::" markup-meta-face
       "./foo/bar.png" markup-internal-reference-face
       "[" markup-meta-face "lorem ipsum" markup-secondary-text-face "]" markup-meta-face "\n" nil
     ;; keyword title
     "image" markup-complex-replacement-face "::" markup-meta-face
       "./foo/bar.png" markup-internal-reference-face
       "[" markup-meta-face "alt" markup-attribute-face "=" markup-meta-face "lorem ipsum" markup-secondary-text-face "]" markup-meta-face "\n" nil
     ;; keyword alt and title
     "image" markup-complex-replacement-face "::" markup-meta-face
       "./foo/bar.png" markup-internal-reference-face
       "[" markup-meta-face "alt" markup-attribute-face "=" markup-meta-face "lorem ipsum" markup-secondary-text-face "," markup-meta-face
       "title" markup-attribute-face "=" markup-meta-face "lorem ipsum" markup-secondary-text-face "]" markup-meta-face "\n" nil
     ;; multiline alt and title
     "image" markup-complex-replacement-face "::" markup-meta-face
       "./foo/bar.png" markup-internal-reference-face
       "[" markup-meta-face "alt" markup-attribute-face "=" markup-meta-face
       "lorem\nipsum\nsit" markup-secondary-text-face "," markup-meta-face
       "title" markup-attribute-face "=" markup-meta-face
       "lorem\nipsum\nsit" markup-secondary-text-face "]" markup-meta-face "\n" nil

     ;; no everything again with inline macros
     "foo " 'no-face "image" markup-complex-replacement-face ":" markup-meta-face
       "./foo/bar.png" markup-internal-reference-face
       "[]" markup-meta-face "bar" 'no-face "\n" nil

     "foo " 'no-face "image" markup-complex-replacement-face ":" markup-meta-face
       "./foo/bar.png" markup-internal-reference-face
       "[" markup-meta-face "lorem ipsum" markup-secondary-text-face "]" markup-meta-face "bar" 'no-face "\n" nil

     "foo " 'no-face "image" markup-complex-replacement-face ":" markup-meta-face
       "./foo/bar.png" markup-internal-reference-face
       "[" markup-meta-face "alt" markup-attribute-face "=" markup-meta-face "lorem ipsum" markup-secondary-text-face "]" markup-meta-face "bar" 'no-face "\n" nil

     "foo " 'no-face "image" markup-complex-replacement-face ":" markup-meta-face
       "./foo/bar.png" markup-internal-reference-face
       "[" markup-meta-face "alt" markup-attribute-face "=" markup-meta-face "lorem ipsum" markup-secondary-text-face "," markup-meta-face
       "title" markup-attribute-face "=" markup-meta-face "lorem ipsum" markup-secondary-text-face "]" markup-meta-face "bar" 'no-face "\n" nil

     "image" markup-complex-replacement-face ":" markup-meta-face
       "./foo/bar.png" markup-internal-reference-face
       "[" markup-meta-face "alt" markup-attribute-face "=" markup-meta-face
       "lorem\nipsum\nsit" markup-secondary-text-face "," markup-meta-face
       "title" markup-attribute-face "=" markup-meta-face
       "lorem\nipsum\nsit" markup-secondary-text-face "]" markup-meta-face "\n" nil))

(ert-deftest adoctest-test-attribute-list ()
  (adoctest-faces "attribute-list"
    ;; positional attribute
    "[" markup-meta-face "hello" markup-value-face "]" markup-meta-face "\n" nil
    ;; positional attribute containing spaces
    "[" markup-meta-face "hello world" markup-value-face "]" markup-meta-face "\n" nil
    ;; positional attribute as string
    "[\"" markup-meta-face  "hello world" markup-value-face "\"]" markup-meta-face "\n" nil

    ;; multiple positional attributes
    "[" markup-meta-face "hello" markup-value-face "," markup-meta-face "world" markup-value-face "]" markup-meta-face "\n" nil

    ;; multiple positional attributes, however one or both are empty (really empty or only one space)
    "[" markup-meta-face "hello" markup-value-face ",]" markup-meta-face "\n" nil
    "[" markup-meta-face "hello" markup-value-face "," markup-meta-face " " markup-value-face "]" markup-meta-face "\n" nil
    "[," markup-meta-face "hello" markup-value-face "]" markup-meta-face "\n" nil
    "[" markup-meta-face " " markup-value-face "," markup-meta-face "hello" markup-value-face "]" markup-meta-face "\n" nil
    "[,]" markup-meta-face "\n" nil
    "[," markup-meta-face " " markup-value-face "]" markup-meta-face "\n" nil
    "[" markup-meta-face " " markup-value-face ",]" markup-meta-face "\n" nil
    "[" markup-meta-face " " markup-value-face "," markup-meta-face " " markup-value-face "]" markup-meta-face "\n" nil

    ;; zero positional attributes
    "[]" markup-meta-face "\n" nil
    "[" markup-meta-face " " markup-value-face "]" markup-meta-face "\n" nil

    ;; keyword attribute
    "[" markup-meta-face "salute" markup-attribute-face "=" markup-meta-face "hello" markup-value-face "]" markup-meta-face "\n" nil
    ;; keyword attribute where value is a string
    "[" markup-meta-face "salute" markup-attribute-face "=\"" markup-meta-face "hello world" markup-value-face "\"]" markup-meta-face "\n" nil

    ;; multiple positional attributes, multiple keyword attributes
    "[" markup-meta-face "lorem" markup-value-face "," markup-meta-face "ipsum" markup-value-face "," markup-meta-face
        "dolor" markup-attribute-face "=" markup-meta-face "sit" markup-value-face "," markup-meta-face
        "dolor" markup-attribute-face "=" markup-meta-face "sit" markup-value-face "]" markup-meta-face "\n" nil

    ;; is , within strings really part of the string and not mistaken as element separator
    "[\"" markup-meta-face "lorem,ipsum=dolor" markup-value-face "\"]" markup-meta-face "\n" nil
    ;; does escaping " in strings work
    "[\"" markup-meta-face "lorem \\\"ipsum\\\" dolor" markup-value-face "\"]" markup-meta-face
    ))

(ert-deftest adoctest-test-block-macro ()
  (adoctest-faces "block-macro"
    "lorem" markup-command-face "::" markup-meta-face "ipsum[]" markup-meta-face))

(ert-deftest adoctest-test-quotes-simple ()
  (adoctest-faces "test-quotes-simple"
   ;; note that in unconstraned quotes cases " ipsum " has spaces around, in
   ;; constrained quotes case it doesn't
   "Lorem " nil "`" markup-meta-hide-face "ipsum" '(markup-typewriter-face markup-verbatim-face) "`" markup-meta-hide-face " dolor\n" nil
   "Lorem " nil "+++" markup-meta-hide-face " ipsum " '(markup-typewriter-face markup-verbatim-face) "+++" markup-meta-hide-face " dolor\n" nil
   "Lorem " nil "$$" markup-meta-hide-face " ipsum " '(markup-typewriter-face markup-verbatim-face) "$$" markup-meta-hide-face " dolor\n" nil
   "Lorem " nil "**" markup-meta-hide-face " ipsum " markup-strong-face "**" markup-meta-hide-face " dolor\n" nil
   "Lorem " nil "*" markup-meta-hide-face "ipsum" markup-strong-face "*" markup-meta-hide-face " dolor\n" nil
   "Lorem " nil "``" markup-replacement-face "ipsum" nil "''" markup-replacement-face " dolor\n" nil
   "Lorem " nil "'" markup-meta-hide-face "ipsum" markup-emphasis-face "'" markup-meta-hide-face " dolor\n" nil
   "Lorem " nil "`" markup-replacement-face "ipsum" nil "'" markup-replacement-face " dolor\n" nil
   "Lorem " nil "++" markup-meta-hide-face " ipsum " markup-typewriter-face "++" markup-meta-hide-face " dolor\n" nil
   "Lorem " nil "+" markup-meta-hide-face "ipsum" markup-typewriter-face "+" markup-meta-hide-face " dolor\n" nil
   "Lorem " nil "__" markup-meta-hide-face " ipsum " markup-emphasis-face "__" markup-meta-hide-face " dolor\n" nil
   "Lorem " nil "_" markup-meta-hide-face "ipsum" markup-emphasis-face "_" markup-meta-hide-face " dolor\n" nil
   "Lorem " nil "##" markup-meta-hide-face " ipsum " markup-gen-face "##" markup-meta-hide-face " dolor\n" nil
   "Lorem " nil "#" markup-meta-hide-face "ipsum" markup-gen-face "#" markup-meta-hide-face " dolor\n" nil
   "Lorem " nil "~" markup-meta-hide-face " ipsum " markup-subscript-face "~" markup-meta-hide-face " dolor\n" nil
   "Lorem " nil "^" markup-meta-hide-face " ipsum " markup-superscript-face "^" markup-meta-hide-face " dolor"))

(ert-deftest adoctest-test-quotes-medium ()
  (adoctest-faces "test-quotes-medium"
   ;; test wheter constrained/unconstrained quotes can spawn multiple lines
   "Lorem " 'no-face "*" markup-meta-hide-face "ipsum" markup-strong-face
   "\n" nil "dolor" markup-strong-face "\n" nil "dolor" markup-strong-face
   "\n" nil "dolor" markup-strong-face "\n" nil "dolor" markup-strong-face
   "*" markup-meta-hide-face
   " sit" 'no-face "\n" nil

   "Lorem " 'no-face "__" markup-meta-hide-face "ipsum" markup-emphasis-face
   "\n" nil "dolor" markup-emphasis-face "\n" nil "dolor" markup-emphasis-face
   "\n" nil "dolor" markup-emphasis-face "\n" nil "dolor" markup-emphasis-face
   "__" markup-meta-hide-face
   " sit" 'no-face "\n" nil

   ;; tests border case that delimiter is at the beginnin/end of an paragraph/line
   ;; constrained at beginning
   "*" markup-meta-hide-face "lorem" 'markup-strong-face "*" markup-meta-hide-face " ipsum\n" 'no-face
   "\n" nil
   ;; constrained at end
   "lorem " 'no-face "*" markup-meta-hide-face "ipsum" markup-strong-face "*" markup-meta-hide-face "\n" nil
   "\n" nil
   ;; constrained from beginning to end
   "*" markup-meta-hide-face "lorem" markup-strong-face "*" markup-meta-hide-face "\n" nil
   "\n" nil
   ;; unconstrained at beginning. Note that "** " at the beginning of a line would be a list item.
   "__" markup-meta-hide-face " lorem " 'markup-emphasis-face "__" markup-meta-hide-face " ipsum\n" 'no-face
   "\n" nil
   ;; unconstrained at end
   "lorem " 'no-face "__" markup-meta-hide-face " ipsum " markup-emphasis-face "__" markup-meta-hide-face "\n" nil
   "\n" nil
   ;; unconstrained from beginning to end
   "__" markup-meta-hide-face " lorem " markup-emphasis-face "__" markup-meta-hide-face "\n" nil
   "\n" nil
   
   ;; test wheter quotes can nest
   ;; done by meta-face-cleanup

   ;; tests that quotes work within titles / labeled lists
   "== " markup-meta-hide-face "chapter " markup-title-1-face "*" markup-meta-hide-face "1" '(markup-title-1-face markup-strong-face) "*" markup-meta-hide-face " ==" markup-meta-hide-face "\n" nil
   "\n" nil
   "chapter " markup-title-2-face "_" markup-meta-hide-face "2" '(markup-title-2-face markup-emphasis-face) "_" markup-meta-hide-face "\n" nil
   "~~~~~~~~~~~" markup-meta-hide-face "\n" nil
   "." markup-meta-face "lorem " 'markup-gen-face "_" markup-meta-hide-face "ipsum" '(markup-gen-face markup-emphasis-face) "_" markup-meta-hide-face "\n" nil
   "\n" nil
   "lorem " markup-gen-face "+" markup-meta-hide-face "ipsum" '(markup-gen-face markup-typewriter-face) "+" markup-meta-hide-face " sit" markup-gen-face "::" markup-list-face " " adoc-align
   ))

;; test border cases where the quote delimiter is at the beginning and/or the
;; end of the buffer
(ert-deftest adoctest-test-quotes-medium-2 ()
  (adoctest-faces "test-quotes-medium-2"
    "*" markup-meta-hide-face "lorem" markup-strong-face "*" markup-meta-hide-face " ipsum" 'no-face))
(ert-deftest adoctest-test-quotes-medium-3 ()
  (adoctest-faces "test-quotes-medium-3"
    "lorem " 'no-face "*" markup-meta-hide-face "ipsum" markup-strong-face "*" markup-meta-hide-face))
(ert-deftest adoctest-test-quotes-medium-4 ()
  (adoctest-faces "test-quotes-medium-4"
    "*" markup-meta-hide-face "lorem" markup-strong-face "*" markup-meta-hide-face))

(ert-deftest adoctest-test-lists-simple ()
  (adoctest-faces "test-lists-simple"
   " " adoc-align "-" markup-list-face " " adoc-align "uo list item\n" nil
   " " adoc-align "*" markup-list-face " " adoc-align "uo list item\n" nil
   " " adoc-align "**" markup-list-face " " adoc-align "uo list item\n" nil
   " " adoc-align "***" markup-list-face " " adoc-align "uo list item\n" nil
   " " adoc-align "****" markup-list-face " " adoc-align "uo list item\n" nil
   " " adoc-align "*****" markup-list-face " " adoc-align "uo list item\n" nil
   "+" markup-list-face " " adoc-align "uo list item\n" nil

   " " adoc-align "1." markup-list-face " " adoc-align "o list item\n" nil
   " " adoc-align "a." markup-list-face " " adoc-align "o list item\n" nil
   " " adoc-align "B." markup-list-face " " adoc-align "o list item\n" nil
   " " adoc-align "ii)" markup-list-face " " adoc-align "o list item\n" nil
   " " adoc-align "II)" markup-list-face " " adoc-align "o list item\n" nil

   " " adoc-align "." markup-list-face " " adoc-align "implicitly numbered list item\n" nil
   " " adoc-align ".." markup-list-face " " adoc-align "implicitly numbered list item\n" nil
   " " adoc-align "..." markup-list-face " " adoc-align "implicitly numbered list item\n" nil
   " " adoc-align "...." markup-list-face " " adoc-align "implicitly numbered list item\n" nil
   " " adoc-align "....." markup-list-face " " adoc-align "implicitly numbered list item\n" nil
   "<1>" markup-list-face " " adoc-align "callout\n" nil
   "1>" markup-list-face " " adoc-align "callout\n" nil

   " " adoc-align "term" markup-gen-face "::" markup-list-face " " adoc-align "lorem ipsum\n" nil
   " " adoc-align "term" markup-gen-face ";;" markup-list-face " " adoc-align "lorem ipsum\n" nil
   " " adoc-align "term" markup-gen-face ":::" markup-list-face " " adoc-align "lorem ipsum\n" nil
   " " adoc-align "term" markup-gen-face "::::" markup-list-face " " adoc-align "lorem ipsum\n" nil
   " " adoc-align "question" markup-gen-face "??" markup-list-face "\n" nil
   "glossary" markup-gen-face ":-" markup-list-face "\n" nil

   "-" markup-list-face " " adoc-align "uo list item\n" nil
   "+" markup-meta-face "\n" nil
   "2nd list paragraph\n" nil ))

(ert-deftest adoctest-test-lists-medium ()
  (adoctest-faces "test-lists-medium"
   ;; white box test: labeled list item font lock keyword is implemented
   ;; specially in that it puts adoc-reserved text-property on the preceding
   ;; newline. However it shall deal with the situation that there is no
   ;; preceding newline, because we're at the beginning of the buffer
   "lorem" markup-gen-face "::" markup-list-face " " nil "ipsum" 'no-face))

(ert-deftest adoctest-test-inline-macros ()
  (adoctest-faces "inline-macros"
    "commandname" markup-command-face ":target[" markup-meta-face "attribute list" markup-value-face "]" markup-meta-face))

(ert-deftest adoctest-test-meta-face-cleanup ()
  ;; begin with a few simple explicit cases which are easier to debug in case of troubles

  ;; 1) test that meta characters always only have a single meta and don't get
  ;;    markup-bold/-emphasis/... face just because they are within a
  ;;    strongh/emphasis/... construct.
  ;; 2) test that nested quotes really apply the faces of both quotes to the inner text
  (adoctest-faces "meta-face-cleanup-1"
    "*" markup-meta-hide-face "lorem " markup-strong-face
        "_" markup-meta-hide-face "ipsum" '(markup-strong-face markup-emphasis-face) "_" markup-meta-hide-face
    " dolor" markup-strong-face "*" markup-meta-hide-face "\n" nil)
  (adoctest-faces "meta-face-cleanup-2"
    "_" markup-meta-hide-face "lorem " markup-emphasis-face
        "*" markup-meta-hide-face "ipsum" '(markup-strong-face markup-emphasis-face) "*" markup-meta-hide-face
    " dolor" markup-emphasis-face "_" markup-meta-hide-face)

  ;; now test all possible cases
  ;; mmm, that is all possible cases inbetween constrained/unconstrained quotes

  ;; .... todo
  )

(ert-deftest adoctest-test-url ()
  (adoctest-faces "url"
    ;; url inline macro with attriblist
    "foo " nil
    "http://www.lorem.com/ipsum.html" markup-internal-reference-face
    "[" markup-meta-face "sit amet" markup-reference-face "]" markup-meta-face
    " bar \n" nil
    ;; link text contains newlines and commas
    "http://www.lorem.com/ipsum.html" markup-internal-reference-face
    "[" markup-meta-face
    "sit,\namet,\nconsectetur" markup-reference-face
    "]" markup-meta-face
    " bar \n" nil
    ;; url inline macro withOUT attriblist
    "http://www.lorem.com/ipsum.html" markup-reference-face
    "[]" markup-meta-face
    " bar \n" nil
    ;; plain url
    "http://www.lorem.com/ipsum.html" markup-reference-face
    " foo " nil "joe.bloggs@foobar.com" markup-reference-face ))

(ert-deftest adoctest-test-url-enclosing-quote ()
  (adoctest-faces "url-enclosing-quote"
    ;; spaces between __ and url seem really to be needed also in asciidoc
    "foo " nil "__" markup-meta-hide-face " " nil
    "http://www.lorem.com/ipsum.html" '(markup-emphasis-face markup-reference-face)
    " " nil "__" markup-meta-hide-face

    "\nfoo " nil
    "**" markup-meta-hide-face " " nil
    "joe.bloggs@foobar.com" '(markup-strong-face markup-reference-face)
    " " nil "**" markup-meta-hide-face ))

;; inline substitutions only within the block they belong to. I.e. don't cross
;; block boundaries.
(ert-deftest adoctest-test-inline-subst-boundaries ()
  (adoctest-faces "inline-subst-boundaries"

   ;; 1) don't cross title boundaries.
   ;; 2) don't cross paragraph boundaries.
   ;; 3) verify that the (un)constrained quotes would work however
   "== " markup-meta-hide-face "chapter ** 1" markup-title-1-face "\n" nil
   "lorem ** ipsum\n" 'no-face
   "\n" nil
   "lorem " 'no-face "**" markup-meta-hide-face " ipsum " markup-strong-face "**" markup-meta-hide-face "\n" nil
   "\n" nil

   "== " markup-meta-hide-face "chapter __ 1" markup-title-1-face " ==" markup-meta-hide-face "\n" nil
   "lorem __ ipsum\n" 'no-face
   "\n" nil
   "lorem " 'no-face "__" markup-meta-hide-face " ipsum " markup-emphasis-face "__" markup-meta-hide-face "\n" nil
   "\n" nil

   "chapter ++ 1" markup-title-1-face "\n" nil
   "------------" markup-meta-hide-face "\n" nil
   "lorem ++ ipsum\n" 'no-face
   "\n" nil
   "lorem " 'no-face "++" markup-meta-hide-face " ipsum " markup-typewriter-face "++" markup-meta-hide-face "\n" nil
   "\n" nil

   "." markup-meta-face "block ^title" markup-gen-face "\n" nil
   "lorem^ ipsum\n" 'no-face
   "\n" nil
   "lorem " 'no-face "^" markup-meta-hide-face " ipsum " markup-superscript-face "^" markup-meta-hide-face "\n" nil
   "\n" nil

   ;; Being able to use a ** that potentially could be mistaken as an end
   ;; delimiter as start delimiter
   "== " markup-meta-hide-face "chapter ** 1" markup-title-1-face "\n" nil
   "lorem " 'no-face "**" markup-meta-hide-face " ipsum " markup-strong-face "**" markup-meta-hide-face "\n" nil
   "\n" nil

   ;; don't cross list item boundaries
   "-" markup-list-face " " nil "lorem ** ipsum\n" 'no-face
   "-" markup-list-face " " nil "dolor ** sit\n" 'no-face
   ;; test that a quote within the list element works
   "-" markup-list-face " " nil "dolor " 'no-face "**" markup-meta-hide-face " sit " markup-strong-face "**" markup-meta-hide-face "\n" nil
   ;; dont mistake '**' list elements for quote starters/enders
   "**" markup-list-face " " nil "lorem ** ipsum\n" 'no-face
   "**" markup-list-face " " nil "dolor ** sit\n" 'no-face
   "**" markup-list-face " " nil "dolor ** sit\n" 'no-face
   ;; don't cross list item boundaries in the case of labeled lists
   "lorem ** ipsum " markup-gen-face "::" markup-list-face " " nil "sit ** dolor\n" 'no-face
   "lorem ** ipsum " markup-gen-face "::" markup-list-face " " nil "sit ** dolor" 'no-face))

(ert-deftest adoctest-test-promote-title ()
  (adoctest-trans "= foo" "== foo" '(adoc-promote-title 1))
  (adoctest-trans "===== foo" "= foo" '(adoc-promote-title 1))
  (adoctest-trans "== foo" "==== foo" '(adoc-promote-title 2))

  (adoctest-trans "= foo =" "== foo ==" '(adoc-promote-title 1))
  (adoctest-trans "===== foo =====" "= foo =" '(adoc-promote-title 1))
  (adoctest-trans "== foo ==" "==== foo ====" '(adoc-promote-title 2))

  (adoctest-trans "foo!\n===!" "foo\n---" '(adoc-promote-title 1))
  (adoctest-trans "foo!\n+++!" "foo\n===" '(adoc-promote-title 1))
  (adoctest-trans "foo!\n---!" "foo\n^^^" '(adoc-promote-title 2)))

;; since it's a whitebox test we know demote and promote only differ by inverse
;; arg. So demote doesn't need to be throuhly tested again
(ert-deftest adoctest-test-demote-title ()
  (adoctest-trans "= foo" "===== foo" '(adoc-demote-title 1))
  (adoctest-trans "= foo =" "===== foo =====" '(adoc-demote-title 1))
  (adoctest-trans "foo!\n===!" "foo\n+++" '(adoc-demote-title 1)))

;; todo: test after transition point is still on title lines
(ert-deftest adoctest-test-toggle-title-type ()
  (adoctest-trans "= one" "one\n===" '(adoc-toggle-title-type))
  (adoctest-trans "two!\n===!" "= two" '(adoc-toggle-title-type))
  (adoctest-trans "= three!\nbar" "three\n=====\nbar" '(adoc-toggle-title-type))
  (adoctest-trans "four!\n====!\nbar" "= four\nbar" '(adoc-toggle-title-type))
  (adoctest-trans "= five" "= five =" '(adoc-toggle-title-type t))
  (adoctest-trans "= six =" "= six" '(adoc-toggle-title-type t)))

(ert-deftest adoctest-test-adjust-title-del ()
  (adoctest-trans "lorem!\n===!" "lorem\n=====" '(adoc-adjust-title-del))
  (adoctest-trans "lorem!\n========!" "lorem\n=====" '(adoc-adjust-title-del))
  (adoctest-trans "lorem!\n=====!" "lorem\n=====" '(adoc-adjust-title-del)))

(ert-deftest adoctest-test-xref-at-point-1 ()
  (unwind-protect
      (progn
	(set-buffer (get-buffer-create "adoc-test"))
	(insert "lorem xref:bogous1[] ipsum xref:foo[bla\nbli] dolor xref:bogous2[]")
	(re-search-backward "bli")	; move point within ref
	(should (equal (adoc-xref-id-at-point) "foo")))
    (kill-buffer "adoc-test")))

(ert-deftest adoctest-test-xref-at-point-2 ()
  (unwind-protect
      (progn
	(set-buffer (get-buffer-create "adoc-test"))
	(insert "lorem <<bogous1,caption>> ipsum <<foo,bla\nbli>> dolor <<bogous2>>")
	(re-search-backward "bli") ; move point within ref
	(should (equal (adoc-xref-id-at-point) "foo")))
    (kill-buffer "adoc-test")))

(ert-deftest adoctest-test-goto-ref-label ()
  (unwind-protect
      (progn
	(set-buffer (get-buffer-create "adoc-test"))
	(insert "[[foo]]\n"		   ;1
		"lorem ipsum\n"		   ;2
		"[[bar]]\n"		   ;3
		"dolor [[geil]]sit amen\n" ;4
		"anchor:cool[]\n")	   ;5
	(adoc-goto-ref-label "cool")
	(should (equal (line-number-at-pos) 5))
	(adoc-goto-ref-label "geil")
	(should (equal (line-number-at-pos) 4))
	(adoc-goto-ref-label "bar")
	(should (equal (line-number-at-pos) 3)))
    (kill-buffer "adoc-test")))

(defun adoctest-template (template expected)
  "Todo document adoctest-template TEMPLATE EXPECTED."
  (let ((buf-name (concat "adoctest-" (symbol-name template))))
    (unwind-protect
	(progn
	  ;; setup
	  (set-buffer (get-buffer-create buf-name))
	  (delete-region (point-min) (point-max))
	  (funcall template)
	  (should (equal (buffer-substring-no-properties (point-min) (point-max)) expected)))
      ;; tear-down
      (kill-buffer buf-name))))

(defun adoctest-quotes (start-del end-del transform)
  "Todo document adoctest-quotes START-DEL END-DEL TRANSFORM."
  (adoctest-trans "lorem ! ipsum"
		  (concat "lorem " start-del end-del " ipsum") transform)
  (adoctest-trans "lorem <ipsum> dolor"
		  (concat "lorem " start-del "ipsum" end-del " dolor") transform))

;; todo: test templates also with tempo-snippets
(ert-deftest adoctest-test-tempo-quotes ()
  (adoctest-quotes "_" "_" '(tempo-template-adoc-emphasis))
  (adoctest-quotes "*" "*" '(tempo-template-adoc-strong))
  (adoctest-quotes "+" "+" '(tempo-template-adoc-monospace))
  (adoctest-quotes "`" "`" '(tempo-template-adoc-monospace-literal))
  (adoctest-quotes "`" "'" '(tempo-template-adoc-single-quote))
  (adoctest-quotes "``" "''" '(tempo-template-adoc-double-quote))
  (adoctest-quotes "[]#" "#" '(tempo-template-adoc-attributed))
  (adoctest-quotes "__" "__" '(tempo-template-adoc-emphasis-uc))
  (adoctest-quotes "**" "**" '(tempo-template-adoc-strong-uc))
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

;; todo: check buffer position after insertion (aka transionsion). Probably
;; factor out from adoctest-trans a defun which translates a string containing
;; !s into one with the ! stripped and a buffer-position-list
(ert-deftest adoctest-test-tempo-title ()
  (let ((adoc-title-style 'adoc-title-style-one-line))
    ;; BUG!! somehow I need to load adoc-mode twice until it works!!!
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

(ert-deftest adoctest-test-tempo-passthroug-macros ()
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

(ert-deftest adoctest-test-make-two-line-title-underline ()
  (should (equal (adoc-make-two-line-title-underline 0 6)
		 "======"))
  (should (equal (adoc-make-two-line-title-underline 2)
		 "~~~~")))

(ert-deftest adoctest-test-repeat-string ()
  (should (equal (adoc-repeat-string "lorem" 0) ""))
  (should (equal (adoc-repeat-string "lorem" 1) "lorem"))
  (should (equal (adoc-repeat-string "lorem" 2) "loremlorem")))
    
(ert-deftest adoctest-test-indent-by-example ()
  (let ((tab-width 2)
  	(indent-tabs-mode nil))
    (adoctest-trans "" " x"   '(adoc-insert-indented "x" 1))
    (adoctest-trans "" "   x" '(adoc-insert-indented "x" 2)))

  (let ((tab-width 3)
	(indent-tabs-mode t))
    (adoctest-trans "" "  x"   '(adoc-insert-indented "x" 1))
    (adoctest-trans "" "\t  x" '(adoc-insert-indented "x" 2))))

(ert-deftest adoctest-test-imenu-create-index ()
  (unwind-protect
      (progn
        (set-buffer (get-buffer-create "adoc-test"))
        (insert "= document title\n"
                "== chapter 1\n"
                "=== sub chapter 1.1\n"
                "chapter 2\n"
                "----------\n"
                "sub chapter 2.1\n"
                "~~~~~~~~~~~~~~\n")
        (should
         (equal
          (adoc-imenu-create-index)
          (list
           (cons "document title" 1)
           (cons "chapter 1" 18)
           (cons "sub chapter 1.1" 31)
           (cons "chapter 2" 51)
           (cons "sub chapter 2.1" 72)))))
    (kill-buffer "adoc-test")))

;; purpose
;; - ensure that the latest version, i.e. the one currently in buffer(s), of
;;   adoc-mode and adoc-mode-test is used for the test
;; - test that adoc-mode and adoc-mode-test are compileble & loadable
;; - ensure no *.elc are lying around because they are 'dangerous' when the
;;   corresponding .el is edited regulary; dangerous because it's not unlikely
;;   that the .el is newer than the .elc, but load-library takes the outdated
;;   .elc.
;; 
;; todo: also test for warnings
(defun adoctest-save-compile-load ()
  "Todo document adoctest-save-compile-load."
  (unwind-protect
      (progn
	(let ((buf-adoc-mode (find-buffer-visiting "adoc-mode.el"))
	      (buf-adoc-mode-test (find-buffer-visiting "adoc-mode-test.el")))

	  ;; adoc-mode
	  (cond
	   ((null buf-adoc-mode))	;nop
	   ((bufferp buf-adoc-mode) (save-buffer buf-adoc-mode))
	   (t (error "Multiple buffer are visiting adoc-mode.el.  Save them first")))
	  (or (byte-compile-file (locate-library "adoc-mode.el" t)) (error "Compile error"))
	  (or (load "adoc-mode.el" nil nil t) (error "Load error"))

	  ;; adoc-mode-test
	  (cond
	   ((null buf-adoc-mode-test))	;nop
	   ((bufferp buf-adoc-mode-test) (save-buffer buf-adoc-mode-test))
	   (t (error "Multiple buffer are visiting adoc-mode-test.el.  Save them first")))
	  (or (byte-compile-file (locate-library "adoc-mode-test.el" t)) (error "Compile error"))
	  (or (load "adoc-mode-test.el" nil nil t) (error "Load error"))))

    (when (file-exists-p "adoc-mode.elc")
      (delete-file "adoc-mode.elc"))
    (when (file-exists-p "adoc-mode-test.elc")
      (delete-file "adoc-mode-test.elc"))))

(defun adoc-test-run()
  (interactive)

  ;; ensure that a failed test can be re-run
  (when (get-buffer "*ert*")
    (kill-buffer "*ert*"))

  ;; ensure no no-longer test defuns exist, which would otherwise be executed
  (mapatoms
   (lambda (x) (if (string-match "^adoctest-test-" (symbol-name x))
		   (unintern x nil))))

  (adoctest-save-compile-load)

  ;; todo: execute tests in an smart order: the basic/simple tests first, so
  ;; when a complicated test fails one knows that the simple things do work
  (ert-run-tests-interactively "^adoctest-test-"))

;;; adoc-mode-test.el ends here
