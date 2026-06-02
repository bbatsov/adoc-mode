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
              :to-equal ""))))

;;; adoc-mode-image-test.el ends here
