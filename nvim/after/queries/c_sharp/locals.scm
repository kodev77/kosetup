; extends
;
; Extra locals for C# so the LSP-free symbols picker (<leader>ss, snacks
; treesitter finder, see plugins/nav-light.lua) has something to show.
;
; The stock nvim-treesitter c_sharp locals.scm only declares method bodies
; ((block)) as scopes and tags classes/properties as a bare @local.definition
; with no kind. The snacks finder keeps only "@local.definition.<kind>"
; captures that sit inside a declared scope, so for C# it found nothing.
;
; Kind words are the ones snacks maps to LSP kinds: type -> Class,
; method -> Method, field -> Field, enum -> Enum, namespace -> Namespace.

; Scopes (so symbols nest: namespace > class > method)
(compilation_unit) @local.scope
(namespace_declaration) @local.scope
(file_scoped_namespace_declaration) @local.scope
(class_declaration) @local.scope
(struct_declaration) @local.scope
(interface_declaration) @local.scope
(record_declaration) @local.scope
(enum_declaration) @local.scope

; Definitions with a kind
(namespace_declaration
  name: (_) @local.definition.namespace)
(file_scoped_namespace_declaration
  name: (_) @local.definition.namespace)
(class_declaration
  name: (identifier) @local.definition.type)
(struct_declaration
  name: (identifier) @local.definition.type)
(interface_declaration
  name: (identifier) @local.definition.type)
(record_declaration
  name: (identifier) @local.definition.type)
(enum_declaration
  name: (identifier) @local.definition.enum)
(enum_member_declaration
  name: (identifier) @local.definition.field)
(constructor_declaration
  name: (identifier) @local.definition.method)
(property_declaration
  name: (identifier) @local.definition.field)
(field_declaration
  (variable_declaration
    (variable_declarator
      .
      (identifier) @local.definition.field)))
