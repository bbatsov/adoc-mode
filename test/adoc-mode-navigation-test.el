;;; adoc-mode-navigation-test.el --- Navigation tests for adoc-mode -*- lexical-binding: t; -*-

;; Copyright © 2025-2026 Bozhidar Batsov

;;; Commentary:

;; Buttercup tests for adoc-mode heading navigation, outline cycling,
;; and cross-reference following.

;;; Code:

(require 'adoc-mode-test-helpers)

(defun adoc-test--insert-nav-doc ()
  "Insert a small multi-level document used by the navigation tests."
  (insert "= Doc Title\n\n"
          "intro\n\n"
          "== Section A\n\n"
          "text a\n\n"
          "=== Sub A1\n\n"
          "text\n\n"
          "=== Sub A2\n\n"
          "more\n\n"
          "== Section B\n\n"
          "end\n"))

(defun adoc-test--goto-heading (text)
  "Move point to the beginning of the line containing TEXT."
  (goto-char (point-min))
  (search-forward text)
  (beginning-of-line))

(describe "adoc-mode heading navigation"

  (describe "next/previous visible heading"
    (it "moves to the next heading of any level"
      (with-temp-buffer
        (adoc-mode)
        (adoc-test--insert-nav-doc)
        (goto-char (point-min))
        (adoc-next-visible-heading 1)
        (expect (looking-at-p "== Section A$") :to-be-truthy)
        (adoc-next-visible-heading 1)
        (expect (looking-at-p "=== Sub A1$") :to-be-truthy)
        (adoc-next-visible-heading 2)
        (expect (looking-at-p "== Section B$") :to-be-truthy)
        (let ((pos (point)))
          (expect (adoc-next-visible-heading 1) :to-throw 'user-error)
          (expect (point) :to-equal pos))))

    (it "moves to the previous heading and climbs out of bodies"
      (with-temp-buffer
        (adoc-mode)
        (adoc-test--insert-nav-doc)
        (adoc-test--goto-heading "Section B")
        (adoc-previous-visible-heading 1)
        (expect (looking-at-p "=== Sub A2$") :to-be-truthy)
        (adoc-previous-visible-heading 2)
        (expect (looking-at-p "== Section A$") :to-be-truthy)
        (adoc-test--goto-heading "text a")
        (adoc-previous-visible-heading 1)
        (expect (looking-at-p "== Section A$") :to-be-truthy)
        ;; a negative argument moves forward
        (adoc-previous-visible-heading -1)
        (expect (looking-at-p "=== Sub A1$") :to-be-truthy))))

  (describe "same-level navigation"
    (it "moves forward at the same level, skipping deeper headings"
      (with-temp-buffer
        (adoc-mode)
        (adoc-test--insert-nav-doc)
        (adoc-test--goto-heading "Section A")
        (adoc-forward-same-level 1)
        (expect (looking-at-p "== Section B$") :to-be-truthy)
        (adoc-test--goto-heading "Sub A1")
        (adoc-forward-same-level 1)
        (expect (looking-at-p "=== Sub A2$") :to-be-truthy)
        (adoc-test--goto-heading "Sub A2")
        (let ((pos (point)))
          (expect (adoc-forward-same-level 1) :to-throw 'user-error)
          (expect (point) :to-equal pos))))

    (it "moves backward at the same level"
      (with-temp-buffer
        (adoc-mode)
        (adoc-test--insert-nav-doc)
        (adoc-test--goto-heading "Section B")
        (adoc-backward-same-level 1)
        (expect (looking-at-p "== Section A$") :to-be-truthy)
        (adoc-test--goto-heading "Sub A2")
        (adoc-backward-same-level 1)
        (expect (looking-at-p "=== Sub A1$") :to-be-truthy)
        (adoc-test--goto-heading "Sub A1")
        (let ((pos (point)))
          (expect (adoc-backward-same-level 1) :to-throw 'user-error)
          (expect (point) :to-equal pos)))))

  (describe "up-heading"
    (it "moves to the parent heading"
      (with-temp-buffer
        (adoc-mode)
        (adoc-test--insert-nav-doc)
        (adoc-test--goto-heading "Sub A1")
        (adoc-up-heading 1)
        (expect (looking-at-p "== Section A$") :to-be-truthy)
        (adoc-test--goto-heading "Sub A2")
        (adoc-up-heading 2)
        (expect (looking-at-p "= Doc Title$") :to-be-truthy)
        (adoc-test--goto-heading "Doc Title")
        (let ((pos (point)))
          (expect (adoc-up-heading 1) :to-throw 'user-error)
          (expect (point) :to-equal pos)))))

  (describe "two-line titles"
    (it "navigates two-line (setext) titles"
      (with-temp-buffer
        (adoc-mode)
        ;; Two-line titles are off by default; opt in for this test.
        (setq-local adoc-enable-two-line-title t)
        (insert "Doc Title\n=========\n\n"
                "intro\n\n"
                "Section A\n---------\n\n"
                "text\n\n"
                "Section B\n---------\n\n"
                "end\n")
        (goto-char (point-min))
        (adoc-next-visible-heading 1)
        (expect (looking-at-p "Section A$") :to-be-truthy)
        (adoc-forward-same-level 1)
        (expect (looking-at-p "Section B$") :to-be-truthy)
        (adoc-up-heading 1)
        (expect (looking-at-p "Doc Title$") :to-be-truthy))))

  (describe "two-line titles disabled by default"
    (it "does not treat setext underlines as headings"
      (with-temp-buffer
        (adoc-mode)
        (insert "Doc Title\n=========\n\n"
                "intro\n\n"
                "Section A\n---------\n\n"
                "text\n")
        (goto-char (point-min))
        ;; adoc-enable-two-line-title is nil, so navigation finds nothing.
        (let ((pos (point)))
          (expect (adoc-next-visible-heading 1) :to-throw 'user-error)
          (expect (point) :to-equal pos)))))

  (describe "code and verbatim blocks"
    (it "skips one-line titles inside a listing block"
      (with-temp-buffer
        (adoc-mode)
        (insert "= Doc\n\n"
                "== Real A\n\ntext\n\n"
                "----\n"
                "== this is code, not a heading\n"
                "more code\n"
                "----\n\n"
                "== Real B\n\nbody\n")
        (goto-char (point-min))
        (adoc-next-visible-heading 1)
        (expect (looking-at-p "== Real A$") :to-be-truthy)
        ;; Jumps straight over the listing block to the next real title.
        (adoc-next-visible-heading 1)
        (expect (looking-at-p "== Real B$") :to-be-truthy)))

    (it "skips one-line titles inside an example block"
      ;; Example/sidebar/quote/open blocks are not fontified as titles
      ;; either, so a `==' line inside them is not a heading.
      (with-temp-buffer
        (adoc-mode)
        (insert "= Doc\n\n"
                "== Real A\n\ntext\n\n"
                "====\n"
                "== this is block content, not a heading\n"
                "====\n\n"
                "== Real B\n\nbody\n")
        (goto-char (point-min))
        (adoc-next-visible-heading 1)
        (expect (looking-at-p "== Real A$") :to-be-truthy)
        (adoc-next-visible-heading 1)
        (expect (looking-at-p "== Real B$") :to-be-truthy)))

    (it "still recognizes a title whose text is entirely a macro"
      ;; The link/image keyword overrides the title face on the text, but
      ;; the leading `==' delimiter keeps its title highlighting.
      (with-temp-buffer
        (adoc-mode)
        (insert "= Doc\n\n"
                "== https://example.com[Home]\n\nbody\n\n"
                "== image:logo.png[Logo]\n\nmore\n")
        (goto-char (point-min))
        (adoc-next-visible-heading 1)
        (expect (looking-at-p "== https://example.com\\[Home]$") :to-be-truthy)
        (adoc-next-visible-heading 1)
        (expect (looking-at-p "== image:logo.png\\[Logo]$") :to-be-truthy)))

    (it "skips a code line that mimics a two-line title underline"
      (with-temp-buffer
        (adoc-mode)
        ;; `end' followed by `----' (the closing listing delimiter) looks
        ;; exactly like a two-line title - it must not stop navigation.
        (insert "= Doc\n\n"
                "== Real A\n\ntext\n\n"
                "[source,ruby]\n----\ndef foo\nend\n----\n\n"
                "== Real B\n\nbody\n")
        (goto-char (point-min))
        (adoc-next-visible-heading 1)
        (expect (looking-at-p "== Real A$") :to-be-truthy)
        (adoc-next-visible-heading 1)
        (expect (looking-at-p "== Real B$") :to-be-truthy)))

    (it "climbs out of a block when navigating backward"
      (with-temp-buffer
        (adoc-mode)
        (insert "= Doc\n\n"
                "== Real A\n\ntext\n\n"
                "----\n== fake heading\nmore\n----\n\n"
                "== Real B\n\nbody\n")
        ;; Start inside the block and move to the previous real heading.
        (goto-char (point-min))
        (search-forward "more")
        (beginning-of-line)
        (adoc-previous-visible-heading 1)
        (expect (looking-at-p "== Real A$") :to-be-truthy)))

    (it "omits code-block lines from the imenu index"
      (with-temp-buffer
        (adoc-mode)
        (insert "= Doc\n\n"
                "== Real A\n\n"
                "----\n== not a heading\n----\n\n"
                "== Real B\n")
        (expect (mapcar (lambda (e) (substring-no-properties (car e)))
                        (adoc-imenu-create-index))
                :to-equal '("Doc" "Real A" "Real B"))))))

(describe "adoc-mode outline cycling"

  (defun adoc-test--cycle-buffer ()
    (adoc-mode)
    (insert "= Top\n\n== A\n\nbody a\n\n== B\n\nbody b\n")
    (font-lock-ensure)
    (goto-char (point-min)))

  (it "cycles a subtree folded then shown"
    (with-temp-buffer
      (adoc-test--cycle-buffer)
      (let ((body (save-excursion (search-forward "body a") (point))))
        (search-forward "== A") (beginning-of-line)
        (expect (outline-invisible-p body) :not :to-be-truthy)
        (adoc-cycle)
        (expect (outline-invisible-p body) :to-be-truthy)
        (adoc-cycle)
        (expect (outline-invisible-p body) :not :to-be-truthy))))

  (it "does not fold when point is off a heading"
    (with-temp-buffer
      (adoc-test--cycle-buffer)
      (let ((body (save-excursion (search-forward "body a") (point))))
        (goto-char body)
        (adoc-cycle)
        (expect (outline-invisible-p body) :not :to-be-truthy))))

  (it "cycles the whole buffer with a prefix argument"
    (with-temp-buffer
      (adoc-test--cycle-buffer)
      (let ((body (save-excursion (search-forward "body a") (point))))
        (expect (outline-invisible-p body) :not :to-be-truthy)
        (adoc-cycle '(4))
        (expect (outline-invisible-p body) :to-be-truthy)
        (adoc-cycle-buffer)
        (adoc-cycle-buffer)
        (expect (outline-invisible-p body) :not :to-be-truthy)))))

(describe "adoc-mode cross-reference following"

  (it "jumps to the anchor defining an id"
    (with-temp-buffer
      (adoc-mode)
      (insert "[[foo]]\n"
              "lorem ipsum\n"
              "[[bar]]\n"
              "dolor [[geil]]sit amen\n"
              "anchor:cool[]\n")
      (adoc-goto-ref-label "cool")
      (expect (line-number-at-pos) :to-equal 5)
      (adoc-goto-ref-label "geil")
      (expect (line-number-at-pos) :to-equal 4)
      (adoc-goto-ref-label "bar")
      (expect (line-number-at-pos) :to-equal 3)))

  (it "follows the block id shorthand, including the style#id form"
    (with-temp-buffer
      (adoc-mode)
      (insert "[#sect2]\n== Two\n\n[source#sid]\n----\ncode\n----\n")
      (adoc-goto-ref-label "sect2")
      (expect (line-number-at-pos) :to-equal 1)
      (adoc-goto-ref-label "sid")
      (expect (line-number-at-pos) :to-equal 4)))

  (it "finds the xref id at point (<<id>> and xref: forms)"
    (with-temp-buffer
      (adoc-mode)
      (insert "lorem xref:bogous1[] ipsum xref:foo[bla\nbli] dolor xref:bogous2[]")
      (re-search-backward "bli")
      (expect (adoc-xref-id-at-point) :to-equal "foo"))
    (with-temp-buffer
      (adoc-mode)
      (insert "lorem <<bogous1,caption>> ipsum <<foo,bla\nbli>> dolor <<bogous2>>")
      (re-search-backward "bli")
      (expect (adoc-xref-id-at-point) :to-equal "foo"))))

(describe "clickable references"
  (defun adoc-test--prop-at (content needle prop)
    "Fontify CONTENT and return text property PROP at the start of NEEDLE."
    (with-temp-buffer
      (insert content)
      (adoc-mode)
      (font-lock-ensure)
      (goto-char (point-min))
      (and (search-forward needle nil t)
           (get-text-property (match-beginning 0) prop))))

  (it "marks every reference construct with the link keymap"
    (let ((doc (concat "[[target]]\n= Doc\n\n"
                       "See <<target>> and <<target,the target>>.\n\n"
                       "Also xref:target[here] and https://example.com[site].\n\n"
                       "A bare https://bare.example.com link.\n\n"
                       "include::other.adoc[]\n")))
      (dolist (needle '("<<target>>" "<<target,the target>>" "xref:target[here]"
                        "https://example.com[site]" "bare.example.com"
                        "include::other.adoc[]"))
        (expect (adoc-test--prop-at doc needle 'keymap) :to-be 'adoc-link-keymap)
        (expect (adoc-test--prop-at doc needle 'mouse-face) :to-be 'highlight)
        (expect (adoc-test--prop-at doc needle 'help-echo) :to-be-truthy))))

  (it "leaves plain prose unclickable"
    (expect (adoc-test--prop-at "just some ordinary prose\n" "ordinary" 'keymap)
            :to-be nil))

  (it "does not make an xref inside a code block clickable"
    (expect (adoc-test--prop-at "----\n<<dead>>\n----\n" "<<dead>>" 'keymap)
            :to-be nil)
    ;; but the same xref outside the block is clickable
    (expect (adoc-test--prop-at "<<live>>\n\n----\ncode\n----\n" "<<live>>" 'keymap)
            :to-be 'adoc-link-keymap))

  (it "binds mouse-2 and follow-link in the link keymap"
    (expect (lookup-key adoc-link-keymap [mouse-2])
            :to-be #'adoc-follow-thing-at-point)
    (expect (lookup-key adoc-link-keymap [follow-link]) :to-be 'mouse-face)))

(describe "adoc--inline-link-at-point"
  (it "extracts a URL macro target without its label"
    (with-temp-buffer
      (adoc-mode)
      (insert "see https://example.com[Example] ok")
      (goto-char (point-min))
      (search-forward "example")
      (expect (adoc--inline-link-at-point) :to-equal "https://example.com")))

  (it "extracts a link: macro target"
    (with-temp-buffer
      (adoc-mode)
      (insert "see link:other.adoc[the doc] ok")
      (goto-char (point-min))
      (search-forward "other")
      (expect (adoc--inline-link-at-point) :to-equal "other.adoc")))

  (it "returns nil away from any link macro"
    (with-temp-buffer
      (adoc-mode)
      (insert "just prose")
      (goto-char (point-min))
      (expect (adoc--inline-link-at-point) :to-be nil))))

;;; adoc-mode-navigation-test.el ends here
