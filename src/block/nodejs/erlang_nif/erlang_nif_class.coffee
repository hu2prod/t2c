module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
  iced_compile
} = require "../../common_import"

{class_generator}   = require "./class_generator"
erlang_nif_decl = require "./erlang_nif_decl"

# TODO use struct
# ###################################################################################################
#    erlang_nif_class
# ###################################################################################################
bdh_module_name_root module, "erlang_nif_class",
  emit_codegen  : (root, ctx)->
    erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
    {erlang_nif_module} = erlang_nif_package_node.data_hash
    
    # TODO move some parts to validator
    class_generator root, ctx, erlang_nif_module
    false

def "erlang_nif_class", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  if !name
    throw new Error "!name"
  
  if name[0].toUpperCase() != name[0]
    p "WARNING. erlang_nif_class #{name}. Class name should be capitalized"
  
  erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
  {erlang_nif_module} = erlang_nif_package_node.data_hash
  
  # PICK ONE
  root = mod_runner.current_runner.curr_root.tr_get "erlang_nif_class", name, "def"
  bdh_node_module_name_assign_on_call root, module, "erlang_nif_class"
  
  class_decl = erlang_nif_module.class_decl_get name
  root.data_hash.erlang_nif_class_decl ?= class_decl
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# TODO use field
# ###################################################################################################
#    erlang_nif_class_kt
# ###################################################################################################
def "erlang_nif_class_kt", (name, type)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  if !name
    throw new Error "!name"
  if !type
    throw new Error "!type"
  
  # erlang_nif_class_decl_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_class_decl"
  erlang_nif_class_decl_node = mod_runner.current_runner.curr_root
  {erlang_nif_class_decl} = erlang_nif_class_decl_node.data_hash
  
  field_decl = erlang_nif_class_decl.field_get name
  
  if type.endsWith "[]"
    type = type.substr 0, type.length-2
    field_decl.is_array = true
  
  field_decl.type = type
  
  return

# ###################################################################################################
#    erlang_nif_class_field_raw
# ###################################################################################################
def "erlang_nif_class_field_raw", (code)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # erlang_nif_class_decl_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_class_decl"
  erlang_nif_class_decl_node = mod_runner.current_runner.curr_root
  {erlang_nif_class_decl} = erlang_nif_class_decl_node.data_hash
  
  for line in code.split "\n"
    field_decl = erlang_nif_class_decl.field_get line
    field_decl.is_raw = true
  
  return

# ###################################################################################################
#    erlang_nif_class_constructor_raw
# ###################################################################################################
def "erlang_nif_class_constructor_raw", (code)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # erlang_nif_class_decl_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_class_decl"
  erlang_nif_class_decl_node = mod_runner.current_runner.curr_root
  {erlang_nif_class_decl} = erlang_nif_class_decl_node.data_hash
  
  if code
    erlang_nif_class_decl.code_init_get code
  
  return

# ###################################################################################################
#    erlang_nif_class_include_raw
# ###################################################################################################
def "erlang_nif_class_include_raw", (code)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
  {erlang_nif_module} = erlang_nif_package_node.data_hash
  
  if code
    # ух какой хак
    # TODO убрать
    class_decl = erlang_nif_module.class_decl_get code
    class_decl.is_fake = true
    class_decl.raw_class_include_code = code
  
  return
