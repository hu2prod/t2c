module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "./common_import"

# ###################################################################################################
#    mod_buf_pool
# ###################################################################################################
bdh_module_name_root module, "mod_buf_pool",
  emit_codegen  : (root, ctx)->
    ctx.tpl_copy "buf_pool.coffee", "misc/util", "src/util"
    false

def "mod_buf_pool", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "mod_buf_pool", "mod_buf_pool", "def"
  bdh_node_module_name_assign_on_call root, module, "mod_buf_pool"
  
  root