module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "./common_import"

# TODO может короче имя для вложенных компонентов
# starter_tmux_split_h -> split_h
# starter_tmux_split_v -> split_v
# starter_tmux_service -> service


# ###################################################################################################
class Starter_tmux_pane
  idx       : 0 # DEBUG
  parent    : null
  split_type: "no"
  pre_code  : ""
  post_code : ""
  code      : ""
  list      : []
  
  constructor:()->
    @list = []
  
  delete : ()->
    @parent = null
    for v in @list
      v.delete()
    @list.clear()
  
  to_code : ()->
    jl = []
    jl.push @pre_code
    if @list.length
      for v in @list
        jl.push v.to_code()
        jl.push @code
      jl.pop()
    else
      jl.push @code
    jl.push @post_code
    
    """
    #{join_list jl, ""}
    """

class Starter_tmux_context
  name : ""
  type : ""
  root_pane : null
  curr_pane : null
  # TODO configure over policy
  delay : "0.1"
  
  constructor:()->
    @curr_pane = @root_pane = new Starter_tmux_pane
  
  delete : ()->
    @root_pane.delete()
    return
  
  mk_pane : ()->
    ret = new Starter_tmux_pane
    ret.parent = @curr_pane
    @curr_pane.list.push ret
    @curr_pane = ret
    ret

# ###################################################################################################
get_starter_tmux_root = ()->
  mod_runner.current_runner.curr_root.type_filter_search "project"

get_local_tmux_root = ()->
  root = mod_runner.current_runner.curr_root
  while root
    return root if root.type == "starter_tmux"
    root = root.parent
  
  throw new Error "can't find starter_tmux"

starter_tmux_init = ()->
  {data_hash} = get_starter_tmux_root()
  data_hash.starter_tmux ?= {}
  data_hash.starter_tmux.type_to_service_to_code_hash ?= {}
  return

def "starter_tmux_set", (name, type, start_bash_code)->
  {data_hash} = get_starter_tmux_root()
  starter_tmux_init()
  
  {type_to_service_to_code_hash} = data_hash.starter_tmux
  
  type_to_service_to_code_hash[type] ?= {}
  type_to_service_to_code_hash[type][name] = start_bash_code
  
  return

# ###################################################################################################
#    starter_tmux
# ###################################################################################################
bdh_module_name_root module, "starter_tmux",
  nodegen       : (root, ctx)->
    {
      name
      type
      data_hash
    } = root
    
    project_node  = root.type_filter_search "project"
    data_hash.screen_name = "#{project_node.name}_#{name}"
    
    npm_script "starter:tmux:#{name}:#{type}", "./starter/tmux_#{name}_#{type}.sh"
    
    false
  
  emit_codegen  : (root, ctx)->
    {
      name
      type
    } = root
    {screen_name} = root.data_hash
    
    ctx.file_render_exec "starter/tmux_#{name}_#{type}.sh", """
      #!/bin/bash
      if screen -S #{screen_name} -Q select .; then
        echo "can't start, already started"
        exit 1
      fi
      ./starter/_tmux_#{name}_#{type}.sh &
      screen -S #{screen_name}
      """#"
    
    # TODO policy
    before_tmux_wait  = 0.5
    after_tmux_wait   = 1
    
    ctx.file_render_exec "starter/_tmux_#{name}_#{type}.sh", """
      #!/bin/bash
      while ! screen -S #{screen_name} -Q select . ; do
        sleep 0.1
      done
      sleep #{before_tmux_wait}
      
      screen -S #{screen_name} -X -p 0 stuff "tmux\\n"
      sleep #{after_tmux_wait}
      #{root.data_hash.tmux_ctx.root_pane.to_code()}
      
      """#"
    
    false

