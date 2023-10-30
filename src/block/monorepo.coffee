module = @
mkdirp = require "mkdirp"
{
  Node
  
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "./common_import"

# ###################################################################################################
#    monorepo
# ###################################################################################################
###
TODO
  collect package.json (хотя бы scripts)
###
walk = (t, fn)=>
  already_processed_child_list = fn t
  if !already_processed_child_list
    mod_runner.current_runner.root_push t
    # note child_list can extend. Pure for is not suitable
    # for v in t.child_list
    #   walk v, fn
    idx = 0
    while idx < t.child_list.length
      v = t.child_list[idx++]
      walk v, fn
    mod_runner.current_runner.root_pop t
  
  return


bdh_module_name_root module, "monorepo",
  nodegen       : (root, ctx)->
    for child in root.child_list
      if child.type != "project"
        throw new Error "monorepo should have only project child #{child.name}:#{child.type} found"
      
      ctx.folder_wrap child.name, ()->
        walk child, (node)->
          ctx.walk_fn node
    
    true
  
  validator     : (root, ctx)->
    for child in root.child_list
      ctx.folder_wrap child.name, ()->
        walk child, (node)->
          ctx.walk_fn node
    true
  
  emit_codebub  : (root, ctx)->
    for child in root.child_list
      ctx.folder_wrap child.name, ()->
        walk child, (node)->
          ctx.walk_fn node
    true
  
  emit_codegen  : (root, ctx)->
    for child in root.child_list
      mkdirp.sync "#{ctx.curr_folder}/#{child.name}"
      ctx.folder_wrap child.name, ()->
        walk child, (node)->
          ctx.walk_fn node
    true
  
  emit_min_deps : (root, ctx, cb)->
    # COPYPASTED from runner
    walk_async = (t, fn, cb)->
      await fn t, defer(err, already_processed_child_list); return cb err if err
      if !already_processed_child_list
        for v in t.child_list
          await walk_async v, fn, defer(err); return cb err if err
      cb()
    
    for child in root.child_list
      # async folder wrap
      ctx.folder_push child.name
      await
        loc_cb = defer(err)
        walk_async child, (node, inner_cb)->
          node.emit_min_deps node, ctx, inner_cb
        , loc_cb
      ctx.folder_pop()
      return cb err if err
    cb null, true

def "monorepo", (name, scope_fn)->
  if mod_runner.current_runner.root
    throw new Error "root node position is already captured"
  
  mod_runner.current_runner.root = root = new Node
  root.name = name
  root.type = "monorepo"
  
  bdh_node_module_name_assign_on_call root, module, "monorepo"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  service_port_offset root
  
  root
