;;; adoc-mode-image-test.el --- tests for adoc-mode image support -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests for image font-lock highlighting in adoc-mode.

;;; Code:

(require 'ert)
(require 'adoc-mode)
(require 'adoc-mode-test)

(ert-deftest adoctest-test-images ()
  (adoctest-faces "images"
                  ;; block macros
                  ;; empty arglist
                  "image" adoc-complex-replacement-face "::" adoc-meta-face
                  "./foo/bar.png" adoc-internal-reference-face
                  "[]" adoc-meta-face "\n" nil
                  ;; pos attribute 0 = alternate text
                  "image" adoc-complex-replacement-face "::" adoc-meta-face
                  "./foo/bar.png" adoc-internal-reference-face
                  "[" adoc-meta-face "lorem ipsum" adoc-secondary-text-face "]" adoc-meta-face "\n" nil
                  ;; keyword title
                  "image" adoc-complex-replacement-face "::" adoc-meta-face
                  "./foo/bar.png" adoc-internal-reference-face
                  "[" adoc-meta-face "alt" adoc-attribute-face "=" adoc-meta-face "lorem ipsum" adoc-secondary-text-face "]" adoc-meta-face "\n" nil
                  ;; keyword alt and title
                  "image" adoc-complex-replacement-face "::" adoc-meta-face
                  "./foo/bar.png" adoc-internal-reference-face
                  "[" adoc-meta-face "alt" adoc-attribute-face "=" adoc-meta-face "lorem ipsum" adoc-secondary-text-face "," adoc-meta-face
                  "title" adoc-attribute-face "=" adoc-meta-face "lorem ipsum" adoc-secondary-text-face "]" adoc-meta-face "\n" nil
                  ;; multiline alt and title
                  "image" adoc-complex-replacement-face "::" adoc-meta-face
                  "./foo/bar.png" adoc-internal-reference-face
                  "[" adoc-meta-face "alt" adoc-attribute-face "=" adoc-meta-face
                  "lorem\nipsum\nsit" adoc-secondary-text-face "," adoc-meta-face
                  "title" adoc-attribute-face "=" adoc-meta-face
                  "lorem\nipsum\nsit" adoc-secondary-text-face "]" adoc-meta-face "\n" nil

                  ;; no everything again with inline macros
                  "foo " 'no-face "image" adoc-complex-replacement-face ":" adoc-meta-face
                  "./foo/bar.png" adoc-internal-reference-face
                  "[]" adoc-meta-face "bar" 'no-face "\n" nil

                  "foo " 'no-face "image" adoc-complex-replacement-face ":" adoc-meta-face
                  "./foo/bar.png" adoc-internal-reference-face
                  "[" adoc-meta-face "lorem ipsum" adoc-secondary-text-face "]" adoc-meta-face "bar" 'no-face "\n" nil

                  "foo " 'no-face "image" adoc-complex-replacement-face ":" adoc-meta-face
                  "./foo/bar.png" adoc-internal-reference-face
                  "[" adoc-meta-face "alt" adoc-attribute-face "=" adoc-meta-face "lorem ipsum" adoc-secondary-text-face "]" adoc-meta-face "bar" 'no-face "\n" nil

                  "foo " 'no-face "image" adoc-complex-replacement-face ":" adoc-meta-face
                  "./foo/bar.png" adoc-internal-reference-face
                  "[" adoc-meta-face "alt" adoc-attribute-face "=" adoc-meta-face "lorem ipsum" adoc-secondary-text-face "," adoc-meta-face
                  "title" adoc-attribute-face "=" adoc-meta-face "lorem ipsum" adoc-secondary-text-face "]" adoc-meta-face "bar" 'no-face "\n" nil

                  "image" adoc-complex-replacement-face ":" adoc-meta-face
                  "./foo/bar.png" adoc-internal-reference-face
                  "[" adoc-meta-face "alt" adoc-attribute-face "=" adoc-meta-face
                  "lorem\nipsum\nsit" adoc-secondary-text-face "," adoc-meta-face
                  "title" adoc-attribute-face "=" adoc-meta-face
                  "lorem\nipsum\nsit" adoc-secondary-text-face "]" adoc-meta-face "\n" nil))

;;; adoc-mode-image-test.el ends here
