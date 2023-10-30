module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "./common_import"

def "fn", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "function", name, "def"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

def "arg", (name, type, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "arg", name, "def"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root
