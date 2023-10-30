module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "./common_import"

# Прим. применим как для frontend так и для backend

# ###################################################################################################
#    router
# ###################################################################################################
def "router", (scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "router", "router", "def"
  root.data_hash.route_com_hash ?= {}
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    router_endpoint
# ###################################################################################################
# TODO alias router_ep, route (опасно, 1 буква разницы с router)
# Вопрос. А какой "физический смысл" в com и title для backend например?
# com ... ну пускай может быть handler'ом
# title - html title? А если там JSON?
def "router router_endpoint", (path, com, title, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "router_endpoint", path, "def"
  
  is_parametric = path.includes "<"
  if is_parametric and !com
    throw new Error "com should be explicit when parametric route"
  
  if !com
    com = path
  
  if !title
    title = com
    title = title.split("_").join(" ")
    title = title.capitalize()
  
  root.data_hash.path   ?= path
  root.data_hash.com    ?= com
  root.data_hash.title  ?= title
  root.data_hash.is_parametric ?= is_parametric
  
  # Прим. при включении заменяет аналог t1c frontend_router_com_wrap
  root.policy_set_here_weak "wrap", false
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root
