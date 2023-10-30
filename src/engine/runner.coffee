module = @
fs = require "fs"
{
  Phase_context_nodegen
  Phase_context_validator
  Phase_context_emit_code_bubble
  Phase_context_emit_codegen
  Phase_context_emit_min_deps
} = require "./ast_handler"
file_walk_recursive  = require "../util/file_walk_recursive"

@current_runner = null

# Legacy API
@go = (opt, cb)->
  # TODO lock
  # reset
  module.current_runner = new module.Runner
  {
    root_folder
    # unused yet
    verbose_phase_name
    verbose_bench
    verbose_repo_prefix
  } = opt
  
  if !fs.existsSync gen_folder = root_folder+"/gen"
    return cb new Error "missing gen #{gen_folder}"
  ordered_file_list = file_walk_recursive root_folder+"/gen"
  
  try
    for file in ordered_file_list
      delete require.cache[require.resolve(file)]
      require file
  catch err
    return cb err
  
  loc_opt = {
    code_bubble_path : root_folder + "/code_bubble"
    codegen_path     : root_folder
    build2_path      : root_folder
  }
  # Для удобства разработки и более красивого и простого кода сделано по-тупому.
  # Оно может кидать как throw так и возвращать через cb
  #   min_deps единственная (пока) асинхронная фаза
  
  cb2 = (err, res)->
    module.current_runner.delete()
    cb err, res
  
  try
    module.current_runner.go loc_opt, cb2
  catch err
    return cb2 err
  
  return

