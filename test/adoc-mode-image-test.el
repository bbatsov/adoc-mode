;;; adoc-mode-image-test.el --- Image tests for adoc-mode -*- lexical-binding: t; -*-

;; Copyright © 2025-2026 Bozhidar Batsov

;;; Commentary:

;; Buttercup tests for adoc-mode image handling (attribute-reference
;; resolution in image paths).

;;; Code:

(require 'adoc-mode-test-helpers)

(describe "adoc-mode image attribute references"

  (it "resolves attribute references in image paths"
    (with-temp-buffer
      (adoc-mode)
      (insert ":my-url: https://example.com/image.png\n"
              ":badge: http://melpa.org/badge.svg\n"
              "\n"
              "image:{my-url}[]\n"
              "image:{badge}[alt]\n"
              "image:{undefined}[]\n"
              "image:plain.png[]\n")
      ;; a defined single reference is resolved
      (expect (adoc--resolve-attribute-references "{my-url}")
              :to-equal "https://example.com/image.png")
      (expect (adoc--resolve-attribute-references "{badge}")
              :to-equal "http://melpa.org/badge.svg")
      ;; an undefined reference is left unchanged
      (expect (adoc--resolve-attribute-references "{undefined}")
              :to-equal "{undefined}")
      ;; plain paths and empty strings are returned as-is
      (expect (adoc--resolve-attribute-references "plain.png")
              :to-equal "plain.png")
      (expect (adoc--resolve-attribute-references "")
              :to-equal "")))

  (it "resolves them the way Asciidoctor does at the image"
    (with-temp-buffer
      (adoc-mode)
      (insert ":base: https://example.com\n:Img: {base}/a.png\n:gone: x\n:gone!:\n\n"
              "image::{img}[]\n\n:base: http://other\n")
      (let ((pos (save-excursion (search-backward "image::"))))
        ;; case-insensitive, nested, and as set above the image
        (expect (adoc--resolve-attribute-references "{IMG}" pos)
                :to-equal "https://example.com/a.png")
        (expect (adoc--resolve-attribute-references "{base}" pos)
                :to-equal "https://example.com")
        ;; unset, and the built-in character attributes
        (expect (adoc--resolve-attribute-references "{gone}{sp}x" pos)
                :to-equal "{gone} x"))))

  (it "counts the counters in the section titles above the image"
    (with-temp-buffer
      (adoc-mode)
      (insert "= D\n\n== A {counter:n}\n\nimage::{n}.png[]\n\n"
              "== B {counter:n}\n\nimage::{n}.png[]\n")
      (goto-char (point-min))
      (let (paths)
        (while (re-search-forward "image::\\([^[]+\\)\\[" nil t)
          (push (adoc--resolve-attribute-references (match-string 1) (match-beginning 0))
                paths))
        (expect (nreverse paths) :to-equal '("1.png" "2.png"))))
    ;; and the entries below them still count
    (with-temp-buffer
      (adoc-mode)
      (insert "= D\n\n== A {counter:n}\n\n:img: x\n\nimage::{img}{n}.png[]\n")
      (expect (adoc--resolve-attribute-references "{img}{n}.png" (point-max))
              :to-equal "x1.png")))

  (it "only scans the section titles when one counts a counter"
    (with-temp-buffer
      (adoc-mode)
      (insert "= D\n\nStep {counter:n}.\n\n:dir: x\n\nimage::{dir}.png[]\n")
      (spy-on 'adoc--section-scan :and-call-through)
      (expect (adoc--resolve-attribute-references "{dir}.png" (point-max))
              :to-equal "x.png")
      (expect 'adoc--section-scan :not :to-have-been-called)))

  (it "keeps the special characters in their values"
    (with-temp-buffer
      (adoc-mode)
      (insert ":dir: R&D <new>\n\nimage::{dir}/a.png[]\n")
      (expect (adoc--resolve-attribute-references "{dir}/a.png")
              :to-equal "R&D <new>/a.png"))))

;;; adoc-mode-image-test.el ends here
