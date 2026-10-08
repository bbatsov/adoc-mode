;;; adoc-mode.el --- a major-mode for editing AsciiDoc files -*- lexical-binding: t; -*-
;;
;; Copyright 2009-2016 Florian Kaufmann <sensorflo@gmail.com>
;; Copyright 2022-2026 Bozhidar Batsov <bozhidar@batsov.dev> and adoc-mode contributors
;;
;; Maintainer: Bozhidar Batsov <bozhidar@batsov.dev>
;; Author: Florian Kaufmann <sensorflo@gmail.com>
;; URL: https://github.com/bbatsov/adoc-mode
;; Created: 2009
;; Version: 0.9.0
;; Package-Requires: ((emacs "28.1"))
;; Keywords: asciidoc, text
;;
;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:

;; AsciiDoc is a text document format for
;; writing short documents, articles, books and UNIX man pages.  AsciiDoc files
;; can be translated to HTML and DocBook markups.
;;
;; adoc-mode is an Emacs major mode for editing AsciiDoc files.  It emphasizes
;; the idea that the document is highlighted so it pretty much looks like the
;; final output.  What must be bold is bold, what must be italic is italic etc.
;; Meta characters are naturally still visible, but in a faint way, so they can
;; be easily ignored.
;;
;; adoc-mode aims to be fully compatible with the modern official AsciiDoc
;; language specification developed under the Eclipse AsciiDoc Working Group
;; (https://gitlab.eclipse.org/eclipse/asciidoc-lang/asciidoc-lang).  Progress
;; toward that goal is tracked in doc/spec-compliance.adoc.

;;; Code:

(require 'cl-lib)
(require 'outline)
(require 'subr-x)
(require 'xref)
(require 'adoc-mode-image)
(require 'adoc-mode-tempo)
(require 'adoc-asciidoctor)

(defconst adoc-mode-version "0.9.0"
  "adoc mode version number.")

;;;; customization
(defgroup adoc nil "Support for editing AsciiDoc files in GNU Emacs."
  :group 'text
  :prefix "adoc-"
  :version "0.9.0"
  :link '(url-link "https://github.com/bbatsov/adoc-mode"))

(defcustom adoc-script-raise '(-0.3 0.3)
  "How much to lower and raise subscript and superscript content.

This is a list of two floats.  The first is negative and specifies
how much subscript is lowered, the second is positive and
specifies how much superscript is raised.  Heights are measured
relative to that of the normal text.  The faces used are
`adoc-superscript-face' and `adoc-subscript-face' respectively.

You need to call `adoc-calc' after a change."
  :type '(list (float :tag "Subscript")
               (float :tag "Superscript"))
  :group 'adoc)

;; Interacts very badly with minor-modes using overlays because
;; `adoc-unfontify-region-function' removes ALL overlays, not only those which
;; where insered by `adoc-mode'.
(defcustom adoc-insert-replacement nil
  "When non-nil the character/string a replacement/entity stands for is displayed.

E.g. after \\='&amp;\\=' an \\='&\\=' is displayed, after \\='(C)\\=' the copy right
sign is displayed.  It is only about display, neither the file nor
the buffer content is affected.

You need to call `adoc-calc' after you change
`adoc-insert-replacement'.  For named character entities (e.g.
\\='&amp;\\=', in contrast to \\='&#20;\\=' or \\='(C)\\=' ) to be displayed you
need to set `adoc-unichar-name-resolver'.

Setting it to non-nil interacts very badly with minor-modes using
overlays."
  :type 'boolean
  :group 'adoc)

(defcustom adoc-unichar-name-resolver nil
  "Function taking a unicode char name and returning it's codepoint.

E.g. when given \"amp\" (as in the character entity reference
\"&amp;\"), it shall return 38 (#x26). Is used to insert the
character a character entity reference is referring to after the
entity.  When adoc-unichar-name-resolver is nil, or when its
function returns nil, nothing is done with named character
entities. Note that if `adoc-insert-replacement' is nil,
adoc-unichar-name-resolver is not used.

You can set it to `adoc-unichar-by-name' which uses the built-in
`sgml-char-names' table.  When you set adoc-unichar-name-resolver
to adoc-unichar-by-name, you need to call `adoc-calc' for the
change to take effect."
  :type '(choice (const nil)
                 (const adoc-unichar-by-name)
                 function)
  :group 'adoc)

(defcustom adoc-two-line-title-del '("==" "--" "~~" "^^" "++")
  "Delimiter used for the underline of two line titles.
Each string must be exactly 2 characters long. Corresponds to the
underlines element in the titles section of the asciidoc
configuration file."
  :type '(list
          (string :tag "level 0")
          (string :tag "level 1")
          (string :tag "level 2")
          (string :tag "level 3")
          (string :tag "level 4")
          (string :tag "level 5"))
  :group 'adoc)
(make-obsolete-variable 'adoc-two-line-title-del
                        "two-line (setext) titles are deprecated and support for them will be removed."
                        "0.10.0")

(defcustom adoc-delimited-block-del
  '("^/\\{4,\\}"         ; 0 comment
    "^\\+\\{4,\\}"       ; 1 pass
    "^-\\{4,\\}"         ; 2 listing
    "^\\.\\{4,\\}"       ; 3 literal
    "^_\\{4,\\}"         ; 4 quote
    "^=\\{4,\\}"         ; 5 example
    "^\\*\\{4,\\}"       ; 6 sidebar
    "^--")               ; 7 open block
  "Regexp used for delimited blocks.

WARNING: They should not contain a $. It is implied that they
match up to end of the line;

They correspond to delimiter variable blockdef-xxx sections in
the AsciiDoc configuration file.

However contrary to the AsciiDoc configuration file a separate
regexp can be given for the start line and for the end line. You
may want to do that because adoc-mode often can't properly
distinguish between a) a two line tile b) start of a delimited
block and c) end of a delimited block. If you start a listing
delimited block with '>----' and end it with '<----', then all
three cases can easily be distinguished. The regexp in your
AsciiDoc config file would the probably be '^[<>]-{4,}$'

Only the highlighting follows this option.  Finding where a block
begins and ends, so that a block is always fontified as a whole (see
`adoc--ensure-block-extents'), uses the standard Asciidoctor delimiters."
  :type '(list
          (choice :tag "comment"
                  (regexp :tag "start/end regexp")
                  (list :tag "separate regexp"
                        (regexp :tag "start regexp")
                        (regexp :tag "end regexp")))
          (choice :tag "pass"
                  (regexp :tag "start/end regexp")
                  (list :tag "separate regexp"
                        (regexp :tag "start regexp")
                        (regexp :tag "end regexp")))
          (choice :tag "listing"
                  (regexp :tag "start/end regexp")
                  (list :tag "separate regexp"
                        (regexp :tag "start regexp")
                        (regexp :tag "end regexp")))
          (choice :tag "literal"
                  (regexp :tag "start/end regexp")
                  (list :tag "separate regexp"
                        (regexp :tag "start regexp")
                        (regexp :tag "end regexp")))
          (choice :tag "quote"
                  (regexp :tag "start/end regexp")
                  (list :tag "separate regexp"
                        (regexp :tag "start regexp")
                        (regexp :tag "end regexp")))
          (choice :tag "example"
                  (regexp :tag "start/end regexp")
                  (list :tag "separate regexp"
                        (regexp :tag "start regexp")
                        (regexp :tag "end regexp")))
          (choice :tag "sidebar"
                  (regexp :tag "start/end regexp")
                  (list :tag "separate regexp"
                        (regexp :tag "start regexp")
                        (regexp :tag "end regexp")))
          (choice :tag "open"
                  (regexp :tag "start/end regexp")
                  (list :tag "separate regexp"
                        (regexp :tag "start regexp")
                        (regexp :tag "end regexp")))))

(defcustom adoc-default-title-type 1
  "Default title type, see `adoc-title-descriptor'."
  :type '(choice (const :tag "One-line" 1)
                 (const :tag "Two-line" 2))
  :group 'adoc)
(make-obsolete-variable 'adoc-default-title-type
                        "two-line (setext) titles are deprecated and support for them will be removed."
                        "0.10.0")

(defcustom adoc-default-title-sub-type 1
  "Default title sub type, see `adoc-title-descriptor'."
  :type '(choice (const :tag "Only starting delimiter" 1)
                 (const :tag "Starting and trailing delimiter" 2))
  :group 'adoc)

(defcustom adoc-enable-two-line-title nil
  "Whether or not two line titles shall be fontified.

Two-line (Setext) titles are deprecated by Asciidoctor in favor
of the one-line (atx) style, and `adoc-mode' will drop support for
them in a future release, along with this option.  Until then,
\\<adoc-mode-map>\\[adoc-toggle-title-type] converts the two-line title
at point to the one-line style while the option is enabled.

nil means never fontify.  t means always fontify.  A number means
only fontify if the line below has NOT the length of the given
number.  You could use a number for example when all your
delimited block lines have a certain length."
  :type '(choice (const nil)
                 (const t)
                 number)
  :group 'adoc)
(make-obsolete-variable 'adoc-enable-two-line-title
                        "two-line (setext) titles are deprecated and support for them will be removed."
                        "0.10.0")

(defcustom adoc-section-id-style 'auto
  "How section auto-ids are derived from section titles.

Asciidoctor turns a section title into an id using the `idprefix' and
`idseparator' attributes.  This option controls which style `adoc-mode'
assumes when offering and resolving section ids (completion, the `xref'
backend, `adoc-goto-ref-label').

`auto'         Honour `:idprefix:' / `:idseparator:' set in the document;
               otherwise use the Antora style when the file lives in an
               Antora component (an `antora.yml' is found above it), and
               the Asciidoctor default style elsewhere.
`asciidoctor'  Asciidoctor's default: prefix and separator both `_'
               (e.g. `My Title' -> `_my_title').
`antora'       Antora's default: empty prefix, `-' separator
               (e.g. `My Title' -> `my-title')."
  :type '(choice (const :tag "Auto-detect" auto)
                 (const :tag "Asciidoctor default (_my_title)" asciidoctor)
                 (const :tag "Antora (my-title)" antora))
  :group 'adoc)

(defcustom adoc-imenu-create-index-function 'adoc-imenu-create-nested-index
  "Function to create the imenu index.
Use `adoc-imenu-create-nested-index' for a hierarchical index
reflecting heading structure, or `adoc-imenu-create-index' for a
flat list."
  :type '(choice (function-item adoc-imenu-create-nested-index)
                 (function-item adoc-imenu-create-index))
  :group 'adoc)

(defcustom adoc-title-style 'adoc-title-style-one-line
  "Title style used for title tempo templates.

See for example `tempo-template-adoc-title-1'."
  :type '(choice (const :tag "== one line" adoc-title-style-one-line)
                 (const :tag "== one line enclosed ==" adoc-title-style-one-line-enclosed)
                 (const :tag "two line\\n--------  (deprecated)" adoc-title-style-two-line))
  :group 'adoc)

(defcustom adoc-fontify-code-blocks-natively 5000
  "When non-nil, fontify code in code blocks using the native major mode.
This only works for code blocks where the language is
specified where we can automatically determine the appropriate
mode to use.  The language to mode mapping may be customized by
setting the variable `adoc-code-lang-modes'.

The value can be a number that determines the size
up to which code blocks are fontified natively.
If the value is another non-nil value then code blocks
are fontified natively regardless of their size."
  :group 'adoc
  :type '(choice :tag "Fontify code blocks " :format "\n%{%t%}: %[Size%] %v"
                 (integer :tag "limited to")
                 (boolean :tag "unlimited"))
  :safe (lambda (x) (or (booleanp x) (numberp x)))
  :package-version '(adoc-mode . "0.8.0"))

;; This is based on `org-src-lang-modes' from org-src.el
(defcustom adoc-code-lang-modes
  '(
    ("asymptote" . asy-mode)
    ("bash" . sh-mode)
    ("C" . c-mode)
    ("cpp" . c++-mode)
    ("C++" . c++-mode)
    ("calc" . fundamental-mode)
    ("ditaa" . artist-mode)
    ("dot" . fundamental-mode)
    ("elisp" . emacs-lisp-mode)
    ("ocaml" . (neocaml-mode tuareg-mode caml-mode))
    ("screen" . shell-script-mode)
    ("shell" . sh-mode)
    ("sqlite" . sql-mode)
    )
  "Alist mapping languages to their major mode.
The key is the language name.  The value is either a single major
mode or a list of candidate modes tried in order, the first
defined one being used.  This makes it possible to map a language
to a preferred mode with fallbacks: for example there is no
ocaml-mode in Emacs, so `ocaml' maps to `neocaml-mode', then
`tuareg-mode', then `caml-mode'."
  :group 'adoc
  :type '(repeat
          (cons
           (string "Language name")
           (choice (symbol "Major mode")
                   (repeat (symbol "Major mode")))))
  :package-version '(adoc-mode . "0.8.0"))

(defcustom adoc-fontify-code-block-default-mode 'prog-mode
  "Default mode to use to fontify code blocks.
This mode is used when automatic detection fails, such as for
code blocks with no language specified."
  :group 'adoc
  :type '(choice function (const :tag "None" nil))
  :package-version '(adoc-mode . "0.8.0"))

(defcustom adoc-font-lock-extend-after-change-max 5000
  "Number of chars scanned backwards for re-fontification of code block headers.
Also used to delimit the scan for the end delimiter."
  :type 'integer
  :group 'adoc
  :package-version '(adoc-mode . "0.8.0"))

(defcustom adoc-max-image-size nil
  "Maximum width and height for displayed images.
This variable may be nil or a cons cell (MAX-WIDTH . MAX-HEIGHT).
When nil, use the actual size.  Otherwise, use ImageMagick to
resize larger images to be of the given maximum dimensions.  This
requires Emacs to be built with ImageMagick support."
  :group 'adoc
  :package-version '(adoc-mode . "0.8.0")
  :type '(choice
          (const :tag "Use actual image width" nil)
          (cons (choice (sexp :tag "Maximum width in pixels")
                        (const :tag "No maximum width" nil))
                (choice (sexp :tag "Maximum height in pixels")
                        (const :tag "No maximum height" nil)))))

(defcustom adoc-display-images t
  "Run `adoc-display-images' in function `adoc-mode'."
  :group 'adoc
  :package-version '(adoc-mode . "0.8.0")
  :type 'boolean)


;;;; faces / font lock
(defgroup adoc-faces nil
  "Faces used in Adoc Mode."
  :group 'adoc
  :group 'faces)

(defface adoc-align-face
  '((t (:inherit (adoc-meta-face))))
  "Face used so the text looks left aligned.

Is applied to whitespaces at the beginning of a line. You want to
set it to a fixed width face. This is useful if your default face
is a variable with face. Because for e.g. in a variable with
face, '- ' and ' ' (two spaces) don't have equal with, with
`adoc-align-face' in the following example the item's text looks
aligned.

- lorem ipsum
  dolor ..."
  :group 'adoc-faces)


;;;; misc
(defconst adoc-title-max-level 5
  "Max title level, counting starts at 0.
AsciiDoc supports six heading levels: a level-0 document title plus
level-1 through level-5 sections.")

(defconst adoc-uolist-max-level 5
  "Max unordered (bulleted) list item nesting level, counting starts at 0.")

(defconst adoc--url-schemes '("http" "https" "ftp" "file" "irc")
  "The URL schemes Asciidoctor makes a link of, as in `https://example.org'.")

(defconst adoc--link-macro-names
  (append adoc--url-schemes '("mailto" "callto" "link"))
  "The names of the inline macros that link somewhere, as in `mailto:me[Me]'.")

;; I think it's actually not worth the fuzz to try to sumarize regexps until
;; profiling profes otherwise. Nevertheless I can't stop doing it.
(defconst adoc-summarize-re-uolisti t
  "When non-nil, sumarize regexps for unordered list items into one regexp.
To become a customizable variable when regexps for list items become
customizable.")

(defconst adoc-summarize-re-olisti t
  "As `adoc-summarize-re-uolisti', but for ordered list items.")

(defconst adoc-summarize-re-llisti t
  "As `adoc-summarize-re-uolisti', but for labeled list items.")

(defvar adoc-unichar-alist nil
  "An alist, key=unicode character name as string, value=codepoint.")

;; although currently always the same face is used, I prefer an alist over a
;; list. It is faster to find out whether any attribute id is in the alist or
;; not. And maybe adoc-faces splits up adoc-secondary-text-face into more
;; specific faces.
(defvar adoc-attribute-face-alist
  '(("id" . adoc-anchor-face)
    ("caption" . adoc-secondary-text-face)
    ("xreflabel" . adoc-secondary-text-face)
    ("alt" . adoc-secondary-text-face)
    ("title" . adoc-secondary-text-face)
    ("attribution" . adoc-secondary-text-face)
    ("citetitle" . adoc-secondary-text-face)
    ("text" . adoc-secondary-text-face))
  "An alist, key=attribute id, value=face.")

(defvar adoc-mode-abbrev-table nil
  "Abbrev table in use in adoc-mode buffers.")

(defvar adoc-font-lock-keywords nil
  "Font lock keywords in adoc-mode buffers.")

(define-abbrev-table 'adoc-mode-abbrev-table ())


;;;; help text copied from asciidoc manual
(defconst adoc-help-constrained-quotes
  "Constrained quotes must be bounded by white space or commonly
  adjoining punctuation characters. These are the most commonly
  used type of quote.")
(defconst adoc-help-emphasis
  "Usually rendered italic")
(defconst adoc-help-bold
  "Usually rendered bold")
(defconst adoc-help-monospace
  "Aka typewritter. This does _not_ mean verbatim / literal")
(defconst adoc-help-single-quote
  "Curved (smart) single quotation marks around the enclosed text,
written as '`text`'.")
(defconst adoc-help-double-quote
  "Curved (smart) double quotation marks around the enclosed text,
written as \"`text`\".")
(defconst adoc-help-underline
  "Applies an underline decoration to the span of text.")
(defconst adoc-help-overline
  "Applies an overline decoration to the span of text.")
(defconst adoc-help-line-through
  "Applies a line-through (aka strikethrough) decoration to the span of text.")
(defconst adoc-help-nobreak
  "Disables words within the span of text from being broken.")
(defconst adoc-help-nowrap
  "Prevents the span of text from wrapping at all.")
(defconst adoc-help-pre-wrap
  "Prevents sequences of space and space-like characters from being collapsed (i.e., all spaces are preserved).")
(defconst adoc-help-attributed
  "A mechanism to allow inline attributes to be applied to
  otherwise unformatted text.")
(defconst adoc-help-unconstrained-quotes
  "Unconstrained quotes have no boundary constraints and can be
  placed anywhere within inline text.")
(defconst adoc-help-line-break
  "A plus character preceded by at least one space character at
  the end of a non-blank line forces a line break. It generates a
  line break (`br`) tag for HTML outputs and a custom XML
  `asciidoc-br` processing instruction for DocBook outputs")
(defconst adoc-help-page-break
  "A line of three or more less-than (`<<<`) characters will
  generate a hard page break in DocBook and printed HTML
  outputs.")
(defconst adoc-help-ruler-line
  "A line of three or more apostrophe characters will generate a
  ruler line. It generates a ruler (`hr`) tag for HTML outputs
  and a custom XML `asciidoc-hr` processing instruction for
  DocBook outputs.")
(defconst adoc-help-entity-reference
  "You can also include arbitrary character entity references in
  the AsciiDoc source. Example both `&amp;` and `&#38;` are
  replace by an & (ampersand).")
(defconst adoc-help-literal-paragraph
  "Verbatim in a monospaced font. Applied to paragraphs where
  the first line is indented by one or more space or tab
  characters")
(defconst adoc-help-delimited-block
  "Delimited blocks are blocks of text enveloped by leading and
  trailing delimiter lines (normally a series of four or more
  repeated characters).")
(defconst adoc-help-delimited-block-comment
  "The contents of 'CommentBlocks' are not processed; they are
  useful for annotations and for excluding new or outdated
  content that you don't want displayed. CommentBlocks are never
  written to output files.")
(defconst adoc-help-delimited-block-passthrouh
  "By default the block contents is subject only to 'attributes'
  and 'macros' substitutions (use an explicit 'subs' attribute to
  apply different substitutions). PassthroughBlock content will
  often be backend specific. The following styles can be applied
  to passthrough blocks: pass:: No substitutions are performed.
  This is equivalent to `subs=\"none\"`. asciimath, latexmath::
  By default no substitutions are performed, the contents are
  rendered as mathematical formulas.")
(defconst adoc-help-delimited-block-listing
  "'ListingBlocks' are rendered verbatim in a monospaced font,
  they retain line and whitespace formatting and are often
  distinguished by a background or border. There is no text
  formatting or substitutions within Listing blocks apart from
  Special Characters and Callouts. Listing blocks are often used
  for computer output and file listings.")
(defconst adoc-help-delimited-block-literal
  "'LiteralBlocks' are rendered just like literal paragraphs.")
(defconst adoc-help-delimited-block-quote
  "'QuoteBlocks' are used for quoted passages of text. There are
  two styles: 'quote' and 'verse'. The style behavior is
  identical to quote and verse paragraphs except that blocks can
  contain multiple paragraphs and, in the case of the 'quote'
  style, other section elements. The first positional attribute
  sets the style, if no attributes are specified the 'quote'
  style is used. The optional 'attribution' and 'citetitle'
  attributes (positional attributes 2 and3) specify the quote's
  author and source.")
(defconst adoc-help-delimited-block-example
  "'ExampleBlocks' encapsulate the DocBook Example element and
  are used for, well, examples. Example blocks can be titled by
  preceding them with a 'BlockTitle'. DocBook toolchains will
  normally automatically number examples and generate a 'List of
  Examples' backmatter section.

  Example blocks are delimited by lines of equals characters and
  can contain any block elements apart from Titles, BlockTitles
  and Sidebars) inside an example block.")
(defconst adoc-help-delimited-block-sidebar
  "A sidebar is a short piece of text presented outside the
  narrative flow of the main text. The sidebar is normally
  presented inside a bordered box to set it apart from the main
  text.The sidebar body is treated like a normal section body.")
(defconst adoc-help-delimited-block-open-block
  "An 'OpenBlock' groups a set of block elements.")
(defconst adoc-help-list
  "Indentation is optional and does _not_ determine nesting.")
(defconst adoc-help-bulleted-list
  "Aka itimized or unordered.")
(defconst adoc-help-list-item-continuation
  "Another list or a literal paragraph immediately following a
  list item is implicitly appended to the list item; to append
  other block elements to a list item you need to explicitly join
  them to the list item with a 'list continuation' (a separator
  line containing a single plus character). Multiple block
  elements can be appended to a list item using list
  continuations (provided they are legal list item children in
  the backend markup).")
(defconst adoc-help-table
  "The AsciiDoc table syntax looks and behaves like other
  delimited block types and supports standard block configuration
  entries.")
(defconst adoc-help-macros
  "Inline Macros occur in an inline element context. A Block
  macro reference must be contained in a single line separated
  either side by a blank line or a block delimiter. Block macros
  behave just like Inline macros, with the following differences:
  1) They occur in a block context. 2) The default syntax is
  <name>::<target>[<attrlist>] (two colons, not one). 3) Markup
  template section names end in -blockmacro instead of
  -inlinemacro.")
(defconst adoc-help-url
  "If you don’t need a custom link caption you can enter the
  http, https, ftp, file URLs and email addresses without any
  special macro syntax.")
(defconst adoc-help-anchor
  "Used to specify hypertext link targets. The `<id>` is a unique
  string that conforms to the output markup's anchor syntax. The
  optional `<xreflabel>` is the text to be displayed by
  captionless 'xref' macros that refer to this anchor.")
(defconst adoc-help-xref
  "Creates a hypertext link to a document anchor. The `<id>`
  refers to an anchor ID. The optional `<caption>` is the link's
  displayed text.")
(defconst adoc-help-local-doc-link
  "Hypertext links to files on the local file system are
  specified using the link inline macro.")
(defconst adoc-help-comment
  "Single lines starting with two forward slashes hard up against
  the left margin are treated as comments. Comment lines do not
  appear in the output unless the showcomments attribute is
  defined. Comment lines have been implemented as both block and
  inline macros so a comment line can appear as a stand-alone
  block or within block elements that support inline macro
  expansion.")
(defconst adoc-help-passthrough-macros
  "Passthrough macros are analogous to passthrough blocks and are
  used to pass text directly to the output. The substitution
  performed on the text is determined by the macro definition but
  can be overridden by the <subslist>. Passthroughs, by
  definition, take precedence over all other text
  substitutions.")
(defconst adoc-help-pass
  "Inline and block. Passes text unmodified (apart from
  explicitly specified substitutions).")
(defconst adoc-help-asciimath
  "Inline and block. Passes text unmodified. A (backend
  dependent) mechanism for rendering mathematical formulas given
  using the ASCIIMath syntax.")
(defconst adoc-help-latexmath
  "Inline and block. Passes text unmodified. A (backend
  dependent) mechanism for rendering mathematical formulas given
  using the LaTeX math syntax.")
(defconst adoc-help-pass-+++
  "Inline and block. The triple-plus passthrough is functionally
  identical to the pass macro but you don’t have to escape ]
  characters and you can prefix with quoted attributes in the
  inline version.")
(defconst adoc-help-pass-$$
  "Inline and block. The double-dollar passthrough is
  functionally identical to the triple-plus passthrough with one
  exception: special characters are escaped.")
(defconst adoc-help-monospace-literal
  "Text quoted with single backtick characters constitutes an
  inline literal passthrough. The enclosed text is rendered in a
  monospaced font and is only subject to special character
  substitution. This makes sense since monospace text is usually
  intended to be rendered literally and often contains characters
  that would otherwise have to be escaped. If you need monospaced
  text containing inline substitutions use a plus character
  instead of a backtick.")

;;; adoc Hiding ===============================================================
(defconst adoc-markup-properties
  '(face adoc-markup-face invisible adoc-markup)
  "List of properties and values to apply to markup.")

(defconst adoc-language-keyword-properties
  '(face adoc-language-keyword-face invisible adoc-markup)
  "List of properties and values to apply to code block language names.")

(defconst adoc-language-info-properties
  '(face adoc-language-info-face invisible adoc-markup)
  "List of properties and values to apply to code block language info strings.")

(defconst adoc-include-title-properties
  '(face adoc-link-title-face invisible adoc-markup)
  "List of properties and values to apply to included code titles.")

;;; Font Lock =================================================================

(require 'font-lock)

(defface adoc-gen-face
  '((t (:inherit font-lock-function-name-face)))
  "Generic/base face for text with special formatting.

Typically `adoc-title-0-face', `adoc-bold-face' etc.
inherit from it.  Also used for generic text that hasn't got its
own dedicated face, e.g. if a markup command imposes arbitrary
colors/sizes/fonts upon it.

The default inherits from `font-lock-function-name-face' so that
AsciiDoc-formatted text picks up the active theme's palette;
customise this face to override the colour for all derived faces
at once."
  :group 'adoc-faces)

(defface adoc-meta-face
  '((t (:inherit shadow :slant normal :weight normal)))
  "Face for general meta characters and base for special meta characters.
Inherits from `shadow' so the colour tracks the active theme.  The
`:slant' and `:weight' resets keep the markup from picking up bold
or italic styling from a surrounding constrained quote."
  :group 'adoc-faces)

(defface adoc-value-face
  '((t :inherit adoc-meta-face))
  "For attribute values."
  :group 'adoc-faces)

(defface adoc-bold-face
  '((t (:inherit bold)))
  "Face for bold text.
Plain `bold' rather than a tinted face, matching `asciidoc-mode' and the
convention in `markdown-mode' / `org-mode'."
  :group 'adoc-faces)

(defface adoc-emphasis-face
  '((t :inherit italic))
  "For emphasized text.
Plain `italic' rather than a tinted face, matching `asciidoc-mode' and the
convention in `markdown-mode' / `org-mode'."
  :group 'adoc-faces)

(defface adoc-markup-face
  '((t (:inherit shadow :slant normal :weight normal)))
  "Face for markup elements."
  :group 'adoc-faces)

(defface adoc-meta-hide-face
  '((t (:inherit adoc-meta-face)))
  "For meta characters which can be \\='hidden\\='.
Hidden in the sense of *almost* not visible.  They do not need to
be properly seen because one knows what these characters must be;
deduced from the highlighting of the near context.  E.g. in
AsciiDoc's \\='_important_\\=', the underscores would be highlighted with
`adoc-meta-hide-face' and the text \\='important\\=' with
`adoc-emphasis-face'.  Because \\='important\\=' is highlighted, one
knows that it must be surrounded with the meta characters \\='_\\=', and
thus the meta characters do not need to be properly seen.

By default this face simply inherits from `adoc-meta-face' so it
tracks the active theme.  Customise it (for example to a foreground
close to the background colour) if you want the markup to fade
further into the background.

For example:
AsciiDoc: *bold emphasis text* or _emphasis text_
          ^                    ^    ^             ^"
  :group 'adoc-faces)

(defface adoc-attribute-face
  '((t :inherit adoc-meta-face :slant italic))
  "For attribute names."
  :group 'adoc-faces)

(defface adoc-anchor-face
  '((t :inherit adoc-meta-face :overline t))
  "For the name/id of an anchor."
  :group 'adoc-faces)

(defface adoc-list-face
  '((t (:inherit adoc-markup-face)))
  "Face for list item markers."
  :group 'adoc-faces)

(defface adoc-checkbox-face
  '((t (:inherit font-lock-constant-face)))
  "Face for checklist checkboxes (`[ ]', `[x]', `[*]')."
  :group 'adoc-faces)

(defface adoc-code-face
  '((t (:inherit fixed-pitch)))
  "Face for inline code and fenced code blocks.
  This may be used, for example, to add a contrasting background to
  inline code fragments and code blocks."
  :group 'adoc-faces)

(defface adoc-command-face
  '((t (:inherit font-lock-builtin-face :weight bold)))
  "Face for command names (e.g. the `kbd' in `kbd:[C-c C-c]')."
  :group 'adoc-faces)

(defface adoc-complex-replacement-face
  '((t (:inherit font-lock-builtin-face)))
  "Markup that is replaced by something complex.
For example an image, or a table of contents.
AsciiDoc: image:...[...]"
  :group 'adoc-faces)

(defface adoc-passthrough-face
  '((t :inherit (fixed-pitch adoc-gen-face)))
  "For text that is passed through yet another parser/renderer.

  Since this text is passed to an arbitrary renderer, it is unknown
  which of its chars are meta characters and which are literal characters."
  :group 'adoc-faces)

(defface adoc-preprocessor-face
  '((t :inherit (font-lock-preprocessor-face adoc-meta-face)))
  "For preprocessor constructs"
  :group 'adoc-faces)

(defface adoc-verbatim-face
  '((t (:inherit font-lock-string-face)))
  "For verbatim text.

Verbatim in a sense that all its characters are to be taken
literally.  Note that does not necessarily mean that it is in
a typewriter font.
For example \\='foo\\=' in the following examples.  In parentheses is a
summary what the command is for according to the given markup
language.
\\=`foo\\=`     (verbatim and typewriter font)
+++foo+++ (only verbatim)"
  :group 'adoc-faces)

(defface adoc-warning-face
  '((t :inherit (font-lock-warning-face)))
  "For things that should stand out."
  :group 'adoc-faces)

(defface adoc-table-face
  '((t (:inherit (adoc-code-face))))
  "Face for tables."
  :group 'adoc-faces)

(defface adoc-language-keyword-face
  '((t (:inherit font-lock-type-face)))
  "Face for programming language identifiers."
  :group 'adoc-faces)

(defface adoc-replacement-face
  '((t (:inherit font-lock-constant-face)))
  "Meta characters that are replaced by text in the output.
See also `adoc-complex-replacement-face'.
For example
AsciiDoc: \\='->\\=' is replaced by an Unicode arrow
It is difficult to say whether adoc-replacement-face is part of
the group adoc-faces-meta or part of the group
adoc-faces-text.  Technically they are clearly meta characters.
However they are just another representation of normal text and I
want to fontify them as such.  E.g. in HTML \\='<b>foo &amp; bar</b>\\=',
the output \\='foo & bar\\=' is fontified bold, thus I also want \\='foo
&amp; bar\\=' in the Emacs buffer be fontified with
adoc-bold-face.  Thus adoc-replacement-face needs to be
something that is orthogonal to the adoc-bold-face etc faces."
  :group 'adoc-faces)

(defface adoc-language-info-face
  '((t (:inherit font-lock-string-face)))
  "Face for programming language info strings."
  :group 'adoc-faces)

(defface adoc-reference-face
  '((t (:inherit link)))
  "Face for the link-text portion of a link or inline macro.
For example the `foo' in `http://example.com[foo]'."
  :group 'adoc-faces)

(defface adoc-url-face
  '((t (:inherit font-lock-string-face)))
  "Face for URL targets and standalone URLs.
For example the URL part of `http://example.com[foo]', or a raw
`http://example.com' appearing as bare text."
  :group 'adoc-faces)

(defface adoc-link-title-face
  '((t (:inherit adoc-markup-face)))
  "Face for reference link titles."
  :group 'adoc-faces)

(defface adoc-link-mouse-face
  '((t (:inherit highlight :underline t)))
  "Face used to highlight a link, URL or anchor under the mouse pointer."
  :group 'adoc-faces)

(defface adoc-comment-face
  '((t (:inherit font-lock-comment-face)))
  "Face for HTML comments."
  :group 'adoc-faces)

(defface adoc-blockquote-face
  '((t (:inherit font-lock-doc-face)))
  "Face for the content of `[quote]' and `[verse]' delimited blocks."
  :group 'adoc-faces)

(defface adoc-metadata-key-face
  '((t (:inherit font-lock-variable-name-face)))
  "Face for the key of a document attribute entry.
For example the `:author:' in `:author: Bozhidar Batsov'."
  :group 'adoc-faces)

(defface adoc-metadata-value-face
  '((t (:inherit font-lock-string-face)))
  "Face for the value of a document attribute entry.
For example `Bozhidar Batsov' in `:author: Bozhidar Batsov'."
  :group 'adoc-faces)

(defface adoc-footnote-marker-face
  '((t (:inherit adoc-command-face)))
  "Face for the `footnote:' / `footnoteref:' macro name."
  :group 'adoc-faces)

(defface adoc-footnote-text-face
  '((t (:inherit font-lock-comment-face)))
  "Face for the body text of a `footnote:[…]' macro."
  :group 'adoc-faces)

(defface adoc-strike-through-face
  '((t (:strike-through t)))
  "Face for strike-through text written as `[.line-through]#text#'."
  :group 'adoc-faces)

(defface adoc-underline-face
  '((t (:underline t)))
  "Face for underlined text written as `[.underline]#text#'."
  :group 'adoc-faces)

(defface adoc-overline-face
  '((t (:overline t)))
  "Face for overlined text written as `[.overline]#text#'."
  :group 'adoc-faces)

(defface adoc-highlight-face
  '((t (:inherit highlight)))
  "Face for highlighted text written as `#text#'.
In Asciidoctor a hash-delimited span renders with the default
`highlighted' style (typically a yellow background)."
  :group 'adoc-faces)

(defface adoc-superscript-face
  '((t :inherit adoc-gen-face :height 0.8))
  "For superscript text.
For example \\='foo\\=' in the ^foo^
Note that typically the major mode doing the font lock
additionaly raises the text; face customization does not provide
this feature."
  :group 'adoc-faces)

(defface adoc-subscript-face
  '((t :inherit adoc-gen-face :height 0.8))
  "For subscript text.
For example \\='foo\\=' in the ~foo~
Note that typically the major mode doing the font lock
additionally lowers the text; face customization does not provide
this feature."
  :group 'adoc-faces)

(defface adoc-title-face
  '((t (:inherit adoc-gen-face :weight bold)))
  "Base face for titles."
  :group 'adoc-faces)

(defcustom adoc-title-scaling t
  "Whether to use variable-height faces for section titles.
When non-nil each `adoc-title-N-face' is sized according to
`adoc-title-scaling-values'.  When nil all title faces use the
buffer's default height.

Modifying this variable through `setq' has no immediate effect on
already-loaded faces; use `customize-set-variable' or call
`adoc-update-title-faces' afterwards."
  :type 'boolean
  :initialize #'custom-initialize-default
  :set (lambda (sym val)
         (set-default sym val)
         (when (fboundp 'adoc-update-title-faces)
           (adoc-update-title-faces)))
  :group 'adoc-faces
  :package-version '(adoc-mode . "0.9.0"))

(defcustom adoc-title-scaling-values
  '(2.0 1.8 1.6 1.4 1.2 1.0)
  "List of `:height' values for titles of level 0 through 5.
Only takes effect when `adoc-title-scaling' is non-nil."
  :type '(repeat float)
  :initialize #'custom-initialize-default
  :set (lambda (sym val)
         (set-default sym val)
         (when (fboundp 'adoc-update-title-faces)
           (adoc-update-title-faces)))
  :group 'adoc-faces
  :package-version '(adoc-mode . "0.9.0"))

(defface adoc-title-0-face
  `((t (:inherit adoc-title-face
                 :height ,(if adoc-title-scaling
                              (float (nth 0 adoc-title-scaling-values))
                            1.0))))
  "Face for document's title.
You probably don't want to customise this face directly.  Instead
configure `adoc-title-face' or the scaling variable
`adoc-title-scaling'."
  :group 'adoc-faces)

(defface adoc-title-1-face
  `((t (:inherit adoc-title-face
                 :height ,(if adoc-title-scaling
                              (float (nth 1 adoc-title-scaling-values))
                            1.0))))
  "Face for level 1 titles.
See `adoc-title-0-face' for customisation tips."
  :group 'adoc-faces)

(defface adoc-title-2-face
  `((t (:inherit adoc-title-face
                 :height ,(if adoc-title-scaling
                              (float (nth 2 adoc-title-scaling-values))
                            1.0))))
  "Face for level 2 titles.
See `adoc-title-0-face' for customisation tips."
  :group 'adoc-faces)

(defface adoc-title-3-face
  `((t (:inherit adoc-title-face
                 :height ,(if adoc-title-scaling
                              (float (nth 3 adoc-title-scaling-values))
                            1.0))))
  "Face for level 3 titles.
See `adoc-title-0-face' for customisation tips."
  :group 'adoc-faces)

(defface adoc-title-4-face
  `((t (:inherit adoc-title-face
                 :height ,(if adoc-title-scaling
                              (float (nth 4 adoc-title-scaling-values))
                            1.0))))
  "Face for level 4 titles.
See `adoc-title-0-face' for customisation tips."
  :group 'adoc-faces)

(defface adoc-title-5-face
  `((t (:inherit adoc-title-face
                 :height ,(if adoc-title-scaling
                              (float (nth 5 adoc-title-scaling-values))
                            1.0))))
  "Face for level 5 titles.
See `adoc-title-0-face' for customisation tips."
  :group 'adoc-faces)

(defun adoc-update-title-faces ()
  "Refresh `adoc-title-N-face' heights from the scaling customs.
Reads `adoc-title-scaling' and `adoc-title-scaling-values' and
applies the corresponding `:height' to every title face.  Faces
that the user has explicitly customised (i.e. that carry a
`saved-face' property) are left untouched.

Called automatically from the `:set' callbacks of
`adoc-title-scaling' and `adoc-title-scaling-values'; invoke it
directly if you changed those variables with `setq'."
  (dotimes (n 6)
    (let ((face (intern (format "adoc-title-%d-face" n)))
          (height (if adoc-title-scaling
                      (float (nth n adoc-title-scaling-values))
                    1.0)))
      (unless (get face 'saved-face)
        (set-face-attribute face nil :height height)))))

(defface adoc-typewriter-face
  '((t :inherit (fixed-pitch adoc-gen-face)))
  "For text in typewriter/monospaced font.

  For example \\='foo\\=' in the following examples:
  +foo+ (only typewriter font)
  \\=`foo\\=` (verbatim and typewriter font)"
  :group 'adoc-faces)

(defface adoc-internal-reference-face
  '((t :inherit adoc-meta-face :underline t))
  "For an internal reference."
  :group 'adoc-faces)

(defface adoc-secondary-text-face
  '((t (:inherit font-lock-comment-face :height 0.9)))
  "For text that is not part of the running text.
For example for captions of tables or images,
or for footnotes, or for floating text."
  :group 'adoc-faces)

(defface adoc-native-code-face
  '((t (:inherit fixed-pitch)))
  "For code blocks that are highlighted natively.

Use it to change the background of the code blocks."
  :group 'adoc-faces)

;;;; regexps
;; from AsciiDoc manual: The attribute name/value syntax is a single line ...
;; from asciidoc.conf:
;; ^:(?P<attrname>\w[^.]*?)(\.(?P<attrname2>.*?))?:(\s+(?P<attrvalue>.*))?$
;; asciidoc src code: AttributeEntry.isnext shows that above regexp is matched
;; against single line.
(defun adoc-re-attribute-entry ()
  (concat "^\\(:[a-zA-Z0-9_][^.\n]*?\\(?:\\..*?\\)?:[ \t]*\\)\\(.*?\\)$"))

;; from asciidoc.conf: ^= +(?P<title>[\S].*?)( +=)?$
;; asciidoc src code: Title.isnext reads two lines, which are then parsed by
;; Title.parse. The second line is only for the underline of two line titles.
(defun adoc-re-one-line-title (level)
  "Returns a regex matching a one line title of the given LEVEL.
When LEVEL is nil, a one line title of any level is matched.

match-data has these sub groups:
1 leading delimiter inclusive whites between delimiter and title text
2 title's text exclusive leading/trailing whites
3 trailing delimiter with all whites
4 trailing delimiter only inclusive whites between title text and delimiter
0 only chars that belong to the title block element

==  my title  ==  n
---12------23------
            4--4"
  (let* ((del (if level
                  (make-string (+ level 1) ?=)
                (concat "=\\{1," (number-to-string (1+ adoc-title-max-level)) "\\}"))))
    (concat
     "^\\(" del "[ \t]+\\)"                   ; 1
     "\\([^ \t\n].*?\\)"                          ; 2
     ;; using \n instead $ is important so group 3 is guaranteed to be at least 1
     ;; char long (except when at the end of the buffer()). That is important to
     ;; to have a place to put the text property adoc-reserved on.
     "\\(\\([ \t]+" del "\\)?[ \t]*\\(?:\n\\|\\'\\)\\)" ))) ; 3 & 4

(defun adoc-make-one-line-title (sub-type level text)
  "Returns a one line title of LEVEL and SUB-TYPE containing the given text."
  (let ((del (make-string (+ level 1) ?=)))
    (concat del " " text (when (eq sub-type 2) (concat " " del)))))

;; AsciiDoc handles that by source code, there is no regexp in AsciiDoc.  See
;; also adoc-re-one-line-title.
(defun adoc-re-two-line-title-underline (&optional del)
  "Returns a regexp matching the underline of a two line title.

DEL is an element of `adoc-two-line-title-del' or nil. If nil,
any del is matched.

Note that even if this regexp matches it still doesn't mean it is
a two line title underline, see also `adoc-re-two-line-title'."
  (concat
   "\\("
   (mapconcat
    (lambda(x)
      (concat
       "\\(?:"
       "\\(?:" (regexp-quote x) "\\)+"
       (regexp-quote (substring x 0 1)) "?"
       "\\)"))
    (if del (list del) adoc-two-line-title-del) "\\|")
   ;; adoc-re-two-line-title shall have same behaviour also one line, thus
   ;; also here use \n instead $
   "\\)[ \t]*\\(?:\n\\|\\'\\)"))

;; asciidoc.conf: regexp for _first_ line
;; ^(?P<title>.*?)$  additionally, must contain (?u)\w, see Title.parse
(defun adoc-re-two-line-title (del)
  "Returns a regexps that matches a two line title.

Note that even if this regexp matches it still doesn't mean it is
a two line title. You additionally have to test if the underline
has the correct length.

DEL is described in `adoc-re-two-line-title-underline'.

match-data has these sub groups:

1 dummy, so that group 2 is the title's text as in
  adoc-re-one-line-title
2 title's text
3 delimiter
0 only chars that belong to the title block element"
  (when (not (eq (length del) 2))
    (error "two line title delimiters must be 2 chars long"))
  (concat
   ;; 1st line: title text must contain at least one \w character, see
   ;; asciidoc src, Title.parse,
   "\\(\\)\\(^.*?[a-zA-Z0-9_].*?\\)[ \t]*\n"
   ;; 2nd line: underline
   (adoc-re-two-line-title-underline del)))

(defun adoc-make-two-line-title (level text)
  "Returns a two line title of given LEVEL containing given TEXT.
LEVEL starts at 1."
  (concat text "\n" (adoc-make-two-line-title-underline level (length text))))

(defun adoc-make-two-line-title-underline (level &optional length)
  "Returns a two line title underline.
LEVEL is the level of the title, starting at 1. LENGTH is the
line of the title's text. When nil it defaults to 4."
  (unless length
    (setq length 4))
  (let* ((repetition-cnt (if (>= length 2) (/ length 2) 1))
         (del (nth level adoc-two-line-title-del))
         (result ""))
    (while (> repetition-cnt 0)
      (setq result (concat result del))
      (setq repetition-cnt (- repetition-cnt 1)))
    (when (eq (% length 2) 1)
      (setq result (concat result (substring del 0 1))))
    result))

(defun adoc-re-oulisti (type &optional level sub-type)
  "Returns a regexp matching an (un)ordered list item.

match-data his this sub groups:
1 leading whites
2 delimiter
3 trailing whites between delimiter and item's text
0 only chars belonging to delimiter/whites. I.e. none of text.

WARNING: See warning about list item nesting level in `adoc-list-descriptor'."
  (cond
   ;;   ^\s*- +(?P<text>.+)$                     normal 0
   ;;   ^\s*\* +(?P<text>.+)$                    normal 1
   ;;   ...                                      ...
   ;;   ^\s*\*{5} +(?P<text>.+)$                 normal 5
   ;;   ^\+ +(?P<text>.+)$                       bibliograpy(DEPRECATED)
   ((eq type 'adoc-unordered)
    (cond
     ((or (eq sub-type 'adoc-normal) (null sub-type))
      (let ((r (cond ((numberp level) (if (eq level 0) "-" (make-string level ?\*)))
                     ((or (null level) (eq level 'adoc-all-levels)) "-\\|\\*\\{1,5\\}")
                     (t (error "Adoc-unordered/adoc-normal: invalid level")))))
        (concat "^\\([ \t]*\\)\\(" r "\\)\\([ \t]+\\)")))
     ((and (eq sub-type 'adoc-bibliography) (null level))
      "^\\(\\)\\(\\+\\)\\([ \t]+\\)")
     (t (error "Adoc-unordered: invalid sub-type/level combination"))))

   ;;   ^\s*(?P<index>\d+\.) +(?P<text>.+)$      decimal = 0
   ;;   ^\s*(?P<index>[a-z]\.) +(?P<text>.+)$    lower alpha = 1
   ;;   ^\s*(?P<index>[A-Z]\.) +(?P<text>.+)$    upper alpha = 2
   ;;   ^\s*(?P<index>[ivx]+\)) +(?P<text>.+)$   lower roman = 3
   ;;   ^\s*(?P<index>[IVX]+\)) +(?P<text>.+)$   upper roman = 4
   ((eq type 'adoc-explicitly-numbered)
    (when level (error "Adoc-explicitly-numbered: invalid level"))
    (let* ((l '("[0-9]+\\." "[a-z]\\." "[A-Z]\\." "[ivx]+)" "[IVX]+)"))
           (r (cond ((numberp sub-type) (nth sub-type l))
                    ((or (null sub-type) (eq sub-type 'adoc-all-subtypes)) (mapconcat #'identity l "\\|"))
                    (t (error "Adoc-explicitly-numbered: invalid subtype")))))
      (concat "^\\([ \t]*\\)\\(" r "\\)\\([ \t]+\\)")))

   ;;   ^\s*\. +(?P<text>.+)$                    normal 0
   ;;   ^\s*\.{2} +(?P<text>.+)$                 normal 1
   ;;   ... etc until 5                          ...
   ((eq type 'adoc-implicitly-numbered)
    (let ((r (cond ((numberp level) (number-to-string (+ level 1)))
                   ((or (null level) (eq level 'adoc-all-levels)) "1,5")
                   (t (error "Adoc-implicitly-numbered: invalid level")))))
      (concat "^\\([ \t]*\\)\\(\\.\\{" r "\\}\\)\\([ \t]+\\)")))

   ;;   ^<?(?P<index>\d*>) +(?P<text>.+)$        callout
   ((eq type 'adoc-callout)
    (when (or level sub-type) (error "Adoc-callout invalid level/sub-type"))
    "^\\(\\)\\(<?[0-9]*>\\)\\([ \t]+\\)")

   ;; invalid
   (t (error "invalid (un)ordered list type"))))

(defun adoc-make-uolisti (level is-1st-line)
  "Returns a regexp matching a unordered list item."
  (let* ((del (if (eq level 0) "-" (make-string level ?\*)))
         (white-1st (if indent-tabs-mode
                        (make-string (/ (* level standard-indent) tab-width) ?\t)
                      (make-string (* level standard-indent) ?\ )))
         (white-rest (make-string (+ (length del) 1) ?\ )))
    (if is-1st-line
        (concat white-1st del " ")
      white-rest)))

(defun adoc-re-llisti (type level)
  "Returns a regexp matching a labeled list item.
Subgroups:
1 leading blanks
2 label text, incl whites before delimiter
3 delimiter incl trailing whites
4 delimiter only

  foo :: bar
-12--23-3
      44"
  (cond
   ;; ^\s*(?P<label>.*[^:])::(\s+(?P<text>.+))?$    normal 0
   ;; ^\s*(?P<label>.*[^;]);;(\s+(?P<text>.+))?$    normal 1
   ;; ^\s*(?P<label>.*[^:]):{3}(\s+(?P<text>.+))?$  normal 2
   ;; ^\s*(?P<label>.*[^:]):{4}(\s+(?P<text>.+))?$  normal 3
   ((eq type 'adoc-labeled-normal)
    (let* ((deluq (nth level '("::" ";;" ":::" "::::"))) ; unqutoed
           (del (regexp-quote deluq))
           (del1st (substring deluq 0 1)))
      (concat
       "^\\([ \t]*\\)"                  ; 1
       "\\(.*[^" del1st "\n]\\)"        ; 2
       "\\(\\(" del "\\)\\(?:[ \t]+\\|$\\)\\)"))) ; 3 & 4

   ;; glossary (DEPRECATED)
   ;; ^(?P<label>.*\S):-$
   ((eq type 'adoc-labeled-qanda)
    (concat
     "^\\([ \t]*\\)"                    ; 1
     "\\(.*[^ \t\n]\\)"                 ; 2
     "\\(\\(\\?\\?\\)\\)$"))            ; 3 & 4

   ;; qanda (DEPRECATED)
   ;; ^\s*(?P<label>.*\S)\?\?$
   ((eq type 'adoc-labeled-glossary)
    (concat
     "^\\(\\)"                          ; 1
     "\\(.*[^ \t\n]\\)"                 ; 2
     "\\(\\(:-\\)\\)$"))                ; 3 & 4
   (t (error "Unknown type/level"))))

(defun adoc-re-delimited-block-line ()
  (concat
   "\\(?:"
   (mapconcat
    (lambda (x)
      (concat "\\(?:" x "\\)[ \t]*$"))
    adoc-delimited-block-del "\\|")
   "\\)"))

(defun adoc-re-delimited-block (del)
  "Return a regexp matching a whole delimited block of type DEL.
DEL indexes `adoc-delimited-block-del'.  Like Asciidoctor, the block
ends at the first line that repeats the opening delimiter exactly.
Group 1 is the opening delimiter, 2 the content, 3 the closing
delimiter."
  (let* ((tmp (nth del adoc-delimited-block-del))
         (start (if (consp tmp) (car tmp) tmp))
         (end (if (consp tmp) (cdr tmp) "\\1")))
    (concat
     "\\(" start "\\)[ \t]*\n"
     "\\(\\(?:.*\n\\)*?\\)"
     "\\(" end "\\)[ \t]*$")))

;; TODO: since its multiline, it doesn't yet work properly.
(defun adoc-re-verbatim-paragraph-sequence ()
  (concat
   "\\("
   ;; 1. paragraph in sequence delimited by blank line or list continuation
   "^\\+?[ \t]*\n"

   ;; sequence of verbatim paragraphs
   "\\(?:"
   ;; 1st line starts with blanks, but has also non blanks, i.e. is not empty
   "[ \t]+[^ \t\n].*"
   ;; 2nd+ line is neither a blank line nor a list continuation line
   "\\(?:\n\\(?:[^+ \t\n]\\|[ \t]+[^ \t\n]\\|\\+[ \t]*[^ \t\n]\\).*?\\)*?"
   ;; paragraph delimited by blank line or list continuation or end of buffer
   ;; NOTE: now list continuation belongs to the verbatim paragraph sequence,
   ;; but actually we want to highlight it differently. Thus the font lock
   ;; keyword handling list continuation must come after verbatim paragraph
   ;; sequence.
   "\\(?:\n[ \t]*\\(?:\n\\|\\'\\)\\|\n\\+[ \t]*\n\\|\\'\\)"
   "\\)+"

   "\\)" ))

;; ^\.(?P<title>([^.\s].*)|(\.[^.\s].*))$
;; Isn't that asciidoc.conf regexp the same as: ^\.(?P<title>(.?[^.\s].*))$
;; insertion: so that this whole regex doesn't mistake a line starting with a
;; cell specifier like .2+| as a block title
(defun adoc-re-block-title ()
  "Returns a regexp matching an block title

Subgroups:
1 delimiter
2 title's text incl trailing whites
3 newline or end-of-buffer anchor

.foo n
12--23"
  (concat
   "^\\(\\.\\)"
   "\\(\\.?\\(?:"
   "[0-9]+[^+*]" ; inserted part, see above
   "\\|[^. \t\n]\\).*\\)"
   "\\(\n\\|\\'\\)"))

;; (?u)^(?P<name>image|unfloat|toc)::(?P<target>\S*?)(\[(?P<attrlist>.*?)\])$
;; note that although it hasn't got the s Python regular expression flag, it
;; still can spawn multiple lines. Probably asciidoc removes newlines before
;; it applies the regexp above
(defun adoc-re-block-macro (&optional cmd-name)
  "Returns a regexp matching an attribute list element.
Subgroups:
1 cmd name
2 target
3 attribute list, exclusive brackets []"
  (concat
   "^\\(" (or cmd-name "[a-zA-Z0-9_]+") "\\)::"
   "\\([^ \t\n]*?\\)"
   "\\["
   "\\(" (adoc-re-content) "\\)"
   "\\][ \t]*$"))

;; ?P<id>[\w\-_]+
(defun adoc-re-id ()
  "Returns a regexp matching an id used by anchors/xrefs"
  "\\(?:[-a-zA-Z0-9_]+\\)")

(defun adoc-re-anchor (&optional type id)
  "Returns a regexp matching an anchor.

If TYPE is non-nil, only that type is matched. If TYPE is nil,
all types are matched.

If ID is non-nil, the regexp matches an anchor defining exactly
this id. If ID is nil, the regexp matches any anchor."
  (cond
   ((eq type 'block-id)
    ;; ^\[\[(?P<id>[\w\-_]+)(,(?P<reftext>.*?))?\]\]$
    (concat "^\\[\\["
            "\\(" (if id (regexp-quote id) (adoc-re-id)) "\\)"
            "\\(?:,\\(.*?\\)\\)?"
            "\\]\\][ \t]*$"))

   ((eq type 'inline-special)
    ;; [\\]?\[\[(?P<attrlist>[\w"_:].*?)\]\]
    (concat "\\(\\[\\[\\)"
            "\\(" (if id
                       (concat (regexp-quote id) "[ \t]*\\(?:,.*?\\)?")
                     "[a-zA-Z0-9\"_:].*?")
            "\\)"
            "\\(\\]\\]\\)"))

   ((eq type 'biblio)
    ;; [\\]?\[\[\[(?P<attrlist>[\w_:][\w_:.-]*?)\]\]\]
    (concat "\\(\\[\\[\\)"
            "\\(\\[" (if id (regexp-quote id) "[a-zA-Z0-9_:][a-zA-Z0-9_:.-]*?") "\\]\\)"
            "\\(\\]\\]\\)"))

   ((eq type 'inline-general)
    (adoc-re-inline-macro "anchor" id))

   ((eq type 'block-id-shorthand)
    ;; Modern block ID shorthand on a block attribute line, e.g. [#id],
    ;; [#id.role%opt] or [style#id].  Group 1 is the id; anything before the
    ;; `#' is a positional style and anything after is a role/option/attr.
    (concat "^\\[\\(?:[^][#\n]*\\)#"
            "\\(" (if id (regexp-quote id) (adoc-re-id)) "\\)"
            "\\(?:[.%,][^]\n]*\\)?"
            "\\][ \t]*$"))

   ((null type)
    (mapconcat
     (lambda (x) (adoc-re-anchor x id))
     '(block-id block-id-shorthand inline-special biblio inline-general)
     "\\|"))

   (t
    (error "Unknown type"))))

(defun adoc-re-xref (&optional type for-kw)
  "Returns a regexp matching a reference.

If TYPE is nil, any type is matched. If FOR-KW is true, the
regexp is intended for a font lock keyword, which has to make
further tests to find a proper xref."
  (cond
   ((eq type 'inline-special-with-caption)
    ;; (?su)[\\]?&lt;&lt;(?P<attrlist>[\w"].*?)&gt;&gt;=xref2
    (if for-kw
        "\\(<<\\)\\([[:alnum:]_#/.:{\"][^,>\n]*?\\(?:\n[^,>\n]*?\\)??\\)\\(,\\)\\(.*?\\(?:\n.*?\\)??\\)\\(>>\\)"
      (concat "\\(<<\\)\\(" (adoc-re-id) "[ \t\n]*\\)\\(,\\)\\([^>\n]*?\\(?:\n[^>\n]*?\\)??\\)\\(>>\\)")))

   ((eq type 'inline-special-no-caption)
    ;; asciidoc.conf uses the same regexp as for without caption
    (if for-kw
        "\\(<<\\)\\([[:alnum:]_#/.:{\"][^,>\n]*?\\(?:\n[^,>\n]*?\\)??\\)\\(>>\\)"
      (concat "\\(<<\\)\\(" (adoc-re-id) "[ \t\n]*\\)\\(>>\\)")))

   ((eq type 'inline-general-macro)
    (adoc-re-inline-macro "xref"))

   ((null type)
    (mapconcat
     (lambda (x) (adoc-re-xref x for-kw))
     '(inline-special-with-caption inline-special-no-caption inline-general-macro)
     "\\|"))

   (t (error "unknown type"))))

(defconst adoc-re-attribute-list-elt
  (concat
   ",?[ \t\n]*"
   "\\(?:\\([a-zA-Z_]+\\)[ \t\n]*=[ \t\n]*\\)?"         ; 1
   "\\(?:"
   ;; regexp for string: See 'Mastering Regular Expressions', chapter 'The
   ;; Real "Unrolling-the-Loop" Pattern'.
   "\"\\([^\"\\]*\\(?:\\\\.[^\"\\]*\\)*\\)\"[ \t\n]*" "\\|"   ; 2
   "\\([^,]+\\)"                                      ; 3
   "\\)")
  "Regexp matching an attribute list element.

Subgroups:
1 attribute name
2 attribute value if given as string
3 attribute value if not given as string")

(defun adoc-re-precond (&optional unwanted-chars backslash-allowed disallowed-at-bol)
  (concat
   (when disallowed-at-bol ".")
   "\\(?:"
   (unless disallowed-at-bol "^\\|")
   "[^"
   (if unwanted-chars unwanted-chars "")
   (if backslash-allowed "" "\\")
   "\n"
   "]"
   "\\)"))

(defun adoc-re-quote-precondition (not-allowed-chars)
  "Regexp that matches before a (un)constrained quote delimiter.

NOT-ALLOWED-CHARS are chars not allowed before the quote."
  (concat
   "\\(?:"
   "^"
   "\\|"
   "\\="
   "\\|"
                                        ; or *not* after
                                        ; - an backslash
                                        ; - user defined chars
   "[^" not-allowed-chars "\\\n]"
   "\\)"))

;; AsciiDoc src:
;; # Unconstrained quotes can appear anywhere.
;; reo = re.compile(r'(?msu)(^|.)(\[(?P<attrlist>[^[\]]+?)\])?' \
;;         + r'(?:' + re.escape(lq) + r')' \
;;         + r'(?P<content>.+?)(?:'+re.escape(rq)+r')')
;;
;; BUG: Escaping ala \\**...** does not yet work. Probably adoc-mode should do
;; it like this, which is more similar to how asciidoc does it: 'Allow'
;; backslash as the first char. If the first char is ineed a backslash, it is
;; 'removed' (-> adoc-meta-hide-face face), and the rest of the match is left
;; unaffected.
(defun adoc-re-unconstrained-quote (ldel &optional rdel content)
  "Return a regexp matching an unconstrained quote between LDEL and RDEL.
RDEL defaults to LDEL.  CONTENT is the regexp for the quoted text,
by default any text spanning up to a paragraph."
  (unless rdel (setq rdel ldel))
  (let* ((qldel (regexp-quote ldel))
         (qrdel (regexp-quote rdel)))
    (concat
     (adoc-re-quote-precondition "")
     "\\(\\[[^][]+?\\]\\)?"
     "\\(" qldel "\\)"
     "\\(" (or content (adoc-re-content "+")) "\\)"
     "\\(" qrdel "\\)")))

;; AsciiDoc src for constrained quotes
;; # The text within constrained quotes must be bounded by white space.
;; # Non-word (\W) characters are allowed at boundaries to accommodate
;; # enveloping quotes.
;;
;; reo = re.compile(r'(?msu)(^|[^\w;:}])(\[(?P<attrlist>[^[\]]+?)\])?' \
;;     + r'(?:' + re.escape(lq) + r')' \
;;     + r'(?P<content>\S|\S.*?\S)(?:'+re.escape(rq)+r')(?=\W|$)')
(defun adoc-re-constrained-quote (ldel &optional rdel)
  "AsciiDoc src for constrained quotes.

subgroups:
1 attribute list [optional]
2 starting del
3 enclosed text
4 closing del"
  (unless rdel (setq rdel ldel))
  (let ((qldel (regexp-quote ldel))
        (qrdel (regexp-quote rdel)))
    (concat
     ;; added &<> because those are special chars which are substituted by a
     ;; entity, which ends in ;, which is prohibited in the ascidoc.conf regexp
     (adoc-re-quote-precondition "A-Za-z0-9;:}&<>")
     "\\(\\[[^][]+?\\]\\)?"
     "\\(" qldel "\\)"
     "\\([^ \t\n]\\|[^ \t\n]" (adoc-re-content) "[^ \t\n]\\)"
     "\\(" qrdel "\\)"
     ;; BUG: now that Emacs doesn't have look-ahead, the match is too long, and
     ;; adjacent quotes of the same type wouldn't be recognized.
     "\\(?:[^A-Za-z0-9\n]\\|[ \t]*$\\)")))

(defun adoc-re-quote (type ldel &optional rdel)
  (cond
   ((eq type 'adoc-constrained)
    (adoc-re-constrained-quote ldel rdel))
   ((eq type 'adoc-unconstrained)
    (adoc-re-unconstrained-quote ldel rdel))
   ((eq type 'adoc-script)
    ;; Super- and subscripts can't contain whitespace (`\S+?' in
    ;; Asciidoctor), so `~/.emacs.d/init.el to ~/backup' isn't one.
    (adoc-re-unconstrained-quote ldel rdel "[^ \t\n]+?"))
   (t
    (error "Invalid type"))))

;; Macros using default syntax. From asciidoc.conf:
;; (?su)(?<!\w)[\\]?(?P<name>http|https|ftp|file|irc|mailto|callto|image|link|anchor|xref|indexterm):(?P<target>\S*?)\[(?P<attrlist>.*?)\]
;;
;; asciidoc.conf itself says: Default (catchall) inline macro is not
;; implemented. It _would_ be
;; (?su)[\\]?(?P<name>\w(\w|-)*?):(?P<target>\S*?)\[(?P<passtext>.*?)(?<!\\)\]=
(defun adoc-re-inline-macro (&optional cmd-name target unconstrained attribute-list-constraints)
  "Returns regex matching an inline macro.

Id CMD-NAME is nil, any command is matched. It maybe a regexp
itself in order to match multiple commands. If TARGET is nil, any
target is matched. When UNCONSTRAINED is nil, the returned regexp
begins with \\='\\<\\=', i.e. it will _not_ match when CMD-NAME is part
of a previous word. When ATTRIBUTE-LIST-CONSTRAINTS is the symbol
`empty', only an empty attribute list is matched, if it is
`single-attribute', only an attribute list with exactly one
attribute is matched.

Subgroups of returned regexp:
1 cmd name
2 :
3 target
4 [
5 attribute list, exclusive brackets [], also when
  attribute-list-constraints is non-nil
6 ]"
  ;; !!! \< is not exactly what AsciiDoc does, see regex above
  (concat
   (unless unconstrained "\\<")
   "\\(" (if cmd-name (concat "\\(?:" cmd-name "\\)") "\\w+") "\\)"
   "\\(:\\)"
   "\\(" (if target (regexp-quote target) "[^ \t\n]*?") "\\)"
   "\\(\\[\\)\\("
   (cond
    ((eq attribute-list-constraints 'empty) "")
    ((eq attribute-list-constraints 'single-attribute) "[^\n,]*?\\(?:\n[^\n,]*?\\)??")
    (t (adoc-re-content)))
   "\\)\\(\\]\\)" ))

;; TODO: use same regexps as for font lock
(defun adoc-re-paragraph-separate ()
  (concat

   ;; empty line
   "[ \t]*$"

   ;; delimited blocks / two line titles
   "\\|"
   "\\("
   "^+" "\\|"
   "\\++" "\\|"
   "/+" "\\|"
   "-+" "\\|"
   "\\.+" "\\|"
   "\\*+" "\\|"
   "_*+" "\\|"
   "=*+" "\\|"
   "~*+" "\\|"
   "^*+" "\\|"
   "--"
   "\\)"
   "[ \t]*$"

   ;; one line titles and block titles (https://docs.asciidoctor.org/asciidoc/latest/blocks/add-title/#block-title-syntax)
   "\\|"
   "[=.].*$"))

;; TODO: use same regexps as for font lock
(defun adoc-re-paragraph-start ()
  (concat
   paragraph-separate

   ;; list items
   "\\|"
   "[ \t]*"
   "\\("
   "-"                  "\\|"
   "\\*\\{1,5\\}"       "\\|"
   "\\.\\{1,5\\}"       "\\|"
   "[0-9]\\{,3\\}\\."   "\\|"
   "[a-z]\\{,3\\}\\."   "\\|"
   "[A-Z]\\{,3\\}\\."   "\\|"
   "[ivxmcIVXMC]+)"     "\\|"
   ".*?:\\{2,4\\}"
   "\\)"
   "\\( \\|$\\)"

   ;; table rows
   "\\|"
   "|"
))

(defun adoc-re-aor(e1 e2)
  "all or: Returns a regex matching \(e1\|e2\|e1e2\)? "
  (concat "\\(?:" e1 "\\)?\\(?:" e2 "\\)?"))

(defun adoc-re-ror(e1 e2)
  "real or: Returns a regex matching \(e1\|e2\|e1e2\)."
  (concat "\\(?:\\(?:" e1 "\\)\\|\\(?:" e2 "\\)\\|\\(?:" e1 "\\)\\(?:" e2 "\\)\\)"))

;; ((?<!\S)((?P<span>[\d.]+)(?P<op>[*+]))?(?P<align>[<\^>.]{,3})?(?P<style>[a-z])?)?\|'
(defun adoc-re-cell-specifier ()
  (let* ((fullspan (concat (adoc-re-ror "[0-9]+" "\\.[0-9]+") "[*+]"))
         (align (adoc-re-ror "[<^>]" "\\.[<^>]"))
         (style "[demshalv]"))
    (concat "\\(?:" fullspan "\\)?\\(?:" align "\\)?\\(?:" style "\\)?")))

;; bug: if qualifier is "+", and the thing to match starts at the end of a
;;      line (i.e. the first char is newline), then wrongly this regexp does
;;      never match.
;; Note: asciidoc uses Python's \s to determine blank lines, while _not_
;;       setting either the LOCALE or UNICODE flag, see
;;       Reader.skip_blank_lines. Python uses [ \t\n\r\f\v] for it's \s . So
;;       the horizontal spaces are [ \t].
(defun adoc-re-content (&optional qualifier)
  "Matches content, possibly spawning multiple non-blank lines"
  (concat
   "\\(?:"
   ;; content on initial line
   "." (or qualifier "*") "?"
   ;; if content spawns multiple lines
   "\\(?:\n"
   ;; complete non blank lines
   "\\(?:[ \t]*\\S-.*\n\\)*?"
   ;; leading content on last line
   ".*?"
   "\\)??"
   "\\)"))


;;;; font lock keywords
(defsubst adoc-kwf-search (regexp &optional bound noerror count)
  "Keyword search for Adoc.
Like `re-search-forward' with the same arguments
REGEXP, BOUND, NOERROR and COUNT.
If a match for REGEXP is found where the text property
`adoc-code-block' is non-nil continue the search.
This speeds up the search and avoids the application of
adoc-syntax to code blocks."
  (let (ret)
    (while (and
            (setq ret (re-search-forward regexp bound noerror count))
            (get-text-property (point) 'adoc-code-block)
            (null (eobp))))
    ret))

(defun adoc-kwf-std (end regexp &optional must-free-groups no-block-del-groups predicate)
  "Standard function for keywords
Intendent to be called from font lock keyword functions. END is
the limit of the search. REXEXP the regexp to be searched.
MUST-FREE-GROUPS a list of regexp group numbers which may not
match text that has an adoc-reserved text-property with a non-nil
value. Likewise, groups in NO-BLOCK-DEL-GROUPS may not contain
text having adoc-reserved set to symbol `block-del'.  PREDICATE,
when non-nil, is called with the match data set and rejects the
match by returning nil.

A rejected match doesn't end the search: font-lock abandons a
keyword for the rest of the region as soon as its matcher returns
nil, so the search goes on to the next match instead."
  (let ((found t) (prevented t))
    (while (and found prevented (<= (point) end) (not (eobp)))
      (setq found (adoc-kwf-search regexp end t))
      (setq prevented
            (and found
                 (or
                  (and predicate (not (funcall predicate)))
                  (cl-some (lambda(x)
                             (and (match-beginning x)
                                  (text-property-not-all (match-beginning x)
                                                         (match-end x)
                                                         'adoc-reserved nil)))
                           must-free-groups)
                  (cl-some (lambda(x)
                             (and (match-beginning x)
                                  (text-property-any (match-beginning x)
                                                     (match-end x)
                                                     'adoc-reserved 'block-del)))
                           no-block-del-groups))))
      (when (and found prevented (<= (point) end))
        (let ((next (1+ (match-beginning 0))))
          ;; Skip past contiguous reserved text to avoid re-matching it
          (while (and (< next end) (get-text-property next 'adoc-reserved))
            (setq next (or (next-single-property-change next 'adoc-reserved nil end)
                           end)))
          (goto-char next))))
    (and found (not prevented))))

(defun adoc-kwf-attribute-list (end)
  ;; for each attribute list before END
  (while (< (point) end)
    (goto-char (or (text-property-not-all (point) end 'adoc-attribute-list nil)
                   end))
    (when (< (point) end)
      (let* ((attribute-list-end
              (or (text-property-any (point) end 'adoc-attribute-list nil)
                  end))
             (prop-of-attribute-list
              (get-text-property (point) 'adoc-attribute-list))
             ;; position (number) or name (string) of current
             ;; attribute. Attribute list start with positional attributes, as
             ;; opposed to named attributes, thus init with 0.
             (pos-or-name-of-attribute 0))

        (if (facep prop-of-attribute-list)
            ;; The attribute list is not really an attribute list. As a whole
            ;; it counts as text.
            (put-text-property
             (point) attribute-list-end
             'face prop-of-attribute-list)

          ;; for each attribute in current attribute list
          (while (re-search-forward adoc-re-attribute-list-elt attribute-list-end t)
            (when (match-beginning 1); i.e. when it'a named attribute
              ;; get attribute's name
              (setq pos-or-name-of-attribute
                    (buffer-substring-no-properties (match-beginning 1) (match-end 1)))
              ;; fontify the attribute's name with adoc-attribute-face
              (put-text-property
               (match-beginning 1) (match-end 1) 'face 'adoc-attribute-face))

            ;; fontify the attribute's value
            (let ((match-group-of-attribute-value (if (match-beginning 2) 2 3))
                  (attribute-value-face
                   (adoc-face-for-attribute pos-or-name-of-attribute prop-of-attribute-list)))
              (put-text-property
               (match-beginning match-group-of-attribute-value)
               (match-end match-group-of-attribute-value)
               'face attribute-value-face))

            (when (numberp pos-or-name-of-attribute)
              (setq pos-or-name-of-attribute (1+ pos-or-name-of-attribute)))))

        (goto-char attribute-list-end))))
  nil)

(defun adoc-facespec-script (face raise)
  "Return a quoted face spec for a super- or subscript in FACE.
The text is displayed RAISE lines higher, unless RAISE is 0."
  (list 'quote
        (append `(face ,face)
                (unless (zerop raise)
                  `(display (raise ,raise))))))

(defun adoc-facespec-subscript ()
  (adoc-facespec-script 'adoc-subscript-face (car adoc-script-raise)))

(defun adoc-facespec-superscript ()
  (adoc-facespec-script 'adoc-superscript-face (cadr adoc-script-raise)))

;; TODO: use & learn some more macro magic so adoc-kw-unconstrained-quote and
;; adoc-kw-constrained-quote are less redundant and have common parts in one
;; macro. E.g. at least such 'lists'
;; (not (text-property-not-all (match-beginning 1) (match-end 1) 'adoc-reserved nil))
;; (not (text-property-not-all (match-beginning 3) (match-end 3) 'adoc-reserved nil))
;; ...
;; could surely be replaced by a single (adoc-not-reserved-bla-bla 1 3)

(defun adoc--delimited-block-match-p ()
  "Return non-nil unless the delimited block matched can't be one.
In a listing, literal or other verbatim block a delimiter line is just
content, and a block nested in another one has to close before it does.
See `adoc--ensure-block-extents' for how blocks are found."
  (let ((block (get-text-property (match-beginning 0) 'adoc-delimited-block)))
    (or (null block)
        (= (nth 1 block) (match-beginning 0))
        (and (not (nth 2 block))
             (<= (match-end 0) (nth 3 block))))))

(defun adoc--outside-delimited-block-p ()
  "Return non-nil when the current match doesn't start inside a delimited block.
Asciidoctor reads a section title inside a delimited block as plain
text.  See `adoc--ensure-block-extents' for how blocks are found."
  (not (get-text-property (match-beginning 0) 'adoc-delimited-block)))

(defun adoc-kw-one-line-title (level text-face)
  "Creates a keyword for font-lock which highlights one line titles.
TEXT-FACE is a face name symbol."
  (let ((face-form (list 'quote text-face)))
    (list
     `(lambda (end) (adoc-kwf-std end ,(adoc-re-one-line-title level) '(0) nil
                                  #'adoc--outside-delimited-block-p))
     '(1 '(face adoc-meta-hide-face adoc-reserved block-del) t)
     `(2 ,face-form t)
     '(3  '(face nil adoc-reserved block-del) t)
     '(4 '(face adoc-meta-hide-face) t t))))

;; TODO: highlight bogous 'two line titles' with warning face
;; TODO: completely remove keyword when adoc-enable-two-line-title is nil
(defun adoc--two-line-title-underline-p (length)
  "Return non-nil when a line LENGTH chars long may underline a two-line title.
That takes two-line titles to be enabled, and LENGTH to differ from
a numeric `adoc-enable-two-line-title'."
  (and adoc-enable-two-line-title
       (not (eql adoc-enable-two-line-title length))))

(defun adoc--two-line-title-match-p ()
  "Return non-nil when the last `adoc-re-two-line-title' match is a title.
The underline has to be about as long as the text, may not be excluded
by `adoc-enable-two-line-title', and the text line may not be a block
attribute list or block title (Asciidoctor reads those as the
metadata of the block below)."
  (let ((underline (- (match-end 3) (match-beginning 3))))
    (and (< (abs (- (- (match-end 2) (match-beginning 2)) underline)) 3)
         (adoc--two-line-title-underline-p underline)
         (not (memq (char-after (match-beginning 2)) '(?\[ ?.))))))

(defun adoc-kw-two-line-title (del text-face)
  "Creates a keyword for font-lock which highlights two line titles.
TEXT-FACE is a face name symbol."
  (let ((face-form (list 'quote text-face)))
    (list
     ;; matcher function
     `(lambda (end)
        (and adoc-enable-two-line-title
             (adoc-kwf-std
              end ,(adoc-re-two-line-title del) '(0) nil
              (lambda ()
                (and (adoc--two-line-title-match-p)
                     (adoc--outside-delimited-block-p))))))
     ;; highlighers
     `(2 ,face-form t)
     `(3 '(face adoc-meta-hide-face adoc-reserved block-del) t))))

;; (defun adoc-?????-attributes (endpos enddelchar)
;;   (list
;;    (concat
;;     ",?[ \t\n]*"
;;     "\\(?:\\([a-zA-Z_]+\\)[ \t\n]*=[ \t\n]*\\)?" ; attribute name
;;     "\\([^" enddelchar ",]*\\|" (adoc-re-string) "\\)"))                                           ; attribute value
;;    '(1 'adoc-attribute-face t)
;;    '(2 'adoc-value-face t)))

(defun adoc-kw-oulisti (type &optional level sub-type)
  "Creates a keyword for font-lock which highlights both (un)ordered list item.
Concerning TYPE, LEVEL and SUB-TYPE see `adoc-re-oulisti'"
  (list
   `(lambda (end) (adoc-kwf-std end ,(adoc-re-oulisti type level sub-type) '(0)))
   '(0 '(face nil adoc-reserved block-del) t)
   '(2 'adoc-list-face t)
   '(3 'adoc-align-face t)))

(defun adoc-kw-llisti (sub-type &optional level)
  "Creates a keyword for font-lock which highlights labeled list item.
Concerning TYPE, LEVEL and SUB-TYPE see `adoc-re-llisti'."
  (list
   `(lambda (end)
      (when (adoc-kwf-std end ,(adoc-re-llisti sub-type level) '(0))
        (let ((pos (match-beginning 0)))
          (when (> pos (point-min))
            (put-text-property (1- pos) pos 'adoc-reserved 'block-del)))
        t))
   '(1 '(face nil adoc-reserved block-del) t)
   '(2 'adoc-gen-face t)
   '(3 '(face adoc-align-face adoc-reserved block-del) t)
   '(4 'adoc-list-face t)))

(defun adoc-kw-list-continuation ()
  (list
   ;; see also regexp of forced line break, which is similar. it is not directly
   ;; obvious from asciidoc sourcecode what the exact rules are.
   (lambda (end) (adoc-kwf-std end "^\\(\\+\\)[ \t]*$" '(1)))
   '(1 '(face adoc-meta-face adoc-reserved block-del) t)))

(defun adoc-kw-checkbox ()
  "Creates a keyword for font-lock which highlights checklist checkboxes.
A checklist item is an unordered list item whose text begins with
`[ ]' (unchecked), `[x]'/`[X]', or `[*]' (checked)."
  (list
   `(lambda (end)
      (adoc-kwf-std end
                    ,(concat "^[ \t]*\\(?:-\\|\\*\\{1,5\\}\\)[ \t]+"
                             "\\(\\[[ xX*]\\]\\)[ \t]")
                    '(1)))
   '(1 'adoc-checkbox-face t)))

(defun adoc-kw-delimited-block (del &optional text-face inhibit-text-reserved)
  "Creates a keyword for font-lock which highlights a delimited block.
TEXT-FACE is a face name symbol or nil."
  (list
   `(lambda (end) (adoc-kwf-std end ,(adoc-re-delimited-block del) '(1 3) nil
                                #'adoc--delimited-block-match-p))
   ;; Leave the faces in the block alone: a compound block (example,
   ;; sidebar, quote, open) holds lists, comments and other blocks whose
   ;; highlighting has to survive.
   '(0 '(face nil font-lock-multiline t))
   '(1 '(face adoc-meta-hide-face adoc-reserved block-del) t)
   (if (not inhibit-text-reserved)
       `(2 '(face ,text-face adoc-reserved t) t t)
     `(2 ',text-face append t))
   '(3 '(face adoc-meta-hide-face adoc-reserved block-del) t)))

;; if adoc-kw-delimited-block, adoc-kw-two-line-title don't find the whole
;; delimited block / two line title, at least 'use up' the delimiter line so it
;; is later not misinterpreted as a funny serries of unconstrained quotes
(defun adoc-kw-delimiter-line-fallback ()
  (list
   `(lambda (end) (adoc-kwf-std end ,(adoc-re-delimited-block-line) '(0)))
   '(0 '(face adoc-meta-face adoc-reserved block-del) t)))

;; admonition paragraph. Note that there is also the style with the leading attribute list.
;; (?s)^\s*(?P<style>NOTE|TIP|IMPORTANT|WARNING|CAUTION):\s+(?P<text>.+)
(defun adoc-kw-admonition-paragraph ()
  "Creates a keyword which highlights admonition paragraphs."
  (list
   ;; matcher function
   (lambda (end)
     (adoc-kwf-std end "^[ \t]*\\(\\(?:CAUTION\\|WARNING\\|IMPORTANT\\|TIP\\|NOTE\\):\\)\\([ \t]+\\)" '(0)))
   ;; highlighters
   '(1 '(face adoc-complex-replacement-face adoc-reserved t))
   '(2 '(face adoc-align-face adoc-reserved t))))

(defun adoc-kw-verbatim-paragraph-sequence ()
  "Creates a keyword which highlights a sequence of verbatim paragraphs."
  (list
   ;; matcher function
   `(lambda (end) (adoc-kwf-std end ,(adoc-re-verbatim-paragraph-sequence) '(0)))
   ;; highlighers
   '(1 '(face adoc-typewriter-face adoc-reserved t font-lock-multiline t))))

(defun adoc-kw-block-title ()
  (list
   `(lambda (end) (adoc-kwf-std end ,(adoc-re-block-title) '(1)))
   '(1 '(face adoc-meta-face adoc-reserved block-del))
   '(2 'adoc-gen-face)
   '(3 '(face nil adoc-reserved block-del))))

(defcustom adoc-role-face-alist
  '(("line-through" . adoc-strike-through-face)
    ("underline"    . adoc-underline-face)
    ("overline"     . adoc-overline-face))
  "Alist mapping AsciiDoc role names to text faces.
Recognised inside `[role]#text#' / `[.role]#text#' (and the
unconstrained `##text##' variant).  Add entries to fontify
additional roles defined in your stylesheet."
  :type '(alist :key-type (string :tag "Role name")
                :value-type (face :tag "Face"))
  :group 'adoc-faces
  :package-version '(adoc-mode . "0.9.0"))

(defun adoc--role-face-from-attribute ()
  "Return the role face for the current quote match, if any.
Looks at the optional attribute list captured in match group 1
and returns the matching face from `adoc-role-face-alist',
otherwise nil.  Handles `[role]', `[.role]', `[role.other]', and
`[role#id]' shapes.

Wrapped in `save-match-data' so we don't disturb font-lock's
outer match while parsing the attribute list."
  (save-match-data
    (when-let* ((beg (match-beginning 1))
                (end (match-end 1))
                (text (buffer-substring-no-properties beg end))
                ((>= (length text) 2)))
      (let* ((inside (substring text 1 -1))
             (no-id (car (split-string inside "#")))
             (without-dot (if (string-prefix-p "." no-id)
                              (substring no-id 1)
                            no-id))
             (names (split-string without-dot "\\." t)))
        (cl-some (lambda (n) (cdr (assoc n adoc-role-face-alist)))
                 names)))))

(defun adoc--quote-face (default-face)
  "Return face(s) for the body of a quoted span.
If the current match's attribute list carries a role recognised
in `adoc-role-face-alist', combine the role face with
DEFAULT-FACE.  Otherwise return DEFAULT-FACE unchanged.

If DEFAULT-FACE is a facespec list (e.g. from
`adoc-facespec-subscript') it is returned as is; role dispatch
only applies to plain face symbols."
  (let ((role (adoc--role-face-from-attribute)))
    (cond
     ((null role) default-face)
     ((null default-face) role)
     ((symbolp default-face) (list role default-face))
     (t default-face))))

(defun adoc-kw-quote (type ldel text-face-spec &optional del-face rdel literal-p)
  "Return a keyword which highlights (un)constrained quotes.
When LITERAL-P is non-nil, the contained text is literal text.
TEXT-FACE-SPEC may be a face name symbol or an already-quoted
face-spec expression (e.g. from `adoc-facespec-subscript')."
  (let ((text-face-form (if (symbolp text-face-spec)
                            (list 'quote text-face-spec)
                          text-face-spec)))
    (list
     ;; matcher function
     `(lambda (end) (adoc-kwf-std end ,(adoc-re-quote type ldel rdel) '(1 2 4) '(3)))
     ;; highlighers
     '(1 '(face adoc-meta-face adoc-reserved t) t t)                    ; attribute list
     `(2 '(face ,(or del-face 'adoc-meta-hide-face) adoc-reserved t) t)  ; open del
     `(3 (adoc--quote-face ,text-face-form) append)                      ; text
     (if literal-p
         '(3 '(face adoc-verbatim-face adoc-reserved t) append)
       '(3 nil)) ; grumbl, I don't know how to get rid of it
     `(4 '(face ,(or del-face 'adoc-meta-hide-face) adoc-reserved t) t)))); close del

(defun adoc-kw-inline-passthrough (type ldel)
  "Return a keyword for an inline passthrough delimited by LDEL.
TYPE is `adoc-constrained' for a single-plus passthrough (`+x+')
or `adoc-unconstrained' for a double-plus one (`++x++').

Unlike the backtick, the plus delimiters are not monospace
formatting in modern AsciiDoc: a passthrough is rendered as
normal output text with inline formatting suppressed.  So the
enclosed text is left in the default face but marked reserved, so
the quote keywords do not format it, and the delimiters are
de-emphasised."
  (list
   `(lambda (end) (adoc-kwf-std end ,(adoc-re-quote type ldel) '(1 2 4) '(3)))
   '(1 '(face adoc-meta-face adoc-reserved t) t t)      ; attribute list
   '(2 '(face adoc-meta-hide-face adoc-reserved t) t)   ; opening delimiter
   '(3 '(face nil adoc-reserved t) t)                   ; passthrough text
   '(4 '(face adoc-meta-hide-face adoc-reserved t) t))) ; closing delimiter

(defconst adoc-re-escaped-formatting
  "\\(\\\\\\)\\(\\([*_`#+^~]\\)\\3*\\)"
  "Regexp matching a backslash-escaped inline formatting delimiter.
Group 1 is the escaping backslash; group 2 is the escaped
delimiter run, a maximal run of one formatting delimiter
character (`*', `**', `+++', …).  A lone `$' is intentionally
excluded: single dollars are not markup (only `$$' is), and a
literal `\\$' is far more common in prose.")

(defun adoc-kw-escaped-formatting ()
  "Return a font-lock keyword for backslash-escaped inline formatting.
In AsciiDoc a backslash before an inline formatting delimiter
escapes it, so the markup is rendered literally.  The keyword
de-emphasises the backslash and marks the escaped delimiters as
reserved literal text, so the quote keywords (which refuse to
match across `adoc-reserved' text) leave the span alone."
  (list
   `(lambda (end)
      (adoc-kwf-std end adoc-re-escaped-formatting '(2)))
   '(1 '(face adoc-meta-hide-face adoc-reserved t) t)  ; the backslash
   '(2 '(face nil adoc-reserved t) t)))                ; the escaped delimiters

(defun adoc-kw-inline-macro (&optional cmd-name unconstrained attribute-list-constraints cmd-face target-faces target-meta-p attribute-list textprops)
  "Returns a kewyword which highlights an inline macro.

For CMD-NAME and UNCONSTRAINED see
`adoc-re-inline-macro'. CMD-FACE determines face for the command
text. If nil, `adoc-command-face' is used.  TARGET-FACES
determines face for the target text. If nil `adoc-meta-face' is
used. If a list, the first is used if the attribute list is the
empty string, the second is used if its not the empty string. If
TARGET-META-P is non-nil, the target text is considered to be
meta characters.
TEXTPROPS is an additional plist with textproperties."
  (list
   `(lambda (end) (adoc-kwf-std end ,(adoc-re-inline-macro cmd-name nil unconstrained attribute-list-constraints) '(1 2 4 5) '(0)))
   `(0 '(face nil . ,textprops) t)
   `(1 '(face ,(or cmd-face 'adoc-command-face) adoc-reserved t adoc-flyspell-ignore t) t) ; cmd-name
   `(2 '(face adoc-meta-face adoc-reserved t . ,textprops) t)                   ; :
   `(3 (list 'face
             ,(cond
               ((not target-faces) ''adoc-meta-face)
               ((listp target-faces)
                `(if (string= (match-string 5) "") ; 5=attribute-list
                     ',(car target-faces)
                   ',(cadr target-faces)))
               (t (list 'quote target-faces)))
             'adoc-flyspell-ignore t 'adoc-reserved t)
       ,(if target-meta-p t 'append))
   `(4 '(face adoc-meta-face adoc-reserved t . ,textprops) t) ; [
   `(5 '(face adoc-meta-face adoc-attribute-list ,(or attribute-list t) . ,textprops) t)
   `(6 '(face adoc-meta-face adoc-reserved t . ,textprops) t))) ; ]

;; largely copied from adoc-kw-inline-macro
;; TODO: output text should be affected by quotes & co, e.g. bold, emph, ...
(defun adoc-kw-inline-macro-urls-attribute-list ()
  (let ((cmd-name (regexp-opt adoc--link-macro-names)))
    (list
     ;; The link text (group 5) may hold other, already highlighted, markup,
     ;; e.g. `https://example.org[the *bold* text]'.
     `(lambda (end) (adoc-kwf-std end ,(adoc-re-inline-macro cmd-name) '(1 2 3 4 6) '(0)))
     '(0 '(face nil keymap adoc-link-keymap mouse-face adoc-link-mouse-face help-echo "mouse-1: visit this link")) ; clickable
     `(1 '(face adoc-url-face adoc-reserved t adoc-flyspell-ignore t) t) ; cmd-name
     `(2 '(face adoc-url-face adoc-reserved t) t) ; :
     `(3 '(face adoc-url-face adoc-reserved t adoc-flyspell-ignore t) t) ; target
     '(4 '(face adoc-meta-face adoc-reserved t) t)               ; [
     `(5 '(face adoc-reference-face adoc-attribute-list adoc-reference-face) append)
     '(6 '(face adoc-meta-face adoc-reserved t) t))))            ; ]

(defun adoc-kw-inline-macro-urls-no-attribute-list ()
  (let ((cmd-name (regexp-opt adoc--link-macro-names)))
    (list
     `(lambda (end) (adoc-kwf-std end ,(adoc-re-inline-macro cmd-name nil nil 'empty) '(0) '(0)))
     '(0 '(face nil keymap adoc-link-keymap mouse-face adoc-link-mouse-face help-echo "mouse-1: visit this link")) ; clickable
     '(1 '(face adoc-url-face adoc-reserved t adoc-flyspell-ignore t) append) ; cmd-name
     '(2 '(face adoc-url-face adoc-reserved t) append)               ; :
     '(3 '(face adoc-url-face adoc-reserved t adoc-flyspell-ignore t) append)               ; target
     '(4 '(face adoc-meta-face adoc-reserved t) t) ; [
                                        ; 5 = attriblist is empty
     '(6 '(face adoc-meta-face adoc-reserved t) t)))) ; ]

;; standalone url
;; From asciidoc.conf:
;; # These URL types don't require any special attribute list formatting.
;; (?su)(?<!\S)[\\]?(?P<name>http|https|ftp|file|irc):(?P<target>//[^\s<>]*[\w/])=
;; # Allow a leading parenthesis and square bracket.
;; (?su)(?<\=[([])[\\]?(?P<name>http|https|ftp|file|irc):(?P<target>//[^\s<>]*[\w/])=
;; # Allow <> brackets.
;; (?su)[\\]?&lt;(?P<name>http|https|ftp|file|irc):(?P<target>//[^\s<>]*[\w/])&gt;=
;;
;; asciidoc.conf bug? why is it so restrictive for urls without attribute
;; list, that version can only have a limited set of characters before. Why
;; not just have the rule that it must start with \b.
;;
;; standalone email
;; From asciidoc.conf:
;; (?su)(?<![">:\w._/-])[\\]?(?P<target>\w[\w._-]*@[\w._-]*\w)(?!["<\w_-])=mailto
;;
;; TODO: properly handle leading backslash escapes
;;
;; non-bugs: __flo@gmail.com__ is also in AsciiDoc *not* an emphasised email, it's
;;   just an emphasised text. That's because the quote transforms happen before
;;   the url transform, thus the middle stage is something like
;;   ...>flo@gmail.com<... According to asciidoc.conf regexps a leading > or a
;;   trailing < are not allowed. In adoc-mode, the fontification is as in
;;   AsciiDoc, but that's coincidence. The reason in adoc-mode is that the
;;   regexps quantifier are greedy instead lazy, thus the trailing __ behind the
;;   email are taken part as the email address, and then adoc-kwf-std can't match
;;   because part of the match (the __) contains text properties with
;;   adoc-reserved non-nil, also because quote highlighting already happened.
(defun adoc-kw-standalone-urls ()
  (let* ((url (concat "\\b" (regexp-opt adoc--url-schemes) "://[^][ \t\n<>]*[a-zA-Z0-9_/]"))
         (url<> (concat "<\\(?:" url "\\)>"))
         (email "[a-zA-Z0-9_][-a-zA-Z0-9_._]*@[-a-zA-Z0-9_._]*[a-zA-Z0-9_]")
         (both (concat "\\(?:" url "\\)\\|\\(?:" url<> "\\)\\|\\(?:" email "\\)")))
    (list
     `(lambda (end) (adoc-kwf-std end ,both '(0) '(0)))
     '(0 '(face adoc-url-face adoc-reserved t adoc-flyspell-ignore t keymap adoc-link-keymap mouse-face adoc-link-mouse-face help-echo "mouse-1: visit this URL") append t))))

;; bug: escapes are not handled yet
;; TODO: give the inserted character a specific face. But I fear that is not
;; possible. The string inserted with the ovlerlay property after-string gets
;; the face of the text 'around' it, which is in this case the text following
;; the replacement.
(defun adoc-kw-replacement (regexp &optional replacement)
  "Creates a keyword for font-lock which highlights replacements."
  (list
   ;; matcher function
   (lambda (end)
     (let (found)
       ;; Skip reserved text, and attribute lists (link text and the like),
       ;; whose face is applied to the list as a whole later on.
       (while (and (setq found (adoc-kwf-search regexp end t))
                   (or (text-property-not-all (match-beginning 1) (match-end 1) 'adoc-reserved nil)
                       (text-property-not-all (match-beginning 1) (match-end 1) 'adoc-attribute-list nil)))
         (goto-char (+ (match-beginning 0) 1)))
       (when (and found adoc-insert-replacement replacement)
         (let* ((s (cond
                    ((stringp replacement)
                     replacement)
                    ((functionp replacement)
                     (funcall replacement (match-string-no-properties 1)))
                    (t (error "Invalid replacement type"))))
                (o (when (stringp s)
                     (make-overlay (match-end 1) (match-end 1)))))
           (when o
             (overlay-put o 'adoc-kw-replacement t)
             (overlay-put o 'after-string s))))
       found))

   ;; highlighters
   (if (and adoc-insert-replacement replacement)
       '(1 '(face adoc-meta-hide-face adoc-reserved t) t)
     '(1 '(face adoc-replacement-face adoc-reserved t) t))))

;; - To ensure that indented lines are nicely aligned. They only look aligned if
;;   the whites at line beginning have a fixed with font.
;; - Some faces have properties which are also visbile on whites
;;   (underlines/backgroundcolor/...), for example links typically gave
;;   underlines. If now a link in an indented paragraph (e.g. because its a list
;;   item), spawns multiple lines, then without countermeasures the blanks at
;;   line beginning would also be underlined, which looks akward.
(defun adoc-flf-first-whites-fixed-width(end)
  ;; it makes no sense to do something with a blank line, so require at least one non blank char.
  (adoc-kwf-std
   end "\\(^[ \t]+\\)[^ \t\n]" nil nil
   (lambda ()
     ;; don't replace a face with with adoc-align-face which already is a fixed with
     ;; font (most probably), because then it also won't look aligned
     (not (or (adoc--face-memq '(adoc-typewriter-face adoc-code-face
                                 adoc-passthrough-face adoc-comment-face)
                               (get-text-property (match-beginning 1) 'face))
              (get-text-property (match-beginning 1) 'adoc-code-block))))))

;; See adoc-flf-first-whites-fixed-width
(defun adoc-kw-first-whites-fixed-width ()
  (list
   'adoc-flf-first-whites-fixed-width
   '(1 'adoc-align-face t)))

;; ensures that faces from the adoc-text group don't overwrite faces from the
;; adoc-meta group
(defun adoc-flf-meta-face-cleanup (end)
  (while (< (point) end)
    (let* ((next-pos (next-single-property-change (point) 'face nil end))
           (faces-raw (get-text-property (point) 'face))
           (faces (if (listp faces-raw) faces-raw (list faces-raw)))
           newfaces
           meta-p)
      (while faces
        (if (member (car faces) '(adoc-meta-hide-face adoc-command-face adoc-attribute-face adoc-value-face adoc-complex-replacement-face adoc-list-face adoc-table-face adoc-table-row-face adoc-table-cell-face adoc-anchor-face adoc-internal-reference-face adoc-comment-face adoc-preprocessor-face))
            (progn
              (setq meta-p t)
              (setq newfaces (cons (car faces) newfaces)))
          (if (not (string-prefix-p "adoc-" (symbol-name (car faces))))
              (setq newfaces (cons (car faces) newfaces))))
        (setq faces (cdr faces)))
      (if meta-p
          (put-text-property (point) next-pos 'face
                             (if (= 1 (length newfaces)) (car newfaces) newfaces)))
      (goto-char next-pos)))
  nil)


;;; Natively highlight source code blocks.
;;
;; The code is an adaption of the code in markdown-mode.el.

(defun adoc-get-lang-mode (lang)
  "Return major mode that should be used for LANG.
LANG is a string, and the returned major mode is a symbol.  A
value in `adoc-code-lang-modes' may be a single mode or a list of
candidate modes; the first one that is defined is used."
  (cl-flet ((candidates (value) (if (listp value) value (list value))))
    (cl-find-if
     #'fboundp
     (append (candidates (cdr (assoc lang adoc-code-lang-modes)))
             (candidates (cdr (assoc (downcase lang) adoc-code-lang-modes)))
             (list (intern (concat lang "-mode"))
                   (intern (concat (downcase lang) "-mode")))))))

;; Based on `org-src-font-lock-fontify-block' from org-src.el.
(defun adoc-fontify-code-block-natively (lang start-block end-block start-src end-src)
  "Fontify source code block.
This function is called by Emacs for automatic fontification when
`adoc-fontify-code-blocks-natively' is non-nil.  LANG is the
language used in the block.
START-BLOCK and END-BLOCK specify the limits of the full source block
with header lines and delimiters (but without header arguments).
START-SRC and END-SRC delimit the actual source code."
  (let ((lang-mode (if lang (adoc-get-lang-mode lang)
                     adoc-fontify-code-block-default-mode)))
    (when (fboundp lang-mode)
      (let ((string (buffer-substring-no-properties start-src end-src))
            (modified (buffer-modified-p))
            (adoc-buffer (current-buffer)))
        (remove-text-properties start-block end-block '(face nil adoc-code-block nil font-lock-fontified nil font-lock-multiline nil))
        (with-current-buffer
            (get-buffer-create
             (concat " adoc-code-fontification:" (symbol-name lang-mode)))
          ;; Make sure that modification hooks are not inhibited in
          ;; the org-src-fontification buffer in case we're called
          ;; from `jit-lock-function' (Bug#25132).
          (let ((inhibit-modification-hooks nil))
            (erase-buffer)
            (insert string))
          (unless (eq major-mode lang-mode) (funcall lang-mode))
          (font-lock-ensure)
          (let ((pos (point-min)))
            (while (< pos (point-max))
              (let ((next (next-single-property-change pos 'face nil (point-max)))
                    (val (get-text-property pos 'face)))
                (when val
                  (put-text-property
                   (+ start-src (1- pos)) (1- (+ start-src next)) 'face
                   val adoc-buffer))
                (setq pos next)))))
        (set-buffer-modified-p modified)))))

(defconst adoc-code-block-begin-regexp
  (cl-flet ((rx-or (first second) (format "\\(?:%s\\|%s\\)" first second))
            (rx-optional (stuff) (format "\\(?:%s\\)?" stuff))
            (outer-brackets-and-delimiter (&rest stuff)
                                          ;; Listing blocks (delimiter ----), open blocks (delimiter --) and literal blocks (delimiter ....) can have `source`-style:
                                          ;; https://docs.asciidoctor.org/asciidoc/latest/blocks/delimited/#summary-of-structural-containers
                                          (format "^\\[%s\\]\\s-*\n\\(?2:\\(--\\(?:--+\\)?\\|\\.\\{4,\\}\\)\\)\n"
                                                  (apply #'concat stuff)))
            ;; The language attribute is positional only (2nd slot).
            ;; It gets its default value from the document attribute `source-language`.
            ;; The leading space between the comma and the 2nd attribute is ignored.
            ;; See https://docs.asciidoctor.org/asciidoc/latest/attributes/element-attributes/#attribute-list.
            ;;
            ;; Even if that is not specified in https://docs.asciidoctor.org,
            ;; whitespaces at the end of the block attributes are silently ignored by Asciidoctor.
            (lang () ",[\t ]*\\(?1:[^],]+\\)")
            (optional-other-args () "\\(?:,[^]]+\\)?"))
    (concat
     (outer-brackets-and-delimiter
      (rx-or
       (concat
        "source"
        (rx-optional (lang))
        (optional-other-args))
       (concat
        (lang)
        (optional-other-args))))
     ;; A Markdown-style fenced code block names its language after the
     ;; fence, as in ```ruby.  Four backticks don't make a fence.
     "\\|^\\(?2:```\\)[ \t]*\\(?1:[^`, \t\n][^,\n]*?\\)?[ \t]*\\(?:,.*\\)?\n"))
  "Regexp matching the beginning of source blocks, fenced ones included.
Group 1 contains the language attribute.
Group 2 contains the block delimiter.")

(defun adoc-search-forward-code-block (last &optional noerror)
  "Search for next adoc-code block up to LAST.
NOERROR is the same as for `search-forward'.

Return a string with the source block language and
set match data if a source block is found.
If the source block is given without the language attribute return t.
If no source block is found return nil.

The overall match data begins at the
header of the code block and ends at the end of the
end delimiter.
The first group of the match data delimits the
actual source code."
  (let (start-header start-src end-src end-block lang)
    (save-match-data
      (while (and (not end-block)
                  (setq start-src (re-search-forward adoc-code-block-begin-regexp
                                                     last noerror)))
        (let ((block (adoc--delimited-block-at (match-beginning 2))))
          ;; Pass over a delimiter line in the content of a verbatim block and
          ;; an unterminated block, see `adoc--ensure-block-extents'.
          (when (and block (= (nth 1 block) (match-beginning 2)))
            (setq lang (or (match-string 1) t)
                  start-header (match-beginning 0))
            (when (re-search-forward
                   (concat "^" (regexp-quote (match-string 2)) "[ \t]*$")
                   (nth 3 block) t)
              (setq end-block (match-end 0)
                    end-src (max start-src (1- (match-beginning 0)))))))))
    (when end-block
      (set-match-data (list start-header end-block start-src end-src (current-buffer)))
      lang)))

(defun adoc-font-lock-extend-after-change-region (beg end _old-len)
  "Enlarge region for re-fontification after edit.
BEG is the beginning of the region and END its end.
The region is extended if it includes a part of a source block.
Returns a cons (BEG . END) with the updated limits of the region."
  (save-match-data
    (save-excursion
      (goto-char beg)
      ;; Maybe edits in header line: Skip to body
      (cl-case (char-after (line-beginning-position))
        (?\[ (forward-line 2))
        (?- (forward-line 1)))
      ;; Search backward for header:
      (let ((beg-block (re-search-backward adoc-code-block-begin-regexp (max 0 (- (point) adoc-font-lock-extend-after-change-max)) t))
            end-block)
        (when beg-block
          (goto-char (match-end 0))
          (setq end-block (or (re-search-forward (format "\n%s$" (regexp-quote (match-string 2)))
                                                 (+ (point) adoc-font-lock-extend-after-change-max)
                                                 t)
                              end))
          (when (and end-block (> end-block beg)) ;; block reaches really into edited area
            (cons (min beg beg-block) (max end end-block))))))))

(defun adoc-fontify-code-blocks (last)
  "Add text properties to next code block from point to LAST.
Use this function as matching function MATCHER in `font-lock-keywords'."
  (let ((lang (adoc-search-forward-code-block last 'noError)))
    (when lang
      (save-excursion
        (save-match-data
          (let* ((start-block (match-beginning 0))
                 (end-block (match-end 0))
                 (start-src (match-beginning 1))
                 (end-src (match-end 1))
                 (end-src+nl (if (eq (char-after end-src) ?\n) (1+ end-src) end-src))
                 (size (1+ (- end-src start-src))))
            (if (and
                 (stringp lang)
                 (if (numberp adoc-fontify-code-blocks-natively)
                     (<= size adoc-fontify-code-blocks-natively)
                   adoc-fontify-code-blocks-natively))
                (progn
                  (adoc-fontify-code-block-natively lang start-block end-block start-src end-src)
                  (font-lock-append-text-property start-src end-src 'face 'adoc-native-code-face)
                  (add-text-properties end-src end-src+nl '(face adoc-native-code-face)))
              ;; code block without language attribute or too large
              (add-text-properties start-src end-src '(face (adoc-verbatim-face adoc-code-face)))
              (add-text-properties end-src end-src+nl '(face adoc-code-face)))
            (add-text-properties start-block start-src '(face adoc-meta-face))
            (put-text-property end-src+nl end-block 'face 'adoc-meta-face)
            (add-text-properties start-src end-src+nl '(adoc-code-block t))
            (add-text-properties start-block end-block '(font-lock-fontified t font-lock-multiline t adoc-reserved t))
            )))
      t)))


;;;; font lock
(defun adoc-unfontify-region-function (beg end)
  (font-lock-default-unfontify-region beg end)

  (dolist (ol (overlays-in beg end))
    (when (overlay-get ol 'adoc-kw-replacement)
      (delete-overlay ol)))

  ;; text properties. Currently only display raise used for sub/superscripts.
  ;; code snipped copied from tex-mode
  (when (not (and (= 0 (car adoc-script-raise)) (= 0 (cadr adoc-script-raise))))
    (while (< beg end)
      (let ((next (next-single-property-change beg 'display nil end))
            (prop (get-text-property beg 'display)))
        (if (and (eq (car-safe prop) 'raise)
                 (member (car-safe (cdr prop)) adoc-script-raise)
                 (null (cddr prop)))
            (put-text-property beg next 'display nil))
        (setq beg next)))))

;;;; Delimited block extents

;; The font-lock keywords match a delimited block with one regexp, from its
;; opening to its closing delimiter, so they only see a block when the region
;; being fontified covers all of it.  jit-lock fontifies the buffer in chunks,
;; and a chunk can begin or end anywhere - including inside a block, where an
;; opening delimiter can't be told from a closing one.  So the extent of every
;; block is recorded by a scan that always pairs the delimiters up from the
;; start of the buffer, and `adoc-font-lock-extend-region' widens the region
;; so it never splits a top-level block.

(defconst adoc--re-block-delimiter
  (concat "^\\(?:\\(?1:"
          (mapconcat #'identity
                     '("/\\{4,\\}" "\\+\\{4,\\}" "-\\{4,\\}" "\\.\\{4,\\}"
                       "_\\{4,\\}" "=\\{4,\\}" "\\*\\{4,\\}" "--"
                       "[,:]=\\{3,\\}")
                     "\\|")
          ;; A fenced code block can name its language after the fence.
          "\\)\\|\\(?1:```\\)\\(?:[^`\n].*\\)?\\)[ \t]*$")
  "Regexp matching a delimited block or CSV/DSV table delimiter line.
Group 1 is the delimiter, which a closing delimiter line repeats.  These
are Asciidoctor's delimiters, Markdown's ``` fence included, not the
ones `adoc-delimited-block-del' customizes for highlighting.  A `|==='
table is highlighted line by line, so it needs no extent.")

(defun adoc--verbatim-delimiter-p (delimiter)
  "Return non-nil when DELIMITER opens a block whose content isn't AsciiDoc.
That's every block but the example, sidebar, quote and open ones."
  (not (or (equal delimiter "--")
           (memq (aref delimiter 0) '(?= ?* ?_)))))

(defconst adoc--re-block-metadata-line
  "^\\(?:\\[.*\\]\\|\\.[^ \t.].*\\)[ \t]*$"
  "Regexp matching a block attribute list, anchor or title line.")

(defun adoc--title-underline-p (open delimiter)
  "Return non-nil when DELIMITER, on the line at OPEN, underlines a title.
That's only possible when two-line titles are enabled, and then a
title line right above makes it the underline of a two-line title
rather than a block delimiter, the same as for fontification."
  (let ((del (and adoc-enable-two-line-title
                  (cl-find (aref delimiter 0) adoc-two-line-title-del
                           :key #'string-to-char))))
    (and del
         (save-excursion
           (goto-char open)
           (and (zerop (forward-line -1))
                (looking-at (adoc-re-two-line-title del))
                (= (match-beginning 3) open)
                (adoc--two-line-title-match-p))))))

(defvar-local adoc--block-extents-done 1
  "Position up to which the delimited block extents are known.
The `adoc-delimited-block' properties from here on are out of date.
See `adoc--ensure-block-extents'.")

(defvar-local adoc--block-extents-unterminated nil
  "Where the first block known to be unterminated would begin, or nil.
Text added anywhere after it might close it.")

(defun adoc--invalidate-block-extents (beg &rest _)
  "Forget the delimited block extents from where a change at BEG matters.
That's the beginning of the top-level block BEG is in, read while the
text before the change is still there.  Otherwise it's the beginning of
BEG's line, which may become a delimiter line, together with any
attribute and title lines above it, which would then belong to its
block.  A change after an unterminated block's opening delimiter can
close it, so then the extents are forgotten from that block on.  Meant
for `before-change-functions'."
  (when (<= beg adoc--block-extents-done)
    (save-excursion
      ;; The block just before BEG counts too when the change continues its
      ;; last line, as text added after a closing delimiter at the very end
      ;; of the buffer does.
      (let ((block (or (and (< beg adoc--block-extents-done)
                            (get-text-property beg 'adoc-delimited-block))
                       (and (> beg (point-min))
                            (not (eq (char-before beg) ?\n))
                            (get-text-property (1- beg) 'adoc-delimited-block)))))
        (goto-char (if block (car (adoc--outermost-block block)) beg))
        (let ((pos (line-beginning-position)))
          (while (and (zerop (forward-line -1))
                      (looking-at-p adoc--re-block-metadata-line))
            (setq pos (point)))
          (setq adoc--block-extents-done (min adoc--block-extents-done pos))))))
  (when (and adoc--block-extents-unterminated
             (< adoc--block-extents-unterminated adoc--block-extents-done))
    (setq adoc--block-extents-done adoc--block-extents-unterminated)))

(defun adoc--ensure-block-extents (pos)
  "Make sure the extents of the delimited blocks before POS are recorded.
Each block, together with the attribute, anchor and title lines right
above it, gets an `adoc-delimited-block' text property whose value is
the list (START OPEN VERBATIM END PARENT): where the block begins, where
its opening delimiter line is, whether its content isn't AsciiDoc (see
`adoc--verbatim-delimiter-p'), where it ends, and the block it's nested
in, or nil.  A block nested in an example, sidebar, quote or open block
gets an extent of its own, so the property holds the innermost block.
Like Asciidoctor, the first line that repeats the opening delimiter
exactly closes a block, whatever it contains, and a nested block has to
close before its parent does.  An unterminated block gets no extent.

The scan picks up where the last one left off, and a block it starts
is recorded whole."
  (when (< adoc--block-extents-done pos)
    (save-excursion
      (save-restriction
        (widen)
        (with-silent-modifications
          (let ((start (progn (goto-char (max adoc--block-extents-done (point-min)))
                              (line-beginning-position)))
                (end (progn (goto-char (min pos (point-max)))
                            ;; Scan whole lines, so no delimiter line is cut in two.
                            (unless (bolp) (forward-line 1))
                            ;; Attribute, anchor and title lines belong to the
                            ;; block that opens below them, so take in the line
                            ;; after them too.
                            (when (save-excursion
                                    (and (zerop (forward-line -1))
                                         (looking-at-p adoc--re-block-metadata-line)))
                              (while (and (not (eobp))
                                          (looking-at-p adoc--re-block-metadata-line))
                                (forward-line 1))
                              (forward-line 1))
                            (point))))
            (setq adoc--block-extents-done
                  (adoc--record-block-extents start end))))))))

(defun adoc--delimited-block-at (pos)
  "Return the delimited block the line at POS is in, or nil.
The value is that of the `adoc-delimited-block' property, see
`adoc--ensure-block-extents'.  Inside a block, a line that looks like
a section title is plain content, as for highlighting."
  (save-match-data
    (adoc--ensure-block-extents (1+ pos))
    (get-text-property pos 'adoc-delimited-block)))

(defun adoc--outermost-block (block)
  "Return the top-level block that BLOCK is nested in, or BLOCK itself.
BLOCK is a value of the `adoc-delimited-block' property."
  (while (nth 4 block)
    (setq block (nth 4 block)))
  block)

(defun adoc--record-block-extents (start end &optional parent)
  "Record the extents of the delimited blocks opened between START and END.
Without PARENT, START has to be outside any block, and the return value
is the position the extents are known up to: END, or the end of a block
that runs past it.  With PARENT, the blocks are nested in that compound
block, whose content runs from START to END, so they have to close
before END.  See `adoc--ensure-block-extents'."
  (goto-char start)
  (unless parent
    (remove-text-properties start end '(adoc-delimited-block nil))
    (when (and adoc--block-extents-unterminated
               (>= adoc--block-extents-unterminated start))
      (setq adoc--block-extents-unterminated nil)))
  (while (and (< (point) end)
              (re-search-forward adoc--re-block-delimiter end t))
    (let* ((open (match-beginning 0))
           (delimiter (match-string-no-properties 1))
           (closing (concat "^" (regexp-quote delimiter) "[ \t]*$")))
      (forward-line 1)
      ;; Nothing in a block is a title, so nothing there underlines one.
      (unless (and (not parent) (adoc--title-underline-p open delimiter))
        (let ((content-start (point))
              (block-start open))
          (save-excursion
            (goto-char open)
            (while (and (zerop (forward-line -1))
                        (looking-at-p adoc--re-block-metadata-line))
              (setq block-start (point))))
          (cond
           ((re-search-forward closing (and parent end) t)
            (let* ((content-end (match-beginning 0))
                   (block-end (min (1+ (point)) (point-max)))
                   (verbatim (adoc--verbatim-delimiter-p delimiter))
                   (block (list block-start open verbatim block-end parent)))
              (put-text-property block-start block-end 'adoc-delimited-block block)
              (unless verbatim
                (adoc--record-block-extents content-start content-end block))
              (unless parent
                (setq end (max end block-end)))
              (goto-char block-end)))
           ;; Asciidoctor runs an unterminated nested block to the end of its
           ;; parent, but it gets no extent, like a top-level one.
           ((not (or parent adoc--block-extents-unterminated))
            (setq adoc--block-extents-unterminated block-start)))))))
  end)

(defvar font-lock-beg)
(defvar font-lock-end)

(defun adoc-font-lock-extend-region ()
  "Extend the font-lock region to paragraph and delimited block boundaries.
Inline formatting in AsciiDoc can span multiple lines within a
paragraph, so the fontification region must cover complete paragraphs
for multiline constructs to be matched.  Likewise a delimited block is
only recognised as a whole, so the region never ends or begins inside
one (see `adoc--ensure-block-extents')."
  (let ((changed nil))
    (save-excursion
      (goto-char font-lock-beg)
      (let ((new-beg (progn (backward-paragraph) (point))))
        (when (< new-beg font-lock-beg)
          (setq font-lock-beg new-beg
                changed t))))
    (save-excursion
      (goto-char font-lock-end)
      (let ((new-end (progn (forward-paragraph) (point))))
        (when (> new-end font-lock-end)
          (setq font-lock-end new-end
                changed t))))
    (adoc--ensure-block-extents font-lock-end)
    (let ((block (get-text-property font-lock-beg 'adoc-delimited-block)))
      (when block
        (let ((block-start (car (adoc--outermost-block block))))
          (when (< block-start font-lock-beg)
            (setq font-lock-beg block-start
                  changed t)))))
    (let ((block (and (> font-lock-end (point-min))
                      (get-text-property (1- font-lock-end) 'adoc-delimited-block))))
      (when block
        (let ((block-end (nth 3 (adoc--outermost-block block))))
          (when (> block-end font-lock-end)
            (setq font-lock-end block-end
                  changed t)))))
    changed))

(defun adoc-font-lock-mark-block-function ()
  (mark-paragraph 2)
  (forward-paragraph -1))

(defvar adoc--table-cell-separator nil
  "Quoted regexp of the separator of the CSV/DSV table being fontified.
Bound by the cell-separator keyword's pre-match form so its anchored
matcher knows whether to highlight commas (CSV) or colons (DSV).")

(defun adoc-kw-csv-dsv-table ()
  "Create a font-lock keyword for CSV and DSV tables.
The modern AsciiDoc table delimiter shorthands `,===' (CSV) and
`:===' (DSV) carry their cell separator in the delimiter itself.  The
whole block is matched at once - opening line, data, and a closing line
using the same shorthand - so the separators are only highlighted
between matching delimiters, never in the surrounding prose."
  (list
   `(lambda (end)
      (adoc-kwf-std
       end
       ;; The data span stops at a blank line so an unclosed table can't
       ;; reach across a paragraph and steal a later table's delimiter as
       ;; its close (which would leak separator highlighting into prose).
       ,(concat "^\\(\\([,:]\\)=\\{3,\\}[ \t]*\\)\n"  ; 1=open line, 2=sep char
                "\\(\\(?:[ \t]*[^ \t\n].*\n\\)*?\\)"   ; 3=cell data (no blank lines)
                "\\(\\2=\\{3,\\}[ \t]*\\)$")           ; 4=close line
       '(1 4) nil #'adoc--delimited-block-match-p))
   '(0 '(face nil font-lock-multiline t) t)
   '(1 '(face adoc-table-face adoc-reserved block-del) t)  ; opening delimiter
   '(4 '(face adoc-table-face adoc-reserved block-del) t)  ; closing delimiter
   ;; anchored: highlight every cell separator within the data
   (list (lambda (limit)
           (and adoc--table-cell-separator
                (re-search-forward adoc--table-cell-separator limit t)))
         '(progn
            (setq adoc--table-cell-separator (regexp-quote (match-string 2)))
            (goto-char (match-beginning 3))
            (match-end 3))
         '(setq adoc--table-cell-separator nil)
         '(0 '(face adoc-table-face adoc-reserved block-del) t))))

(defconst adoc--re-markdown-thematic-break
  "^ \\{0,3\\}\\(\\([-*_]\\)\\( *\\)\\2\\3\\2\\)[ \t]*$"
  "Regexp matching a Markdown-style thematic break, such as `* * *'.
Group 1 is the break without its indentation, group 2 its character and
group 3 the spaces between them.")

(defconst adoc--re-verbatim-style-line
  "^\\[\\(?:literal\\|listing\\|source\\|verse\\)\\(?:[,#.%].*\\)?\\][ \t]*$"
  "Regexp matching a block attribute line that makes a paragraph verbatim.")

(defun adoc--thematic-break-line-p (pos)
  "Return non-nil when the line at POS looks like a thematic break."
  (save-excursion
    (goto-char pos)
    (beginning-of-line)
    (looking-at-p adoc--re-markdown-thematic-break)))

(defun adoc--block-begins-p ()
  "Return non-nil when a block can begin on the line at point.
That's below a blank line, a section title, a block delimiter or a list
continuation, or below a block attribute or anchor line, which also
ends a paragraph above it.  Block titles,
comments and attribute entries leave it to the line above them.  A block
attribute line with a verbatim style, such as `[source]', makes the
line part of a paragraph, though."
  (save-excursion
    (let (attributes)
      (catch 'done
        (while t
          (cond
           ((or (/= (forward-line -1) 0) (looking-at-p "[ \t]*$"))
            (throw 'done t))
           ((looking-at-p adoc--re-verbatim-style-line) (throw 'done nil))
           ((looking-at-p "\\[.*\\][ \t]*$") (setq attributes t))
           ((or (looking-at-p (adoc-re-one-line-title nil))
                (looking-at-p adoc--re-block-delimiter)
                (looking-at-p "\\+[ \t]*$"))
            (throw 'done t))
           ((looking-at-p "\\.[^ \t.]\\|//\\(?:[^/]\\|$\\)\\|:!?[[:alnum:]_][^:\n]*:\\(?:[ \t]\\|$\\)"))
           (t (throw 'done attributes))))))))

(defun adoc--open-list-keys (pos)
  "Return the keys of the list levels open above the line at POS.
They come innermost first, see `adoc--list-item-key'.  Lines like
`* * *' in the list are items when their key is open, and thematic
breaks, which Asciidoctor puts in the item above, otherwise."
  (let (keys)
    (dolist (item (reverse (adoc--list-items-above (list :marker-beg pos) t))
                  keys)
      (let* ((key (adoc--list-item-key item))
             (open (member key keys)))
        (cond
         (open (setq keys open))
         ((not (adoc--thematic-break-line-p (plist-get item :marker-beg)))
          (push key keys)))))))

(defun adoc--markdown-thematic-break-p ()
  "Return non-nil when the line at point is a Markdown-style thematic break.
Asciidoctor takes `---', `* * *' and the like for one where a block
begins, see `adoc--block-begins-p'.  Where `* * *' or `- - -' continues
a list, it's an item instead when a level open there has the same
marker, or when it's right below an item."
  (save-excursion
    (save-match-data
      (beginning-of-line)
      (and (looking-at adoc--re-markdown-thematic-break)
           (not (nth 2 (adoc--delimited-block-at (point))))
           (let* ((char (match-string-no-properties 2))
                  (open (and (not (string-empty-p (match-string 3)))
                             (not (equal char "_"))
                             (adoc--open-list-keys (match-beginning 1)))))
             (if open
                 (not (or (member char open)
                          (save-excursion
                            (and (zerop (forward-line -1))
                                 (adoc--list-item-at-point t)))))
               (adoc--block-begins-p)))))))

(defun adoc-get-font-lock-keywords ()
  "Return list of keywords for `adoc-mode'."
  (list
   '(adoc-fontify-code-blocks) ; listing
   ;; Asciidoc BUG: Lex.next has a different order than the following extract
   ;; from the documentation states.

   ;; When a block element is encountered asciidoc(1) determines the type of
   ;; block by checking in the following order (first to last):
   ;; 1. (section)
   ;; 2. Titles,
   ;; 3. BlockMacros,
   ;; 4. Lists,
   ;; 5. DelimitedBlocks,
   ;; 6. Tables,
   ;; 7. AttributeEntrys,
   ;; 8. AttributeLists,
   ;; 9. BlockTitles,
   ;; 10. Paragraphs.

   ;; sections / document structure
   ;; ------------------------------
   (adoc-kw-one-line-title 0 'adoc-title-0-face)
   (adoc-kw-one-line-title 1 'adoc-title-1-face)
   (adoc-kw-one-line-title 2 'adoc-title-2-face)
   (adoc-kw-one-line-title 3 'adoc-title-3-face)
   (adoc-kw-one-line-title 4 'adoc-title-4-face)
   (adoc-kw-one-line-title 5 'adoc-title-5-face)
   (adoc-kw-two-line-title (nth 0 adoc-two-line-title-del) 'adoc-title-0-face)
   (adoc-kw-two-line-title (nth 1 adoc-two-line-title-del) 'adoc-title-1-face)
   (adoc-kw-two-line-title (nth 2 adoc-two-line-title-del) 'adoc-title-2-face)
   (adoc-kw-two-line-title (nth 3 adoc-two-line-title-del) 'adoc-title-3-face)
   (adoc-kw-two-line-title (nth 4 adoc-two-line-title-del) 'adoc-title-4-face)
   ;; AsciiDoc's two-line title syntax has only five delimiter pairs, so
   ;; there is no level-5 two-line title (one-line titles cover six levels).


   ;; block macros
   ;; ------------------------------
   ;; TODO: respect asciidoc.conf order

   ;; -- system block macros
   ;;     # Default system macro syntax.
   ;; SYS_RE = r'(?u)^(?P<name>[\\]?\w(\w|-)*?)::(?P<target>\S*?)' + \
   ;;          r'(\[(?P<attrlist>.*?)\])$'
   ;; conditional inclusion
   (list "^\\(\\(?:ifn?def\\|endif\\)::\\)\\([^ \t\n]*?\\)\\(\\[\\).+?\\(\\]\\)[ \t]*$"
         '(1 '(face adoc-preprocessor-face adoc-reserved block-del))    ; macro name
         '(2 '(face adoc-meta-face adoc-reserved block-del))       ; condition
         '(3 '(face adoc-meta-hide-face adoc-reserved block-del))  ; [
                                        ; ... attribute list content = the conditionally included text
         '(4 '(face adoc-meta-hide-face adoc-reserved block-del))) ; ]
   ;; include
   (list "^\\(\\(include1?::\\)\\([^ \t\n]*?\\)\\(\\[\\)\\(.*?\\)\\(\\]\\)\\)[ \t]*$"
         '(1 '(face nil adoc-reserved block-del keymap adoc-link-keymap mouse-face adoc-link-mouse-face help-echo "mouse-1: open this include")) ; the whole match
         '(2 '(face adoc-preprocessor-face adoc-flyspell-ignore t))      ; macro name
         '(3 '(face adoc-meta-face adoc-flyspell-ignore t))              ; file name
         '(4 'adoc-meta-hide-face)         ; [
         '(5 'adoc-meta-face)              ;   attribute list content
         '(6 'adoc-meta-hide-face))        ; ]


   ;; -- special block macros
   ;; ruler line.
   ;; Is a block marcro in asciidoc.conf, although manual has it in the "text formatting" section
   ;; ^'{3,}$=#ruler
   (list "^\\('\\{3,\\}+\\)[ \t]*$"
         '(1 '(face adoc-complex-replacement-face adoc-reserved block-del)))
   ;; Markdown-style ruler line, which comes before the list items, as `* * *'
   ;; would make one
   (list (lambda (end)
           (adoc-kwf-std end adoc--re-markdown-thematic-break '(1) nil
                         #'adoc--markdown-thematic-break-p))
         '(1 '(face adoc-complex-replacement-face adoc-reserved block-del)))
   ;; forced pagebreak
   ;; Is a block marcro in asciidoc.conf, although manual has it in the "text formatting" section
   ;; ^<{3,}$=#pagebreak
   (list "^\\(<\\{3,\\}+\\)[ \t]*$"
         '(1 '(face adoc-meta-face adoc-reserved block-del)))
   ;; comment
   ;; (?mu)^[\\]?//(?P<passtext>[^/].*|)$
   ;; I don't know what the [\\]? should mean
   (list "^\\(//\\(?:[^/].*\\|\\)\\(?:\n\\|\\'\\)\\)"
         '(1 '(face adoc-comment-face adoc-reserved block-del)))
   ;; image. The first positional attribute is per definition 'alt', see
   ;; asciidoc manual, sub chapter 'Image macro attributes'.
   (list `(lambda (end) (adoc-kwf-std end ,(adoc-re-block-macro "image") '(0)))
         '(0 '(face adoc-meta-face adoc-reserved block-del keymap adoc-image-link-map)) ; whole match
         '(1 '(face adoc-complex-replacement-face adoc-flyspell-ignore t) t) ; 'image'
         '(2 '(face adoc-internal-reference-face adoc-flyspell-ignore t) t)  ; file name
         '(3 '(face adoc-meta-face adoc-reserved nil adoc-attribute-list ("alt")) t)) ; attribute list

   ;; passthrough: (?u)^(?P<name>pass)::(?P<subslist>\S*?)(\[(?P<passtext>.*?)\])$
   ;; todo

   ;; -- general block macro
   (list `(lambda (end) (adoc-kwf-std end ,(adoc-re-block-macro) '(0)))
         '(0 '(face adoc-meta-face adoc-reserved block-del)) ; whole match
         '(1 '(face adoc-command-face adoc-flyspell-ignore t) t)                            ; command name
         '(3 '(face adoc-meta-face adoc-reserved nil adoc-attribute-list t) t)) ; attribute list

   ;; lists
   ;; ------------------------------
   ;; TODO: respect and insert adoc-reserved
   ;;
   ;; bug: for items beginning with a label (i.e. user text): if might be that
   ;; the label contains a bogous end delimiter such that you get a
   ;; highlighting that starts in the line before the label item and ends
   ;; within the label. Example:
   ;;
   ;; bla bli 2 ** 8 is 256                   quote starts at this **
   ;; that is **important**:: bla bla         ends at the first **
   ;;
   ;; similarly:
   ;;
   ;; bla 2 ** 3:: bla bla 2 ** 3 gives       results in an untwanted unconstrained quote
   ;;
   ;; - dsfadsf sdf ** asfdfsad
   ;; - asfdds fsda ** fsfas
   ;;
   ;; maybe the solution is invent a new value for adoc-reserved, or a new
   ;; property alltogether. That would also be used for the trailing \n in other
   ;; block elements. Text is not allowed to contain them. All font lock
   ;; keywords standing for asciidoc inline substitutions would have to be
   ;; adapted.
   ;;
   ;;
   ;; bug: the text of labelleled items gets inline macros such as anchor not
   ;; highlighted. See for example [[X80]] in asciidoc manual source.
   (adoc-kw-oulisti 'adoc-unordered 'adoc-all-levels)
   (adoc-kw-oulisti 'adoc-unordered nil 'adoc-bibliography)
   (adoc-kw-oulisti 'adoc-explicitly-numbered )
   (adoc-kw-oulisti 'adoc-implicitly-numbered 'adoc-all-levels)
   (adoc-kw-oulisti 'adoc-callout)
   (adoc-kw-llisti 'adoc-labeled-normal 0)
   (adoc-kw-llisti 'adoc-labeled-normal 1)
   (adoc-kw-llisti 'adoc-labeled-normal 2)
   (adoc-kw-llisti 'adoc-labeled-normal 3)
   (adoc-kw-llisti 'adoc-labeled-qanda)
   (adoc-kw-llisti 'adoc-labeled-glossary)
   (adoc-kw-checkbox)
   (adoc-kw-list-continuation)

   ;; Delimited blocks
   ;; ------------------------------
   (adoc-kw-delimited-block 0 'adoc-comment-face)   ; comment
   (adoc-kw-delimited-block 1 'adoc-passthrough-face) ; passthrough
   (adoc-kw-delimited-block 2 'adoc-code-face) ; listing
   (adoc-kw-delimited-block 3 'adoc-verbatim-face) ; literal
   (adoc-kw-delimited-block 4 'adoc-blockquote-face t) ; quote
   (adoc-kw-delimited-block 5 nil t) ; example
   (adoc-kw-delimited-block 6 'adoc-secondary-text-face t) ; sidebar
   (adoc-kw-delimited-block 7 nil t) ; open block
   (adoc-kw-delimiter-line-fallback)


   ;; tables
   ;; ------------------------------
   ;; must come BEFORE block title, else rows starting like .2+| ... | ... are taken as
   (list "^[|,:]=\\{3,\\}[ \t]*$" '(0 'adoc-table-face)) ; ^[|,:]={3,}$
   (list (concat "^\\(" (adoc-re-cell-specifier) "\\)\\(|\\)")
         '(1 '(face adoc-meta-face adoc-reserved block-del) nil t)
         '(2 '(face adoc-table-face adoc-reserved block-del) nil t)
         (list (concat "\\(" (adoc-re-cell-specifier) "\\)\\(|\\)")
               '(save-excursion (end-of-line) (point)) nil
               '(1 '(face adoc-meta-face adoc-reserved block-del) nil t)
               '(2 '(face adoc-table-face adoc-reserved block-del) nil t)))
   ;; CSV (,===) and DSV (:===) tables
   (adoc-kw-csv-dsv-table)


   ;; attribute entry
   ;; ------------------------------
   (list (adoc-re-attribute-entry)
         '(1 'adoc-metadata-key-face)
         '(2 'adoc-metadata-value-face nil t))


   ;; attribute list
   ;; ----------------------------------

   ;; --- special attribute lists
   ;; quote/verse
   (list (concat
          "^\\("
          "\\(\\[\\)"
          "\\(quote\\|verse\\)"
          "\\(?:\\(,\\)\\(.*?\\)\\(?:\\(,\\)\\(.*?\\)\\)?\\)?"
          "\\(\\]\\)"
          "\\)[ \t]*$")
         '(1 '(face nil adoc-reserved block-del)) ; whole match
         '(2 'adoc-meta-hide-face)            ; [
         '(3 'adoc-meta-face)                 ;   quote|verse
         '(4 'adoc-meta-hide-face nil t)      ;   ,
         '(5 'adoc-secondary-text-face nil t) ;   attribution(author)
         '(6 'adoc-meta-face nil t)           ;   ,
         '(7 'adoc-secondary-text-face nil t) ;   cite title
         '(8 'adoc-meta-hide-face))           ; ]
   ;; admonition block
   (list "^\\(\\[\\(?:CAUTION\\|WARNING\\|IMPORTANT\\|TIP\\|NOTE\\)\\]\\)[ \t]*$"
         '(1 '(face adoc-complex-replacement-face adoc-reserved block-del)))
   ;; block id [[BLOCK-ID,SECONDARY-TEXT]]
   (list `(lambda (end) (adoc-kwf-std end ,(adoc-re-anchor 'block-id) '(0)))
         '(0 '(face adoc-meta-face adoc-reserved block-del))
         '(1 '(face adoc-anchor-face adoc-flyspell-ignore t) t) ;; BLOCK-ID
         '(2 'adoc-secondary-text-face t t)) ;; SECONDARY-TEXT
   ;; block id shorthand on its own line: [#id], [#id.role], [#id.role%opt]
   (list `(lambda (end)
            (adoc-kwf-std
             end
             "^\\(\\[#\\)\\([-a-zA-Z0-9_]+\\)\\(?:[.%][^]\n]*\\)?\\(\\]\\)[ \t]*$"
             '(0)))
         '(0 '(face adoc-meta-face adoc-reserved block-del))
         '(2 '(face adoc-anchor-face adoc-flyspell-ignore t) t)) ;; BLOCK-ID

   ;; --- general attribute list block element
   ;; ^\[(?P<attrlist>.*)\]$
   (list (lambda (end) (adoc-kwf-std end "^\\(\\[\\(.*\\)\\]\\)[ \t]*$" '(0)))
         '(1 '(face adoc-meta-face adoc-reserved block-del))
         '(2 '(face adoc-meta-face adoc-attribute-list t)))


   ;; block title
   ;; -----------------------------------
   (adoc-kw-block-title)


   ;; paragraphs
   ;; --------------------------
   (adoc-kw-verbatim-paragraph-sequence)
   (adoc-kw-admonition-paragraph)
   (list "^[ \t]+$" '(0 '(face nil adoc-reserved block-del) t))

   ;; Inline substitutions
   ;; ==========================================
   ;; Inline substitutions within block elements are performed in the
   ;; following default order:
   ;; -. Passthrough stuff removal (seen in asciidoc source)
   ;; 1. Special characters
   ;; 2. Quotes
   ;; 3. Special words
   ;; 4. Replacements
   ;; 5. Attributes
   ;; 6. Inline Macros
   ;; 7. Replacements2


   ;; backslash-escaped inline formatting (must precede the quote keywords
   ;; below so the escaped delimiters are reserved before they are scanned)
   (adoc-kw-escaped-formatting)

   ;; Curved (smart) quotes: "`text`" -> double, '`text`' -> single.  These
   ;; must precede the backtick keywords below so the enclosing backticks are
   ;; taken as part of the quote delimiter rather than as inline code.  The
   ;; enclosed text is normal text, so it gets no special face.
   (adoc-kw-quote 'adoc-constrained "\"`" nil nil "`\"")
   (adoc-kw-quote 'adoc-constrained "'`" nil nil "`'")

   ;; Inline code and passthroughs
   ;; ----------------------------
   ;; Asciidoctor: `text` is inline code (monospace literal)
   (adoc-kw-quote 'adoc-unconstrained "``" 'adoc-typewriter-face nil nil t)
   (adoc-kw-quote 'adoc-constrained "`" 'adoc-typewriter-face nil nil t)
   ;; +++text+++ passthrough (no substitutions)
   (adoc-kw-quote 'adoc-unconstrained "+++" 'adoc-typewriter-face nil nil t)
   ;; $$text$$ passthrough (special characters escaped)
   (adoc-kw-quote 'adoc-unconstrained "$$" 'adoc-typewriter-face nil nil t)
   ;; +text+ / ++text++ inline passthroughs.  In modern AsciiDoc these are
   ;; passthroughs (formatting suppressed, rendered as normal text), NOT
   ;; monospace; only the backtick is monospace.  Must precede the quote
   ;; keywords so the enclosed text is reserved before they scan it.  The
   ;; double (unconstrained) form is registered first so it wins over the
   ;; single (constrained) one.
   (adoc-kw-inline-passthrough 'adoc-unconstrained "++")
   (adoc-kw-inline-passthrough 'adoc-constrained "+")

   ;; special characters
   ;; ------------------
   ;; no highlighting for them, since they are a property of the backend markup,
   ;; not of AsciiDoc syntax


   ;; quotes: unconstrained and constrained
   ;; order given by asciidoc.conf
   ;; ------------------------------
   (adoc-kw-quote 'adoc-unconstrained "**" 'adoc-bold-face)
   (adoc-kw-quote 'adoc-constrained "*" 'adoc-bold-face)
   ;; The +text+ / ++text++ monospace markup of legacy AsciiDoc.py
   ;; "compat-mode" is gone; the plus forms are inline passthroughs, handled
   ;; in the passthrough section above.  Backtick is the only monospace mark.
   (adoc-kw-quote 'adoc-unconstrained  "__" 'adoc-emphasis-face)
   (adoc-kw-quote 'adoc-constrained "_" 'adoc-emphasis-face)
   (adoc-kw-quote 'adoc-unconstrained "##" 'adoc-highlight-face) ; highlighted text
   (adoc-kw-quote 'adoc-constrained "#" 'adoc-highlight-face)    ; highlighted text
   (adoc-kw-quote 'adoc-script "~" (adoc-facespec-subscript)) ; subscript
   (adoc-kw-quote 'adoc-script "^" (adoc-facespec-superscript)) ; superscript


   ;; special words
   ;; --------------------
   ;; there are no default special words to highlight


   ;; attributes
   ;; ---------------------------------
   ;; attribute reference, including the `:'-separated reference macros
   ;; {counter:name}, {counter2:name}, and {set:name:value}
   (list "{\\(?:\\(?:counter2?\\|set\\):[^}\n]*\\|\\w[[:word:]-]*\\(?:[=?!#%@$][^}\n]*\\)?\\)}"
         '(0 'adoc-replacement-face))


   ;; inline macros (that includes anchors, links, footnotes,....)
   ;; ------------------------------
   ;; TODO: make adoc-kw-... macros to have less redundancy
   ;; Note: Some regexp/kewyords are within the macro section
   ;; TODO:
   ;; - allow multiline
   ;; - currently escpapes are not looked at
   ;; - adapt to the adoc-reserved scheme
   ;; - same order as in asciidoc.conf (is that in 'reverse'? cause 'default syntax' comes first)

   ;; Macros using default syntax, but having special highlighting in adoc-mode
   ;; Remote inline images may contain an url.  So they must be fontified before general urls.
   (adoc-kw-inline-macro "image" nil nil 'adoc-complex-replacement-face 'adoc-internal-reference-face t
                         '("alt") '(keymap adoc-image-link-map))
   (adoc-kw-inline-macro-urls-no-attribute-list)
   (adoc-kw-inline-macro-urls-attribute-list)
   (adoc-kw-inline-macro "anchor" nil nil nil 'adoc-anchor-face t '("xreflabel"))
   (adoc-kw-inline-macro "xref" nil nil nil '(adoc-reference-face adoc-internal-reference-face) t
                         '(("caption") (("caption" . adoc-reference-face)))
                         '(keymap adoc-link-keymap mouse-face adoc-link-mouse-face help-echo "mouse-1: jump to this anchor"))
   (adoc-kw-inline-macro "footnote" t nil 'adoc-footnote-marker-face nil nil 'adoc-footnote-text-face)
   (adoc-kw-inline-macro "footnoteref" t 'single-attribute 'adoc-footnote-marker-face nil nil
                         '(("id") (("id" . adoc-internal-reference-face))))
   (adoc-kw-inline-macro "footnoteref" t nil 'adoc-footnote-marker-face nil nil
                         '(("id" "text") (("text" . adoc-footnote-text-face))))

   ;; icon macro: icon:target[attrlist], target is the icon name/path
   (adoc-kw-inline-macro "icon" nil nil 'adoc-command-face 'adoc-internal-reference-face t)

   ;; Asciidoctor UI macros
   (adoc-kw-inline-macro "kbd" t nil 'adoc-command-face nil t)
   (adoc-kw-inline-macro "btn" t nil 'adoc-command-face nil t)
   (adoc-kw-inline-macro "menu" nil nil 'adoc-command-face nil t)

   ;; Passthrough inline macros
   (adoc-kw-inline-macro "pass" nil nil nil nil t)
   (adoc-kw-inline-macro "stem" nil nil nil nil t)
   (adoc-kw-inline-macro "latexmath" nil nil nil nil t)
   (adoc-kw-inline-macro "asciimath" nil nil nil nil t)

   (adoc-kw-standalone-urls)

   ;; Macros using default syntax and having default highlighting in adoc-mode
   (adoc-kw-inline-macro)

   ;; bibliographic anchor ala [[[id]]]
   ;; actually in AsciiDoc the part between the innermost brackets is an
   ;; attribute list, for simplicity adoc-mode doesn't really treat it as such.
   ;; The attrib list can only contain one element anyway.
   (list `(lambda (end) (adoc-kwf-std end ,(adoc-re-anchor 'biblio) '(1 3) '(0)))
         '(1 '(face adoc-meta-face adoc-reserved t) t)  ; [[
         '(2 'adoc-gen-face)                             ; [id]
         '(3 '(face adoc-meta-face adoc-reserved t) t)) ; ]]
   ;; anchor ala [[id]] or [[id,xreflabel]]
   (list `(lambda (end) (adoc-kwf-std end ,(adoc-re-anchor 'inline-special) '(1 3) '(0)))
         '(1 '(face adoc-meta-face adoc-reserved t) t)
         '(2 '(face adoc-meta-face adoc-attribute-list ("id" "xreflabel")) t)
         '(3 '(face adoc-meta-face adoc-reserved t) t))

   ;; see also xref: within inline macros
   ;; reference with own/explicit caption
   (list (adoc-re-xref 'inline-special-with-caption t)
         ;; clickable, but not inside code/literal blocks (those set adoc-reserved)
         '(0 (unless (get-text-property (match-beginning 0) 'adoc-reserved)
               '(face nil keymap adoc-link-keymap mouse-face adoc-link-mouse-face help-echo "mouse-1: jump to this anchor")))
         '(1 'adoc-meta-hide-face)       ; <<
         '(2 'adoc-meta-face)            ; anchor-id
         '(3 'adoc-meta-hide-face)       ; ,
         '(4 'adoc-reference-face)       ; link text
         '(5 'adoc-meta-hide-face))      ; >>
   ;; reference without caption
   (list (adoc-re-xref 'inline-special-no-caption t)
         '(0 (unless (get-text-property (match-beginning 0) 'adoc-reserved)
               '(face nil keymap adoc-link-keymap mouse-face adoc-link-mouse-face help-echo "mouse-1: jump to this anchor")))
         '(1 'adoc-meta-hide-face)       ; <<
         '(2 'adoc-reference-face)       ; link text = anchor id
         '(3 'adoc-meta-hide-face))      ; >>

   ;; replacements
   ;; --------------------------------
   ;; They come after the inline macros and cross references, which may
   ;; contain them (`https://example.org[Bob's page]'): a replacement reserves
   ;; its text, and a macro running later would refuse to match across it.
   ;; Asciidoc.conf surrounds em dash with thin spaces. I think that does not
   ;; make sense here, all that spaces you would see in the buffer would at best
   ;; be confusing.
   (adoc-kw-replacement "\\((C)\\)" "\u00A9")  ;; ©
   (adoc-kw-replacement "\\((R)\\)" "\u00AE")  ;; ®
   (adoc-kw-replacement "\\((TM)\\)" "\u2122") ;; ™
   ;; (^-- )=&#8212;&#8201;
   ;; (\n-- )|( -- )|( --\n)=&#8201;&#8212;&#8201;
   ;; (\w)--(\w)=\1&#8212;\2
   (adoc-kw-replacement "^\\(--\\)[ \t]" "\u2014") ; em dash. See also above
   (adoc-kw-replacement "[ \t]\\(--\\)\\(?:[ \t]\\|$\\)" "\u2014") ; dito
   (adoc-kw-replacement "[a-zA-Z0-9_]\\(--\\)[a-zA-Z0-9_]" "\u2014") ; dito
   (adoc-kw-replacement "[a-zA-Z0-9_]\\('\\)[a-zA-Z0-9_]" "\u2019") ; punctuation apostrophe
   (adoc-kw-replacement "\\(\\.\\.\\.\\)" "\u2026") ; ellipsis
   (adoc-kw-replacement "\\(->\\)" "\u2192")
   (adoc-kw-replacement "\\(=>\\)" "\u21D2")
   (adoc-kw-replacement "\\(<-\\)" "\u2190")
   (adoc-kw-replacement "\\(<=\\)" "\u21D0")
   ;; general character entity reference
   ;; (?<!\\)&amp;([:_#a-zA-Z][:_.\-\w]*?;)=&\1
   (adoc-kw-replacement "\\(&[:_#a-zA-Z]\\(?:[-:_.]\\|[a-zA-Z0-9_]\\)*?;\\)" 'adoc-entity-to-string)

   ;; index terms
   ;; TODO:
   ;; - copy asciidocs regexps below
   ;; - add the indexterm2?:...[...] syntax
   ;; ifdef::asciidoc7compatible[]
   ;;   (?su)(?<!\S)[\\]?\+\+(?P<attrlist>[^+].*?)\+\+(?!\+)=indexterm
   ;;   (?<!\S)[\\]?\+(?P<attrlist>[^\s\+][^+].*?)\+(?!\+)=indexterm2
   ;; ifndef::asciidoc7compatible[]
   ;;   (?su)(?<!\()[\\]?\(\(\((?P<attrlist>[^(].*?)\)\)\)(?!\))=indexterm
   ;;   (?<!\()[\\]?\(\((?P<attrlist>[^\s\(][^(].*?)\)\)(?!\))=indexterm2
   ;;
   (list "(((?\\([^\\\n]\\|\\\\.\\)*?)))?" '(0 'adoc-meta-face))

   ;; passthrough. Note that quote section has some of them also
   ;; TODO: passthrough stuff
   ;; (?su)[\\]?(?P<name>pass):(?P<subslist>\S*?)\[(?P<passtext>.*?)(?<!\\)\]=[]
   ;; (?su)[\\]?\+\+\+(?P<passtext>.*?)\+\+\+=pass[]
   ;; (?su)[\\]?\$\$(?P<passtext>.*?)\$\$=pass[specialcharacters]
   ;; # Inline literal (within ifndef::no-inline-literal[])
   ;; (?su)(?<!\w)([\\]?`(?P<passtext>\S|\S.*?\S)`)(?!\w)=literal[specialcharacters]



   ;; -- forced linebreak
   ;; manual: A plus character preceded by at least one space character at the
   ;; end of a non-blank line forces a line break.
   ;; Asciidoc bug: If has that affect also on a non blank line.
   ;; TODO: what kind of element is that? Really text formatting? Its not in asciidoc.conf
   (list (lambda (end) (adoc-kwf-std end "^.*[^ \t\n].*[ \t]\\(\\+\\)[ \t]*$" '(1)))
         '(1 'adoc-meta-face))

   ;; -- callout anchors (references are within list)
   ;; commented out because they are only within (literal?) blocks
   ;; asciidoc.conf: [\\]?&lt;(?P<index>\d+)&gt;=callout
   ;; (list "^\\(<\\)\\([0-9+]\\)\\(>\\)" '(1 'adoc-meta-face) '(3 'adoc-meta-face))


   ;; Replacements2
   ;; -----------------------------
   ;; there default replacements2 section is empty


   ;; misc
   ;; ------------------------------

   ;; -- misc
   (adoc-kw-first-whites-fixed-width)

   ;; -- warnings
   ;; TODO: add tooltip explaining what is the warning all about
   ;; bogous 'list continuation'
   (list "^\\([ \t]+\\+[ \t]*\\)$" '(1 'adoc-warning-face t))
   ;; list continuation witch appends a literal paragraph. The user probably
   ;; wanted to add a normal paragraph. List paragraphs are appended
   ;; implicitly.
   (list "^\\(\\+[ \t]*\\)\n\\([ \t]+\\)[^ \t\n]" '(1 'adoc-warning-face t) '(2 'adoc-warning-face t))

   ;; content of attribute lists
   (list 'adoc-kwf-attribute-list)

   ;; cleanup
   (list 'adoc-flf-meta-face-cleanup)))

;;;; interactively-callable commands
(defun adoc-mode-version ()
  "Show the version number in the minibuffer."
  (interactive)
  (message "adoc-mode, version %s" adoc-mode-version))

(define-obsolete-function-alias 'adoc-show-version #'adoc-mode-version "0.9")

(defun adoc-goto-ref-label (id)
  "Goto the anchor defining the id ID."
  ;; KLUDGE: Getting the default, i.e. trying to parse the xref 'at' point, is
  ;; not done nicely. backward-char 5 because the longest 'starting' of an xref
  ;; construct is 'xref:' (others are '<<'). All this fails if point is within
  ;; the id, opposed to the start the id. Or if the xref spawns over the current
  ;; line.
  (interactive (let* ((default (adoc-xref-id-at-point))
                      (default-str (if default (concat "(default " default ")") "")))
                 (list
                  ;; Offer the buffer's anchors and section ids as candidates,
                  ;; but stay permissive (require-match nil) so a not-yet-defined
                  ;; id can still be entered.
                  (completing-read
                   (concat "Goto anchor of reference/label " default-str ": ")
                   (delete-dups (append (adoc--collect-anchor-ids)
                                        (adoc--collect-section-ids)))
                   nil nil nil nil default))))
  (let ((target (save-excursion
                  ;; resolve against an explicit anchor or a section (auto-id
                  ;; or title) without moving point yet
                  (when (adoc--goto-id id) (point)))))
    (if (null target) (user-error "Can't find an anchor defining '%s'" id))
    (push-mark)
    (goto-char target)))

(defun adoc--inline-link-at-point ()
  "Return the target of an inline link or URL macro covering point, or nil.
Handles `link:target[...]' and `scheme:target[...]' (for the schemes
in `adoc--link-macro-names').  The result is the string to open: the
bare target for `link:', or `scheme:target' for the URL schemes (the
attribute list / label is dropped)."
  (save-excursion
    (let ((pos (point))
          (eol (line-end-position))
          (re (adoc-re-inline-macro (regexp-opt adoc--link-macro-names))))
      (beginning-of-line)
      (catch 'found
        (while (re-search-forward re eol t)
          (when (and (<= (match-beginning 0) pos) (<= pos (match-end 0)))
            (let ((cmd (match-string-no-properties 1))
                  (target (match-string-no-properties 3)))
              (throw 'found
                     (if (string= cmd "link")
                         target
                       (concat cmd ":" target))))))
        nil))))

(defun adoc-follow-thing-at-point ()
  "Follow the link or reference at point.
When point is on an Antora page `xref:' (e.g. `xref:other.adoc#frag[]'),
open the resolved page and jump to its fragment.
When point is on a URL or `link:' macro, open it.
When point is on an `include::' macro, open the referenced file.
When point is on an xref or cross-reference, jump to its anchor."
  (interactive)
  (cond
   ;; include:: macro — open the file
   ((save-excursion
      (beginning-of-line)
      (looking-at "include1?::\\([^ \t\n\\[]+\\)"))
    (let ((file (match-string-no-properties 1)))
      (if (file-exists-p file)
          (find-file file)
        (user-error "File not found: %s" file))))
   ;; Antora page xref — resolve to a file in the component and open it
   ;; (only in an Antora component, so a plain `.adoc' xref elsewhere falls
   ;; through to the in-buffer handling).
   ((and (adoc--antora-root) (adoc--antora-page-xref-at-point))
    (let* ((target (adoc--antora-page-xref-at-point))
           (resolved (adoc--antora-resolve-page target)))
      (cond
       ((null resolved)
        (user-error "Cannot resolve Antora xref: %s" target))
       ((not (file-exists-p (car resolved)))
        (user-error "Antora xref target not found: %s" (car resolved)))
       (t
        (xref-push-marker-stack)
        (find-file (car resolved))
        (when (cdr resolved)
          (or (adoc--goto-id (cdr resolved))
              (message "No anchor or section `%s' in %s"
                       (cdr resolved) (file-name-nondirectory (car resolved)))))))))
   ;; xref at point — jump to anchor
   ((adoc-xref-id-at-point)
    (adoc-goto-ref-label (adoc-xref-id-at-point)))
   ;; link:/URL inline macro — follow the target, ignoring the label
   ((adoc--inline-link-at-point)
    (let ((target (adoc--inline-link-at-point)))
      (cond
       ;; Every macro but `link:' is named after its URI scheme.
       ((string-match-p (concat "\\`" (regexp-opt (remove "link" adoc--link-macro-names)) ":")
                        target)
        (browse-url target))
       ((file-exists-p target) (find-file target))
       (t (user-error "File not found: %s" target)))))
   ;; bare URL at point — open in browser
   ((thing-at-point 'url)
    (browse-url (thing-at-point 'url t)))
   (t
    (user-error "Nothing to follow at point"))))

(defvar adoc-link-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map [mouse-2] #'adoc-follow-thing-at-point)
    (define-key map [follow-link] 'mouse-face)
    map)
  "Keymap on clickable references (xrefs, links, URLs, `include::').
A quick `mouse-1' or a `mouse-2' click follows the reference via
`adoc-follow-thing-at-point'.  It is attached to those constructs as a
`keymap' text property during fontification.")
;; Make the symbol usable as the value of a `keymap' text property.
(fset 'adoc-link-keymap adoc-link-keymap)

(defun adoc-promote (&optional arg interactive)
  "Promote the title or list item at point ARG levels.

As in Org mode, promoting moves the structure up the outline: a
section title loses a level marker (e.g. `===' -> `==', see
`adoc-promote-title') and a list item is nested one level
shallower (e.g. `**' -> `*').  ARG defaults to 1; a negative ARG
demotes instead.

Anywhere else, move backward ARG words when called interactively
\(INTERACTIVE is non-nil), like `org-metaleft'."
  (interactive (list (prefix-numeric-value current-prefix-arg) t))
  (let ((item (adoc--list-item-at-point)))
    (cond
     (item (adoc--change-list-item-level item (- (or arg 1))))
     ((and interactive (not (adoc-title-descriptor))) (backward-word arg))
     (t (adoc-promote-title arg)))))

(defun adoc-demote (&optional arg interactive)
  "Demote the title or list item at point ARG levels.

The opposite of `adoc-promote': a section title gains a level
marker (e.g. `==' -> `===') and a list item is nested one level
deeper (e.g. `*' -> `**').

Anywhere else, move forward ARG words when called interactively
\(INTERACTIVE is non-nil), like `org-metaright'."
  (interactive (list (prefix-numeric-value current-prefix-arg) t))
  (let ((item (adoc--list-item-at-point)))
    (cond
     (item (adoc--change-list-item-level item (or arg 1)))
     ((and interactive (not (adoc-title-descriptor))) (forward-word arg))
     (t (adoc-demote-title arg)))))

(defun adoc-promote-title (&optional arg)
  "Promote the title at point ARG levels, e.g. `===' -> `=='.

ARG defaults to 1; a negative ARG demotes instead.  If ARG is 0,
the title is only reformatted, see `adoc-adjust-title-del'."
  (interactive "p")
  (adoc-modify-title (- (or arg 1))))

(defun adoc-demote-title (&optional arg)
  "Demote the title at point ARG levels, e.g. `==' -> `==='.
The opposite of `adoc-promote-title'."
  (interactive "p")
  (adoc-modify-title (or arg 1)))

(defun adoc-adjust-title-del ()
  "Adjusts underline length to match the length of the title's text.

E.g. after editing a two line title, call `adoc-adjust-title-del' so
the underline has the correct length."
  (interactive)
  (adoc-modify-title))

(defun adoc-toggle-title-type (&optional type-type)
  "Toggles title's type.

If TYPE-TYPE is nil, title's type is toggled. If TYPE-TYPE is
non-nil, the sub type is toggled."
  (interactive "P")
  (when type-type
    (setq type-type t))
  (adoc-modify-title nil nil (not type-type) type-type))

;;;; List editing

(defun adoc--list-item-at-point (&optional with-breaks)
  "Return a description of the list item on the current line, or nil.
The description is a plist with these keys:

:type        one of `unordered', `implicit-numbered',
             `explicit-numbered'
:marker      the marker string, e.g. \"*\", \"..\" or \"1.\"
:indent      the leading whitespace string
:marker-beg  buffer position of the marker's first character
:level       0-based nesting level

Labeled lists and callouts are intentionally not recognised, as
their markers are too easily confused with ordinary prose, and
neither are lines in verbatim blocks, such as listings, or thematic
breaks, such as `* * *', unless WITH-BREAKS is non-nil."
  (save-excursion
    (beginning-of-line)
    (cond
     ((nth 2 (adoc--delimited-block-at (point))) nil)
     ((looking-at (adoc-re-oulisti 'adoc-unordered 'adoc-all-levels))
      (let ((marker (match-string-no-properties 2)))
        (unless (and (not with-breaks) (adoc--markdown-thematic-break-p))
          (list :type 'unordered
                :marker marker
                :indent (match-string-no-properties 1)
                :marker-beg (match-beginning 2)
                :level (if (string-prefix-p "-" marker) 0 (length marker))))))
     ((looking-at (adoc-re-oulisti 'adoc-implicitly-numbered 'adoc-all-levels))
      (let ((marker (match-string-no-properties 2)))
        (list :type 'implicit-numbered
              :marker marker
              :indent (match-string-no-properties 1)
              :marker-beg (match-beginning 2)
              :level (1- (length marker)))))
     ((looking-at (adoc-re-oulisti 'adoc-explicitly-numbered))
      (list :type 'explicit-numbered
            :marker (match-string-no-properties 2)
            :indent (match-string-no-properties 1)
            :marker-beg (match-beginning 2)
            :level 0)))))

(defun adoc--list-item-key (item)
  "Return what sets ITEM's nesting level in its list.
That's its marker, or for an explicitly numbered item, the kind of
numbering.  As in Asciidoctor, an item nests under the one above it when
their keys differ, unless an item it's nested in has the same key, in
which case it goes back out to that item's level."
  (if (eq (plist-get item :type) 'explicit-numbered)
      (adoc--explicit-marker-kind (plist-get item :marker))
    (plist-get item :marker)))

(defun adoc--check-level (level max-level)
  "Return LEVEL, or signal a `user-error' if it's outside 0 to MAX-LEVEL.
For promoting and demoting titles and list items."
  (cond
   ((< level 0) (user-error "Cannot promote any further"))
   ((> level max-level) (user-error "Cannot demote any further"))
   (t level)))

(defun adoc--increment-marker (marker)
  "Return list MARKER incremented for the next sibling item.
Arabic numbers (\"1.\") and single letters (\"a.\") are
incremented.  Roman numerals, the last letter of the alphabet,
and other markers are returned unchanged, leaving the user to fix
them up."
  (cond
   ((string-match "\\`\\([0-9]+\\)\\(\\.\\)\\'" marker)
    (concat (number-to-string (1+ (string-to-number (match-string 1 marker))))
            (match-string 2 marker)))
   ;; Stop before the alphabet wraps past `z'/`Z' into punctuation.
   ((string-match "\\`\\([a-yA-Y]\\)\\(\\.\\)\\'" marker)
    (concat (char-to-string (1+ (aref (match-string 1 marker) 0)))
            (match-string 2 marker)))
   (t marker)))

(defun adoc--list-items-above (item &optional with-breaks)
  "Return the items above ITEM in its list, nearest first.
The list ends at a paragraph or block that follows a blank line, as in
AsciiDoc, or at the start of the delimited block it's in.  A delimited
block inside the list is skipped as a whole, so its lines aren't taken
for items.  WITH-BREAKS is passed on to `adoc--list-item-at-point'."
  (save-excursion
    (goto-char (plist-get item :marker-beg))
    (let ((own (adoc--delimited-block-at (line-beginning-position)))
          items)
      (catch 'done
        (while (zerop (forward-line -1))
          (let* ((block (adoc--delimited-block-at (point)))
                 (nested (and block (not (equal block own)))))
            (cond
             (nested (goto-char (car block)))
             ((and block (<= (point) (nth 1 own))) (throw 'done nil)))
            (let ((other (and (not nested) (adoc--list-item-at-point with-breaks))))
              (cond
               (other (push other items))
               ((looking-at-p "[ \t]*$"))
               ((save-excursion
                  (or (/= (forward-line -1) 0) (looking-at-p "[ \t]*$")))
                (throw 'done nil)))))))
      (nreverse items))))

(defun adoc--outer-unordered-marker (item)
  "Return the marker of the outermost unordered items in ITEM's list.
That's `-' or `*', so ITEM promoted to the outermost level stays in
its list.  Return `*' when the list has no such item above ITEM."
  (or (seq-some (lambda (other)
                  (let ((marker (plist-get other :marker)))
                    (and (eq (plist-get other :type) 'unordered)
                         (= (length marker) 1)
                         marker)))
                (adoc--list-items-above item))
      "*"))

(defun adoc--prev-list-sibling-p (item)
  "Return non-nil when ITEM's list has an item at ITEM's level above it.
That's an item with the same marker.  Asciidoctor nests an item with
a new marker under the one above it, so going up, a shorter marker of
the same kind, or a different one of the same length, is ITEM's parent."
  (let ((type (plist-get item :type))
        (marker (plist-get item :marker)))
    (catch 'done
      (dolist (other (adoc--list-items-above item))
        (when (eq (plist-get other :type) type)
          (let ((other-marker (plist-get other :marker)))
            (cond
             ((string= other-marker marker) (throw 'done t))
             ((<= (length other-marker) (length marker)) (throw 'done nil))))))
      nil)))

(defun adoc--change-list-item-level (item delta)
  "Change list ITEM's nesting level by DELTA, rewriting its marker.
A positive DELTA nests the item deeper, a negative one shallower.

The depth is the marker's length, as Asciidoctor nests on a change of
marker: `-' and `*' both mark the outermost level of an unordered
list, `**' the next one.  Signal a `user-error' when the new depth is
outside the five levels `adoc-mode' recognizes, and, as in Org mode,
when demoting the first item of a list, which would leave it with no
item to nest under.  A DELTA of 0 leaves ITEM alone."
  (let ((type (plist-get item :type))
        (old-marker (plist-get item :marker))
        (beg (plist-get item :marker-beg)))
    (when (eq type 'explicit-numbered)
      (user-error "Cannot change the nesting level of a numbered list item"))
    (unless (zerop delta)
      (let ((depth (1+ (adoc--check-level (+ (length old-marker) delta -1) 4))))
        (when (and (> delta 0) (not (adoc--prev-list-sibling-p item)))
          (user-error "Cannot demote the first item of a list"))
        (let ((new-marker (cond
                           ((eq type 'implicit-numbered) (make-string depth ?.))
                           ((= depth 1) (adoc--outer-unordered-marker item))
                           (t (make-string depth ?*)))))
          (unless (string= new-marker old-marker)
            (save-excursion
              (goto-char beg)
              (delete-region beg (+ beg (length old-marker)))
              (insert new-marker))))))))

(defun adoc-insert-list-item (&optional _arg)
  "Insert a new list item below the item at point.
The new item keeps the indentation, marker style and nesting
level of the current item; explicitly-numbered items get an
incremented number or letter."
  (interactive "p")
  (let ((item (adoc--list-item-at-point)))
    (unless item
      (user-error "Not on a list item"))
    (let ((indent (plist-get item :indent))
          (new-marker (if (eq (plist-get item :type) 'explicit-numbered)
                          (adoc--increment-marker (plist-get item :marker))
                        (plist-get item :marker))))
      (end-of-line)
      (insert "\n" indent new-marker " "))))

(defun adoc--line-list-level ()
  "Return the nesting level of the list item on the current line, or nil."
  (let ((item (adoc--list-item-at-point)))
    (and item (plist-get item :level))))

(defun adoc--list-item-block-end (level)
  "Return the position at the end of the list item block on the current line.
Point must be at the beginning of the marker line of an item at
nesting LEVEL.  The block runs through any immediately following
continuation lines and more deeply nested items, stopping before
the first blank line, sibling, or shallower item.  The returned
position is at the beginning of a line (or `point-max')."
  (save-excursion
    (forward-line 1)
    (let ((end (point)))
      (while (and (not (eobp))
                  (not (looking-at-p "[ \t]*$"))
                  (let ((il (adoc--line-list-level)))
                    (or (null il) (> il level))))
        (forward-line 1)
        (setq end (point)))
      end)))

(defun adoc--same-list-p (item)
  "Return non-nil if the item on the current line is a sibling of ITEM.
Siblings share the same list type, nesting level and indentation
\(and, for explicitly-numbered lists, the same marker kind), so
two distinct adjacent lists are not treated as one."
  (let ((other (adoc--list-item-at-point)))
    (and other
         (eq (plist-get other :type) (plist-get item :type))
         (= (plist-get other :level) (plist-get item :level))
         (string= (plist-get other :indent) (plist-get item :indent))
         (or (not (eq (plist-get item :type) 'explicit-numbered))
             (eq (adoc--explicit-marker-kind (plist-get other :marker))
                 (adoc--explicit-marker-kind (plist-get item :marker)))))))

(defun adoc--next-sibling-start (from item)
  "Return the start of the next sibling of ITEM at or after FROM, or nil.
Blank lines, continuation lines and more deeply nested items are
skipped.  A shallower item, or a same-level item belonging to a
different list, stops the search and yields nil."
  (let ((level (plist-get item :level)))
    (save-excursion
      (goto-char from)
      (catch 'found
        (while (not (eobp))
          (unless (looking-at-p "[ \t]*$")
            (let ((il (adoc--line-list-level)))
              (cond
               ((null il))
               ((and (= il level) (adoc--same-list-p item)) (throw 'found (point)))
               ((<= il level) (throw 'found nil)))))
          (forward-line 1))
        nil))))

(defun adoc--prev-sibling-start (before item)
  "Return the start of the previous sibling of ITEM before BEFORE, or nil.
Blank lines, continuation lines and more deeply nested items are
skipped.  A shallower item, or a same-level item belonging to a
different list, stops the search and yields nil."
  (let ((level (plist-get item :level)))
    (save-excursion
      (goto-char before)
      (catch 'found
        (while (not (bobp))
          (forward-line -1)
          (unless (looking-at-p "[ \t]*$")
            (let ((il (adoc--line-list-level)))
              (cond
               ((null il))
               ((and (= il level) (adoc--same-list-p item)) (throw 'found (point)))
               ((<= il level) (throw 'found nil))))))
        nil))))

(defun adoc--move-list-item (down)
  "Move the list item at point past its sibling, DOWN when non-nil else up.
The item's nested sub-items and continuation lines move with it."
  (let ((item (adoc--list-item-at-point)))
    (unless item
      (user-error "Not on a list item"))
    (let ((level (plist-get item :level))
          (col (current-column)))
      (beginning-of-line)
      (let* ((s1 (point))
             (e1 (adoc--list-item-block-end level)))
        (if down
            (let ((s2 (adoc--next-sibling-start e1 item)))
              (unless s2 (user-error "No next item at this level"))
              (let ((e2 (save-excursion
                          (goto-char s2)
                          (adoc--list-item-block-end level))))
                ;; Avoid merging lines when the buffer lacks a final newline.
                (when (and (= e2 (point-max)) (/= (char-before e2) ?\n))
                  (save-excursion (goto-char (point-max)) (insert "\n"))
                  (setq e2 (point-max)))
                (transpose-regions s1 e1 s2 e2)
                (goto-char (+ s1 (- e2 e1)))
                (move-to-column col)))
          (let ((ps (adoc--prev-sibling-start s1 item)))
            (unless ps (user-error "No previous item at this level"))
            ;; Avoid merging lines when the buffer lacks a final newline.
            (when (and (= e1 (point-max)) (/= (char-before e1) ?\n))
              (save-excursion (goto-char (point-max)) (insert "\n"))
              (setq e1 (point-max)))
            (transpose-regions ps s1 s1 e1)
            (goto-char ps)
            (move-to-column col)))))))

(defun adoc-move-list-item-down (&optional arg)
  "Move the list item at point down past the next sibling ARG times.
The item's nested sub-items and continuation lines move with it."
  (interactive "p")
  (dotimes (_ (or arg 1))
    (adoc--move-list-item t)))

(defun adoc-move-list-item-up (&optional arg)
  "Move the list item at point up past the previous sibling ARG times.
The item's nested sub-items and continuation lines move with it."
  (interactive "p")
  (dotimes (_ (or arg 1))
    (adoc--move-list-item nil)))

(defun adoc--explicit-marker-kind (marker)
  "Return the kind of an explicitly-numbered list MARKER.
One of `arabic', `lower-alpha', `upper-alpha', `lower-roman',
`upper-roman', or nil."
  (cond
   ((string-match-p "\\`[0-9]+\\.\\'" marker) 'arabic)
   ((string-match-p "\\`[a-z]\\.\\'" marker) 'lower-alpha)
   ((string-match-p "\\`[A-Z]\\.\\'" marker) 'upper-alpha)
   ((string-match-p "\\`[ivxlcdm]+)\\'" marker) 'lower-roman)
   ((string-match-p "\\`[IVXLCDM]+)\\'" marker) 'upper-roman)))

(defun adoc--explicit-marker-value (kind marker)
  "Return the 1-based ordinal that MARKER represents for list KIND."
  (pcase kind
    ('arabic (string-to-number marker))
    ('lower-alpha (1+ (- (aref marker 0) ?a)))
    ('upper-alpha (1+ (- (aref marker 0) ?A)))))

(defun adoc--explicit-marker (kind n)
  "Return the marker string for the Nth (1-based) item of list KIND."
  (pcase kind
    ('arabic (format "%d." n))
    ('lower-alpha (format "%c." (+ ?a (1- n))))
    ('upper-alpha (format "%c." (+ ?A (1- n))))))

(defun adoc--explicit-item-on-line-p (kind indent)
  "Non-nil if the current line holds an explicit item of KIND and INDENT."
  (let ((item (adoc--list-item-at-point)))
    (and item
         (eq (plist-get item :type) 'explicit-numbered)
         (string= (plist-get item :indent) indent)
         (eq (adoc--explicit-marker-kind (plist-get item :marker)) kind))))

(defun adoc-renumber-list ()
  "Renumber the explicitly-numbered list at point.
Only flat arabic (\"1.\") and alphabetic (\"a.\"/\"A.\") lists are
renumbered; the sequence starts from the first item's current
value.  Roman-numeral lists are left untouched."
  (interactive)
  (let ((item (adoc--list-item-at-point)))
    (unless (and item (eq (plist-get item :type) 'explicit-numbered))
      (user-error "Not on an explicitly-numbered list item"))
    (let* ((indent (plist-get item :indent))
           (kind (adoc--explicit-marker-kind (plist-get item :marker))))
      (unless (memq kind '(arabic lower-alpha upper-alpha))
        (user-error "Can only renumber arabic or alphabetic lists"))
      (save-excursion
        (beginning-of-line)
        ;; Walk back to the first item of the run.
        (while (save-excursion (and (zerop (forward-line -1))
                                    (adoc--explicit-item-on-line-p kind indent)))
          (forward-line -1))
        (let ((n (adoc--explicit-marker-value
                  kind (plist-get (adoc--list-item-at-point) :marker))))
          (while (and (not (eobp))
                      (adoc--explicit-item-on-line-p kind indent))
            (when (and (memq kind '(lower-alpha upper-alpha)) (> n 26))
              (user-error "Alphabetic lists cannot have more than 26 items"))
            (let* ((it (adoc--list-item-at-point))
                   (beg (plist-get it :marker-beg))
                   (old (plist-get it :marker))
                   (new (adoc--explicit-marker kind n)))
              (unless (string= old new)
                (save-excursion
                  (goto-char beg)
                  (delete-region beg (+ beg (length old)))
                  (insert new))))
            (setq n (1+ n))
            (forward-line 1)))))))

(defun adoc-calc ()
  "(Re-)calculates variables used in adoc-mode.
Needs to be called after changes to certain (customization)
variables. Mostly in order font lock highlighting works as the
new customization demands."
  (interactive)

  (when (and (null adoc-insert-replacement)
             adoc-unichar-name-resolver)
    (message "Warning: adoc-unichar-name-resolver is non-nil, but is adoc-insert-replacement is nil"))
  (when (and (eq adoc-unichar-name-resolver 'adoc-unichar-by-name)
             (null adoc-unichar-alist))
    (adoc-make-unichar-alist))

  (setq adoc-font-lock-keywords (adoc-get-font-lock-keywords))
  (when (eq major-mode 'adoc-mode)
    ;; the extents depend on `adoc-enable-two-line-title'
    (setq adoc--block-extents-done 1
          adoc--block-extents-unterminated nil))
  (when (and font-lock-mode (eq major-mode 'adoc-mode))
    (font-lock-flush)
    (font-lock-ensure)))

;;;; misc
(defun adoc-insert-comment (&optional beg end)
  "Comment out the lines between BEG and END, or start a comment line.
Interactively BEG and END delimit the active region.  An AsciiDoc
comment line starts with `//' in the first column, so every line gets
one there."
  (interactive (when (use-region-p)
                 (list (region-beginning) (region-end))))
  (if (not beg)
      (tempo-template-adoc-comment)
    (save-excursion
      (let ((end (copy-marker end)))
        (goto-char beg)
        (beginning-of-line)
        (while (< (point) end)
          (insert "// ")
          (forward-line 1))
        (set-marker end nil)))))

(defun adoc-insert-indented (str indent-level)
  "Indents and inserts STR such that point is at INDENT-LEVEL."
  (indent-to (- (* tab-width indent-level) (length str)))
  (insert str))


(defun adoc-forward-xref (&optional bound)
  "Move forward to the next xref and return its id.

Search for the nearest cross-reference of any form - `<<id>>',
`<<id,caption>>' or `xref:id[...]' - set the match data to it and move
point to its end.  Return nil, leaving point unmoved, when none is found
before BOUND.

Searching for each form independently and taking the earliest match
matters: a plain `<<id>>' must not be skipped just because a
`<<id,caption>>' happens to appear later in the search range."
  (let ((start (point))
        (best nil)
        (best-id nil)
        (best-data nil))
    (dolist (spec '((inline-special-with-caption . 2)
                    (inline-special-no-caption . 2)
                    (inline-general-macro . 3)))
      (goto-char start)
      (when (and (re-search-forward (adoc-re-xref (car spec)) bound t)
                 (or (null best) (< (match-beginning 0) best)))
        (setq best (match-beginning 0)
              best-id (match-string-no-properties (cdr spec))
              best-data (match-data))))
    (if best
        (progn (set-match-data best-data)
               (goto-char (match-end 0))
               best-id)
      (goto-char start)
      nil)))

(defun adoc-xref-id-at-point ()
  "Returns id referenced by the xref point is at.

Returns nil if there was no xref found."
  (save-excursion
    ;; search the xref within +-1 one line. I.e. if the xref spawns more than
    ;; two lines, it wouldn't be found.
    (let ((id)
          (saved-point (point))
          (end (save-excursion (forward-line 1) (line-end-position))))
      (forward-line -1)
      (while (and (setq id (adoc-forward-xref end))
                  (or (< saved-point (match-beginning 0))
                      (> saved-point (match-end 0)))))
      ;; `adoc-re-xref' captures trailing whitespace inside the id group
      ;; (e.g. `<<foo >>'); the actual anchor id has none.  And the `#' in
      ;; a same-page `xref:#id[]' isn't part of the id.
      (and id (string-remove-prefix "#" (string-trim id))))))

(defun adoc-title-descriptor (&optional strict-match )
  "Returns title descriptor of title point is in.

When STRICT-MATCH is t, and 2 line title is used, the lengths of the underline
text and title must not differ by more than 2 characters.

Two line titles are only recognised when `adoc-enable-two-line-title'
is non-nil.

Title descriptor looks like this: (TYPE SUB-TYPE LEVEL TEXT START END)

0 TYPE: 1 fore one line title, 2 for two line title.

1 SUB-TYPE: Only applicable for one line title: 1 for only
starting delimiter ('== my title'), 2 for both starting and
trailing delimiter ('== my title ==').

2 LEVEL: Level of title. A value between 0 and
`adoc-title-max-level' inclusive.

3 TEXT: Title's text

4 START / 5 END: Start/End pos of match"
  (save-excursion
    (let ((level 0)
          found
          type sub-type text)
      (beginning-of-line)
      (while (and (not found) (<= level adoc-title-max-level))
        (cond
         ((looking-at (adoc-re-one-line-title level))
          (setq type 1)
          (setq text (match-string 2))
          (setq sub-type (if (match-beginning 4) 2 1))
          (setq found t))
         ;; WARNING: if you decide to replace adoc-re-two-line-title with a
         ;; method ensuring the correct length of the underline, be aware that
         ;; due to adoc-adjust-title-del we sometimes want to find a title which has
         ;; the wrong underline length.
         ;; Two-line titles only cover the first N levels (one per entry in
         ;; adoc-two-line-title-del); skip the check for higher levels.
         ;; They're also only recognised when enabled, like fontification,
         ;; navigation and imenu do - otherwise a line of text above a
         ;; block delimiter (`----', `====') would pass for one.
         ((and adoc-enable-two-line-title
               (< level (length adoc-two-line-title-del))
               (or (looking-at (adoc-re-two-line-title (nth level adoc-two-line-title-del)))
                   (save-excursion
                     (forward-line -1)
                     (beginning-of-line)
                     (looking-at (adoc-re-two-line-title (nth level adoc-two-line-title-del)))))
               ;; If strict-mode, expect title and underline text lengths to be at most +-2 characters different
               (or (not strict-match)
                   (<= (abs (- (length (match-string 3))
                               (length (match-string 2))))
                       2))
               (not (string-prefix-p "[" (match-string 2)))
               (adoc--two-line-title-underline-p (- (match-end 3) (match-beginning 3))))
          (setq type 2)
          (setq text (match-string 2))
          (setq found t))
         (t
          (setq level (+ level 1)))))
      ;; a title-like line inside a delimited block is just content
      (when (and found (not (adoc--delimited-block-at (match-beginning 0))))
        (list type sub-type level text (match-beginning 0) (match-end 0))))))

(defun adoc-make-title (descriptor)
  (let ((type (nth 0 descriptor))
        (sub-type (nth 1 descriptor))
        (level (nth 2 descriptor))
        (text (nth 3 descriptor)))
    (if (eq type 1)
        (adoc-make-one-line-title sub-type level text)
      (adoc-make-two-line-title level text))))

(defun adoc--book-p ()
  "Return non-nil when the document header sets the doctype to book.
The header runs from the first line that isn't blank to the next blank
line."
  (save-excursion
    (save-restriction
      (widen)
      (goto-char (point-min))
      (skip-chars-forward " \t\n")
      (let ((case-fold-search nil)
            (end (save-excursion
                   (if (re-search-forward "^[ \t]*$" nil t) (point) (point-max)))))
        (re-search-forward "^:doctype:[ \t]+book[ \t]*$" end t)))))

(defun adoc--level-0-title-allowed-p ()
  "Return non-nil when the title at point may be at level 0.
In a book, level 0 sections are parts.  Otherwise level 0 is for the
document title only, which must come before any other title."
  (or (adoc--book-p)
      (save-excursion
        (beginning-of-line)
        (let (found)
          (while (and (not found)
                      (re-search-backward "^=\\{1,6\\}[ \t]+[^ \t\n]" nil t))
            (setq found (not (adoc--delimited-block-at (point)))))
          (not found)))))

(defun adoc-modify-title (&optional new-level-rel new-level-abs new-type new-sub-type create)
  "Modify properties of title point is on.

NEW-LEVEL-REL defines the new title level relative to the current
one. Negative values are allowed. 0 or nil means don't change. A
resulting level outside the range the title type supports signals a
`user-error'.
NEW-LEVEL-ABS defines the new level absolutely. When both
NEW-LEVEL-REL and NEW-LEVEL-ABS are non-nil, NEW-LEVEL-REL takes
precedence. When both are nil, level is not affected.

When NEW-TYPE is nil, the title type is unaffected. If NEW-TYPE
is t, the type is toggled. If it's 1 or 2, the new type is one
line title or two line title respectively.

NEW-SUB-TYPE is analogous to NEW-TYPE. However when the actual
title has no sub type, only the absolute values of NEW-SUB-TYPE
apply, otherwise the new sub type becomes
`adoc-default-title-sub-type'.

If CREATE is nil, an error is signaled if point is not on a
title. If CREATE is non-nil a new title is created if point is
currently not on a title.

BUG: In one line title case: number of spaces between delimiters
and title's text are not preserved, afterwards its always one space."
  (let ((descriptor (adoc-title-descriptor)))
    (if (or create (not descriptor))
        (user-error "Point is not on a title"))

    (let* ((type (nth 0 descriptor))
           (new-type-val (cond
                          ((eq new-type 1) 2)
                          ((eq new-type 2) 1)
                          ((not (or (eq type 1) (eq type 2)))
                           (error "Invalid title type"))
                          ((eq new-type nil) type)
                          ((eq new-type t) (if (eq type 1) 2 1))
                          (t (error "NEW-TYPE has invalid value"))))
           (sub-type (nth 1 descriptor))
           (new-sub-type-val (cond
                              ((eq new-sub-type 1) 2)
                              ((eq new-sub-type 2) 1)
                              ((null sub-type) adoc-default-title-sub-type) ; there wasn't a sub-type before
                              ((not (or (eq sub-type 1) (eq sub-type 2)))
                               (error "Invalid title sub-type"))
                              ((eq new-sub-type nil) sub-type)
                              ((eq new-sub-type t) (if (eq sub-type 1) 2 1))
                              (t (error "NEW-SUB-TYPE has invalid value"))))
           (level (nth 2 descriptor))
           ;; One-line titles support six levels (0-5); two-line titles
           ;; only support as many levels as adoc-two-line-title-del has
           ;; entries (currently five, 0-4).
           (level-count (if (eq new-type-val 1)
                            (1+ adoc-title-max-level)
                          (length adoc-two-line-title-del)))
           (new-level (cond
                       ((or (null new-level-rel) (eq new-level-rel 0))
                        level)
                       (new-level-rel
                        (let ((new (adoc--check-level (+ level new-level-rel)
                                                      (1- level-count))))
                          (when (and (= new 0) (> level 0)
                                     (not (adoc--level-0-title-allowed-p)))
                            (user-error "Only the document title, or a part in a book, can be at level 0"))
                          new))
                       ((not (null new-level-abs))
                        new-level-abs)
                       (t
                        level)))
           (start (nth 4 descriptor))
           (end (nth 5 descriptor))
           (saved-col (current-column)))

      (when (eq new-type-val 2)
        (unless adoc-enable-two-line-title
          (user-error "Two-line titles are disabled, see `adoc-enable-two-line-title'"))
        (when (>= new-level level-count)
          (user-error "Two-line titles only support levels 0-%d" (1- level-count))))

      ;; set new title descriptor
      (setcar (nthcdr 0 descriptor) new-type-val)
      (setcar (nthcdr 1 descriptor) new-sub-type-val)
      (setcar (nthcdr 2 descriptor) new-level)

      ;; replace old title by new
      (let ((end-char (char-before end)))
        (beginning-of-line)
        (when (and (eq type 2) (looking-at (adoc-re-two-line-title-underline)))
          (forward-line -1)
          (beginning-of-line))
        (delete-region start end)
        (insert (adoc-make-title descriptor))
        (when (equal end-char ?\n)
          (insert  "\n")
          (forward-line -1)))

      ;; reposition point
      (when (and (eq new-type-val 2) (eq type 1))
        (forward-line -1))
      (move-to-column saved-col))))

;;;; Section auto-ids

;; Asciidoctor derives an id for every section from its title (unless
;; `sectids' is off).  These ids are what cross-references point at in
;; practice - far more often than explicit `[[id]]' anchors - so we generate
;; them and feed them to completion, the `xref' backend and
;; `adoc-goto-ref-label'.

;; Document attributes apply from the line that sets them on, so the scan
;; that works out the section ids keeps track of them in document order, as
;; Asciidoctor does.

(defconst adoc--re-attribute-entry-line
  "^:\\(!\\)?\\([[:alnum:]_][[:alnum:]_-]*\\)\\(!\\)?:\\(?:[ \t]+\\(.*?\\)\\)?[ \t]*$"
  "Regexp matching an attribute entry line.
Group 2 is the name and group 4 the value.  Group 1 or 3 matches the
`!' of an entry that unsets the attribute.")

(defconst adoc--builtin-attribute-values
  '(("amp" . "&") ("apos" . "&#39;") ("asterisk" . "*") ("backslash" . "\\")
    ("backtick" . "`") ("blank" . "") ("brvbar" . "&#166;") ("caret" . "^")
    ("cpp" . "C&#43;&#43;") ("deg" . "&#176;") ("empty" . "") ("endsb" . "]")
    ("gt" . ">") ("ldquo" . "&#8220;") ("lsquo" . "&#8216;") ("lt" . "<")
    ("nbsp" . "&#160;") ("plus" . "&#43;") ("pp" . "&#43;&#43;")
    ("quot" . "&#34;") ("rdquo" . "&#8221;") ("rsquo" . "&#8217;")
    ("sp" . " ") ("startsb" . "[") ("tilde" . "~") ("two-colons" . "::")
    ("two-semicolons" . ";;") ("vbar" . "|") ("wj" . "&#8288;")
    ("zwsp" . "&#8203;"))
  "Asciidoctor's built-in attributes that stand for a character.")

(defun adoc--in-verbatim-block-p (pos)
  "Return non-nil when POS is in the content of a verbatim delimited block.
That's a listing, literal, passthrough or comment block, whose content
isn't AsciiDoc."
  (let ((block (adoc--delimited-block-at pos)))
    (and block (nth 2 block) (> pos (nth 1 block)))))

(defun adoc--attribute-entries ()
  "Return the buffer's attribute entries as a list of (POSITION NAME VALUE).
NAME is downcased, as attribute names are case-insensitive, and VALUE
is nil for an entry that unsets the attribute.  A value continued on
the next line with a trailing ` \\' is joined up.  Entries in verbatim
blocks are just text, so they're left out."
  (let (entries)
    (save-excursion
      (save-match-data
        (goto-char (point-min))
        (while (re-search-forward adoc--re-attribute-entry-line nil t)
          (let ((pos (match-beginning 0))
                (name (downcase (match-string-no-properties 2)))
                (value (unless (or (match-beginning 1) (match-beginning 3))
                         (or (match-string-no-properties 4) ""))))
            (while (and value (string-suffix-p " \\" value)
                        (zerop (forward-line 1)) (not (eobp)))
              (setq value (concat (substring value 0 -1)
                                  (string-trim (buffer-substring-no-properties
                                                (point) (line-end-position))))))
            (unless (adoc--in-verbatim-block-p pos)
              (push (list pos name value) entries))))))
    (nreverse entries)))

(defun adoc--substitute-attributes (text attributes)
  "Replace the attribute references in TEXT with their values.
ATTRIBUTES is an alist of (NAME . VALUE) with downcased names, which
take precedence over Asciidoctor's built-in character attributes.  A
reference to an attribute that isn't set stays as it is, as Asciidoctor
leaves it by default, and an escaped one (`\\{name}') loses its
backslash."
  (if (not (string-search "{" text))
      text
    (replace-regexp-in-string
     "\\(\\\\\\)?{\\([[:alnum:]_][[:alnum:]_-]*\\)}"
     (lambda (ref)
       (let ((name (downcase (match-string 2 ref))))
         (cond
          ((match-beginning 1) (substring ref 1))
          ((cdr (or (assoc name attributes)
                    (assoc name adoc--builtin-attribute-values))))
          (t ref))))
     text t t)))

(defun adoc--apply-attribute-entry (entry attributes)
  "Return ATTRIBUTES, an alist of (NAME . VALUE), updated by attribute ENTRY.
ENTRY is one of the elements `adoc--attribute-entries' returns.  Its
value can refer to the attributes set before it."
  (let ((name (nth 1 entry))
        (value (nth 2 entry)))
    (setq attributes (assoc-delete-all name attributes))
    (if value
        (cons (cons name (adoc--substitute-attributes value attributes))
              attributes)
      attributes)))

(defun adoc--antora-p ()
  "Return non-nil when the buffer's file lives in an Antora component."
  (and buffer-file-name
       (locate-dominating-file buffer-file-name "antora.yml")
       t))

(defun adoc--section-id-params (attributes antora)
  "Return the (PREFIX . SEPARATOR) for section ids under ATTRIBUTES.
ATTRIBUTES is an alist of the document attributes in effect, and ANTORA
is non-nil when the buffer's file is in an Antora component.  The
document's `idprefix' and `idseparator' only count in the `auto' style
\(see `adoc-section-id-style'), and they default to Antora's in a
component.  Like Asciidoctor, only the first character of a longer
separator is used."
  (pcase adoc-section-id-style
    ('asciidoctor (cons "_" "_"))
    ('antora (cons "" "-"))
    (_ (let ((prefix (cdr (assoc "idprefix" attributes)))
             (separator (or (cdr (assoc "idseparator" attributes))
                            (if antora "-" "_"))))
         (cons (or prefix (if antora "" "_"))
               (substring separator 0 (min 1 (length separator))))))))

(defun adoc--link-macro-text (text)
  "Return the text a link or xref macro with attribute list TEXT shows.
That's TEXT itself unless it has named attributes, and then its first
positional attribute.  Return nil when there's none, as the macro shows
its target then."
  (cond
   ((string-empty-p text) nil)
   ((not (string-search "=" text)) text)
   ((string-match "\\`\"\\([^\"]*\\)\"" text) (match-string 1 text))
   (t (let ((first (car (split-string text ","))))
        (unless (string-search "=" first) first)))))

(defun adoc--section-title-text (title)
  "Return the text of section TITLE the way Asciidoctor renders it.
Only as far as it matters for its id, which is derived from the
rendered title with the markup taken out: link and xref macros give
their text, images and anchors nothing, a role list before quoted
text goes, emphasis loses its underscores, and the replacements for
the copyright sign, dashes, the ellipsis and arrows become entities.
Attribute references are expected to be substituted already."
  (if (not (string-match-p "[][+<>_(:.=-]" title))
      title                             ; nothing to render
    (adoc--render-section-title title)))

(defun adoc--render-section-title (title)
  "Do the work of `adoc--section-title-text' for TITLE."
  (let ((case-fold-search nil)
        (text title))
    ;; Raw HTML passes through, and the id leaves its tags out.
    (setq text (replace-regexp-in-string
                "\\+\\+\\+\\(.+?\\)\\+\\+\\+\\|pass:[a-z,]*\\[\\(.*?\\)\\]"
                (lambda (pass)
                  (let ((content (or (match-string 1 pass) (match-string 2 pass))))
                    (save-match-data
                      (replace-regexp-in-string "<[^>]+>" "" content))))
                text t t))
    (setq text (replace-regexp-in-string
                "\\[\\[[^]\n]*\\]\\]\\|anchor:[^ \t\n[]+\\[[^]\n]*\\]\\|image:[^ \t\n[]+\\[[^]\n]*\\]"
                "" text t t))
    (setq text (replace-regexp-in-string "<<[^,>\n]+,[ \t]*\\([^>\n]+\\)>>" "\\1" text t))
    (setq text (replace-regexp-in-string
                (concat "\\(link:\\|mailto:\\|xref:\\|" (regexp-opt adoc--url-schemes)
                        "://\\)\\([^][ \t\n]*\\)\\[\\([^]\n]*\\)\\]")
                (lambda (macro)
                  (let ((kind (match-string 1 macro))
                        (target (match-string 2 macro))
                        (label (match-string 3 macro)))
                    (save-match-data
                      (cond
                       ((adoc--link-macro-text label))
                       ((string-suffix-p "//" kind) (concat kind target))
                       ;; Asciidoctor shows the converted path of another
                       ;; document
                       ((equal kind "xref:")
                        (replace-regexp-in-string
                         "\\.adoc\\(?:#.*\\)?\\'" ".html" target))
                       (t target)))))
                text t t))
    ;; A role or other attribute list before quoted text: `[.role]#text#'.
    (setq text (replace-regexp-in-string
                "\\(^\\|[^[:alnum:]_;:}]\\)\\[[^]\n]*\\]\\([#*_`^~]\\)" "\\1\\2" text t))
    ;; Emphasis, the one kind of quoted text whose markup is a valid id
    ;; character.  Constrained emphasis needs no word character around it,
    ;; and as matching it uses up the character after it, it takes another
    ;; pass for each emphasized word that directly follows another.
    (setq text (replace-regexp-in-string "__\\(.+?\\)__" "\\1" text t))
    (let ((re (concat "\\(^\\|[^[:alnum:]_;:}]\\)_\\([^ \t\n]\\|[^ \t\n].*?[^ \t\n]\\)_"
                      "\\([^[:alnum:]_]\\|$\\)")))
      (while (string-match re text)
        (setq text (replace-match "\\1\\2\\3" t nil text))))
    ;; Replacements, except the ones that give an apostrophe, whose
    ;; characters the id drops anyway.
    (setq text (replace-regexp-in-string "\\(?:^\\| \\)--\\(?: \\|$\\)" "" text t t))
    (while (string-match "\\([[:alnum:]_]\\)--\\([[:alnum:]_]\\)" text)
      (setq text (replace-match "\\1\\2" t nil text)))
    (replace-regexp-in-string
     "\\(\\\\\\)?\\(([CR])\\|(TM)\\|\\.\\.\\.\\|->\\|=>\\|<-\\|<=\\)"
     (lambda (replacement)
       (if (match-beginning 1) (substring replacement 1) ""))
     text t t)))

(defun adoc--section-id (title prefix separator)
  "Return the Asciidoctor auto-id for the section titled TITLE.
PREFIX and SEPARATOR are the `idprefix' and `idseparator' to use, see
`adoc--section-id-params'.  Mirrors Asciidoctor's id generation: take
the rendered title (see `adoc--section-title-text'), downcase it, drop
entities and characters outside letters/digits/`_'/space/`.'/`-',
prepend the prefix, translate each run of space, `.', `-' and separator
characters to one separator, then drop a trailing separator, and a
leading one when there's no prefix."
  (let ((id (downcase (adoc--section-title-text title))))
    (setq id (replace-regexp-in-string
              "&\\(?:[a-z][a-z]+[0-9]\\{0,2\\}\\|#[0-9]\\{2,6\\}\\|#x[0-9a-f]\\{2,5\\}\\);"
              "" id t t))                ; entities
    (setq id (replace-regexp-in-string "[^[:alnum:]_ .-]" "" id)) ; invalid chars
    (setq id (concat prefix id))
    (if (string-empty-p separator)
        ;; An empty separator only deletes spaces; `.' and `-' are kept.
        (string-replace " " "" id)
      (setq id (replace-regexp-in-string
                (concat (regexp-opt-charset (string-to-list (concat " .-" separator)))
                        "+")
                separator id t t))
      (when (string-suffix-p separator id)
        (setq id (substring id 0 -1)))
      (if (and (string-empty-p prefix) (string-prefix-p separator id))
          (substring id 1)
        id))))

(defun adoc--section-explicit-id (descriptor)
  "Return the explicit id of the section title DESCRIPTOR describes, or nil.
That's a block anchor or id on the lines right above the title
\(`[[id]]', `[#id]'), or an anchor at the end of the title text.  A
section that has one gets no auto-id."
  (or (let ((text (nth 3 descriptor)))
        (when (string-match "\\[\\[\\([^],[:space:]]+\\)[^]]*\\]\\][ \t]*\\'" text)
          (substring-no-properties (match-string 1 text))))
      (save-excursion
        (goto-char (nth 4 descriptor))
        (let (id)
          (while (and (not id)
                      (zerop (forward-line -1))
                      (looking-at-p "\\[.*\\][ \t]*$"))
            (when (or (looking-at (adoc-re-anchor 'block-id))
                      (looking-at (adoc-re-anchor 'block-id-shorthand)))
              (setq id (match-string-no-properties 1))))
          id))))

(defun adoc--explicit-id-positions ()
  "Return (POSITION . ID) for the buffer's explicit ids, in document order.
That's block ids (`[[id]]', `[#id]') and inline anchors (`[[id]]',
`anchor:id[]') outside comments and verbatim blocks: the ids Asciidoctor
has registered by the time it reaches the section titles after them.
It's an approximation, as Asciidoctor registers an inline anchor in a
block title or a description list term, say, only later on."
  (let (ids)
    (save-excursion
      (save-match-data
        (pcase-dolist (`(,type . ,group) '((block-id . 1) (block-id-shorthand . 1)
                                           (inline-special . 2) (inline-general . 3)))
          (goto-char (point-min))
          (let ((re (adoc-re-anchor type)))
            (while (re-search-forward re nil t)
              (let ((pos (match-beginning 0))
                    ;; `inline-special' has `id,reftext' in its group
                    (id (car (split-string (match-string-no-properties group)
                                           "[ \t,]" t))))
                (unless (or (null id)
                            (adoc--in-verbatim-block-p pos)
                            ;; escaped, or the inside of a `[[[biblio]]]'
                            (memq (char-before pos) '(?\\ ?\[))
                            (save-excursion
                              (goto-char pos)
                              (beginning-of-line)
                              (looking-at-p "//\\(?:[^/]\\|$\\)")))
                  (push (cons pos id) ids))))))))
    (sort ids (lambda (a b) (< (car a) (car b))))))

(defun adoc--section-title-with-attributes (title attributes)
  "Return section TITLE with the document ATTRIBUTES in effect applied.
That's its attribute references substituted, and with `experimental'
set, the `kbd:' and `btn:' macros replaced by their text."
  (let ((text (adoc--substitute-attributes title attributes)))
    (if (assoc "experimental" attributes)
        (replace-regexp-in-string
         "\\(?:kbd\\|btn\\):\\[\\([^]\n]*\\)\\]" "\\1" text t)
      text)))

(defun adoc--unique-section-id (title params taken next)
  "Return the auto-id for TITLE with PARAMS, numbered if it's TAKEN.
PARAMS is (PREFIX . SEPARATOR).  TAKEN is a hash table of the ids in
use, and the first of `ID', `ID<separator>2', `ID<separator>3', ...
that isn't is returned, as Asciidoctor does.  NEXT is a hash table of
the number to try first for each ID, as the ones before it are taken."
  (let ((id (adoc--section-id title (car params) (cdr params))))
    (if (not (gethash id taken))
        id
      (let ((n (gethash id next 2))
            candidate)
        (while (gethash (setq candidate (concat id (cdr params) (number-to-string n)))
                        taken)
          (setq n (1+ n)))
        (puthash id (1+ n) next)
        candidate))))

(defvar-local adoc--section-table-cache nil
  "The last `adoc--section-table' as (KEY . TABLE), see there.")

(defun adoc--section-table ()
  "Return a list of (ID TITLE POSITION EXPLICIT) for the buffer's sections.
See `adoc--scan-sections'.  The ids depend on the document header and
the titles before them, so narrowing doesn't change them.  The table is
kept until the text of the buffer or a setting it depends on changes."
  (let ((key (list (buffer-chars-modified-tick) adoc-section-id-style
                   adoc-enable-two-line-title buffer-file-name)))
    (if (equal key (car adoc--section-table-cache))
        (cdr adoc--section-table-cache)
      (let ((table (save-restriction
                     (widen)
                     (adoc--scan-sections))))
        (setq adoc--section-table-cache (cons key table))
        table))))

(defun adoc--scan-sections ()
  "Return the sections of the buffer for `adoc--section-table'.
The list is in document order, with one element for each section title
font-lock actually fontifies as one, so `==' lines inside code or other
delimited blocks are skipped, and so is the document title.  ID is the
section's explicit id when EXPLICIT is non-nil, otherwise its auto-id,
or nil where `sectids' is unset.  The document attributes set above a
title apply to its auto-id: `idprefix', `idseparator' and `sectids', as
well as the ones it refers to.  An auto-id already taken by an earlier
section or explicit id gets a number appended, `_foo_2', `_foo_3' and
so on, as in Asciidoctor."
  (save-excursion
    (save-match-data
      (font-lock-ensure)
      (let ((re (adoc--re-all-titles))
            (antora (adoc--antora-p))
            (entries (adoc--attribute-entries))
            (anchors (adoc--explicit-id-positions))
            (taken (make-hash-table :test #'equal))
            (next (make-hash-table :test #'equal))
            ;; Asciidoctor sets `sectids' by default.
            (attributes (list (cons "sectids" "")))
            (result '()))
        (goto-char (point-min))
        (while (re-search-forward re nil t)
          (goto-char (match-beginning 0))
          (let ((descriptor (adoc--heading-descriptor-at-point)))
            (if (not descriptor)
                (forward-line 1)
              (let ((start (nth 4 descriptor)))
                (while (and entries (< (car (car entries)) start))
                  (setq attributes
                        (adoc--apply-attribute-entry (pop entries) attributes)))
                (while (and anchors (< (car (car anchors)) start))
                  (puthash (cdr (pop anchors)) t taken))
                ;; A level-0 title is the document title, not a section.
                (when (> (nth 2 descriptor) 0)
                  (let* ((explicit (adoc--section-explicit-id descriptor))
                         (title (string-trim (nth 3 descriptor)))
                         (id (or explicit
                                 (when (assoc "sectids" attributes)
                                   (adoc--unique-section-id
                                    (adoc--section-title-with-attributes
                                     title attributes)
                                    (adoc--section-id-params attributes antora)
                                    taken next)))))
                    (when id (puthash id t taken))
                    (push (list id title start (and explicit t)) result)))
                (goto-char (nth 5 descriptor))))))
        (nreverse result)))))

(defun adoc--collect-sections ()
  "Return a list of (ID TITLE POSITION) for the buffer's section auto-ids.
See `adoc--section-table'.  Sections with an explicit id have no
auto-id, as their anchors already define them."
  (let (sections)
    (pcase-dolist (`(,id ,title ,pos ,explicit) (adoc--section-table))
      (when (and id (not explicit))
        (push (list id title pos) sections)))
    (nreverse sections)))

(defun adoc--collect-section-ids ()
  "Return the auto-ids of the buffer's section titles."
  (mapcar #'car (adoc--collect-sections)))

(defun adoc--section-position (id)
  "Return the start position of the section matching ID, or nil.
A section matches when its auto-id equals ID or, for a natural
cross-reference, when its title does."
  (seq-some (lambda (s)
              (when (or (string= (nth 0 s) id)
                        (string= (nth 1 s) id))
                (nth 2 s)))
            (adoc--collect-sections)))

(defun adoc--section-definitions (id)
  "Return a list of xref items for sections matching ID (auto-id or title)."
  (let ((buffer (current-buffer)))
    (delq nil
          (mapcar (lambda (s)
                    (when (or (string= (nth 0 s) id)
                              (string= (nth 1 s) id))
                      (xref-make (nth 1 s)
                                 (xref-make-buffer-location buffer (nth 2 s)))))
                  (adoc--collect-sections)))))

(defun adoc--goto-id (id)
  "Move point to the anchor or section identified by ID in this buffer.
Search explicit anchors first (`[[id]]', `[#id]', ...), then fall back
to a section whose auto-id or title matches.  Return non-nil on success,
leaving point on the target; return nil and do not move otherwise.
Ids are case-sensitive, as in Asciidoctor."
  (let ((pos (or (save-excursion
                   (goto-char (point-min))
                   (let ((case-fold-search nil))
                     (re-search-forward (adoc-re-anchor nil id) nil t)))
                 (adoc--section-position id))))
    (when pos
      (goto-char pos)
      t)))

;;;; Antora cross-references

;; Antora lays a documentation component out as `<root>/antora.yml' plus
;; `<root>/modules/<module>/pages/...'.  Cross-references between pages use a
;; resource id - `xref:[module:]relative/path.adoc[#fragment][text]' - where
;; the path is relative to the target module's `pages' directory.  Resolution
;; here is intentionally limited to the current component (cross-component and
;; explicit `version@' targets need Antora's site catalog, which we lack).

(defun adoc--antora-root ()
  "Return the Antora component root (the dir holding `antora.yml'), or nil."
  (and buffer-file-name
       (locate-dominating-file buffer-file-name "antora.yml")))

(defun adoc--antora-current-module (root file)
  "Return the Antora module name FILE lives in, relative to ROOT, or nil."
  (let ((rel (file-relative-name file root)))
    (when (string-match "\\`modules/\\([^/]+\\)/" rel)
      (match-string 1 rel))))

(defun adoc--antora-resolve-page (target)
  "Resolve an Antora page xref TARGET to (FILE . FRAGMENT), or nil.
TARGET is the raw xref target, e.g. `basics/install.adoc#frag' or
`other-module:page.adoc'.  FRAGMENT is nil when none is given.  Returns
nil when the buffer is not in an Antora component or the target names a
different component (out of scope)."
  (let ((root (adoc--antora-root)))
    (when (and root buffer-file-name)
      (let ((module (adoc--antora-current-module root buffer-file-name))
            (coord target)
            (fragment nil))
        ;; Drop a leading `version@', but only when a module/component
        ;; coordinate follows (an `@' before the first `:') so a filename
        ;; that merely contains `@' is left intact.
        (let ((at (string-match "@" coord))
              (colon (string-match ":" coord)))
          (when (and at colon (< at colon))
            (setq coord (substring coord (1+ at)))))
        ;; Split off the `#fragment'; an empty fragment counts as none.
        (when (string-match "#" coord)
          (let ((frag (substring coord (1+ (match-beginning 0)))))
            (setq fragment (unless (string-empty-p frag) frag)
                  coord (substring coord 0 (match-beginning 0)))))
        (let* ((parts (split-string coord ":"))
               (path (pcase (length parts)
                       (1 (car parts))
                       (2 (setq module (car parts)) (cadr parts))
                       (_ nil))))           ; component:module:path -> out of scope
          (when (and path module)
            ;; Strip a leading family coordinate (e.g. `page$').
            (setq path (replace-regexp-in-string "\\`[a-z]+\\$" "" path))
            (cons (expand-file-name (concat "modules/" module "/pages/" path) root)
                  fragment)))))))

(defun adoc--antora-page-xref-at-point ()
  "Return the page-xref TARGET at point, or nil.
Only an `xref:' whose target names a `.adoc' page (as opposed to an
in-buffer id) qualifies."
  (save-excursion
    (let ((pos (point))
          (eol (line-end-position))
          (re (adoc-re-inline-macro "xref")))
      (beginning-of-line)
      (catch 'found
        (while (re-search-forward re eol t)
          (when (and (<= (match-beginning 0) pos) (<= pos (match-end 0)))
            (let ((target (match-string-no-properties 3)))
              (throw 'found
                     (and (string-match-p "\\.adoc\\(?:#\\|\\'\\)" target)
                          target)))))
        nil))))

(defun adoc--antora-page-targets ()
  "Return the component's pages as xref targets, or nil outside Antora.
Pages in the current module are listed by their path relative to that
module's `pages' directory; pages in other modules are prefixed with
`module:'."
  (let ((root (adoc--antora-root)))
    (when (and root buffer-file-name)
      (let ((current (adoc--antora-current-module root buffer-file-name))
            (modules-dir (expand-file-name "modules" root))
            (targets '()))
        (when (file-directory-p modules-dir)
          (dolist (mdir (directory-files modules-dir t "\\`[^.]"))
            (let ((pages (expand-file-name "pages" mdir)))
              (when (file-directory-p pages)
                (let ((module (file-name-nondirectory mdir)))
                  (dolist (file (directory-files-recursively pages "\\.adoc\\'"))
                    (let ((rel (file-relative-name file pages)))
                      ;; skip any dot-prefixed segment: lock files
                      ;; (`.#foo.adoc') and hidden dirs (`.git/...'), which
                      ;; Antora ignores
                      (unless (string-match-p "\\(?:\\`\\|/\\)\\." rel)
                        (push (if (equal module current) rel
                                (concat module ":" rel))
                              targets)))))))))
        (nreverse targets)))))

(defun adoc--antora-page-fragments (page)
  "Return the section ids and anchors defined in the xref target PAGE.
PAGE is an xref page target (e.g. `topic/p.adoc' or `mod:p.adoc')
resolved relative to the current buffer's Antora component."
  (let ((resolved (adoc--antora-resolve-page page)))
    (when (and resolved
               (file-exists-p (car resolved))
               (not (file-directory-p (car resolved))))
      (with-current-buffer (find-file-noselect (car resolved))
        (delete-dups (append (adoc--collect-anchor-ids)
                             (adoc--collect-section-ids)))))))

(defun adoc--antora-current-page-targets ()
  "Return the xref target form(s) other pages use to reference this page.
A list of the module-pages-relative path and its `module:'-qualified
form, or nil when the buffer is not a page in an Antora component."
  (let ((root (adoc--antora-root)))
    (when (and root buffer-file-name)
      (let* ((module (adoc--antora-current-module root buffer-file-name))
             (pages (and module
                         (expand-file-name (concat "modules/" module "/pages")
                                           root)))
             (rel (and pages (file-relative-name buffer-file-name pages))))
        (when (and rel (not (string-prefix-p ".." rel)))
          (list rel (concat module ":" rel)))))))

(defun adoc--antora-references (id)
  "Return cross-references to ID across the current Antora component.
Searches the component's `.adoc' files for same-page references
\(`<<id>>', `xref:id[]', `xref:#id[]') and cross-page references to this
page's id (`xref:this/page.adoc#id[]')."
  (let* ((root (adoc--antora-root))
         (qid (regexp-quote id))
         (targets (adoc--antora-current-page-targets))
         (same (concat "<<" qid "[,>]\\|xref:#?" qid "\\["))
         ;; A flat alternation (no shy group): `grep -E' under POSIX/GNU grep
         ;; rejects the `(?:...)' that a shy group would translate to.
         (cross (when targets
                  (mapconcat (lambda (target)
                               (concat "xref:" (regexp-quote target) "#" qid "\\["))
                             targets "\\|")))
         (regexp (if cross (concat same "\\|" cross) same))
         ;; ids are case-sensitive (this also keeps grep from using -i)
         (case-fold-search nil))
    (xref-matches-in-directory regexp "*.adoc" root nil)))

(defun adoc--completion-xref-target-bounds ()
  "Return (START . END) of the `xref:' target text up to point, or nil.
Only matches when point is within the target portion of an `xref:'
macro (after `xref:', before the `[' or any whitespace)."
  (save-excursion
    (let ((pos (point))
          (bol (line-beginning-position)))
      (when (re-search-backward "xref:" bol t)
        (let ((start (match-end 0)))
          (when (and (<= start pos)
                     (not (save-excursion
                            (goto-char start)
                            (re-search-forward "[][ \t]" pos t))))
            (cons start pos)))))))

;;;; Completion

(defconst adoc-intrinsic-attributes
  '("doctitle" "author" "authorinitials" "firstname" "middlename" "lastname"
    "email" "revnumber" "revdate" "revremark" "docdate" "doctime" "docdatetime"
    "localdate" "localtime" "localdatetime" "sectnums" "sectnumlevels"
    "sectlinks" "sectanchors" "toc" "toclevels" "toc-title" "icons" "iconfont"
    "experimental" "nofooter" "noheader" "source-highlighter" "imagesdir"
    "iconsdir" "stylesheet" "stylesdir" "linkcss" "data-uri" "idprefix"
    "idseparator" "leveloffset" "tabsize" "version-label" "lang" "encoding")
  "Common intrinsic AsciiDoc attribute names offered for completion.
These supplement the attributes actually defined in the buffer.")

(defconst adoc--completion-common-langs
  '("c" "clojure" "cpp" "csharp" "css" "diff" "elixir" "emacs-lisp" "erlang"
    "go" "groovy" "haskell" "html" "java" "javascript" "json" "kotlin" "lua"
    "ocaml" "perl" "php" "python" "ruby" "rust" "scala" "sh" "shell" "sql"
    "swift" "toml" "typescript" "xml" "yaml")
  "Common source-block language names offered for completion.")

(defun adoc--collect-anchor-ids ()
  "Return a list of the explicit anchor ids defined in the buffer.
Scans for block ids (`[[id]]', `[#id]'), inline anchors
\(`[[id,reftext]]') and bibliography anchors (`[[[ref]]]').  Computed
section auto-ids are intentionally not included."
  (let ((ids '()))
    (save-excursion
      (save-match-data
        ;; block-id and block-id-shorthand expose the bare id in group 1.
        (dolist (type '(block-id block-id-shorthand))
          (goto-char (point-min))
          (let ((re (adoc-re-anchor type)))
            (while (re-search-forward re nil t)
              (push (match-string-no-properties 1) ids))))
        ;; inline-special is `[[id,reftext]]'; group 2 is `id,reftext'.
        (goto-char (point-min))
        (let ((re (adoc-re-anchor 'inline-special)))
          (while (re-search-forward re nil t)
            (let ((attrlist (match-string-no-properties 2)))
              (push (car (split-string attrlist "[ \t,]" t)) ids))))
        ;; biblio is `[[[ref]]]'; group 2 is `[ref]'.
        (goto-char (point-min))
        (let ((re (adoc-re-anchor 'biblio)))
          (while (re-search-forward re nil t)
            (push (string-trim (match-string-no-properties 2) "\\[" "\\]")
                  ids)))))
    (delete-dups (delq nil ids))))

(defun adoc--collect-attribute-names ()
  "Return attribute names for completion.
The union of the attributes defined in the buffer (`:name:' entries)
and `adoc-intrinsic-attributes'."
  (let ((names (copy-sequence adoc-intrinsic-attributes)))
    (save-excursion
      (save-match-data
        (goto-char (point-min))
        (let ((re (adoc-re-attribute-entry)))
          (while (re-search-forward re nil t)
            ;; Group 1 is `:name[.subname]:' (optionally `:!name:' to unset).
            ;; The bare name is the first run of id chars after the leading
            ;; colon, stopping before any `.subname' or the closing colon.
            (let ((raw (match-string-no-properties 1)))
              (when (string-match ":!?\\([-a-zA-Z0-9_]+\\)" raw)
                (push (match-string 1 raw) names)))))))
    (delete-dups names)))

(defun adoc--completion-langs ()
  "Return the source-block language names offered for completion."
  (delete-dups
   (append (mapcar #'car adoc-code-lang-modes)
           adoc--completion-common-langs)))

(defun adoc--completion-token-bounds (&optional chars)
  "Return the bounds (START . END) of the token around point.
CHARS is the `skip-chars-backward' set delimiting the token; it
defaults to the id characters allowed in attribute names and the like."
  (save-excursion
    (let ((end (point))
          (start (progn (skip-chars-backward (or chars "-a-zA-Z0-9_"))
                        (point))))
      (cons start end))))

(defun adoc--completion-xref-bounds ()
  "Return token bounds when point is inside an unclosed xref reference.
Handles both the `<<id' and `xref:id' forms.  Returns nil otherwise."
  (let ((line-start (line-beginning-position))
        (orig (point)))
    (save-excursion
      (when (or
             ;; `<<' not yet closed by `>>', point before any `,'.
             (save-excursion
               (and (re-search-backward "<<" line-start t)
                    (goto-char (match-end 0))
                    (not (re-search-forward "\\(>>\\|,\\)" orig t))))
             ;; `xref:' target, point before the `[' or `,'.
             (save-excursion
               (and (re-search-backward "xref:" line-start t)
                    (goto-char (match-end 0))
                    (not (re-search-forward "[][,]" orig t)))))
        ;; Anchor ids may contain `.' (biblio / inline anchors), so include
        ;; it in the token even though `adoc-re-id' itself is narrower.
        (adoc--completion-token-bounds "-a-zA-Z0-9_.")))))

(defun adoc--completion-attribute-bounds ()
  "Return token bounds when point is inside an unclosed `{' reference.
Returns nil otherwise."
  (let ((line-start (line-beginning-position))
        (orig (point)))
    (save-excursion
      (when (save-excursion
              (and (re-search-backward "{" line-start t)
                   (goto-char (match-end 0))
                   (not (re-search-forward "[{}]" orig t))))
        (adoc--completion-token-bounds)))))

(defun adoc--completion-include-bounds ()
  "Return path bounds when point is inside an `include::' target.
Returns nil otherwise."
  (save-excursion
    (let ((bol (line-beginning-position))
          (pos (point)))
      (goto-char bol)
      (when (and (looking-at "include1?::")
                 (<= (match-end 0) pos))
        (let ((start (match-end 0)))
          (goto-char start)
          (unless (re-search-forward "\\[" pos t)
            (cons start pos)))))))

(defun adoc--completion-source-lang-bounds ()
  "Return language-token bounds when point is in a `[source,LANG' field.
Returns nil otherwise."
  (save-excursion
    (let ((bol (line-beginning-position))
          (pos (point)))
      (goto-char bol)
      (when (and (looking-at "\\[source,[ \t]*")
                 (<= (match-end 0) pos))
        (let ((start (match-end 0)))
          (goto-char start)
          (unless (re-search-forward "[],]" pos t)
            (cons start pos)))))))

(defun adoc-completion-at-point ()
  "Complete the AsciiDoc construct at point.
A `completion-at-point-functions' entry that offers candidates for
cross-reference / anchor ids inside `<<' and `xref:', attribute names
inside `{', file paths after `include::', and source-block languages
inside `[source,'."
  (let (bounds)
    (cond
     ;; An unclosed `{' means an attribute reference, even when it sits inside
     ;; an xref target or a `[source,' field, so check it first.
     ((setq bounds (adoc--completion-attribute-bounds))
      (list (car bounds) (cdr bounds)
            (completion-table-dynamic
             (lambda (_) (adoc--collect-attribute-names)))
            :annotation-function (lambda (_) " attribute")
            :company-kind (lambda (_) 'variable)
            :exclusive 'no))
     ;; Antora `xref:' target - complete page paths, and section ids/anchors
     ;; after a `#fragment'.  Falls through to the generic xref branch outside
     ;; an Antora component.
     ((and (adoc--antora-root)
           (setq bounds (adoc--completion-xref-target-bounds)))
      (let* ((start (car bounds))
             (end (cdr bounds))
             (text (buffer-substring-no-properties start end))
             (hash (string-match "#" text)))
        (if hash
            (let ((page (substring text 0 hash)))
              (list (+ start hash 1) end
                    (completion-table-dynamic
                     (lambda (_)
                       ;; an empty page (`xref:#frag') is a same-page
                       ;; reference - complete against this buffer
                       (if (string-empty-p page)
                           (delete-dups (append (adoc--collect-anchor-ids)
                                                (adoc--collect-section-ids)))
                         (adoc--antora-page-fragments page))))
                    :annotation-function (lambda (_) " section")
                    :company-kind (lambda (_) 'reference)
                    :exclusive 'no))
          (list start end
                (completion-table-dynamic
                 (lambda (_) (append (adoc--antora-page-targets)
                                     (adoc--collect-anchor-ids)
                                     (adoc--collect-section-ids))))
                :annotation-function (lambda (_) " page")
                :company-kind (lambda (_) 'file)
                :exclusive 'no))))
     ((setq bounds (adoc--completion-xref-bounds))
      (list (car bounds) (cdr bounds)
            (completion-table-dynamic
             (lambda (_) (delete-dups (append (adoc--collect-anchor-ids)
                                              (adoc--collect-section-ids)))))
            :annotation-function (lambda (_) " anchor")
            :company-kind (lambda (_) 'reference)
            :exclusive 'no))
     ((setq bounds (adoc--completion-source-lang-bounds))
      (list (car bounds) (cdr bounds)
            (completion-table-dynamic
             (lambda (_) (adoc--completion-langs)))
            :annotation-function (lambda (_) " lang")
            :company-kind (lambda (_) 'enum)
            :exclusive 'no))
     ((setq bounds (adoc--completion-include-bounds))
      (list (car bounds) (cdr bounds)
            #'completion-file-name-table
            :annotation-function (lambda (_) " file")
            :company-kind (lambda (_) 'file)
            :exclusive 'no)))))

;;;; xref backend

;; A single-buffer `xref' backend over AsciiDoc anchors: definitions are
;; anchors (`[[id]]', `[#id]', `[[[biblio]]]') and references are the xrefs
;; that point at them (`<<id>>', `<<id,text>>', `xref:id[...]').  Registering
;; it lights up `M-?' (`xref-find-references') and the xref marker stack;
;; `M-.' stays on `adoc-follow-thing-at-point' (which also follows URLs and
;; `include::').

(defun adoc--xref-backend ()
  "Return the `xref' backend for `adoc-mode'."
  'adoc)

(defun adoc--anchor-id-at-point ()
  "Return the id of the anchor definition point is on, or nil."
  (save-excursion
    (let ((pos (point))
          (eol (line-end-position))
          (found nil))
      (beginning-of-line)
      (dolist (type '(block-id block-id-shorthand inline-special biblio) found)
        (unless found
          (save-excursion
            (let ((re (adoc-re-anchor type)))
              (while (and (not found) (re-search-forward re eol t))
                (when (and (<= (match-beginning 0) pos) (<= pos (match-end 0)))
                  (setq found
                        (pcase type
                          ((or 'block-id 'block-id-shorthand)
                           (match-string-no-properties 1))
                          ('inline-special
                           (car (split-string (match-string-no-properties 2)
                                               "[ \t,]" t)))
                          ('biblio
                           (string-trim (match-string-no-properties 2)
                                        "\\[" "\\]"))))))))))) ))

(defun adoc--re-xref-to (id)
  "Return a regexp matching a cross-reference to the anchor ID.
Trailing whitespace is tolerated after the id (as in `<<foo >>'), the
same way `adoc-re-xref' permits it."
  (let ((q (regexp-quote id)))
    (concat "<<" q "[ \t\n]*\\(?:,\\|>>\\)\\|xref:#?" q "\\[")))

(defun adoc--xref-collect (regexp)
  "Return a list of xref items, one per match of REGEXP in the buffer.
Each item's summary is the matched line; its location is the start of
the match.  The search is case-sensitive, like ids."
  (let ((buffer (current-buffer))
        (case-fold-search nil)
        (items '()))
    (save-excursion
      (save-match-data
        (goto-char (point-min))
        (while (re-search-forward regexp nil t)
          (let ((pos (match-beginning 0))
                (summary (buffer-substring-no-properties
                          (line-beginning-position) (line-end-position))))
            (push (xref-make (string-trim summary)
                             (xref-make-buffer-location buffer pos))
                  items)))))
    (nreverse items)))

(defun adoc--section-id-at-point ()
  "Return the id of the section title point is on, or nil.
That's its explicit id, or else its auto-id.  The document title isn't
a section, so it has none."
  (when (adoc-title-descriptor)         ; cheap, before fontifying
    (font-lock-ensure)
    (let ((descriptor (adoc--heading-descriptor-at-point)))
      (when (and descriptor (> (nth 2 descriptor) 0))
        (or (adoc--section-explicit-id descriptor)
            (car (cl-find (nth 4 descriptor) (adoc--section-table)
                          :key #'caddr)))))))

(cl-defmethod xref-backend-identifier-at-point ((_backend (eql adoc)))
  (or (adoc-xref-id-at-point)
      (adoc--anchor-id-at-point)
      (adoc--section-id-at-point)))

(cl-defmethod xref-backend-identifier-completion-table ((_backend (eql adoc)))
  (delete-dups (append (adoc--collect-anchor-ids) (adoc--collect-section-ids))))

(cl-defmethod xref-backend-definitions ((_backend (eql adoc)) identifier)
  (append (adoc--xref-collect (adoc-re-anchor nil identifier))
          (adoc--section-definitions identifier)))

(cl-defmethod xref-backend-references ((_backend (eql adoc)) identifier)
  ;; In an Antora component search the whole component (so cross-page
  ;; references show up); otherwise stay within the current buffer.
  (if (adoc--antora-root)
      (adoc--antora-references identifier)
    (adoc--xref-collect (adoc--re-xref-to identifier))))

(cl-defmethod xref-backend-apropos ((_backend (eql adoc)) pattern)
  (require 'apropos)                    ; for `apropos-parse-pattern'
  (let ((re (xref-apropos-regexp pattern)))
    (cl-loop for id in (adoc--collect-anchor-ids)
             when (string-match-p re id)
             append (adoc--xref-collect (adoc-re-anchor nil id)))))

;;;; Heading navigation

(defun adoc--re-all-titles ()
  "Return a regexp matching any section title.
Two-line (setext) titles are only included when
`adoc-enable-two-line-title' is non-nil, mirroring fontification -
otherwise a line of body text followed by a delimited-block line
\(e.g. `----') would be mistaken for a two-line title underline."
  (let* ((two-line-count (if adoc-enable-two-line-title
                             (length adoc-two-line-title-del)
                           0))
         (core
          (mapconcat
           (lambda (level)
             (if (< level two-line-count)
                 (concat
                  (adoc-re-one-line-title level)
                  "\\|"
                  (adoc-re-two-line-title (nth level adoc-two-line-title-del)))
               (adoc-re-one-line-title level)))
           (number-sequence 0 adoc-title-max-level)
           "\\)\\|\\(?:")))
    (concat "\\(?:" core "\\)")))

(defconst adoc--title-faces
  '(adoc-title-0-face adoc-title-1-face adoc-title-2-face
    adoc-title-3-face adoc-title-4-face adoc-title-5-face)
  "The faces font-lock applies to the text of a section title.")

(defun adoc--face-memq (faces value)
  "Return non-nil when the `face' text-property VALUE includes a FACES member.
VALUE may be a face symbol, an anonymous face spec, or a list of
either."
  (cond ((symbolp value) (memq value faces))
        ((listp value) (cl-some (lambda (v) (adoc--face-memq faces v)) value))))

(defun adoc--fontified-as-title-p (start end)
  "Return non-nil when font-lock fontified START..END as a section title.
Navigation and imenu use this so that they agree with what is
highlighted: a `==' line inside a code or other delimited block, and
a two-line title when `adoc-enable-two-line-title' is disabled, are
not fontified as titles and so are not treated as headings.  The
region must already be fontified - the heading-navigation commands
and `adoc-imenu-create-index' call `font-lock-ensure' first.

For a one-line title the leading delimiter at START carries
`adoc-meta-hide-face'.  Inline markup in the title text does not
touch that delimiter, so a title made entirely of a macro is still
recognised.  The title keywords skip the inside of delimited blocks
\(see `adoc--outside-delimited-block-p'), so a `==' line there never
gets that face.  A two-line title has no such delimiter, so fall back
to looking for a title face on its text."
  (or (adoc--face-memq '(adoc-meta-hide-face) (get-text-property start 'face))
      (let ((pos start) found)
        (while (and (not found) (< pos end))
          (when (adoc--face-memq adoc--title-faces (get-text-property pos 'face))
            (setq found t))
          (setq pos (next-single-property-change pos 'face nil end)))
        found)))

(defun adoc--heading-descriptor-at-point ()
  "Return the title descriptor at point when it is a navigable heading.
Like `adoc-title-descriptor', but only accepts a match that
font-lock actually fontified as a section title (see
`adoc--fontified-as-title-p'), keeping navigation in step with the
highlighting."
  (let ((descriptor (adoc-title-descriptor)))
    (when (and descriptor
               (adoc--fontified-as-title-p (nth 4 descriptor) (nth 5 descriptor)))
      descriptor)))

(defun adoc--title-bounds ()
  "Return (LEVEL START END) when point is on a section title, else nil.
START and END delimit the whole title (both lines for a two-line
title); point need not be on the first line."
  (let ((descriptor (adoc--heading-descriptor-at-point)))
    (when descriptor
      (list (nth 2 descriptor) (nth 4 descriptor) (nth 5 descriptor)))))

(defun adoc--forward-heading ()
  "Move point to the start of the next section title.
Return the title's level, or nil if there is no following title.
Point is left unchanged when nil is returned."
  (let ((bounds (adoc--title-bounds))
        (re (adoc--re-all-titles))
        (orig (point))
        level)
    ;; If we're on a title, step past it so we don't match it again.
    (when bounds (goto-char (nth 2 bounds)))
    (while (and (not level) (re-search-forward re nil t))
      (goto-char (match-beginning 0))
      (let ((descriptor (adoc--heading-descriptor-at-point)))
        (if descriptor
            (setq level (nth 2 descriptor))
          ;; A regexp match the descriptor rejects (e.g. a code line
          ;; inside a listing block); skip the line and retry.
          (forward-line 1))))
    (unless level (goto-char orig))
    level))

(defun adoc--backward-heading ()
  "Move point to the start of the previous section title.
Return the title's level, or nil if there is no preceding title.
Point is left unchanged when nil is returned."
  (let ((bounds (adoc--title-bounds))
        (re (adoc--re-all-titles))
        (orig (point))
        level)
    (when bounds (goto-char (nth 1 bounds)))
    (while (and (not level) (re-search-backward re nil t))
      (goto-char (match-beginning 0))
      (let ((descriptor (adoc--heading-descriptor-at-point)))
        (when descriptor (setq level (nth 2 descriptor)))))
    (unless level (goto-char orig))
    level))

(defun adoc--back-to-heading ()
  "Move to the title heading the section point is in, return its level.
Signal a `user-error' when point is before the first section title."
  (let ((bounds (adoc--title-bounds)))
    (cond
     (bounds (goto-char (nth 1 bounds)) (car bounds))
     (t (let ((level (adoc--backward-heading)))
          (unless level (user-error "Before first section title"))
          level)))))

(defun adoc-next-visible-heading (arg)
  "Move forward to the ARGth next visible section title.
With a negative ARG, move backward (see
`adoc-previous-visible-heading')."
  (interactive "p")
  (if (< arg 0)
      (adoc-previous-visible-heading (- arg))
    ;; Fontify first so `adoc--fontified-as-title-p' can tell real
    ;; titles from title-looking lines inside code or other blocks.
    (font-lock-ensure)
    (let ((orig (point))
          level)
      (dotimes (_ arg)
        (while (and (setq level (adoc--forward-heading))
                    (invisible-p (point))))
        (unless level
          (goto-char orig)
          (user-error "No following section title"))))))

(defun adoc-previous-visible-heading (arg)
  "Move backward to the ARGth previous visible section title.
With a negative ARG, move forward (see
`adoc-next-visible-heading')."
  (interactive "p")
  (if (< arg 0)
      (adoc-next-visible-heading (- arg))
    (font-lock-ensure)
    (let ((orig (point))
          level)
      (dotimes (_ arg)
        (while (and (setq level (adoc--backward-heading))
                    (invisible-p (point))))
        (unless level
          (goto-char orig)
          (user-error "No preceding section title"))))))

(defun adoc-forward-same-level (arg)
  "Move forward to the ARGth next visible title at the same level.
A title at a shallower (more important) level or the end of the
buffer stops the search.  With a negative ARG, move backward."
  (interactive "p")
  (if (< arg 0)
      (adoc-backward-same-level (- arg))
    (font-lock-ensure)
    (let ((orig (point))
          (level (adoc--back-to-heading)))
      (dotimes (_ arg)
        (let (target stop found)
          (while (and (not target) (not stop)
                      (setq found (adoc--forward-heading)))
            (cond
             ((< found level) (setq stop t))
             ((and (= found level) (not (invisible-p (point))))
              (setq target (point)))))
          (unless target
            (goto-char orig)
            (user-error "No following same-level section title")))))))

(defun adoc-backward-same-level (arg)
  "Move backward to the ARGth previous visible title at the same level.
A title at a shallower (more important) level or the start of the
buffer stops the search.  With a negative ARG, move forward."
  (interactive "p")
  (if (< arg 0)
      (adoc-forward-same-level (- arg))
    (font-lock-ensure)
    (let ((orig (point))
          (level (adoc--back-to-heading)))
      (dotimes (_ arg)
        (let (target stop found)
          (while (and (not target) (not stop)
                      (setq found (adoc--backward-heading)))
            (cond
             ((< found level) (setq stop t))
             ((and (= found level) (not (invisible-p (point))))
              (setq target (point)))))
          (unless target
            (goto-char orig)
            (user-error "No preceding same-level section title")))))))

(defun adoc-up-heading (arg)
  "Move to the visible parent title, ARG levels up."
  (interactive "p")
  (font-lock-ensure)
  (let ((orig (point))
        (level (adoc--back-to-heading)))
    (dotimes (_ arg)
      (let (target found)
        (while (and (not target)
                    (setq found (adoc--backward-heading)))
          (when (and (< found level) (not (invisible-p (point))))
            (setq target (point)
                  level found)))
        (unless target
          (goto-char orig)
          (user-error "No parent section title"))))))

;;;; Outline cycling

(defun adoc--outline-search (&optional bound move backward looking-at)
  "Search for the next section title, for `outline-search-function'.
That's the next match of `outline-regexp' at the beginning of a line,
like `outline-minor-mode' does without this function, except that lines
inside delimited blocks don't count.  BOUND, MOVE, BACKWARD and
LOOKING-AT are as in `outline-search-function'."
  (if looking-at
      (and (looking-at outline-regexp)
           (not (adoc--delimited-block-at (point))))
    (let ((regexp (concat "^\\(?:" outline-regexp "\\)"))
          (limit (or bound (if backward (point-min) (point-max))))
          (origin (point))
          (more t)
          found)
      (while (and more
                  (if backward
                      (re-search-backward regexp limit t)
                    (re-search-forward regexp limit t)))
        (let ((block (adoc--delimited-block-at (match-beginning 0))))
          (if (not block)
              (setq found t more nil)
            ;; Carry on past the block, none of its lines can be a title.
            (let* ((outer (adoc--outermost-block block))
                   (next (if backward (car outer) (nth 3 outer))))
              (if (if backward (> next limit) (< next limit))
                  (goto-char next)
                (setq more nil))))))
      (unless found
        (goto-char (if move limit origin)))
      found)))

(defun adoc-cycle (&optional arg)
  "Cycle the visibility of the section subtree at point.
On a section title, rotate its subtree between folded, child
titles only, and fully shown (via `outline-cycle').  Off a title,
indent or insert a tab as usual.  With a prefix ARG, cycle the
visibility of the whole buffer instead (see `adoc-cycle-buffer').

Only one-line titles (e.g. `== Title') are recognised by the
underlying `outline-minor-mode'."
  (interactive "P")
  (cond
   (arg (adoc-cycle-buffer))
   ;; Emacs 28 has no `outline-search-function', so check for a block here.
   ((and (outline-on-heading-p)
         (not (adoc--delimited-block-at (line-beginning-position))))
    (outline-cycle))
   (t (indent-for-tab-command))))

(defun adoc-cycle-buffer ()
  "Cycle the visibility of all section titles in the buffer.
Rotate between an overview (top-level titles only), a table of
contents (all titles, no bodies), and the fully expanded buffer
\(via `outline-cycle-buffer')."
  (interactive)
  (outline-cycle-buffer))

;;;; Text styling

(defun adoc--insert-markup (left right)
  "Wrap the active region or the word at point with LEFT and RIGHT.
If the region (or word) is already wrapped with those delimiters,
remove them instead, so the command toggles the markup off.  With
no region and no word at point, insert the delimiters and leave
point between them."
  (let ((ll (length left))
        (rl (length right)))
    (cond
     ((use-region-p)
      (let ((beg (region-beginning))
            (end (region-end)))
        (cond
         ;; Delimiters sit just outside the region: unwrap them.
         ((and (>= (- beg ll) (point-min))
               (<= (+ end rl) (point-max))
               (string= (buffer-substring-no-properties (- beg ll) beg) left)
               (string= (buffer-substring-no-properties end (+ end rl)) right))
          (delete-region end (+ end rl))
          (delete-region (- beg ll) beg)
          (goto-char (- end ll)))
         ;; Delimiters sit just inside the region: unwrap them.
         ((and (>= (- end beg) (+ ll rl))
               (string= (buffer-substring-no-properties beg (+ beg ll)) left)
               (string= (buffer-substring-no-properties (- end rl) end) right))
          (delete-region (- end rl) end)
          (delete-region beg (+ beg ll))
          (goto-char (- end ll rl)))
         (t
          (goto-char end)
          (insert right)
          (goto-char beg)
          (insert left)
          (goto-char (+ end ll rl))))))
     ((thing-at-point 'word)
      (let* ((bounds (bounds-of-thing-at-point 'word))
             (beg (car bounds))
             (end (cdr bounds)))
        (goto-char end)
        (insert right)
        (goto-char beg)
        (insert left)
        (goto-char (+ end ll rl))))
     (t
      (insert left right)
      (backward-char rl)))))

(defun adoc-insert-bold ()
  "Make the region or word at point bold (`*text*'), or toggle it off."
  (interactive)
  (adoc--insert-markup "*" "*"))

(defun adoc-insert-italic ()
  "Emphasise the region or word at point (`_text_'), or toggle it off."
  (interactive)
  (adoc--insert-markup "_" "_"))

(defun adoc-insert-monospace ()
  "Make the region or word at point monospaced (\\=`text\\=`), or toggle it off."
  (interactive)
  (adoc--insert-markup "`" "`"))

(defun adoc-insert-highlight ()
  "Highlight the region or word at point (`#text#'), or toggle it off."
  (interactive)
  (adoc--insert-markup "#" "#"))

(defun adoc-insert-superscript ()
  "Superscript the region or word at point (`^text^'), or toggle it off."
  (interactive)
  (adoc--insert-markup "^" "^"))

(defun adoc-insert-subscript ()
  "Subscript the region or word at point (`~text~'), or toggle it off."
  (interactive)
  (adoc--insert-markup "~" "~"))

(defun adoc-insert-link (url &optional text)
  "Insert an AsciiDoc link to URL labelled TEXT.
Interactively, prompt for both; an active region supplies the
default link text and is replaced by the link.  When TEXT is
empty, a bare URL is inserted."
  (interactive
   (let ((region (when (use-region-p)
                   (buffer-substring-no-properties
                    (region-beginning) (region-end)))))
     (list (read-string "URL: ")
           (read-string "Link text: " region))))
  (when (use-region-p)
    (delete-region (region-beginning) (region-end)))
  (insert url)
  (when (and text (> (length text) 0))
    (insert "[" text "]")))

(defvar adoc-style-map
  (let ((map (make-sparse-keymap)))
    (define-key map "b" 'adoc-insert-bold)
    (define-key map "i" 'adoc-insert-italic)
    (define-key map "m" 'adoc-insert-monospace)
    (define-key map "h" 'adoc-insert-highlight)
    (define-key map "l" 'adoc-insert-link)
    (define-key map "^" 'adoc-insert-superscript)
    (define-key map "~" 'adoc-insert-subscript)
    map)
  "Keymap for AsciiDoc text-styling commands, bound to \\`C-c C-s'.")

(defvar sgml-char-names)

(defun adoc-make-unichar-alist ()
  "Create `adoc-unichar-alist' from the built-in `sgml-char-names'."
  (require 'sgml-mode)
  (setq adoc-unichar-alist nil)
  (dotimes (i (length sgml-char-names))
    (when (aref sgml-char-names i)
      (push (cons (aref sgml-char-names i) i) adoc-unichar-alist))))

(defun adoc-unichar-by-name (name)
  "Return unicode codepoint of char with the given NAME."
  (cdr (assoc name adoc-unichar-alist)))

(defun adoc-entity-to-string (entity)
  "Returns a string containing the character referenced by ENTITY.

ENTITY is a string containing a character entity reference like
e.g. '&#38;' or '&amp;'. nil is returned if its an invalid
entity, or when customizations prevent `adoc-entity-to-string' from
knowing it. E.g. when `adoc-unichar-name-resolver' is nil."
  (save-match-data
    (let (ch)
      (setq ch
            (cond
             ;; hex
             ((string-match "&#x\\([0-9a-fA-F]+?\\);" entity)
              (string-to-number (match-string 1 entity) 16))
             ;; dec
             ((string-match "&#\\([0-9]+?\\);" entity)
              (string-to-number (match-string 1 entity)))
             ;; name
             ((and adoc-unichar-name-resolver
                   (string-match "&\\(.+?\\);" entity))
              (funcall adoc-unichar-name-resolver
                       (match-string 1 entity)))))
      (when (characterp ch) (make-string 1 ch)))))

(defun adoc-face-for-attribute (pos-or-name &optional attribute-list-prop-val)
  "Returns the face to be used for the given attribute.

The face to be used is looked up in `adoc-attribute-face-alist',
unless that alist is overwritten by the content of
ATTRIBUTE-LIST-PROP-VAL.

POS-OR-NAME identifies the attribute for which the face is
returned. When POS-OR-NAME satisfies numberp, it is the number of
the positional attribute, where as the first positinal attribute
has position 0. Otherwise POS-OR-NAME is the name of the named
attribute.

The value of ATTRIBUTE-LIST-PROP-VAL is one of the following:
- nil
- FACE
- POS-TO-NAME
- (POS-TO-NAME LOCAL-ATTRIBUTE-FACE-ALIST)

POS-TO-NAME is a list of strings mapping positions to attribute
names. E.g. (\"foo\" \"bar\") means that the first positional
attribute corresponds to the named attribute foo, and the 2nd
positional attribute corresponds to the named attribute bar.

FACE is something that satisfies facep; in that case the whole
attribute list is fontified with that face. However that case is
handled outside this function.

An attribute name is first looked up in
LOCAL-ATTRIBUTE-FACE-ALIST before it is looked up in
`adoc-attribute-face-alist'."
  (let* ((has-pos-to-name (listp attribute-list-prop-val))
         (has-local-alist (and has-pos-to-name (listp (car-safe attribute-list-prop-val))))
         (pos-to-name (cond ((not has-pos-to-name) nil)
                            (has-local-alist (car attribute-list-prop-val))
                            (t attribute-list-prop-val)))
         (local-attribute-face-alist (when has-local-alist (cadr attribute-list-prop-val)))
         (name (cond ((stringp pos-or-name) pos-or-name)
                     ((numberp pos-or-name) (nth pos-or-name pos-to-name)))))
    (or (when name (or (cdr (assoc name local-attribute-face-alist))
                       (cdr (assoc name adoc-attribute-face-alist))))
        'adoc-value-face)))

(defun adoc-imenu-create-index ()
  (let* ((index-alist)
         (re-all-titles (adoc--re-all-titles)))
    (save-restriction
      (widen)
      ;; Fontify so we can skip title-looking lines inside code blocks.
      (font-lock-ensure)
      (goto-char (point-min))
      (while (re-search-forward re-all-titles nil t)
        (backward-char) ; skip backwards the trailing \n of a title
        (let* ((descriptor (adoc-title-descriptor t))
               (title-text (nth 3 descriptor))
               (title-pos (nth 4 descriptor)))
          (when (and title-text
                     (adoc--fontified-as-title-p title-pos (nth 5 descriptor)))
            (setq
             index-alist
             (cons (cons title-text title-pos) index-alist))))))
    (nreverse index-alist)))

(defun adoc-imenu-create-nested-index ()
  "Create a nested imenu index reflecting the heading hierarchy."
  (let ((flat-index (adoc-imenu-create-index)))
    (adoc--imenu-nest flat-index)))

(defun adoc--imenu-heading-level (_title-text pos)
  "Return the heading level (0-4) for heading at POS.
_TITLE-TEXT is unused but accepted for interface consistency."
  (save-excursion
    (goto-char pos)
    (let ((descriptor (adoc-title-descriptor t)))
      (if descriptor
          (nth 2 descriptor)
        0))))

(defun adoc--imenu-nest (flat-index)
  "Convert FLAT-INDEX (a flat list of (name . pos)) into a nested alist.
Each heading contains its sub-headings as a nested menu."
  (let ((items (mapcar (lambda (item)
                         (cons (car item)
                               (cons (cdr item)
                                     (adoc--imenu-heading-level
                                      (car item) (cdr item)))))
                       flat-index)))
    ;; items is now ((name pos . level) ...)
    (adoc--imenu-build-tree items)))

(defun adoc--imenu-build-tree (items)
  "Build a nested imenu tree from ITEMS, a list of (NAME POS . LEVEL).
Each item gets the items that follow it as its children, up to the
next one at the same or a higher level.  The first item can be at any
level, so a document without a level 0 title, or one that skips a
level, keeps all its sections."
  (let (result)
    (while items
      (let* ((item (pop items))
             (level (cddr item))
             children)
        (while (and items (> (cddr (car items)) level))
          (push (pop items) children))
        (push (if children
                  (cons (car item)
                        (cons (cons nil (cadr item))
                              (adoc--imenu-build-tree (nreverse children))))
                (cons (car item) (cadr item)))
              result)))
    (nreverse result)))

(defvar adoc-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?$ "." table)
    (modify-syntax-entry ?% "." table)
    (modify-syntax-entry ?& "." table)
    (modify-syntax-entry ?' "." table)
    (modify-syntax-entry ?` "." table)
    (modify-syntax-entry ?\" "." table)
    (modify-syntax-entry ?* "." table)
    (modify-syntax-entry ?+ "." table)
    (modify-syntax-entry ?. "." table)
    (modify-syntax-entry ?/ "." table)
    (modify-syntax-entry ?< "." table)
    (modify-syntax-entry ?= "." table)
    (modify-syntax-entry ?> "." table)
    (modify-syntax-entry ?\\ "." table)
    (modify-syntax-entry ?| "." table)
    (modify-syntax-entry ?_ "." table)
    table)
  "Syntax table to use in adoc-mode.")

(defvar adoc-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "\C-c\C-n" 'adoc-next-visible-heading)
    (define-key map "\C-c\C-p" 'adoc-previous-visible-heading)
    (define-key map "\C-c\C-f" 'adoc-forward-same-level)
    (define-key map "\C-c\C-b" 'adoc-backward-same-level)
    (define-key map "\C-c\C-u" 'adoc-up-heading)
    (define-key map (kbd "M-<left>") 'adoc-promote)
    (define-key map (kbd "M-<right>") 'adoc-demote)
    (define-key map (kbd "M-RET") 'adoc-insert-list-item)
    (define-key map (kbd "M-<up>") 'adoc-move-list-item-up)
    (define-key map (kbd "M-<down>") 'adoc-move-list-item-down)
    (define-key map (kbd "TAB") 'adoc-cycle)
    (define-key map (kbd "<backtab>") 'adoc-cycle-buffer)
    (define-key map "\C-c\C-s" adoc-style-map)
    (define-key map "\C-c\C-t" 'adoc-toggle-title-type)
    (define-key map "\C-c\C-a" 'adoc-goto-ref-label)
    (define-key map "\C-c\C-o" 'adoc-follow-thing-at-point)
    (define-key map (kbd "M-.") 'adoc-follow-thing-at-point)
    (define-key map "\C-c\C-c" 'adoc-asciidoctor-menu)
    (easy-menu-define adoc-mode-menu map "Menu for adoc mode"
      `("AsciiDoc"
        ["Next heading" adoc-next-visible-heading]
        ["Previous heading" adoc-previous-visible-heading]
        ["Forward (same level)" adoc-forward-same-level]
        ["Backward (same level)" adoc-backward-same-level]
        ["Up to parent heading" adoc-up-heading]
        "---"
        ["Cycle subtree visibility" adoc-cycle]
        ["Cycle buffer visibility" adoc-cycle-buffer]
        "---"
        ["Promote (title / list item)" adoc-promote]
        ["Demote (title / list item)" adoc-demote]
        ["Insert list item" adoc-insert-list-item]
        ["Move list item up" adoc-move-list-item-up]
        ["Move list item down" adoc-move-list-item-down]
        ["Renumber list" adoc-renumber-list]
        "---"
        ("Styling"
         ["Bold" adoc-insert-bold]
         ["Italic" adoc-insert-italic]
         ["Monospace" adoc-insert-monospace]
         ["Highlight" adoc-insert-highlight]
         ["Superscript" adoc-insert-superscript]
         ["Subscript" adoc-insert-subscript]
         ["Link" adoc-insert-link])
        ["Toggle title type" adoc-toggle-title-type]
        ["Adjust title underline" adoc-adjust-title-del]
        ["Follow thing at point" adoc-follow-thing-at-point]
        ["Goto anchor" adoc-goto-ref-label]
        "---"
        ("Preview / Export"
         ["Preview" adoc-preview]
         ["Live preview mode" adoc-live-preview-mode
          :style toggle :selected adoc-live-preview-mode]
         "---"
         ["Export to HTML5" adoc-export-html]
         ["Export to DocBook 5" adoc-export-docbook]
         ["Export to PDF" adoc-export-pdf]
         ["Export to EPUB3" adoc-export-epub])
        "---"
        ;; names|wording / rough order/ help texts are from asciidoc manual
        ("Templates / cheat sheet"
         ("Text formatting - constrained quotes"
          :help ,adoc-help-constrained-quotes
          ["_Emphasis_" tempo-template-adoc-emphasis
           :help ,adoc-help-emphasis ]
          ["*Bold*" tempo-template-adoc-bold
           :help ,adoc-help-bold ]
          ["`Monospaced`" tempo-template-adoc-monospace-literal
           :help ,adoc-help-monospace]
          ["Passthrough: +text+" tempo-template-adoc-typewriter-face
           :help ,adoc-help-pass]
          ["Curved double quote: \"`text`\"" tempo-template-adoc-double-curved-quote
           :help ,adoc-help-double-quote]
          ["Curved single quote: '`text`'" tempo-template-adoc-single-curved-quote
           :help ,adoc-help-single-quote]
          ["The text [.underline]#underline me# is underlined." tempo-template-adoc-underline
           :help ,adoc-help-underline]
          ["The text [.overline]#overline me# is overlined." tempo-template-adoc-overline
           :help ,adoc-help-overline]
          ["The text [.line-through]#line-through me# is line-through." tempo-template-adoc-line-through
           :help ,adoc-help-line-through]
          ["The text [.nobreak]#no break me# is non-breakable." tempo-template-adoc-nobreak
           :help ,adoc-help-nobreak]
          ["The text [.nowrap]#no wrap me# is non-wrapable." tempo-template-adoc-nowrap
           :help ,adoc-help-nowrap]
          ["The text [.pre-wrap]#pre-wrap me# is pre-wrapped." tempo-template-adoc-pre-wrap
           :help ,adoc-help-pre-wrap]
          ["[attributes]##text##" tempo-template-adoc-attributed
           :help ,adoc-help-attributed])
         ("Text formatting - unconstrained quotes"
          :help ,adoc-help-unconstrained-quotes
          ["^Superscript^" tempo-template-adoc-superscript]
          ["~Subscript~" tempo-template-adoc-subscript]
          ["__Emphasis__" tempo-template-adoc-emphasis-uc
           :help ,adoc-help-emphasis ]
          ["**Bold**" tempo-template-adoc-bold-uc
           :help ,adoc-help-bold ]
          ["Passthrough: ++text++" tempo-template-adoc-monospace-uc
           :help ,adoc-help-pass]
          ["[attributes]##text##" tempo-template-adoc-attributed-uc
           :help ,adoc-help-attributed])
         ("Text formatting - misc"
          ["Line break: <SPC>+<NEWLINE>" tempo-template-adoc-line-break
           :help ,adoc-help-line-break]
          ["Page break: <<<" tempo-template-adoc-page-break
           :help ,adoc-help-page-break]
          ["Ruler line: ---" tempo-template-adoc-ruler-line
           :help ,adoc-help-ruler-line])
         ("Text formatting - replacements"
          ["Copyright: (C) \u2192 \u00A9" tempo-template-adoc-copyright]
          ["Trademark: (TM) \u2192 \u2122" tempo-template-adoc-trademark]
          ["Registered trademark: (R) \u2192 \u00AE" tempo-template-adoc-registered-trademark]
          ["Dash: -- \u2192 \u2014" tempo-template-adoc-dash]
          ["Ellipsis: ... \u2192 \u2026" tempo-template-adoc-ellipsis]
          ["Right arrow: -> \u2192 \u2192" tempo-template-adoc-right-arrow]
          ["Left arrow: <- \u2192 \u2190" tempo-template-adoc-left-arrow]
          ["Right double arrow: => \u2192 \u21D2" tempo-template-adoc-right-double-arrow]
          ["Left double arrow: <= \u2192 \u21D0" tempo-template-adoc-left-double-arrow]
          "---"
          ["Character entity reference: &...;" tempo-template-adoc-entity-reference
           :help ,adoc-help-entity-reference])
         ("Titles"
          [,(concat "Document title (level 0): " (adoc-template-str-title 0))
           tempo-template-adoc-title-1]
          [,(concat "Section title (level 1): " (adoc-template-str-title 1))
           tempo-template-adoc-title-2]
          [,(concat "Section title (level 2): " (adoc-template-str-title 2))
           tempo-template-adoc-title-3]
          [,(concat "Section title (level 3): " (adoc-template-str-title 3))
           tempo-template-adoc-title-4]
          [,(concat "Section title (level 4): " (adoc-template-str-title 4))
           tempo-template-adoc-title-5]
          ["Block title: .foo" tempo-template-adoc-block-title]
          ["BlockId: [[id]]" tempo-template-adoc-anchor]) ; redundant to anchor below
         ("Paragraphs"
          ["Literal paragraph" tempo-template-adoc-literal-paragraph
           :help ,adoc-help-literal-paragraph]
          "---"
          ["TIP: " tempo-template-adoc-paragraph-tip]
          ["NOTE: " tempo-template-adoc-paragraph-note]
          ["IMPORTANT: " tempo-template-adoc-paragraph-important]
          ["WARNING: " tempo-template-adoc-paragraph-warning]
          ["CAUTION: " tempo-template-adoc-paragraph-caution])
         ("Delimited blocks"
          :help ,adoc-help-delimited-block
          ;; BUG: example does not reflect the content of adoc-delimited-block-del
          ["Comment: ////" tempo-template-adoc-delimited-block-comment
           :help ,adoc-help-delimited-block-comment]
          ["Passthrough: ++++" tempo-template-adoc-delimited-block-passthrough
           :help ,adoc-help-delimited-block-passthrouh]
          ["Listing: ----" tempo-template-adoc-delimited-block-listing
           :help ,adoc-help-delimited-block-listing]
          ["Literal: ...." tempo-template-adoc-delimited-block-literal
           :help ,adoc-help-delimited-block-literal]
          ["Quote: ____" tempo-template-adoc-delimited-block-quote
           :help ,adoc-help-delimited-block-quote]
          ["Example: ====" tempo-template-adoc-delimited-block-example
           :help ,adoc-help-delimited-block-example]
          ["Sidebar: ****" tempo-template-adoc-delimited-block-sidebar
           :help ,adoc-help-delimited-block-sidebar]
          ["Open: --" tempo-template-adoc-delimited-block-open-block
           :help ,adoc-help-delimited-block-open-block])
         ("Lists"
          :help ,adoc-help-list
          ("Bulleted"
           :help ,adoc-help-bulleted-list
           ["Item: -" tempo-template-adoc-bulleted-list-item-1]
           ["Item: **" tempo-template-adoc-bulleted-list-item-2]
           ["Item: ***" tempo-template-adoc-bulleted-list-item-3]
           ["Item: ****" tempo-template-adoc-bulleted-list-item-4]
           ["Item: *****" tempo-template-adoc-bulleted-list-item-5])
          ("Numbered - explicit"
           ["Arabic (decimal) numbered item: 1." tempo-template-adoc-numbered-list-item]
           ["Lower case alpha (letter) numbered item: a." tempo-template-adoc-numbered-list-item]
           ["Upper case alpha (letter) numbered item: A." tempo-template-adoc-numbered-list-item]
           ["Lower case roman numbered list item: i)" tempo-template-adoc-numbered-list-item-roman]
           ["Upper case roman numbered list item: I)" tempo-template-adoc-numbered-list-item-roman])
          ("Numbered - implicit"
           ["Arabic (decimal) numbered item: ." tempo-template-adoc-implicit-numbered-list-item-1]
           ["Lower case alpha (letter) numbered item: .." tempo-template-adoc-implicit-numbered-list-item-2]
           ["Upper case alpha (letter)numbered item: ..." tempo-template-adoc-implicit-numbered-list-item-3]
           ["Lower case roman numbered list item: ...." tempo-template-adoc-implicit-numbered-list-item-4]
           ["Upper case roman numbered list item: ....." tempo-template-adoc-implicit-numbered-list-item-5])
          ["Labeled item: label:: text" tempo-template-adoc-labeled-list-item]
          ["List item continuation: <NEWLINE>+<NEWLINE>" tempo-template-adoc-list-item-continuation
           :help ,adoc-help-list-item-continuation])
         ("Tables"
          :help ,adoc-help-table
          ["Example table" tempo-template-adoc-example-table])
         ("Macros (inline & block)"
          :help ,adoc-help-macros
          ["URL: http://foo.com" tempo-template-adoc-url
           :help ,adoc-help-url]
          ["URL with caption: http://foo.com[caption]" tempo-template-adoc-url-caption
           :help ,adoc-help-url]
          ["EMail: bob@foo.com" tempo-template-adoc-email
           :help ,adoc-help-url]
          ["EMail with caption: mailto:address[caption]" tempo-template-adoc-email-caption
           :help ,adoc-help-url]
          ["Anchor aka BlockId (syntax 1): [[id,xreflabel]]" tempo-template-adoc-anchor
           :help ,adoc-help-anchor]
          ["Anchor (syntax 2): anchor:id[xreflabel]" tempo-template-adoc-anchor-default-syntax
           :help ,adoc-help-anchor]
          ["Xref (syntax 1): <<id,caption>>" tempo-template-adoc-xref
           :help ,adoc-help-xref]
          ["Xref (syntax 2): xref:id[caption]" tempo-template-adoc-xref-default-syntax
           :help ,adoc-help-xref]
          ["Image: image:target-path[caption]" tempo-template-adoc-image]
          ["Comment: //" adoc-insert-comment
           :help ,adoc-help-comment]
          ("Passthrough macros"
           :help ,adoc-help-passthrough-macros
           ["pass:[text]" tempo-template-adoc-pass
            :help ,adoc-help-pass]
           ["ASCIIMath: asciimath:[text]" tempo-template-adoc-asciimath
            :help ,adoc-help-asciimath]
           ["LaTeX math: latexmath[text]" tempo-template-adoc-latexmath
            :help ,adoc-help-latexmath]
           ["+++text+++" tempo-template-adoc-pass-+++
            :help ,adoc-help-pass-+++]
           ["$$text$$" tempo-template-adoc-pass-$$
            :help ,adoc-help-pass-$$]
           ["`text`" tempo-template-adoc-monospace-literal ; redundant to the one in the quotes section
            :help ,adoc-help-monospace-literal])))
        "---"
        ["Toggle display of images" adoc-toggle-images t]))
    map)
  "Keymap used in adoc mode.")


;;;###autoload
(define-derived-mode adoc-mode text-mode "adoc"
  "Major mode for editing AsciiDoc text files.
Turning on Adoc mode runs the normal hook `adoc-mode-hook'."
  ;; comments
  (setq-local comment-column 0)
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "^//[ \t]*")
  (setq-local comment-end-skip "[ \t]*\\(?:\n\\|\\'\\)")

  ;; paragraphs
  (setq-local paragraph-separate (adoc-re-paragraph-separate))
  (setq-local paragraph-start (adoc-re-paragraph-start))
  (setq-local paragraph-ignore-fill-prefix t)

  ;; font lock
  (adoc-calc)
  (setq-local font-lock-defaults
              '(adoc-font-lock-keywords
                nil nil nil nil
                (font-lock-multiline . t)
                (font-lock-mark-block-function . adoc-font-lock-mark-block-function)))
  (setq-local font-lock-extra-managed-props '(adoc-reserved adoc-attribute-list adoc-code-block adoc-flyspell-ignore))
  (setq-local font-lock-unfontify-region-function 'adoc-unfontify-region-function)
  (setq-local font-lock-extend-after-change-region-function #'adoc-font-lock-extend-after-change-region)
  (add-hook 'font-lock-extend-region-functions #'adoc-font-lock-extend-region nil t)
  (add-hook 'before-change-functions #'adoc--invalidate-block-extents nil t)

  ;; outline mode
  (setq-local outline-regexp "=\\{1,6\\}[ \t]+[^ \t\n]")
  (setq-local outline-level (lambda ()
                              (save-excursion
                                (skip-chars-forward "=")
                                (current-column))))
  ;; Emacs 29+ (on 28, title-like lines in blocks still count as headings)
  (when (boundp 'outline-search-function)
    (setq-local outline-search-function #'adoc--outline-search))
  (outline-minor-mode 1)

  ;; fill
  (add-hook 'fill-nobreak-predicate #'adoc-fill-nobreak-p nil t)
  (setq-local fill-paragraph-function #'adoc-fill-paragraph)

  ;; completion
  (add-hook 'completion-at-point-functions #'adoc-completion-at-point nil t)

  ;; diagnostics (opt-in: contributes when the user enables `flymake-mode')
  (add-hook 'flymake-diagnostic-functions #'adoc-flymake nil t)

  ;; cross-references (`M-?' for references, the xref marker stack, etc.)
  (add-hook 'xref-backend-functions #'adoc--xref-backend nil t)

  (adoc--warn-about-two-line-titles)
  ;; also catch the option being set as a file- or dir-local variable
  (add-hook 'hack-local-variables-hook #'adoc--warn-about-two-line-titles nil t)

  ;; misc
  (setq-local page-delimiter "^<<<+$")
  (setq-local require-final-newline mode-require-final-newline)
  (setq-local parse-sexp-lookup-properties t)

  ;; it's the user's decision whether he wants to set imenu-sort-function to
  ;; nil, or even something else. See also similar comment in sgml-mode.
  (setq-local imenu-create-index-function adoc-imenu-create-index-function)

  (when (and (display-graphic-p) adoc-display-images)
    (adoc-display-images)))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.a\\(?:scii\\)?doc\\'" . adoc-mode))

(defvar adoc--two-line-title-warning-shown nil
  "Non-nil once the two-line title deprecation warning has been shown.")

(defun adoc--warn-about-two-line-titles ()
  "Warn once per session when two-line titles are enabled.
They're deprecated, see `adoc-enable-two-line-title'."
  (when (and adoc-enable-two-line-title
             (not adoc--two-line-title-warning-shown))
    (setq adoc--two-line-title-warning-shown t)
    (display-warning
     '(adoc-mode two-line-titles)
     (substitute-command-keys
      "`adoc-enable-two-line-title' is set, but two-line (setext) titles are \
deprecated and `adoc-mode' will drop support for them in a future release.  \
\\<adoc-mode-map>\\[adoc-toggle-title-type] converts the title at point to the \
one-line style."))))


;; Auto-fill

(defun adoc-fill-nobreak-p ()
  "Return non-nil if the current line is a section title.
Used as a `fill-nobreak-predicate' to prevent `auto-fill-mode'
from breaking section title lines."
  (save-excursion
    (beginning-of-line)
    (looking-at-p "=\\{1,6\\}[ \t]")))

(defun adoc-fill-paragraph (&optional justify)
  "Fill the current paragraph, preserving AsciiDoc hard line breaks.
A line ending in a space followed by `+' is a forced line break;
filling must not merge it with the following line.  Such breaks
are marked as hard newlines so the filler keeps them.  Serves as
the buffer's `fill-paragraph-function'."
  (save-excursion
    (let ((beg (progn (backward-paragraph) (point)))
          (end (progn (forward-paragraph) (point))))
      ;; Drop any stale hard newlines first (e.g. from a ` +' the user has
      ;; since deleted), then mark the breaks that are still present.
      (remove-text-properties beg end '(hard nil))
      (goto-char beg)
      (while (re-search-forward " \\+$" end t)
        (when (eq (char-after) ?\n)
          (put-text-property (point) (1+ (point)) 'hard t)))))
  (let ((use-hard-newlines t)
        (fill-paragraph-function nil))
    (fill-paragraph justify))
  t)

;; Flyspell

(defun adoc-flyspell-p ()
  "Function for `flyspell-mode-predicate' property of `adoc-mode'.
Returns t if word at point should be checked, nil otherwise."
  (font-lock-ensure (line-beginning-position) (line-end-position))
  (not (get-text-property
        (1- (point)) ;; preceding word is checked, so 1- should do no harm
        'adoc-flyspell-ignore)))

(put 'adoc-mode 'flyspell-mode-predicate 'adoc-flyspell-p)

(provide 'adoc-mode)

;; Local Variables:
;; indent-tabs-mode: nil
;; coding: utf-8
;; End:
;;; adoc-mode.el ends here
