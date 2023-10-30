module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  hydrator_def
  
  mod_runner
} = require "./common_import"

policy_filter = (policy_obj)->
  return false if policy_obj.platform != "nodejs"
  return false if policy_obj.language != "iced"
  true

block_filter_gen = (type)->
  (root)->
    root.type == type

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

hydrator_def policy_filter, block_filter_gen("REPLACE_ME"), (root)->
  bdh_node_module_name_assign_on_call root, module, "REPLACE_ME"
  return
