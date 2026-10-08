;;; adoc-mode-section-id-test.el --- Section auto-id tests -*- lexical-binding: t; -*-

;; Copyright © 2026 Bozhidar Batsov

;;; Commentary:

;; Buttercup tests for AsciiDoc section auto-ids: the id-generation algorithm
;; (validated against the real `asciidoctor' when available), id-style
;; detection (document attributes / Antora layout / `adoc-section-id-style'),
;; collecting section ids, and resolving them via the xref backend and
;; `adoc-goto-ref-label'.

;;; Code:

(require 'adoc-mode-test-helpers)
(require 'cl-lib)

(defun adoc-test--asciidoctor-section-ids (doc)
  "Return the ids the real Asciidoctor gives the section titles in DOC."
  (with-temp-buffer
    (insert doc)
    (call-process-region (point-min) (point-max)
                         "asciidoctor" t t nil "-s" "-o" "-" "-")
    (goto-char (point-min))
    (let (ids)
      (while (re-search-forward "<h[1-6] id=\"\\([^\"]*\\)\"" nil t)
        (push (match-string 1) ids))
      (nreverse ids))))

(defun adoc-test--section-ids (doc)
  "Return the ids `adoc-mode' gives the section titles in DOC, in order."
  (with-temp-buffer
    (insert doc)
    (adoc-mode)
    (delq nil (mapcar #'car (adoc--section-table)))))

(describe "adoc--section-id"
  (it "generates Asciidoctor-default (underscore) ids"
    (expect (adoc--section-id "Clojure CLI Setup" "_" "_")
            :to-equal "_clojure_cli_setup")
    (expect (adoc--section-id "Hello, World!" "_" "_") :to-equal "_hello_world")
    (expect (adoc--section-id "Foo & Bar (baz)" "_" "_") :to-equal "_foo_bar_baz")
    (expect (adoc--section-id "Dots.in.title" "_" "_") :to-equal "_dots_in_title")
    (expect (adoc--section-id "1. Numbered start" "_" "_")
            :to-equal "_1_numbered_start")
    (expect (adoc--section-id "snake_case_already" "_" "_")
            :to-equal "_snake_case_already"))

  (it "collapses separator-adjacent runs to a single separator"
    ;; a kept underscore next to a converted space must not double up
    (expect (adoc--section-id "foo_ bar" "_" "_") :to-equal "_foo_bar")
    (expect (adoc--section-id "a_-_b" "_" "_") :to-equal "_a_b"))

  (it "with an empty separator only removes spaces, keeping . and -"
    (expect (adoc--section-id "a.b-c" "" "") :to-equal "a.b-c")
    (expect (adoc--section-id "a b" "" "") :to-equal "ab"))

  (it "generates Antora-style (kebab) ids"
    (expect (adoc--section-id "Clojure CLI Setup" "" "-")
            :to-equal "clojure-cli-setup")
    (expect (adoc--section-id "kebab-already-here" "" "-")
            :to-equal "kebab-already-here")
    (expect (adoc--section-id "snake_case_already" "" "-")
            :to-equal "snake_case_already"))

  (it "matches the real asciidoctor for a range of titles"
    (assume (executable-find "asciidoctor") "asciidoctor not installed")
    (dolist (title '("Clojure CLI Setup" "Hello, World!" "C++ and C#"
                     "Trailing punctuation!!!" "UPPER lower MiXeD"
                     "1. Numbered start" "Dots.in.title"))
      (dolist (style '(("_" . "_") ("" . "-")))
        (let* ((pre (car style)) (sep (cdr style))
               (attrs (format ":idprefix: %s\n:idseparator: %s" pre sep))
               (doc (format "= D\n%s\n\n== %s\n" attrs title))
               (html (with-temp-buffer
                       (insert doc)
                       (call-process-region (point-min) (point-max)
                                            "asciidoctor" nil t nil "-s" "-o" "-" "-")
                       (buffer-string)))
               (real (when (string-match "id=\"\\([^\"]*\\)\"" html)
                       (match-string 1 html))))
          (expect (adoc--section-id title pre sep) :to-equal real))))))

(describe "section ids of marked-up titles"
  (it "uses the text of link and xref macros"
    (expect (adoc--section-id "Department xref:cops_bundler.adoc[Bundler]" "_" "_")
            :to-equal "_department_bundler")
    (expect (adoc--section-id "https://www.gnu.org/x.html[Xref] integration" "" "-")
            :to-equal "xref-integration")
    (expect (adoc--section-id "A link:x.html[Text,window=_blank] b" "_" "_")
            :to-equal "_a_text_b")
    (expect (adoc--section-id "A link:x.html[] b" "_" "_") :to-equal "_a_x_html_b")
    (expect (adoc--section-id "A link:x[a=b] c" "_" "_") :to-equal "_a_x_c")
    (expect (adoc--section-id "See <<t,the target>>" "_" "_")
            :to-equal "_see_the_target"))

  (it "leaves images, anchors and quote roles out"
    (expect (adoc--section-id "Logo image:x.png[Alt text] here" "_" "_")
            :to-equal "_logo_here")
    (expect (adoc--section-id "Foo [[x]] bar" "_" "_") :to-equal "_foo_bar")
    (expect (adoc--section-id "A [.red]#big# deal" "_" "_") :to-equal "_a_big_deal"))

  (it "drops the underscores of emphasis but not of words"
    (expect (adoc--section-id "The _Big_ Day and snake_case" "" "-")
            :to-equal "the-big-day-and-snake_case")
    (expect (adoc--section-id "_a_ _b_" "" "-") :to-equal "a-b")
    (expect (adoc--section-id "__un__constrained" "" "-") :to-equal "unconstrained"))

  (it "applies Asciidoctor's replacements"
    (expect (adoc--section-id "A (C) B -- C" "_" "_") :to-equal "_a_bc")
    (expect (adoc--section-id "Foo--Bar--Baz" "_" "_") :to-equal "_foobarbaz")
    (expect (adoc--section-id "Wait...what" "_" "_") :to-equal "_waitwhat")
    (expect (adoc--section-id "v2 -> v3" "" "-") :to-equal "v2-v3")
    (expect (adoc--section-id "A \\(C) b" "_" "_") :to-equal "_a_c_b"))

  (it "drops entities and keeps the text of literal tags"
    (expect (adoc--section-id "Caf&#233; &amp; Bar" "_" "_") :to-equal "_caf_bar")
    (expect (adoc--section-id "Use <b>x</b>" "_" "_") :to-equal "_use_bxb")
    (expect (adoc--section-id "Use +++<b>x</b>+++ now" "_" "_") :to-equal "_use_x_now"))

  (it "uses the text of kbd: and btn: macros when they're enabled"
    (expect (adoc-test--section-ids "= D\n\n== Press kbd:[Ctrl+C]\n")
            :to-equal '("_press_kbdctrlc"))
    (expect (adoc-test--section-ids "= D\n:experimental:\n\n== Press kbd:[Ctrl+C]\n")
            :to-equal '("_press_ctrlc")))

  (it "resolves the built-in character attributes"
    (expect (adoc-test--section-ids "= D\n\n== Use{sp}{cpp} and{nbsp}more {empty}x\n")
            :to-equal '("_use_c_andmore_x")))

  (it "matches the real asciidoctor"
    (assume (executable-find "asciidoctor") "asciidoctor not installed")
    (let ((titles '("Department xref:cops_bundler.adoc[Bundler]"
                    "https://www.gnu.org/x.html[Xref] integration"
                    "A link:x.html[Text,window=_blank] b"
                    "E https://x.org[\"Quoted, text\",role=x] f"
                    "Mail mailto:a@b.org[Me]" "See xref:other.adoc#frag[]"
                    "A link:x[a=b] c" "B https://x.org[a=b] c" "C xref:o.adoc[a=b] d"
                    "Logo image:x.png[Alt text] here" "Foo [[x]] mid"
                    "A [.red]#big# deal" "B [.x]_it_ c" "x[0]_suffix_ y[1]#z#"
                    "The _Big_ Day and snake_case" "_a_ _b_ a_b_ c"
                    "__un__constrained" "*Bold* #mark# ^sup^ ~sub~ `mono_x`"
                    "A (C) B (TM) -- C ... D -> E => F" "Foo--Bar--Baz"
                    "Don't wait...what" "A \\(C) b \\... c"
                    "Caf&#233; &amp; Bar &#x2014; x" "Use <b>x</b> and a < b > c"
                    "Use +++<b>x</b>+++ and pass:[<i>y</i>] now"
                    "Use{sp}{cpp} and{nbsp}more {empty}x {amp} y {plus}z"
                    "Press kbd:[Ctrl+C] or btn:[OK]")))
      (dolist (attrs '("" ":idprefix:\n:idseparator: -\n" ":experimental:\n"))
        (let ((doc (concat "= D\n" attrs "\n"
                           (mapconcat (lambda (title) (concat "== " title "\n\n"))
                                      titles ""))))
          (expect (adoc-test--section-ids doc)
                  :to-equal (adoc-test--asciidoctor-section-ids doc)))))))

(describe "adoc--section-table"
  (it "keeps up with edits and settings"
    (with-adoc-buffer "= D\n\n== Foo\n"
      (expect (adoc--collect-section-ids) :to-equal '("_foo"))
      (goto-char (point-max))
      (insert "\n== Foo\n")
      (expect (adoc--collect-section-ids) :to-equal '("_foo" "_foo_2"))
      (let ((adoc-section-id-style 'antora))
        (expect (adoc--collect-section-ids) :to-equal '("foo" "foo-2")))
      (expect (adoc--collect-section-ids) :to-equal '("_foo" "_foo_2")))))

(describe "adoc--section-id-params"
  (it "honours an explicit adoc-section-id-style"
    (let ((doc "= D\n:idprefix: x\n:idseparator: .\n\n== A B\n"))
      (let ((adoc-section-id-style 'antora))
        (expect (adoc-test--section-ids doc) :to-equal '("a-b")))
      (let ((adoc-section-id-style 'asciidoctor))
        (expect (adoc-test--section-ids doc) :to-equal '("_a_b")))
      (let ((adoc-section-id-style 'auto))
        (expect (adoc-test--section-ids doc) :to-equal '("xa.b")))))

  (it "defaults to the Asciidoctor style outside Antora"
    (with-temp-buffer
      (setq buffer-file-name "/tmp/adoc-section-id-plain.adoc")
      (insert "= D\n\n== A B\n")
      (adoc-mode)
      (let ((adoc-section-id-style 'auto))
        (expect (adoc--collect-section-ids) :to-equal '("_a_b")))
      (set-buffer-modified-p nil))))

(describe "document attributes in section ids"
  (it "applies :idprefix: and :idseparator: in a buffer without a file"
    (expect (adoc-test--section-ids "= D\n:idprefix:\n:idseparator: -\n\n== Foo Bar\n")
            :to-equal '("foo-bar")))

  (it "applies an attribute from the line that sets it on"
    (expect (adoc-test--section-ids "= D\n\n== Foo\n\n:idprefix: x\n\n== Bar\n")
            :to-equal '("_foo" "xbar")))

  (it "puts the prefix in front before translating the separators"
    (expect (adoc-test--section-ids "= D\n:idprefix: sec-\n\n== Foo Bar\n")
            :to-equal '("sec_foo_bar"))
    (expect (adoc-test--section-ids "= D\n:idprefix: x\n\n== .NET Core\n")
            :to-equal '("x_net_core"))
    (expect (adoc-test--section-ids "= D\n:idprefix:\n:idseparator: -\n\n== .NET Core\n")
            :to-equal '("net-core")))

  (it "gives the same ids when the buffer is narrowed"
    (with-adoc-buffer "= D\n:idprefix: x\n\n== Foo\n"
      (re-search-forward "^== Foo")
      (narrow-to-region (line-beginning-position) (point-max))
      (expect (adoc--section-id-at-point) :to-equal "xfoo")
      (expect (adoc--collect-section-ids) :to-equal '("xfoo"))))

  (it "uses only the first character of a longer separator"
    (expect (adoc-test--section-ids "= D\n:idseparator: ab\n\n== Foo Bar\n")
            :to-equal '("_fooabar")))

  (it "gives sections no auto-id while sectids is unset"
    (expect (adoc-test--section-ids "= D\n:sectids!:\n\n== Foo\n") :to-equal nil)
    (expect (adoc-test--section-ids "= D\n:!sectids:\n\n== Foo\n") :to-equal nil)
    (expect (adoc-test--section-ids
             "= D\n\n== Foo\n\n:sectids!:\n\n== Bar\n\n:sectids:\n\n== Baz\n")
            :to-equal '("_foo" "_baz")))

  (it "keeps explicit section ids while sectids is unset"
    (with-adoc-buffer "= D\n:sectids!:\n\n[#bar]\n== Foo\n\n== Baz\n"
      (expect (adoc--collect-section-ids) :to-equal nil)
      (re-search-forward "^== Foo")
      (expect (adoc--section-id-at-point) :to-equal "bar")
      (re-search-forward "^== Baz")
      (expect (adoc--section-id-at-point) :to-be nil)))

  (it "substitutes attribute references in titles"
    (expect (adoc-test--section-ids
             (concat "= D\n:Product: Acme\n:full: {product} Pro\n\n"
                     "== {product} Setup\n\n== {FULL}\n\n== {missing} Bits\n\n"
                     "== \\{product} Escaped\n\n:product!:\n\n== {product} Again\n"))
            :to-equal '("_acme_setup" "_acme_pro" "_missing_bits"
                        "_product_escaped" "_product_again"))
    (with-adoc-buffer "= D\n:product: Acme\n\n== {product} Setup\n"
      (re-search-forward "^== ")
      (expect (adoc--section-id-at-point) :to-equal "_acme_setup")))

  (it "ignores attribute entries in verbatim blocks"
    (expect (adoc-test--section-ids
             "= D\n\n----\n:p: Zed\n----\n\n====\n:q: Zap\n\nx\n====\n\n== {p} {q}\n")
            :to-equal '("_p_zap"))
    (expect (adoc-test--section-ids
             "= D\n\n====\n:q: Zap\n\n....\n:q: Zoo\n....\n====\n\n== {q}\n")
            :to-equal '("_zap")))

  (it "matches the real asciidoctor"
    (assume (executable-find "asciidoctor") "asciidoctor not installed")
    (dolist (doc '("= D\n:idprefix:\n:idseparator: -\n\n== Foo Bar\n"
                   "= D\n\n== Foo\n\n:idprefix: x\n:idseparator: .\n\n== Bar Baz\n"
                   "= D\n:idseparator: ab\n\n== Foo Bar\n"
                   "= D\n:idprefix: sec-\n\n== Foo Bar\n\n:idprefix: x\n\n== .NET Core\n"
                   "= D\n\n== Foo\n\n:sectids!:\n\n== Bar\n\n:sectids:\n\n== Baz\n"
                   "= D\n:Product: Acme\n:full: {product} Pro\n\n== {full} Setup\n"
                   "= D\n\n== {p} A\n\n:p: Zed \\\n  Zap\n\n== {p} B\n\n:p!:\n\n== {p} C\n"
                   "= D\n:p: Zed\n\n== \\{p} A\n\n----\n:p: Zap\n----\n\n== {p} B\n"))
      (expect (adoc-test--section-ids doc)
              :to-equal (adoc-test--asciidoctor-section-ids doc)))))

(describe "duplicate section ids"
  (it "numbers the ids of repeated titles"
    (expect (adoc-test--section-ids "= D\n\n== Foo\n\n== Foo\n\n=== Foo\n")
            :to-equal '("_foo" "_foo_2" "_foo_3"))
    (expect (adoc-test--section-ids
             "= D\n:idprefix:\n:idseparator: -\n\n== Foo Bar\n\n== Foo Bar\n")
            :to-equal '("foo-bar" "foo-bar-2"))
    (expect (adoc-test--section-ids "= D\n:idseparator:\n\n== Foo\n\n== Foo\n")
            :to-equal '("_foo" "_foo2")))

  (it "skips the ids explicit anchors above the title already use"
    (expect (adoc-test--section-ids
             "= D\n\npara [[_foo]]here\n\n[[_foo_2]]\nx\n\n== Foo\n\n== Bar\n\nanchor:_bar[]\n")
            :to-equal '("_foo_3" "_bar")))

  (it "doesn't count anchors in verbatim blocks, comments or escaped ones"
    (expect (adoc-test--section-ids
             (concat "= D\n\n----\n[[_foo]]\n----\n\n////\n[[_foo]]\n////\n\n"
                     "====\n----\n[[_foo]]\n----\n====\n\n"
                     "// [[_foo]]\n\nx \\[[_foo]]\n\n== Foo\n"))
            :to-equal '("_foo")))

  (it "resolves a numbered id to its own section"
    (with-adoc-buffer "= D\n\n== Foo\n\none\n\n== Foo\n\ntwo\n"
      (expect (adoc--goto-id "_foo_2") :to-be-truthy)
      (expect (line-number-at-pos) :to-equal 7)
      (expect (adoc--section-id-at-point) :to-equal "_foo_2")
      (let ((defs (xref-backend-definitions 'adoc "_foo_2")))
        (expect (length defs) :to-equal 1)
        (expect (line-number-at-pos
                 (xref-location-marker (xref-item-location (car defs))))
                :to-equal 7))
      (expect (adoc--collect-section-ids) :to-equal '("_foo" "_foo_2"))))

  (it "matches the real asciidoctor"
    (assume (executable-find "asciidoctor") "asciidoctor not installed")
    (dolist (doc '("= D\n\n== Foo\n\n== Foo\n\n== Foo\n"
                   "= D\n\n== Foo\n\n== Foo 2\n\n== Foo\n\n== Foo\n"
                   "= D\n:idseparator:\n\n== Foo\n\n== Foo\n\n== Foo 2\n"
                   "= Foo\n\n== Foo\n\n[discrete]\n== Foo\n\n== Foo\n"
                   "= D\n\n[[_foo_2]]\n== Bar\n\n== Foo\n\n== Foo\n"
                   "= D\n\n[#x]\n== Foo\n\n== Foo\n\n== Bar [[_foo_2]]\n\n== Foo\n"
                   "= D\n\n[source#_foo,ruby]\n----\nx\n----\n\n== Foo\n"
                   "= D\n\n====\n[[_foo]]\npara\n====\n\n== Foo\n\npara [[_foo_3]]\n\n== Foo\n"
                   "= D\n\n== Foo\n\n:sectids!:\n\n== Foo\n\n:sectids:\n\n== Foo\n"
                   "= D\n\n----\n[[_foo]]\n----\n\n// [[_foo]]\n\n== Foo\n"))
      (expect (adoc-test--section-ids doc)
              :to-equal (adoc-test--asciidoctor-section-ids doc)))))

(describe "Antora layout detection"
  (it "detects an antora.yml above the file and uses the kebab style"
    (let* ((root (make-temp-file "adoc-antora-" t))
           (pages (expand-file-name "modules/ROOT/pages" root))
           (page (expand-file-name "p.adoc" pages)))
      (unwind-protect
          (progn
            (make-directory pages t)
            (with-temp-file (expand-file-name "antora.yml" root)
              (insert "name: demo\nversion: ~\n"))
            (with-temp-file page (insert "= Page\n\n== My Section\n"))
            (with-current-buffer (find-file-noselect page)
              (unwind-protect
                  (let ((adoc-section-id-style 'auto))
                    (expect (adoc--antora-p) :to-be-truthy)
                    (expect (adoc--collect-section-ids) :to-equal '("my-section"))
                    ;; the document can override one of Antora's defaults
                    (goto-char (point-min))
                    (insert ":idprefix: x\n")
                    (expect (adoc--collect-section-ids) :to-equal '("xmy-section")))
                (set-buffer-modified-p nil)
                (kill-buffer))))
        (delete-directory root t)))))

(describe "adoc--collect-sections"
  (it "collects section ids, skipping the doctitle and code blocks"
    (with-temp-buffer
      (insert "= Doc Title\n\n"
              "== First Section\n\ntext\n\n"
              "----\n== Not A Heading\n----\n\n"
              "=== Nested One\n")
      (adoc-mode)
      (expect (adoc--collect-section-ids)
              :to-equal '("_first_section" "_nested_one")))))

(describe "section ids as xref targets"
  (it "resolves a section auto-id as an xref definition"
    (with-temp-buffer
      (insert "= Doc\n\n== Clojure CLI Setup\n\ntext\n")
      (adoc-mode)
      (let ((defs (xref-backend-definitions 'adoc "_clojure_cli_setup")))
        (expect (length defs) :to-equal 1)
        (expect (xref-item-summary (car defs)) :to-equal "Clojure CLI Setup"))))

  (it "lets adoc-goto-ref-label jump to a section by its auto-id"
    (with-temp-buffer
      (insert "= Doc\n\n== First\n\ntext\n\n== Second Section\n\nmore\n")
      (adoc-mode)
      (goto-char (point-min))
      (adoc-goto-ref-label "_second_section")
      (expect (line-number-at-pos) :to-equal 7)))

  (it "offers section ids in the xref completion table"
    (with-temp-buffer
      (insert "[[explicit]]\n= Doc\n\n== A Section\n")
      (adoc-mode)
      (let ((table (xref-backend-identifier-completion-table 'adoc)))
        (expect (member "a-section" table) :to-be nil) ; default style is underscore
        (expect (member "_a_section" table) :to-be-truthy)
        (expect (member "explicit" table) :to-be-truthy)))))

(provide 'adoc-mode-section-id-test)

;;; adoc-mode-section-id-test.el ends here
