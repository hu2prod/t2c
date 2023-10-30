module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
  iced_compile
} = require "../../common_import"

{class_generator}   = require "./class_generator"
napi_decl = require "./napi_decl"

# TODO use struct
# ###################################################################################################
#    napi_class
# ###################################################################################################
bdh_module_name_root module, "napi_class",
  emit_codegen  : (root, ctx)->
    napi_package_node = mod_runner.current_runner.curr_root.type_filter_search "napi_package"
    {napi_module} = napi_package_node.data_hash
    
    # TODO move some parts to validator
    class_generator root, ctx, napi_module
    false

def "napi_class", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  if !name
    throw new Error "!name"
  
  if name[0].toUpperCase() != name[0]
    p "WARNING. napi_class #{name}. Class name should be capitalized"
  
  napi_package_node = mod_runner.current_runner.curr_root.type_filter_search "napi_package"
  {napi_module} = napi_package_node.data_hash
  
  # PICK ONE
  # edge case, pipeline +1 level
  # root = mod_runner.current_runner.curr_root.tr_get "napi_class", name, "def"
  root = napi_package_node.tr_get "napi_class", name, "def"
  bdh_node_module_name_assign_on_call root, module, "napi_class"
  
  class_decl = napi_module.class_decl_get name
  root.data_hash.napi_class_decl ?= class_decl
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# TODO use field
# ###################################################################################################
#    napi_class_kt
# ###################################################################################################
def "napi_class_kt", (name, type)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  if !name
    throw new Error "!name"
  if !type
    throw new Error "!type"
  
  # napi_class_decl_node = mod_runner.current_runner.curr_root.type_filter_search "napi_class_decl"
  napi_class_decl_node = mod_runner.current_runner.curr_root
  {napi_class_decl} = napi_class_decl_node.data_hash
  
  field_decl = napi_class_decl.field_get name
  
  if type.endsWith "[]"
    type = type.substr 0, type.length-2
    field_decl.is_array = true
  
  field_decl.type = type
  
  return

# ###################################################################################################
#    napi_class_field_raw
# ###################################################################################################
def "napi_class_field_raw", (code)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # napi_class_decl_node = mod_runner.current_runner.curr_root.type_filter_search "napi_class_decl"
  napi_class_decl_node = mod_runner.current_runner.curr_root
  {napi_class_decl} = napi_class_decl_node.data_hash
  
  for line in code.split "\n"
    field_decl = napi_class_decl.field_get line
    field_decl.is_raw = true
  
  return

# ###################################################################################################
#    napi_class_constructor_raw
# ###################################################################################################
def "napi_class_constructor_raw", (code)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # napi_class_decl_node = mod_runner.current_runner.curr_root.type_filter_search "napi_class_decl"
  napi_class_decl_node = mod_runner.current_runner.curr_root
  {napi_class_decl} = napi_class_decl_node.data_hash
  
  if code
    napi_class_decl.code_init_get code
  
  return

# ###################################################################################################
#    napi_class_include_raw
# ###################################################################################################
def "napi_class_include_raw", (code)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  napi_package_node = mod_runner.current_runner.curr_root.type_filter_search "napi_package"
  {napi_module} = napi_package_node.data_hash
  
  if code
    # ух какой хак
    # TODO убрать
    class_decl = napi_module.class_decl_get code
    class_decl.is_fake = true
    class_decl.raw_class_include_code = code
  
  return

# ###################################################################################################
#    napi_class_dep
# ###################################################################################################
def "napi_class_dep", (class_name)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # napi_class_decl_node = mod_runner.current_runner.curr_root.type_filter_search "napi_class_decl"
  napi_class_decl_node = mod_runner.current_runner.curr_root
  if napi_class_decl = napi_class_decl_node.data_hash.napi_class_decl
    napi_class_decl.class_dep_get class_name
  else if napi_fn_decl = napi_class_decl_node.data_hash.napi_fn_decl
    napi_fn_decl.class_dep_get class_name
  else
    throw new Error "can't apply napi_class_dep"
  
  
  return
