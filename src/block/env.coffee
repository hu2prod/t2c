module = @
fs = require "fs"
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "./common_import"

# ###################################################################################################
#    env
# ###################################################################################################
bdh_module_name_root module, "env",
  nodegen  : (root, ctx)->
    gitignore ".env"
    gitignore ".env.local"
    false
  
  emit_codegen  : (root, ctx)->
    path = "#{ctx.curr_folder}/.env"
    # не перетирать, а дописывать
    if fs.existsSync path
      old_cont = fs.readFileSync path, "utf-8"
      old_line_list = old_cont.split "\n"
      old_line_hash = {}
      for v in old_line_list
        continue if !v
        check_val = v.split("=")[0]
        old_line_hash[check_val] = true
      
      extra_line_list = []
      for line in root.data_hash.line_list
        check_val = line.split("=")[0]
        continue if old_line_hash[check_val]
        extra_line_list.push line
      
      if extra_line_list.length
        new_cont = old_cont + "\n" + extra_line_list.join "\n"
        ctx.file_render ".env", new_cont
    else
      new_cont = root.data_hash.line_list.join "\n"
      ctx.file_render ".env", new_cont
    
    false

def "env", (multi_line_str="")->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  project_node = mod_runner.current_runner.curr_root.type_filter_search "project"
  root = project_node.tr_get "env", "env", "def"
  # root = mod_runner.current_runner.curr_root.tr_get "env", "env", "def"
  bdh_node_module_name_assign_on_call root, module, "env"
  
  root.data_hash.line_list ?= []
  for line in multi_line_str.split "\n"
    line = line.trim()
    continue if !line
    root.data_hash.line_list.upush line
  
  root