class @Runner
  # Корень документа
  root      : null
  
  # Корень куда достраивать
  curr_root : null
  root_stack_list : []
  
  constructor:()->
    @root_stack_list = []
  
  delete : ()->
    @root?.delete()
    @root = null
    
    # они уже null'ы, но если с ошибкой то надо
    @curr_root?.delete()
    @curr_root = null
    # p @root_stack_list
    for v in @root_stack_list
      # может быть null (в случае ошибки)
      v?.delete()
    
    @root_stack_list.clear()
    return
  
  root_push : (root)->
    @root_stack_list.push @curr_root
    @curr_root = root
    return
  
  root_pop : ()->
    if @root_stack_list.length == 0
      throw new Error "bad root_pop"
    @curr_root = @root_stack_list.pop()
    return
  
  root_wrap : (root, cb)->
    @root_push root
    cb?()
    @root_pop()
    return
  
  go : (opt, cb)->
    start_ts = Date.now()
    root = @root
    code_bubble_path= opt.code_bubble_path  ? "code_bubble"
    codegen_path    = opt.codegen_path      ? "."
    build2_path     = opt.build2_path       ? "."
    
    # NOTE. perf suboptimal
    walk = (t, fn)=>
      @root_push t
      already_processed_child_list = fn t
      if !already_processed_child_list
        # note child_list can extend. Pure for is not suitable
        # for v in t.child_list
        #   walk v, fn
        idx = 0
        while idx < t.child_list.length
          v = t.child_list[idx++]
          walk v, fn
      @root_pop t
      return
    
    walk_child_list_only = (t, fn, idx = 0)=>
      @root_push t
      # note child_list can extend. Pure for is not suitable
      # for v in t.child_list
      #   walk v, fn
      while idx < t.child_list.length
        v = t.child_list[idx++]
        walk v, fn
      @root_pop t
      
      return
    
    # for min deps
    # подозрение на то, что iced тут делает mem leak
    # walk_async = (t, fn, cb)->
      # await fn t, defer(err, already_processed_child_list); return cb err if err
      # if !already_processed_child_list
        # for v in t.child_list
          # await walk_async v, fn, defer(err); return cb err if err
      
      # cb()
    walk_async = (t, fn, cb)=>
      @root_push t
      fn t, (err, already_processed_child_list)=>
        @root_pop t
        return cb err if err
        if !already_processed_child_list
          list = t.child_list
          idx = 0
          len = list.length
          progress = ()->
            if idx >= len
              cb()
              return
            
            v = list[idx]
            idx++
            walk_async v, fn, (err)->
              return cb err if err
              progress()
          
          progress()
        else
          cb()
    
    # ###################################################################################################
    #    
    #    nodegen
    #    
    # ###################################################################################################
    # nodegen особенный. т.к. есть hydrator
    # nodegen может быть заранее не назначен пока не пройдет через node которая вызовет hydrator_apply
    
    ctx_nodegen = new Phase_context_nodegen
    ctx_nodegen.curr_folder = codegen_path
    
    found_count = 0
    walk_fn = (node)->
      # p "ctx_nodegen.hydrator_fn", !!ctx_nodegen.hydrator_fn, node.type, node.name
      ctx_nodegen.hydrator_fn? node
      
      if !node.nodegen
        throw new Error "node has no defined nodegen. name=#{node.name} type=#{node.type} src_nodegen=#{node.src_nodegen}"
      
      if !node.data_hash._nodegen_pass
        node.nodegen node, ctx_nodegen
        node.data_hash._nodegen_pass = true
        found_count++
      else
        # hotfix
        # тоже проходим для обновления, но не увеличиваем found_count
        node.nodegen node, ctx_nodegen
      
      return
    
    ctx_nodegen.walk_fn = walk_fn
    ctx_nodegen.walk_child_list_only_fn = (node, start_idx)->
      walk_child_list_only node, walk_fn, start_idx
    
    ctx_nodegen.inject_to = (target_root, scope_fn)->
      module.current_runner.root_wrap target_root, scope_fn
      # ctx_nodegen.walk_child_list_only_fn target_root
      walk_fn target_root
    
    walk root, walk_fn
    while found_count
      # puts "found_count #{found_count}"
      found_count = 0
      walk root, walk_fn
    
    # ###################################################################################################
    #    
    #    Validation
    #    
    # ###################################################################################################
    # ###################################################################################################
    #    Validation phase 1. basic checks
    # ###################################################################################################
    walk root, (node)->
      if !node.validator
        throw new Error "node has no defined validator. name=#{node.name} type=#{node.type} src_nodegen=#{node.src_nodegen}"
      false
    
    walk root, (node)->
      if !node.emit_codebub
        throw new Error "node has no defined emit_codebub. name=#{node.name} type=#{node.type} src_nodegen=#{node.src_nodegen}"
      false
    
    walk root, (node)->
      if !node.emit_codegen
        throw new Error "node has no defined emit_codegen. name=#{node.name} type=#{node.type} src_nodegen=#{node.src_nodegen}"
      false
    
    walk root, (node)->
      if !node.emit_min_deps
        throw new Error "node has no defined emit_min_deps. name=#{node.name} type=#{node.type} src_nodegen=#{node.src_nodegen}"
      false
    
    # ###################################################################################################
    #    Validation phase 2. Run validators
    # ###################################################################################################
    ctx_validator = new Phase_context_validator
    ctx_validator.curr_folder = codegen_path
    walk_fn = (node)->
      node.validator node, ctx_validator
    ctx_validator.walk_fn = walk_fn
    ctx_validator.walk_child_list_only_fn = (node, start_idx)->
      walk_child_list_only node, walk_fn, start_idx
    
    walk root, (node)->
      node.validator node, ctx_validator
    
    # ###################################################################################################
    #    
    #    Emit
    #    
    # ###################################################################################################
    # ###################################################################################################
    #    Emit phase 1. code bubble
    # ###################################################################################################
    ctx_emit_code_bubble = new Phase_context_emit_code_bubble
    ctx_emit_code_bubble.curr_folder = code_bubble_path
    
    walk_fn = (node)->
      node.emit_codebub node, ctx_emit_code_bubble
    ctx_emit_code_bubble.walk_fn = walk_fn
    ctx_emit_code_bubble.walk_child_list_only_fn = (node, start_idx)->
      walk_child_list_only node, walk_fn, start_idx
    walk root, (node)->
      node.emit_codebub node, ctx_emit_code_bubble
    
    # ###################################################################################################
    #    Emit phase 2. code gen
    # ###################################################################################################
    ctx_emit_codegen = new Phase_context_emit_codegen
    ctx_emit_codegen.curr_folder = codegen_path
    
    walk_fn = (node)->
      node.emit_codegen node, ctx_emit_codegen
    ctx_emit_codegen.walk_fn = walk_fn
    ctx_emit_codegen.walk_child_list_only_fn = (node, start_idx)->
      walk_child_list_only node, walk_fn, start_idx
    
    walk root, (node)->
      node.emit_codegen node, ctx_emit_codegen
    
    # ###################################################################################################
    #    Emit phase 3. min deps
    # ###################################################################################################
    ctx_emit_min_deps = new Phase_context_emit_min_deps
    ctx_emit_min_deps.curr_folder = codegen_path
    ctx_emit_min_deps.walk_child_list_only_fn = (node, start_idx, cb)=>
      idx = start_idx
      @root_push node
      # note child_list can extend. Pure for is not suitable
      # for v in node.child_list
      #   walk v, fn
      while idx < node.child_list.length
        v = node.child_list[idx++]
        await walk_async v, fn, defer(err); return cb err if err
      @root_pop node
      cb null
    
    # TODO walk_fn
    await
      loc_cb = defer(err)
      walk_async root, (node, inner_cb)->
        node.emit_min_deps node, ctx_emit_min_deps, inner_cb
      , loc_cb
    return cb err if err
    
    root.delete()
    ###
    TODO emit warnings for non-used policy
    ###
    elp_ts = Date.now() - start_ts
    mem = process.memoryUsage()
    p [
      "done in #{elp_ts} ms"
      "mem"
      mem.rss
      mem.heapTotal
      mem.heapUsed
    ].join " "
    
    cb()
    return
