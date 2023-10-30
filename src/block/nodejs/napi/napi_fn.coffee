module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
  iced_compile
} = require "../../common_import"

{fn_generator}      = require "./fn_generator"
napi_decl = require "./napi_decl"

# TODO rework with fn, arg
# TODO use hydrator
# ###################################################################################################
#    napi_fn
# ###################################################################################################
bdh_module_name_root module, "napi_fn",
  nodegen       : (root, ctx)->
    root.data_hash.napi_fn_decl.code_unit = root.policy_get_val_use "code_unit"
    false
  
  emit_codebub  : (root, ctx)->
    napi_package_node = mod_runner.current_runner.curr_root.type_filter_search "napi_package"
    {napi_module} = napi_package_node.data_hash
    
    # TODO move some parts to validator
    # костыли, чтобы меньше copypaste
    ret = fn_generator root, ctx, napi_module
    
    if ret.fn_cont_use_code_bubble
      ret.fn_cont = ctx.file_render ret.cb_name, ret.fn_cont
    root.data_hash.napi_fn_tmp_ret ?= ret
    
    false
  
  emit_codegen  : (root, ctx)->
    napi_package_node = mod_runner.current_runner.curr_root.type_filter_search "napi_package"
    {napi_module} = napi_package_node.data_hash
    
    {
      fn_cont
      file_hash
    } = root.data_hash.napi_fn_tmp_ret
    # костыли, чтобы меньше copypaste
    for k,v of file_hash
      ctx.file_render v.name, v.fn fn_cont
    
    false

def "napi_fn", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  napi_package_node = mod_runner.current_runner.curr_root.type_filter_search "napi_package"
  {napi_module} = napi_package_node.data_hash
  
  root = mod_runner.current_runner.curr_root.tr_get "napi_fn", name, "def"
  bdh_node_module_name_assign_on_call root, module, "napi_fn"
  
  # BUG в случае nested может случайно пропустить границу napi_package
  # napi_class_node = mod_runner.current_runner.curr_root.type_filter_search "napi_class"
  # BUG? если между napi_class и napi_fn какая-то прослойка
  napi_class_node = mod_runner.current_runner.curr_root
  
  # TODO check что class принадлежит napi_module
  if napi_class_node.type == "napi_class"
    {napi_class_decl} = napi_class_node.data_hash
    
    fn_decl = napi_class_decl.fn_decl_get name
    fn_decl.parent_class_name = napi_class_decl.name
    root.policy_set_here_weak "code_unit", "class__#{napi_class_decl.name}"
  else
    fn_decl = napi_module.fn_decl_get name
    root.policy_set_here_weak "code_unit", "module"
  
  root.data_hash.napi_fn_decl ?= fn_decl
  
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    napi_fn_arg
# ###################################################################################################
bdh_module_name_root module, "napi_fn_arg",
  validator     : (root, ctx)->
    napi_package_node = mod_runner.current_runner.curr_root.type_filter_search "napi_package"
    {napi_module} = napi_package_node.data_hash
    
    # napi_fn_node = mod_runner.current_runner.curr_root.type_filter_search "napi_fn"
    napi_fn_node = mod_runner.current_runner.curr_root
    {napi_fn_decl} = napi_fn_node.data_hash
    
    
    {type} = root.data_hash.napi_arg
    
    if !napi_decl.std_fn_decl_type_hash[type]
      if !napi_module.class_decl_hash[type]?
        throw new Error "class '#{type}' doesn't exists fn_name=#{napi_fn_decl.name}"
    
    false

def "napi_fn_arg", (name, type)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # napi_fn_node = mod_runner.current_runner.curr_root.type_filter_search "napi_fn"
  napi_fn_node = mod_runner.current_runner.curr_root
  {napi_fn_decl} = napi_fn_node.data_hash
  
  if name == "ret" or name.startsWith "ret_"
    arg = napi_fn_decl.ret_get name
  else
    arg = napi_fn_decl.arg_get name
  
  arg.name = name
  if type.endsWith "[]"
    type = type.substr 0, type.length-2
    arg.is_array = true
  
  arg.type = type
  
  # only for validator
  root = mod_runner.current_runner.curr_root.tr_get "napi_fn_arg", name, "def"
  bdh_node_module_name_assign_on_call root, module, "napi_fn_arg"
  
  root.data_hash.napi_arg ?= arg
  
  root

def "napi_fn_arg_raw", (name, type)->
  arg = napi_fn_arg name, type
  arg.is_raw = true
  arg

# ###################################################################################################
#    napi_fn_raw_fixed_code
# ###################################################################################################
# TODO move to policy?
def "napi_fn_raw_fixed_code", (code)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  napi_fn_node = mod_runner.current_runner.curr_root
  {napi_fn_decl} = napi_fn_node.data_hash
  
  napi_fn_decl.raw_fixed_code = code
  
  return

def "napi_fn_sync_only", (name)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  napi_fn_node = mod_runner.current_runner.curr_root
  {napi_fn_decl} = napi_fn_node.data_hash
  
  napi_fn_decl.gen_sync = true
  napi_fn_decl.gen_async= false
  
  return

def "napi_fn_sync_env", (name)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  napi_fn_node = mod_runner.current_runner.curr_root
  {napi_fn_decl} = napi_fn_node.data_hash
  
  napi_fn_decl.gen_sync = true
  napi_fn_decl.gen_async= false
  napi_fn_decl.gen_env  = true
  
  return
