module = @
fs = require "fs"
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
  mod_config
} = wtf = require "./common_import"

# ###################################################################################################
#    file_render
# ###################################################################################################
bdh_module_name_root module, "file_render",
  emit_codegen  : (root, ctx)->
    ctx.file_render root.name, root.data_hash.content
    false

def "file_render", (name, content)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # немного под вопросом на какой root вешать
  
  root = mod_runner.current_runner.curr_root.tr_get "file_render", name, "def"
  bdh_node_module_name_assign_on_call root, module, "file_render"
  root.data_hash.content ?= content
  
  root

