module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "./common_import"

# ###################################################################################################
#    frontend
# ###################################################################################################
def "frontend", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "frontend", name, "def"
  root.policy_set_here_weak "ws_hotreload_port",  20000
  root.policy_set_here_weak "http_port",          10000
  root.policy_set_here_weak "start_script",       true
  root.policy_set_here_weak "title",              root.parent.name # expect project node
  
  root.data_hash.node_com_hash ?= {}
  root.data_hash.node_storybook_com_hash ?= {}
  root.data_hash.storybook_file_hash ?= {}
  root.data_hash.com_hash   ?= {}
  root.data_hash.router_is_active ?= false
  root.data_hash.route_list ?= []
  root.data_hash.storybook_copy_list ?= [] # временно пишу туда found
  root.data_hash.ws_mod_sub ?= false
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    frontend_com
# ###################################################################################################
def "frontend frontend_com", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  name = name.toLowerCase()
  
  frontend_node = mod_runner.current_runner.curr_root.type_filter_search "frontend"
  root = frontend_node.tr_get "frontend_com", name, "def"
  # if root.parent.data_hash.node_com_hash[root.name]
    # throw new Error "frontend_com #{root.name} already defined"
  
  root.parent.data_hash.node_com_hash[root.name] = root
  root.data_hash.folder ?= "htdocs/_app_control"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    frontend_com_storybook
# ###################################################################################################
def "frontend frontend_com_storybook", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  name = name.toLowerCase()
  
  frontend_node = mod_runner.current_runner.curr_root.type_filter_search "frontend"
  root = frontend_node.tr_get "frontend_com_storybook", name, "def"
  # if root.parent.data_hash.node_storybook_com_hash[root.name]
    # throw new Error "frontend_com_storybook #{root.name} already defined"
  
  root.parent.data_hash.node_storybook_com_hash[root.name] = root
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    frontend_storybook_file
# ###################################################################################################
def "frontend frontend_storybook_file", (path)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  frontend_node = mod_runner.current_runner.curr_root.type_filter_search "frontend"
  root = frontend_node.tr_get "frontend_storybook_file", path, "def"
  
  root.parent.data_hash.storybook_file_hash[root.name] = root
  
  root
