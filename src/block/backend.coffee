module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "./common_import"

# ###################################################################################################
#    backend
# ###################################################################################################
def "backend", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "backend", name, "def"
  root.policy_set_here_weak "hot_reload", true
  root.policy_set_here_weak "ws",     false
  root.policy_set_here_weak "http",   false
  # TODO https? (built-in)
  root.policy_set_here_weak "static", false
  root.policy_set_here_weak "ws_port",   21000
  root.policy_set_here_weak "http_port", 11000
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root
