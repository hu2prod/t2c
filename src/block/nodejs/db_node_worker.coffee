module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "../common_import"

# ###################################################################################################
#    db_node_worker
# ###################################################################################################
def "db_node_worker", (name)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  node = node_worker "db"
  node.data_hash.require_codebub = 'db = require "../db"'
  node.data_hash.code_codebub = '''
    if !table = db[req.table_name]
      return cb new Error "unknown table_name '#{req.table_name}'"
    
    # NOTE semi-vulnerable, consider whitelist for methods
    if !table[req.method_name]
      return cb new Error "unknown method_name '#{req.method_name}'"
    
    await table[req.method_name](req.req).cb defer(err, res); return cb err if err
    
    cb null, res
    '''#'
  
  return
