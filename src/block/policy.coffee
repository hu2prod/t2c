module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "./common_import"

def "policy_set", (key, val)->
  mod_runner.current_runner.curr_root.policy_set_here key, val
  return

