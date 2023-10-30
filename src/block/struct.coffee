module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "./common_import"

def "struct", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "struct", name, "def"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

def "field", (name, type, opt={}, scope_fn=()->)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  if type.endsWith "?"
    type = type.substr 0, type.length-1
    opt.allow_null = true
  
  root = mod_runner.current_runner.curr_root.tr_get "field", name, "def"
  root.data_hash.type ?= type
  root.data_hash.opt  ?= opt
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root
