module = @
{
  Node
  
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  hydrator_list_filter
  hydrator_apply
  
  mod_runner
  mod_config
} = require "./common_import"

# ###################################################################################################
#    util
# ###################################################################################################
class @Arch
  name        : ""
  node_version: ""
  os          : ""
  arch        : ""

class @Build2_ent
  name    : ""
  payload : ""
  dependency_list : []
  
  constructor:()->
    @dependency_list = []
  

class @Build2_descriptor
  file_render_done : false
  ent_list : []
  ent_hash : []
  
  constructor:()->
    @ent_list = []
    @ent_hash = []
    @ext_import_file_list = []
    @ext_import_file_hash = []
  
  ent_get : (name)->
    if !ret = @ent_hash[name]
      @ent_hash[name] = ret = new module.Build2_ent
      @ent_list.push ret
      ret.name = name
    ret

# ###################################################################################################
#    project
# ###################################################################################################
bdh_module_name_root module, "project",
  nodegen : (root, ctx)->
    # ###################################################################################################
    #    default policy set
    # ###################################################################################################
    if root.policy_get_val_no_use("platform") == "nodejs"
      root.policy_set_here_weak "language", "iced"
      root.policy_set_here_weak "package_manager", "pnpm"
    
    # ###################################################################################################
    platform = root.policy_get_val_use("platform")
    
    mod_runner.current_runner.root_wrap root, ()->
      node = gitignore()
      node.src_nodegen = "project"
    
    # ###################################################################################################
    #    nodejs
    # ###################################################################################################
    if platform == "nodejs"
      mod_runner.current_runner.root_wrap root, ()->
        gitignore "node_modules"
        package_json_node = package_json()
        package_json_node.src_nodegen = "project"
        obj = {
          name          : root.name
          version     : root.policy_get_val_use_default "version",      "1.0.0"
          description: root.policy_get_val_use_default "description",  ""
          # TEMP disabled for electron
          # "main"        : root.policy_get_val_use_default "main",         "index.js"
          scripts     : {}
          keywords    : root.policy_get_val_use_default "keywords",     []
          
          # TODO global settings
          # TODO OR get current github user (if possible)
          # TODO OR get current user (if != root)
          author      : {
            name : root.policy_get_val_use_default "author",       "vird"
            email: root.policy_get_val_use_default "author_email", "virdvip@gmail.com"
          }
          license     : root.policy_get_val_use_default "license",      "MIT"
          dependencies: {}
          devDependencies: {}
        }
        # weak obj_set
        for k,v of obj
          package_json_node.data_hash.package_json[k] ?= v
        return
    
    # ###################################################################################################
    #    hydrator
    # ###################################################################################################
    policy_obj = {
      platform
      language : root.policy_get_val_use "language"
    }
    h_list = hydrator_list_filter policy_obj
    
    ctx.hydrator_fn = (t)->
      hydrator_apply h_list, t
      return
    
    false
  
  emit_codegen  : (root, ctx)->
    if root.data_hash.build2_desc.ent_list.length == 0
      ctx.file_delete "build2.json"
      ctx.file_delete "arch_linux_list"
      ctx.file_delete "arch_win_list"
    else
      ent_list = []
      for ent in root.data_hash.build2_desc.ent_list
        ent_list.push {
          name            : ent.name
          payload         : ent.payload
          dependency_list : ent.dependency_list
        }
      ctx.file_render "build2.json", JSON.stringify {
        ent_list
      }, null, 2
      
      arch_list = Object.values root.data_hash.arch_hash
      
      arch_list_linux = arch_list.filter (t)->t.os == "linux"
      if arch_list_linux.length
        ctx.file_render "arch_linux_list", arch_list_linux.map((t)->t.name).join "\n"
      else
        ctx.file_delete "arch_linux_list"
      
      arch_list_win = arch_list.filter (t)->t.os == "win"
      if arch_list_win.length
        ctx.file_render "arch_win_list", arch_list_win.map((t)->t.name).join "\n"
      else
        ctx.file_delete "arch_win_list"
    
    false
  
  # Подумать надо ли какая-то валидация
  # TODO нужно проверять что нет вложенных проектов

def "project", (name, scope_fn)->
  if mod_runner.current_runner.curr_root
    if mod_runner.current_runner.curr_root.type != "monorepo"
      throw new Error "root node position is already captured and it's not monorepo"
  
  if mod_runner.current_runner.curr_root
    root = mod_runner.current_runner.curr_root.tr_get "monorepo", name, "def"
  else
    mod_runner.current_runner.root = root = new Node
  
  root.name = name
  root.type = "project"
  root.data_hash.build2_desc ?= new module.Build2_descriptor
  
  root.data_hash.os_hash  ?= {}
  root.data_hash.arch_hash?= {}
  root.data_hash.arch_get ?= (name)->
    {
      arch_hash
      os_hash
    } = root.data_hash
    if !ret = arch_hash[name]
      arch_hash[name] = ret = new module.Arch
      ret.name = name
      
      # node_version == node16 (prefixed)
      [node_version, os, arch] = name.split "-"
      
      ret.node_version = node_version
      ret.os           = os
      ret.arch         = arch
      
      os_hash[os] = true
    
    ret
  
  bdh_node_module_name_assign_on_call root, module, "project"
  
  root.policy_set_here_weak "platform", "nodejs"
  
  service_port_offset root
  
  mod_runner.current_runner.root_wrap root, ()->
    arch mod_config.curr_arch
    scope_fn()
  
  root

# ###################################################################################################
#    arch
# ###################################################################################################
def "arch", (name)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  project_node = mod_runner.current_runner.curr_root.type_filter_search "project"
  project_node.data_hash.arch_get name
  
  return

# ###################################################################################################
#    build2
# ###################################################################################################
def "build2", (name, cmd, dep_list = [])->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  project_node = mod_runner.current_runner.curr_root.type_filter_search "project"
  {build2_desc} = project_node.data_hash
  ent     = build2_desc.ent_get name
  ent.payload = cmd
  ent.dependency_list = dep_list
  
  return

def "service_port_offset", (root)->
  # TODO move to something parallel
  root.data_hash.autoport_service_list_hash ?= {}
  root.policy_set_here_weak "service_port_offset", 0
  root.data_hash.get_autoport_offset = (service_type, target_node)->
    hash = root.data_hash.autoport_service_list_hash
    hash[service_type] ?= []
    list = hash[service_type]
    idx = list.idx target_node
    if idx == -1
      idx = list.length
      list.push target_node
    
    return idx + root.policy_get_val_use "service_port_offset"
  
  return
