module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "./common_import"

def "leveldb", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # reason. No conflict with db
  name ||= "leveldb"
  
  root = db name, scope_fn
  root.policy_get("type")   .val = "leveldb"
  root.policy_get("driver") .val = "raw"
  
  root

# осторожно, не имеет механизм backup'а. Копируй как есть