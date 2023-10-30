module = @
require "event_mixin"
require "lock_mixin"
db = require "../db"
config = require "../config"
# api = require "./index"

@perf_log = true
@debug_log= true
@on_missing_key_id = "drop"

class @LLM_key_queue
  parent_vendor : null
  key_id : 0
  scheduled_queue_list  : []
  in_progress_queue_list: []
  rate_limit_task       : null
  default_limit         : 0
  
  _deleted : false
  event_mixin @
  lock_mixin @
  constructor:(@parent_vendor, @key_id, @default_limit)->
    event_mixin_constructor @
    lock_mixin_constructor @
    @$limit = @default_limit
    
    @scheduled_queue_list   = []
    @in_progress_queue_list = []
  
  delete : ()->
    @_deleted = true
  
  item_count_get : ()->
    @scheduled_queue_list.length + @in_progress_queue_list.length
  
  rate_limit_on : (task)->
    if @rate_limit_task
      old_idx = @scheduled_queue_list.idx @rate_limit_task
      new_idx = @scheduled_queue_list.idx task
      return if old_idx < new_idx
    
    if module.debug_log
      puts "DEBUG rate_limit_on key_id=#{@key_id}"
    @rate_limit_task = task
    @$limit = 1
    return
  
  rate_limit_off : (task)->
    if @rate_limit_task == task
      if module.debug_log
        puts "DEBUG rate_limit_off key_id=#{@key_id}"
      @rate_limit_task = null
      @$limit = @default_limit
    return
  
  task_push : (task)->
    @scheduled_queue_list.push task
    @dispatch "push"
    return
  
  # TODO rework. Single handler for all queues inside vendor
  # current cons: multiple timers
  do_loop : ()->
    do ()=>
      while !@_deleted
        if @scheduled_queue_list.length == 0
          await
            unlock = defer()
            cb = (err)=>
              return if !unlock
              @off "push", cb
              old_unlock = unlock
              unlock = null
              old_unlock()
            setTimeout cb, 100
            @once "push", cb
          continue
        
        task = @scheduled_queue_list.shift()
        # task wait
        d_ts = Date.now() - new Date task.updatedAt
        if module.perf_log
          puts "PERF task queue wait #{d_ts} ms"
        
        await @lock defer()
        loc_opt = {
          task
          queue : @
        }
        
        @in_progress_queue_list.push task
        @parent_vendor.progress_fn loc_opt, (err, res)=>
          if err
            perr err
          @unlock()
      return

class @LLM_vendor
  # replace me
  name : ""
  retry_count     : 20
  queue_load_fn   : null
  build_request_fn: null
  make_request_fn : null
  progress_fn     : null # причина - слишком много openai-specific костылей
  
  task_in_progress_queue_list : []
  
  # WARNING в queue могут быть дырки (queue с limit = 0)
  queue_list : []
  
  _handler_complete : null
  event_mixin @
  constructor : ()->
    event_mixin_constructor @
    @task_in_progress_queue_list = []
    @queue_list = []
    @on "llm_gen_complete", @_handler_complete = ()=>
      while @task_in_progress_queue_list.length
        task = @task_in_progress_queue_list[0]
        
        return if !best_queue = @_pick_best_queue()
        @task_in_progress_queue_list.shift()
        best_queue.task_push task
      return
  
  _deleted : false
  delete : ()->
    @_deleted = true
    @off "llm_gen_complete", @_handler_complete
    @task_in_progress_queue_list.clear()
    for queue in @queue_list
      queue.delete()
    return
  
  # ###################################################################################################
  #    misc internal
  # ###################################################################################################
  _pick_best_queue : ()->
    best_queue = @queue_list[0]
    for queue in @queue_list
      if best_queue.item_count_get() > queue.item_count_get()
        best_queue = queue

    return null if best_queue.item_count_get() >= best_queue.$limit
    best_queue
  
  # ###################################################################################################
  #    API
  # ###################################################################################################
  task_push : (task)->
    if @_deleted
      puts "IGNORED task #{task.id} (reason LLM_vendor is deleted)"
      return false
    
    if task.key_id?
      if queue = @queue_list[task.key_id]
        queue.task_push task
        return true
      
      if module.on_missing_key_id == "reroute"
        perr "WARNING. Missing key_id. Task rerouted task.id=#{task.id}"
        task.key_id = null
        # WARNING db will not update key_id until status=IN_PROGRESS
      else # if module.on_missing_key_id == "drop"
        perr "CRITICAL. Missing key_id. Task dropped task.id=#{task.id}"
        return
    
    best_queue = @_pick_best_queue()
    
    if !best_queue
      @task_in_progress_queue_list.push task
      return false
    else
      if module.debug_log
        puts "DEBUG instant"
      best_queue.task_push task
      return true
  