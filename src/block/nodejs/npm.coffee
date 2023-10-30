module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "../common_import"

# will be setted later in zz_npm_version
@default_package_version_hash = {}

# ###################################################################################################
#    npm_i
# ###################################################################################################
bdh_module_name_root module, "npm_i",
  nodegen       : (root, ctx)->
    walk = (root)->
      loop
        return ret if ret = root.tr_get_try "package_json", "package_json"
        return null if !root.parent
        root = root.parent
      return
    
    package_json_node = walk root
    if !package_json_node
      throw new Error "can't find any root with typed ref package_json"
    
    {
      package_name
      package_version
    } = root.data_hash
    
    if !package_version
      package_version = module.default_package_version_hash[package_name]
    
    if !package_version
      throw new Error "no package version specified for package_name=#{package_name}"
    
    {
      package_json
    } = package_json_node.data_hash
    
    if old_version = package_json.dependencies[package_name]
      if old_version != package_version
        throw new Error "npm version conflict package_name=#{package_name} old_version=#{curr_version} new_version=#{package_version}"
    else
      package_json.dependencies[package_name] = package_version
    
    false

def "npm_i", (package_name, package_version)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  anon_name = "#{package_name}_#{package_version}"
  
  root = mod_runner.current_runner.curr_root.tr_get "npm_i", anon_name, "def"
  bdh_node_module_name_assign_on_call root, module, "npm_i"
  root.data_hash.package_name   = package_name
  root.data_hash.package_version= package_version

# ###################################################################################################
#    npm_i_dev
# ###################################################################################################
bdh_module_name_root module, "npm_i_dev",
  nodegen       : (root, ctx)->
    walk = (root)->
      loop
        return ret if ret = root.tr_get_try "package_json", "package_json"
        return null if !root.parent
        root = root.parent
      return
    
    package_json_node = walk root
    if !package_json_node
      throw new Error "can't find any root with typed ref package_json"
    
    {
      package_name
      package_version
    } = root.data_hash
    
    if !package_version
      package_version = module.default_package_version_hash[package_name]
    
    if !package_version
      throw new Error "no package version specified for package_name=#{package_name}"
    
    {
      package_json
    } = package_json_node.data_hash
    
    if old_version = package_json.devDependencies[package_name]
      if old_version != package_version
        throw new Error "npm version conflict package_name=#{package_name} old_version=#{curr_version} new_version=#{package_version}"
    else
      package_json.devDependencies[package_name] = package_version
    
    false

def "npm_i_dev", (package_name, package_version)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  anon_name = "#{package_name}_#{package_version}"
  
  root = mod_runner.current_runner.curr_root.tr_get "npm_i_dev", anon_name, "def"
  bdh_node_module_name_assign_on_call root, module, "npm_i_dev"
  root.data_hash.package_name   = package_name
  root.data_hash.package_version= package_version
  
  root

# ###################################################################################################
#    node_loop_sh
# ###################################################################################################
bdh_module_name_root module, "node_loop_sh",
  emit_codegen  : (root, ctx)->
    ctx.file_render_exec "loop.sh", ctx.tpl_read "misc/loop.sh"
    false

def "node_loop_sh", ()->
  root = mod_runner.current_runner.curr_root.tr_get "node_loop_sh", "node_loop_sh", "def"
  bdh_node_module_name_assign_on_call root, module, "node_loop_sh"
  
  return


# ###################################################################################################
#    npm_script
# ###################################################################################################
bdh_module_name_root module, "npm_script",
  nodegen  : (root, ctx)->
    walk = (node)->
      loop
        return ret if ret = node.tr_get_try "package_json", "package_json"
        return null if !node.parent
        node = node.parent
      return
    
    package_json_node = walk root
    if !package_json_node
      throw new Error "can't find any node with typed ref package_json"
    
    {
      package_json
    } = package_json_node.data_hash
    
    {
      script_name
      script_command
    } = root.data_hash
    
    if old_script_command = package_json.scripts[script_name]
      if old_script_command != script_command
        throw new Error "script command conflict script_name=#{script_name} old_script_command=#{old_script_command} new_script_command=#{script_command}"
    else
      package_json.scripts[script_name] = script_command
    
    false

def "npm_script", (script_name, script_command)->
  root = mod_runner.current_runner.curr_root.tr_get "npm_script", script_name, "def"
  bdh_node_module_name_assign_on_call root, module, "npm_script"
  root.data_hash.script_name   = script_name
  root.data_hash.script_command= script_command
  
  root

# ###################################################################################################
#    misc
# ###################################################################################################
def "npm_all", ()->
  for k,v of module.default_package_version_hash
    puts k
    npm_i k
  return
