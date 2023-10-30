module = @
fs = require "fs"
{execSync} = require "child_process"
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
  mod_config
} = require "./common_import"

# ###################################################################################################
#    cache
# ###################################################################################################
bdh_module_name_root module, "cache",
  nodegen  : (root, ctx)->
    gitignore "cache"
    false
  
  validator  : (root, ctx)->
    if !mod_config.local_config.cache_path
      throw new Error "!local_config.cache_path"
    false
  
  emit_codegen  : (root, ctx)->
    project_node = root.type_filter_search "project"
    
    remote_path = "#{mod_config.local_config.cache_path}/#{project_node.name}_cache"
    execSync "mkdir -p #{remote_path}"
    if !fs.existsSync "cache"
      execSync "ln -s #{remote_path} cache"
    
    false
 

def "cache", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  project_node = mod_runner.current_runner.curr_root.type_filter_search "project"
  root = project_node.tr_get "cache", "cache", "def"
  # root = mod_runner.current_runner.curr_root.tr_get "cache", "cache", "def"
  bdh_node_module_name_assign_on_call root, module, "cache"
  
  root