def "starter_tmux", (name, type, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  starter_tmux_init()
  
  root = mod_runner.current_runner.curr_root.tr_get "starter_tmux", "#{name}_#{type}", "def"
  bdh_node_module_name_assign_on_call root, module, "starter_tmux"
  root.data_hash.tmux_ctx = tmux_ctx = new Starter_tmux_context
  tmux_ctx.name = name
  tmux_ctx.type = type
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    starter_tmux_split_h
# ###################################################################################################
bdh_module_name_root module, "starter_tmux_split_h",
  # Микрокостыль. Нельзя на уровне nodegen проверить все сервисы, они могут быть догенерированы
  validator       : (root, ctx)->
    {
      screen_name
      tmux_ctx
    } = get_local_tmux_root().data_hash
    
    old_pane = tmux_ctx.curr_pane
    unless old_pane.split_type in ["h", "no"]
      throw new Error "conflict split type '#{old_pane.split_type}'"
    
    
    tmux_ctx.mk_pane()
    
    ctx.walk_child_list_only_fn root
    
    {curr_pane} = tmux_ctx
    if curr_pane.split_type == "no" and curr_pane.parent
      curr_pane.parent.list.remove curr_pane
    
    old_pane.split_type = "h"
    pre_code_r = """
      sleep #{tmux_ctx.delay}
      screen -S #{screen_name} -X -p 0 stuff "^B"
      sleep #{tmux_ctx.delay}
      screen -S #{screen_name} -X -p 0 stuff "%"
      
      """#"
    pre_code_l = """
      sleep #{tmux_ctx.delay}
      screen -S #{screen_name} -X -p 0 stuff "^B"
      sleep #{tmux_ctx.delay}
      screen -S #{screen_name} -X -p 0 stuff "^[[D"
      
      """#"
    old_pane.pre_code = """
      # create tabs h
      #{pre_code_r.repeat old_pane.list.length-1}
      #{pre_code_l.repeat old_pane.list.length-1}
      # fill tabs h
      """#"
    old_pane.post_code = """
      # reset tab pos v
      #{pre_code_l.repeat old_pane.list.length-1}
      """#"
    
    old_pane.code = """
      # next h
      sleep #{tmux_ctx.delay}
      screen -S #{screen_name} -X -p 0 stuff "^B"
      sleep #{tmux_ctx.delay}
      screen -S #{screen_name} -X -p 0 stuff "^[[C"
      
      """#"
    
    tmux_ctx.curr_pane = old_pane
    if tmux_ctx.curr_pane.parent
      tmux_ctx.curr_pane = tmux_ctx.curr_pane.parent
      tmux_ctx.mk_pane()
    
    true

def "starter_tmux starter_tmux_split_h", (scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.mk_child "starter_tmux_split_h", "", "def"
  bdh_node_module_name_assign_on_call root, module, "starter_tmux_split_h"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  root

# ###################################################################################################
#    starter_tmux_split_v
# ###################################################################################################
bdh_module_name_root module, "starter_tmux_split_v",
  # Микрокостыль. Нельзя на уровне nodegen проверить все сервисы, они могут быть догенерированы
  validator       : (root, ctx)->
    {
      screen_name
      tmux_ctx
    } = get_local_tmux_root().data_hash
    
    old_pane = tmux_ctx.curr_pane
    unless old_pane.split_type in ["v", "no"]
      throw new Error "conflict split type '#{old_pane.split_type}'"
    
    tmux_ctx.mk_pane()
    
    ctx.walk_child_list_only_fn root
    
    {curr_pane} = tmux_ctx
    if curr_pane.split_type == "no" and curr_pane.parent
      curr_pane.parent.list.remove curr_pane
    
    old_pane.split_type = "v"
    old_pane.code = """
      # next v
      sleep #{tmux_ctx.delay}
      screen -S #{screen_name} -X -p 0 stuff "^B"
      sleep #{tmux_ctx.delay}
      screen -S #{screen_name} -X -p 0 stuff "^[[B"
      
      """#"
    
    
    pre_code_d = """
      sleep #{tmux_ctx.delay}
      screen -S #{screen_name} -X -p 0 stuff "^B"
      sleep #{tmux_ctx.delay}
      screen -S #{screen_name} -X -p 0 stuff "\\""
      
      """#"
    pre_code_u = """
      sleep #{tmux_ctx.delay}
      screen -S #{screen_name} -X -p 0 stuff "^B"
      sleep #{tmux_ctx.delay}
      screen -S #{screen_name} -X -p 0 stuff "^[[A"
      
      """#"
    old_pane.pre_code = """
      # create tabs v
      #{pre_code_d.repeat old_pane.list.length-1}
      #{pre_code_u.repeat old_pane.list.length-1}
      # fill tabs v
      """#"
    old_pane.post_code = """
      # reset tab pos v
      #{pre_code_u.repeat old_pane.list.length-1}
      """#"
    
    tmux_ctx.curr_pane = old_pane
    if tmux_ctx.curr_pane.parent
      tmux_ctx.curr_pane = tmux_ctx.curr_pane.parent
      tmux_ctx.mk_pane()
    
    true

def "starter_tmux starter_tmux_split_v", (scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.mk_child "starter_tmux_split_v", "", "def"
  bdh_node_module_name_assign_on_call root, module, "starter_tmux_split_v"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  root

# ###################################################################################################
#    starter_tmux_service
# ###################################################################################################
bdh_module_name_root module, "starter_tmux_service",
  # Микрокостыль. Нельзя на уровне nodegen проверить все сервисы, они могут быть догенерированы
  validator : (root, ctx)->
    {type_to_service_to_code_hash} = get_starter_tmux_root().data_hash.starter_tmux
    
    {
      screen_name
      tmux_ctx
    } = get_local_tmux_root().data_hash
    
    type_hash = type_to_service_to_code_hash[tmux_ctx.type]
    if !type_hash?
      throw new Error "unknown starter type '#{tmux_ctx.type}'"
    
    code = type_hash[root.name]
    if !code?
      puts "known service list"
      for k,v of type_hash
        puts "  #{k}"
      throw new Error "unknown service '#{root.name}'"
    
    code += "\n"
    # \n escape in string
    code = code.split("\n").join("\\n")
    
    code = """
      sleep #{tmux_ctx.delay}
      screen -S #{screen_name} -X -p 0 stuff "#{code}"
      """#"
    
    if tmux_ctx.curr_pane.split_type != "no"
      throw new Error "service pane should have split type 'no'. Got split_type='#{tmux_ctx.curr_pane.split_type}'"
    tmux_ctx.curr_pane.split_type = "service"
    tmux_ctx.curr_pane.code = code
    if parent = tmux_ctx.curr_pane.parent
      tmux_ctx.curr_pane = parent
      tmux_ctx.mk_pane()
    
    false

def "starter_tmux starter_tmux_service", (name)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "starter_tmux_service", name, "def"
  bdh_node_module_name_assign_on_call root, module, "starter_tmux_service"
  
  root

# ###################################################################################################
#    starter_tmux_custom
# ###################################################################################################
bdh_module_name_root module, "starter_tmux_custom",
  # Микрокостыль. Нельзя на уровне nodegen проверить все сервисы, они могут быть догенерированы
  validator : (root, ctx)->
    {
      screen_name
      tmux_ctx
    } = get_local_tmux_root().data_hash
    
    code = root.name
    if root.name
      code += "\n"
    # \n escape in string
    code = code.split("\n").join("\\n")
    
    code = """
      sleep #{tmux_ctx.delay}
      screen -S #{screen_name} -X -p 0 stuff "#{code}"
      """#"
    
    if tmux_ctx.curr_pane.split_type != "no"
      throw new Error "service pane should have split type 'no'. Got split_type='#{tmux_ctx.curr_pane.split_type}'"
    tmux_ctx.curr_pane.split_type = "service" # TODO change
    tmux_ctx.curr_pane.code = code
    if parent = tmux_ctx.curr_pane.parent
      tmux_ctx.curr_pane = parent
      tmux_ctx.mk_pane()
    
    false

def "starter_tmux_custom", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # странная особенность, но ладно, пока проехали
  root = mod_runner.current_runner.curr_root.tr_get "starter_tmux_custom", name, "def"
  bdh_node_module_name_assign_on_call root, module, "starter_tmux_custom"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root
