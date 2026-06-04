;;; adoc-mode-completion-test.el --- Completion-at-point tests -*- lexical-binding: t; -*-

;; Copyright © 2026 Bozhidar Batsov

;;; Commentary:

;; Buttercup tests for `adoc-completion-at-point' and its helpers: the anchor
;; and attribute candidate collectors, and the per-context detectors that pick
;; the right completion (xref/anchor ids, attribute names, include paths,
;; source-block languages) based on the construct at point.

;;; Code:

(require 'adoc-mode-test-helpers)

(defun adoc-test--capf-at (content)
  "Return a description of `adoc-completion-at-point' in CONTENT.
Point is placed where the literal `|' marker appears in CONTENT (the
marker is removed first).  Returns nil when no completion is offered,
otherwise a plist with `:start', `:end', `:collection', and the resolved
`:candidates' (computed while the buffer is still live, since the
collection scans it lazily)."
  (with-temp-buffer
    (insert (adoc-test--dedent content))
    (goto-char (point-min))
    (let ((pos (when (search-forward "|" nil t)
                 (delete-char -1)
                 (point))))
      (adoc-mode)
      (when pos (goto-char pos))
      (let ((capf (adoc-completion-at-point)))
        (when capf
          (list :start (nth 0 capf)
                :end (nth 1 capf)
                :collection (nth 2 capf)
                :token (buffer-substring-no-properties (nth 0 capf) (nth 1 capf))
                :candidates (all-completions "" (nth 2 capf))))))))

(defun adoc-test--capf-candidates (capf)
  "Return the resolved candidate strings of CAPF (a `adoc-test--capf-at' plist)."
  (plist-get capf :candidates))

(describe "adoc--collect-anchor-ids"
  (it "collects ids from every explicit anchor form"
    (with-adoc-buffer "
      [[alpha]]
      [[beta,Beta Text]]
      [#gamma]
      [source#delta]
      [[[biblio1]]]
      "
      (expect (sort (adoc--collect-anchor-ids) #'string<)
              :to-equal '("alpha" "beta" "biblio1" "delta" "gamma"))))

  (it "returns nil when there are no anchors"
    (with-adoc-buffer "Just some prose with <<a-ref>> but no definitions.\n"
      (expect (adoc--collect-anchor-ids) :to-equal nil))))

(describe "adoc--collect-attribute-names"
  (it "includes buffer-defined attributes and strips subnames"
    (with-adoc-buffer ":my-attr: value\n:other.sub.deep: w\n:flag!:\n"
      (let ((names (adoc--collect-attribute-names)))
        (expect (member "my-attr" names) :to-be-truthy)
        ;; multi-segment subnames are stripped to the bare name
        (expect (member "other" names) :to-be-truthy)
        (expect (member "other.sub" names) :to-be nil)
        ;; a trailing unset `!' is not part of the name
        (expect (member "flag" names) :to-be-truthy)
        (expect (member "flag!" names) :to-be nil))))

  (it "includes curated intrinsic attributes"
    (with-adoc-buffer "no attributes here\n"
      (let ((names (adoc--collect-attribute-names)))
        (expect (member "toc" names) :to-be-truthy)
        (expect (member "doctitle" names) :to-be-truthy)))))

(describe "adoc-completion-at-point"
  (describe "xref / anchor context"
    (it "completes inside an unclosed <<"
      (let ((capf (adoc-test--capf-at "[[alpha]]\n\nSee <<al|")))
        (expect capf :to-be-truthy)
        (expect (member "alpha" (adoc-test--capf-candidates capf))
                :to-be-truthy)))

    (it "completes inside an xref: target"
      (let ((capf (adoc-test--capf-at "[[alpha]]\n\nxref:al|")))
        (expect capf :to-be-truthy)
        (expect (member "alpha" (adoc-test--capf-candidates capf))
                :to-be-truthy)))

    (it "does not complete after a closed <<id>>"
      (expect (adoc-test--capf-at "See <<id>>|") :to-be nil))

    (it "covers a dotted id so the candidate matches"
      (let ((capf (adoc-test--capf-at "[[a.b]]\n\nSee <<a.b|")))
        (expect capf :to-be-truthy)
        (expect (member "a.b" (adoc-test--capf-candidates capf))
                :to-be-truthy)
        ;; the whole dotted id is the completion token, not just `b'
        (expect (plist-get capf :token) :to-equal "a.b"))))

  (describe "attribute context"
    (it "completes inside an unclosed {"
      (let ((capf (adoc-test--capf-at ":my-attr: v\n\nUse {my|")))
        (expect capf :to-be-truthy)
        (expect (member "my-attr" (adoc-test--capf-candidates capf))
                :to-be-truthy)))

    (it "does not complete after a closed {attr}"
      (expect (adoc-test--capf-at "{my-attr} text|") :to-be nil))

    (it "wins over xref when a { is open inside <<"
      (let ((capf (adoc-test--capf-at ":my-attr: v\n\nSee <<{my|")))
        (expect (member "my-attr" (adoc-test--capf-candidates capf))
                :to-be-truthy)))

    (it "wins over the source-language context when a { is open"
      (let ((capf (adoc-test--capf-at ":my-attr: v\n\n[source,{my|")))
        (expect (member "my-attr" (adoc-test--capf-candidates capf))
                :to-be-truthy))))

  (describe "source language context"
    (it "completes the language inside [source,"
      (let ((capf (adoc-test--capf-at "[source,ru|")))
        (expect capf :to-be-truthy)
        (expect (member "ruby" (adoc-test--capf-candidates capf))
                :to-be-truthy)))

    (it "does not complete after the closing bracket"
      (expect (adoc-test--capf-at "[source,ruby]|") :to-be nil)))

  (describe "include context"
    (it "offers file completion after include::"
      (let ((capf (adoc-test--capf-at "include::fo|")))
        (expect capf :to-be-truthy)
        (expect (plist-get capf :collection) :to-be #'completion-file-name-table)))

    (it "does not complete once the attribute list is open"
      (expect (adoc-test--capf-at "include::f.adoc[|") :to-be nil)))

  (it "returns nil in plain prose"
    (expect (adoc-test--capf-at "just some ordinary prose here|") :to-be nil)))

(provide 'adoc-mode-completion-test)

;;; adoc-mode-completion-test.el ends here
