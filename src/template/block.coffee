module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "./common_import"

# ###################################################################################################
#    REPLACE_ME
# ###################################################################################################
bdh_module_name_root module, "REPLACE_ME",
  nodegen       : (root, ctx)->
    false
  
  validator     : (root, ctx)->
    false
  
  emit_codebub  : (root, ctx)->
    false
  
  emit_codegen  : (root, ctx)->
    false
  
  emit_min_deps : (root, ctx, cb)->
    cb null, false

def "REPLACE_ME", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # PICK ONE
  # root = mod_runner.current_runner.curr_root.tr_get "REPLACE_ME", name, "def"
  # root = mod_runner.current_runner.curr_root.tr_get "REPLACE_ME", "REPLACE_ME", "def"
  bdh_node_module_name_assign_on_call root, module, "REPLACE_ME"
  
  # root.policy_set_here_weak "hot_reload", true
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root
