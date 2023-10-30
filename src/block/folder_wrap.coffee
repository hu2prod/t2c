module = @
fs = require "fs"
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "./common_import"

# ###################################################################################################
#    folder_wrap
# ###################################################################################################
bdh_module_name_root module, "folder_wrap",
  nodegen       : (root, ctx)->
    ctx.folder_wrap root.name, ()->
      ctx.walk_child_list_only_fn root
    true
  
  validator     : (root, ctx)->
    ctx.folder_wrap root.name, ()->
      ctx.walk_child_list_only_fn root
    true
  
  emit_codebub  : (root, ctx)->
    ctx.folder_wrap root.name, ()->
      ctx.walk_child_list_only_fn root
    true
  
  emit_codegen  : (root, ctx)->
    ctx.folder_wrap root.name, ()->
      ctx.walk_child_list_only_fn root
    true
  
  emit_min_deps : (root, ctx, cb)->
    ctx.folder_push root.name
    await ctx.walk_child_list_only_fn root, 0, defer(err)
    ctx.folder_pop()
    cb err, true

# name == folder
def "folder_wrap", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "folder_wrap", name, "def"
  bdh_node_module_name_assign_on_call root, module, "folder_wrap"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root
