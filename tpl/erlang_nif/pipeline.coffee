class @Pipeline
  mod         : null
  
  thread_list : []
  node_list   : []
  node_i_list : []
  node_o_list : []
  
  task_list : [] # every task should use this array, otherwise will be GC-collected
  task_free_list : []
  
  _default_layout : false
  default_msg_ring_size : 4096
  task_wip_count  : 0
  
  fn_hash : {}
  
  constructor : ()->
    @node_list  = []
    @node_i_list= []
    @node_o_list= []
    
    @task_list = []
    @task_free_list = []
    @fn_hash    = {}
  
  class_node  : null
  class_task  : null
  class_thread: null
  prefix_set : (prefix)->
    @class_node   = @mod[prefix+"node"]
    @class_task   = @mod[prefix+"task"]
    @class_thread = @mod[prefix+"thread"]
    return
  
  # ###################################################################################################
  #    
  # ###################################################################################################
  _node_create : (fn_index)->
    @node_list.push node = new @class_node
    if @_default_layout
      node_err = @node_o_list[0]
      i_pad = node.pad_o_add_sync()
      o_pad = node_err.pad_i_add_sync()
      node.link_sync i_pad, o_pad, node_err, @default_msg_ring_size
    node.fn_set_sync fn_index
    node
  
  node_create : (fn_name)->
    fn_index = @fn_hash[fn_name]
    if !fn_index?
      throw new Error "bad fn_name #{fn_name}"
    
    node = @_node_create fn_index
    # TODO set thread for node
    node
  
  node_create_in  : (fn_name)->
    fn_index = @fn_hash[fn_name]
    if !fn_index?
      throw new Error "bad fn_name #{fn_name}"
    
    node = @_node_create fn_index
    node.ep_i_sync @default_msg_ring_size
    @node_i_list.push node
    node
  
  node_create_out : (fn_name)->
    fn_index = @fn_hash[fn_name]
    if !fn_index?
      throw new Error "bad fn_name #{fn_name}"
    
    # не устанавливать out pad'ы при _default_layout
    @node_list.push node = new @class_node
    @node_o_list.push node
    node.ep_o_sync @default_msg_ring_size
    node.fn_set_sync fn_index
    node
  
  chain : (node_list...)->
    return if node_list.length < 2
    prev_node = node_list[0]
    for i in [1 ... node_list.length] by 1
      node = node_list[i]
      @link prev_node, node
      prev_node = node
    return
  
  link : (node_i, node_o)->
    pad_i = node_i.pad_o_add_sync()
    pad_o = node_o.pad_i_add_sync()
    node_i.link_sync pad_i, pad_o, node_o, @default_msg_ring_size
  
  # ###################################################################################################
  #    start/stop
  # ###################################################################################################
  start : ()->
    for thread in @thread_list
      thread.start_sync()
    return
  
  stop_hard : ()->
    for thread in @thread_list
      thread.stop_sync()
    return
  
  stop_soft : (opt, cb)->
    stop_hard_timeout = opt.stop_hard_timeout ? 10000
    # ###################################################################################################
    #    phase 1 wait for all tasks done
    # ###################################################################################################
    loop
      task_wip_count = @task_wip_count
      for node in @node_o_list
        task_wip_count -= node.task_pull_count_sync()
      
      break if task_wip_count <= 0
      await setTimeout defer(), 100
    
    # ###################################################################################################
    #    phase 2 schedule stop
    # ###################################################################################################
    for thread in @thread_list
      thread.stop_schedule_sync()
    
    # ###################################################################################################
    #    phase 3 wait for threads actually stop
    # ###################################################################################################
    start_ts = Date.now()
    loop
      thread_alive_count = 0
      for thread in @thread_list
        thread_alive_count += +thread.started_get_sync()
      
      break if thread_alive_count == 0
      
      if Date.now() - start_ts > stop_hard_timeout
        # ###################################################################################################
        #    phase 4 (optional) hard stop
        # ###################################################################################################
        puts "WARNING. Stop hard #{thread_alive_count} alive threads"
        # stop hard
        for thread in @thread_list
          thread.thread_stop_hard_sync()
        break
      
      await setTimeout defer(), 100
    
    cb()
  
  # ###################################################################################################
  #    default layout
  # ###################################################################################################
  default_layout : ()->
    @_default_layout = true
    fan_1n_mod_in = 1
    fan_n1_mod_out= 2
    
    node_err = @node_create_out "fan_n1_mod_out"
    
    # mod_in/out делает доп функциональность по установке служебных полей, чтобы этого не делать в основном потоке
    node_in  = @node_create_in  "fan_1n_mod_in"
    node_out = @node_create_out "fan_n1_mod_out"
    @thread_list.push sys_thread = new @class_thread
    sys_thread.node_attach_sync node_err
    sys_thread.node_attach_sync node_in
    sys_thread.node_attach_sync node_out
    
    return
  
  # use separate cpu_core_id_set, node node_attach_sync
  thread_alloc : ()->
    @thread_list.push thread = new @class_thread
    thread
  
  task_get : ()->
    ret = @task_free_list.pop()
    return ret if ret
    ret = new @class_task
    @task_list.push ret
    ret
  
  task_push : (task, i_node = @node_i_list[0])->
    @task_wip_count++
    free_count_left = i_node.task_push_sync task
    if free_count_left == 0
      perr "WARNING pipeline i ring soft overflow"
    free_count_left
  
  task_pull_count : ()->
    ret = 0
    for node_o in @node_o_list
      ret += node_o.task_pull_count_sync()
    ret
  
  task_pull : (node_o_list = @node_o_list)->
    # проверяет сначала output err node
    # потом output node
    for node_o, node_o_idx in node_o_list
      task = node_o.task_pull_sync()
      continue if !task
      task._node_o_idx = node_o_idx
      @task_wip_count--
      return task
    
    return null
  
  task_pull_ack : (task)->
    @task_free_list.push task
    return
