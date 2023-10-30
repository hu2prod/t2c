module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
  iced_compile
} = require "../../common_import"

{fn_generator}      = require "./fn_generator"
erlang_nif_decl = require "./erlang_nif_decl"

# TODO rework with fn, arg
# TODO use hydrator
# ###################################################################################################
#    erlang_nif_fn
# ###################################################################################################
bdh_module_name_root module, "erlang_nif_fn",
  emit_codebub  : (root, ctx)->
    erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
    {erlang_nif_module} = erlang_nif_package_node.data_hash
    
    # TODO move some parts to validator
    # костыли, чтобы меньше copypaste
    ret = fn_generator root, ctx, erlang_nif_module
    
    if ret.fn_cont_use_code_bubble
      ret.fn_cont = ctx.file_render ret.cb_name, ret.fn_cont
    root.data_hash.erlang_nif_fn_tmp_ret ?= ret
    
    false
  
  emit_codegen  : (root, ctx)->
    erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
    {erlang_nif_module} = erlang_nif_package_node.data_hash
    
    {
      fn_cont
      file_render_name
      file_render_fn
    } = root.data_hash.erlang_nif_fn_tmp_ret
    # костыли, чтобы меньше copypaste
    ctx.file_render file_render_name, file_render_fn fn_cont
    false

def "erlang_nif_fn", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
  {erlang_nif_module} = erlang_nif_package_node.data_hash
  
  root = mod_runner.current_runner.curr_root.tr_get "erlang_nif_fn", name, "def"
  bdh_node_module_name_assign_on_call root, module, "erlang_nif_fn"
  
  # BUG в случае nested может случайно пропустить границу erlang_nif_package
  # erlang_nif_class_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_class"
  # BUG? если между erlang_nif_class и erlang_nif_fn какая-то прослойка
  erlang_nif_class_node = mod_runner.current_runner.curr_root
  
  # TODO check что class принадлежит erlang_nif_module
  if erlang_nif_class_node.type == "erlang_nif_class"
    {erlang_nif_class_decl} = erlang_nif_class_node.data_hash
    
    fn_decl = erlang_nif_class_decl.fn_decl_get name
    fn_decl.parent_class_name = erlang_nif_class_decl.name
  else
    fn_decl = erlang_nif_module.fn_decl_get name
  
  root.data_hash.erlang_nif_fn_decl ?= fn_decl
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    erlang_nif_fn_arg
# ###################################################################################################
bdh_module_name_root module, "erlang_nif_fn_arg",
  validator     : (root, ctx)->
    erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
    {erlang_nif_module} = erlang_nif_package_node.data_hash
    
    # erlang_nif_fn_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_fn"
    erlang_nif_fn_node = mod_runner.current_runner.curr_root
    {erlang_nif_fn_decl} = erlang_nif_fn_node.data_hash
    
    
    {type} = root.data_hash.erlang_nif_arg
    
    if !erlang_nif_decl.std_fn_decl_type_hash[type]
      if !erlang_nif_module.class_decl_hash[type]?
        throw new Error "class '#{type}' doesn't exists fn_name=#{erlang_nif_fn_decl.name}"
    
    false

def "erlang_nif_fn_arg", (name, type)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # erlang_nif_fn_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_fn"
  erlang_nif_fn_node = mod_runner.current_runner.curr_root
  {erlang_nif_fn_decl} = erlang_nif_fn_node.data_hash
  
  if name == "ret" or name.startsWith "ret_"
    arg = erlang_nif_fn_decl.ret_get name
  else
    arg = erlang_nif_fn_decl.arg_get name
  
  arg.name = name
  if type.endsWith "[]"
    type = type.substr 0, type.length-2
    arg.is_array = true
  
  arg.type = type
  
  # only for validator
  root = mod_runner.current_runner.curr_root.tr_get "erlang_nif_fn_arg", name, "def"
  bdh_node_module_name_assign_on_call root, module, "erlang_nif_fn_arg"
  
  root.data_hash.erlang_nif_arg ?= arg
  
  root

def "erlang_nif_fn_arg_raw", (name, type)->
  arg = erlang_nif_fn_arg name, type
  arg.is_raw = true
  arg

# ###################################################################################################
#    erlang_nif_fn_raw_fixed_code
# ###################################################################################################
# TODO move to policy?
def "erlang_nif_fn_raw_fixed_code", (code)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  erlang_nif_fn_node = mod_runner.current_runner.curr_root
  {erlang_nif_fn_decl} = erlang_nif_fn_node.data_hash
  
  erlang_nif_fn_decl.raw_fixed_code = code
  
  return

def "erlang_nif_fn_sync_only", (name)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  erlang_nif_fn_node = mod_runner.current_runner.curr_root
  {erlang_nif_fn_decl} = erlang_nif_fn_node.data_hash
  
  erlang_nif_fn_decl.gen_sync = true
  erlang_nif_fn_decl.gen_async= false
  
  return

def "erlang_nif_fn_sync_env", (name)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  erlang_nif_fn_node = mod_runner.current_runner.curr_root
  {erlang_nif_fn_decl} = erlang_nif_fn_node.data_hash
  
  erlang_nif_fn_decl.gen_sync = true
  erlang_nif_fn_decl.gen_async= false
  erlang_nif_fn_decl.gen_env  = true
  
  return
