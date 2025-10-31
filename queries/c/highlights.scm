; NeoGhidra Treesitter Highlights for Decompiled C Code

; Functions
(function_definition
  declarator: (function_declarator
    declarator: (identifier) @function))

(call_expression
  function: (identifier) @function.call)

; Types
(primitive_type) @type.builtin
(type_identifier) @type

; Variables
(identifier) @variable

; Parameters
(parameter_declaration
  declarator: (identifier) @parameter)

; Constants
(number_literal) @number
(string_literal) @string
(char_literal) @character

; Keywords
[
  "return"
  "if"
  "else"
  "switch"
  "case"
  "default"
  "while"
  "for"
  "do"
  "break"
  "continue"
  "goto"
] @keyword

[
  "struct"
  "union"
  "enum"
  "typedef"
] @keyword.type

[
  "const"
  "volatile"
  "static"
  "extern"
  "inline"
] @keyword.modifier

; Operators
[
  "="
  "+"
  "-"
  "*"
  "/"
  "%"
  "=="
  "!="
  "<"
  ">"
  "<="
  ">="
  "&&"
  "||"
  "!"
  "&"
  "|"
  "^"
  "~"
  "<<"
  ">>"
  "++"
  "--"
  "+="
  "-="
  "*="
  "/="
  "%="
  "&="
  "|="
  "^="
  "<<="
  ">>="
] @operator

; Comments
(comment) @comment

; Preprocessor
(preproc_directive) @preproc
(preproc_def) @preproc
(preproc_include) @include

; Punctuation
["(" ")" "[" "]" "{" "}"] @punctuation.bracket
["," ";" ":"] @punctuation.delimiter

; Special
(null) @constant.builtin
[(true) (false)] @boolean
