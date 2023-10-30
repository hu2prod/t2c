module = @
fs = require "fs"
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "../common_import"

# ###################################################################################################
#    npmrc
# ###################################################################################################
bdh_module_name_root module, "npmrc",
  emit_codegen  : (root, ctx)->
    path = "#{ctx.curr_folder}/.npmrc"
    # не перетирать, а дописывать
    if fs.existsSync path
      old_cont = fs.readFileSync path, "utf-8"
      old_line_list = old_cont.split "\n"
      old_line_hash = {}
      for v in old_line_list
        continue if !v
        old_line_hash[v] = true
      
      extra_line_list = []
      for line in root.data_hash.line_list
        continue if old_line_hash[line]
        extra_line_list.push line
      
      if extra_line_list.length
        new_cont = old_cont + "\n" + extra_line_list.join "\n"
        ctx.file_render ".npmrc", new_cont
    else
      new_cont = root.data_hash.line_list.join "\n"
      ctx.file_render ".npmrc", new_cont
    
    false

def "npmrc", (multi_line_str="")->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  project_node = mod_runner.current_runner.curr_root.type_filter_search "project"
  root = project_node.tr_get "npmrc", "npmrc", "def"
  # root = mod_runner.current_runner.curr_root.tr_get "npmrc", "npmrc", "def"
  bdh_node_module_name_assign_on_call root, module, "npmrc"
  
  root.data_hash.line_list ?= []
  for line in multi_line_str.split "\n"
    line = line.trim()
    continue if !line
    root.data_hash.line_list.upush line
  
  root

