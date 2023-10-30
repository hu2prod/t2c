module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
  iced_compile
} = require "../../common_import"

erlang_nif_decl = require "./erlang_nif_decl"

###
still missing
t1 erlang_nif fn          mod_pipeline task_wip_count ret:u32
###

# ###################################################################################################
#    erlang_nif_pipeline
# ###################################################################################################
bdh_module_name_root module, "erlang_nif_pipeline",
  nodegen       : (root, ctx)->
    erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
    {erlang_nif_module} = erlang_nif_package_node.data_hash
    
    pipeline_decl = root.data_hash.erlang_nif_pipeline_decl
    
    pipeline_name = pipeline_decl.name
    package_name  = erlang_nif_module.name
    
    class_node  = "#{pipeline_name.capitalize()}_node"
    class_task  = "#{pipeline_name.capitalize()}_task"
    class_thread= "#{pipeline_name.capitalize()}_thread"
    
    # ###################################################################################################
    #    
    #    misc
    #    
    # ###################################################################################################
    # Прим. только для linux архитектур
    # TODO сделать кроссплатформенно
    erlang_nif_config_lib "-lpthread", /linux/
    
    erlang_nif_thread_util()
    
    # ###################################################################################################
    #    class task
    # ###################################################################################################
    class_name = "#{pipeline_name.capitalize()}_task"
    root.data_hash.class_ast_node = erlang_nif_class class_name, ()->
      erlang_nif_class_kt "task_instance_uid",  "i32"
      erlang_nif_class_kt "task_uid",           "i32"
      erlang_nif_class_kt "curr_fn_index",      "i32"
      
      erlang_nif_class_constructor_raw "_this->task_instance_uid = ++#{pipeline_name}_global_task_instance_uid;"
      
      erlang_nif_fn "task_instance_uid_get", ()->
        erlang_nif_fn_arg "ret", "i32"
        erlang_nif_fn_raw_fixed_code """
          ret = _this->task_instance_uid;
          """
    
    # ###################################################################################################
    #    class node
    # ###################################################################################################
    erlang_nif_class class_node, ()->
      pad_type = "std::vector<Message_ring<#{pipeline_name.capitalize()}_task>*>"
      erlang_nif_class_field_raw "#{pad_type} pad_i_list"
      erlang_nif_class_field_raw "#{pad_type} pad_o_list"
      erlang_nif_class_kt "fn_index",   "u32"
      erlang_nif_class_kt "thread_set", "bool"
      erlang_nif_class_kt "heartbeat_counter",   "u32"
      
      erlang_nif_class_field_raw "bool (*fn)(#{class_node}*, #{class_thread}*)"
      
      erlang_nif_fn "pad_reset", ()->
        erlang_nif_fn_raw_fixed_code """
          _this->pad_i_list.resize(0);
          _this->pad_o_list.resize(0);
          """
      
      erlang_nif_fn "pad_i_add", ()->
        erlang_nif_fn_arg "ret", "u32"
        
        erlang_nif_fn_raw_fixed_code """
          ret = _this->pad_i_list.size();
          _this->pad_i_list.push_back(nullptr);
          """
      
      erlang_nif_fn "pad_o_add", ()->
        erlang_nif_fn_arg "ret", "u32"
        
        erlang_nif_fn_raw_fixed_code """
          ret = _this->pad_o_list.size();
          _this->pad_o_list.push_back(nullptr);
          """
      
      erlang_nif_fn "fn_set", ()->
        erlang_nif_fn_arg "fn_index", "u32"
        
        erlang_nif_fn_raw_fixed_code """
          if (fn_index-1 >= #{pipeline_name}_global_registry_fn_list.size()) {
            err = new std::string("fn_index out of range");
            return;
          }
          
          if (fn_index == 0) {
            _this->fn = nullptr;
            _this->fn_index = 0;
            return;
          }
          _this->fn = #{pipeline_name}_global_registry_fn_list[fn_index-1];
          _this->fn_index = fn_index;
          """#"
      
      erlang_nif_fn "fn_get", ()->
        erlang_nif_fn_arg "ret", "u32"
        
        erlang_nif_fn_raw_fixed_code """
          ret = _this->fn_index;
          """
      
      erlang_nif_fn "link", ()->
        erlang_nif_fn_arg "pad_i", "u32"
        erlang_nif_fn_arg "pad_o", "u32"
        erlang_nif_fn_arg "dst",   class_node
        erlang_nif_fn_arg "ring_size", "u32"
        
        erlang_nif_fn_raw_fixed_code """
          if (pad_i >= _this->pad_o_list.size()) {
            err = new std::string("pad_i->link out of range");
            return;
          }
          if (pad_o >= dst->pad_i_list.size()) {
            err = new std::string("link->pad_o out of range");
            return;
          }
          
          {
            Message_ring<#{class_task}>* old_msg_ring = _this->pad_o_list[pad_i];
            if (old_msg_ring) {
              old_msg_ring->ref_count--;
              if (old_msg_ring->ref_count <= 0) {
                // TODO move all tasks inside to free query
                delete old_msg_ring;
              }
            }
          }
          
          {
            Message_ring<#{class_task}>* old_msg_ring = dst->pad_i_list[pad_o];
            if (old_msg_ring) {
              old_msg_ring->ref_count--;
              if (old_msg_ring->ref_count <= 0) {
                // TODO move all tasks inside to free query
                delete old_msg_ring;
              }
            }
          }
          
          Message_ring<#{class_task}>* ring = new Message_ring<#{class_task}>(ring_size);
          _this->pad_o_list[pad_i] = ring;
          dst->pad_i_list[pad_o] = ring;
          ring->ref_count = 2;
          """#"
      
      erlang_nif_fn "ep_i", ()->
        erlang_nif_fn_arg "ring_size", "u32"
        
        erlang_nif_fn_raw_fixed_code  """
          if (_this->pad_i_list.size()) {
            err = new std::string("ep_i requires that there is no other inputs");
            return;
          }
          
          Message_ring<#{class_task}>* ring = new Message_ring<#{class_task}>(ring_size);
          _this->pad_i_list.push_back(ring);
          """#"
      
      erlang_nif_fn "ep_o", ()->
        erlang_nif_fn_arg "ring_size", "u32"
        
        erlang_nif_fn_raw_fixed_code  """
          if (_this->pad_o_list.size()) {
            err = new std::string("ep_o requires that there is no other outputs");
            return;
          }
          
          Message_ring<#{class_task}>* ring = new Message_ring<#{class_task}>(ring_size);
          _this->pad_o_list.push_back(ring);
          """#"
      
      erlang_nif_fn "task_push", ()->
        erlang_nif_fn_arg "task", class_task
        erlang_nif_fn_arg "ret",  "i32"
        
        erlang_nif_fn_raw_fixed_code  """
          if (_this->pad_i_list.size() == 0) {
            err = new std::string("no i pads");
            return;
          }
          
          Message_ring<#{class_task}>* ring = _this->pad_i_list[0];
          if (!ring) {
            err = new std::string("null pad (ring)");
            return;
          }
          ret = ring->push_and_get_free_nonbackpressure_push_size();
          task->task_uid = ++#{pipeline_name}_global_task_uid;
          if (task->task_uid < 0) {
            task->task_uid = #{pipeline_name}_global_task_uid = 1;
          }
          
          ring->push(task);
          """#"
      
      erlang_nif_fn "task_pull", ()->
        # erlang_nif_fn_arg "ret", class_task
        erlang_nif_fn_arg "ret", "i32"
        
        erlang_nif_fn_raw_fixed_code """
          if (_this->pad_o_list.size() == 0) {
            err = new std::string("no o pads");
            return;
          }
          
          Message_ring<#{class_task}>* ring = _this->pad_o_list[0];
          if (!ring) {
            err = new std::string("null pad (ring)");
            return;
          }
          if (!ring->can_pull()) {
            ret = 0;
            return;
          }
          
          ret = ring->pull()->task_instance_uid;
          """#"
      
      erlang_nif_fn "task_pull_count", ()->
        erlang_nif_fn_arg "ret", "u32"
        
        erlang_nif_fn_raw_fixed_code """
          if (_this->pad_o_list.size() == 0) {
            err = new std::string("no o pads");
            return;
          }
          
          Message_ring<#{class_task}>* ring = _this->pad_o_list[0];
          if (!ring) {
            err = new std::string("null pad (ring)");
            return;
          }
          ret = ring->get_available_pull_size();
          """#"
    
    # ###################################################################################################
    #    class thread
    # ###################################################################################################
    idle_delay_mcs = root.policy_get_val_use "idle_delay_mcs"
    erlang_nif_class class_thread, ()->
      erlang_nif_class_kt "node_list", "#{pipeline_name.capitalize()}_node[]"
      
      erlang_nif_class_field_raw "volatile bool started = false"
      erlang_nif_class_field_raw "volatile bool need_shutdown = false"
      erlang_nif_class_field_raw "u64 idle_delay_mcs = #{idle_delay_mcs}"
      erlang_nif_class_field_raw "THREAD_TYPE thread"
      erlang_nif_class_field_raw "u32 cpu_core_id = 0"
      
      erlang_nif_fn "cpu_core_id_set", ()->
        erlang_nif_fn_arg "cpu_core_id", "u32"
        
        erlang_nif_fn_raw_fixed_code """
          _this->cpu_core_id = cpu_core_id;
          """
      
      erlang_nif_fn "node_attach", ()->
        erlang_nif_fn_arg "node", class_node
        
        erlang_nif_fn_raw_fixed_code """
          _this->node_list.push_back(node);
          node->thread_set = true;
          """
      
      erlang_nif_fn "start", ()->
        erlang_nif_fn_raw_fixed_code """
          if (_this->started) {
            err = new std::string("already started");
            return;
          }
          _this->need_shutdown = false;
          
          #{class_node}** node_list = _this->node_list.data();
          size_t node_list_count    = _this->node_list.size();
          for(size_t i=0;i<node_list_count;i++) {
            #{class_node}* node = node_list[i];
            if (!node->fn) {
              err = new std::string("node [");
              *err += std::to_string(i);
              *err += "] has no assigned fn";
              return;
            }
          }
          
          THREAD_CREATE(_this->thread, err, #{pipeline_name}_worker_thread, _this)
          _this->started = true;
          """#"
      
      erlang_nif_fn "stop_schedule", ()->
        erlang_nif_fn_raw_fixed_code """
          _this->need_shutdown = true;
          """
      
      erlang_nif_fn "stop_hard_term", ()->
        erlang_nif_fn_raw_fixed_code """
          _this->need_shutdown = true;
          _this->started = false;
          THREAD_TERM(_this->thread);
          """
      
      erlang_nif_fn "stop_hard_kill", ()->
        erlang_nif_fn_raw_fixed_code """
          _this->need_shutdown = true;
          _this->started = false;
          THREAD_KILL(_this->thread);
          """
      
      erlang_nif_fn "started_get", ()->
        erlang_nif_fn_arg "ret", "bool"
        erlang_nif_fn_raw_fixed_code """
          ret = _this->started;
          """
    
    # ###################################################################################################
    #    
    #    default fn
    #    
    # ###################################################################################################
    # Прим. не переносится т.к. нужно подставлять pipeline_name и class_thread
    fan_list = []
    fan_list.push fan_name = "fan_1n_mod_in"
    task_saturation_threshold = root.policy_get_val_use "task_saturation_threshold"
    erlang_nif_file_raw_post "#{pipeline_name}_#{fan_name}.cpp", """
      #pragma once
      
      bool #{pipeline_name}_#{fan_name}(#{class_node}* node, #{class_thread}* _thread) {
        node->heartbeat_counter++;
        
        if (node->pad_i_list.size() == 0) {
          return false;
        }
        
        if (node->pad_o_list.size() <= 1) {
          return false;
        }
        
        
        Message_ring<#{class_task}>** o_ring_list       = node->pad_o_list.data();
        size_t                        o_ring_list_count = node->pad_o_list.size();
        
        Message_ring<#{class_task}>* i_ring = node->pad_i_list[0];
        if (!i_ring) {
          return false;
        }
        
        if (!i_ring->can_pull()) {
          return false;
        }
        
        bool ret = false;
        size_t task_saturation_threshold = #{task_saturation_threshold};
        
        // TODO config
        for(int i=0;i<10;i++) {
          if (!i_ring->can_pull()) break;
          Message_ring<#{class_task}>* send_ring = nullptr;
          
          // NOTE o_ring_list_count[0] is o_ring_err
          for(size_t j=1;j<o_ring_list_count;j++) {
            Message_ring<#{class_task}>* o_ring = o_ring_list[j];
            if (!o_ring) continue;
            o_ring->push_and_get_free_nonbackpressure_push_size();
          }
          
          // policy: first count < hash_thread_task_saturation_threshold
          // reason keep most threads in sleep state, wakeup introduces extra latency
          //   much more than calc hash_thread_task_saturation_threshold hashes
          //   hash_thread_task_saturation_threshold should be tuned
          for(size_t j=1;j<o_ring_list_count;j++) {
            Message_ring<#{class_task}>* o_ring = o_ring_list[j];
            if (!o_ring) continue;
            if (o_ring->get_available_pull_size() >= task_saturation_threshold) continue;
            send_ring = o_ring;
            break;
          }
          
          if (!send_ring) {
            // policy: most free ring
            // assume all have same size, so most free count == less loaded ring
            size_t best_free_count = 0;
            for(size_t j=1;j<o_ring_list_count;j++) {
              Message_ring<#{class_task}>* o_ring = o_ring_list[j];
              if (!o_ring) continue;
              size_t curr_free_count = o_ring->get_free_nonbackpressure_push_size();
              if (best_free_count < curr_free_count) {
                send_ring = o_ring;
                best_free_count = curr_free_count;
              }
            }
          }
          
          if (send_ring) {
            ret = true;
            #{class_task}* task = i_ring->pull();
            send_ring->push(task);
          }
        }
        
        return ret;
      }
      
      """
    
    fan_list.push fan_name = "fan_n1_mod_out"
    erlang_nif_file_raw_post "#{pipeline_name}_#{fan_name}.cpp", """
      #pragma once
      
      bool #{pipeline_name}_#{fan_name}(#{class_node}* node, #{class_thread}* _thread) {
        node->heartbeat_counter++;
        
        if (node->pad_i_list.size() == 0) {
          return false;
        }
        
        if (node->pad_o_list.size() == 0) {
          return false;
        }
        
        Message_ring<#{class_task}>* o_ring = node->pad_o_list[0];
        if (!o_ring) {
          return false;
        }
        if (!o_ring->push_and_get_free_nonbackpressure_push_size()) {
          return false;
        }
        
        
        Message_ring<#{class_task}>** i_ring_list       = node->pad_i_list.data();
        size_t                        i_ring_list_count = node->pad_i_list.size();
        
        bool res = false;
        for(size_t j=0;j<i_ring_list_count;j++) {
          Message_ring<#{class_task}>* i_ring = i_ring_list[j];
          if (!i_ring) continue;
          while (i_ring->can_pull()) {
            if (!o_ring->get_free_nonbackpressure_push_size()) {
              return res;
            }
            #{class_task}* task = i_ring->pull();
            o_ring->push(task);
            res = true;
          }
        }
        
        return res;
      }
      
      """
    
    jl = []
    for fan_name in fan_list
      jl.push "#{pipeline_name}_global_registry_fn_list.push_back(#{pipeline_name}_#{fan_name});"
    
    erlang_nif_init_raw join_list jl
    
    # ###################################################################################################
    #    
    #    worker_thread
    #    
    # ###################################################################################################
    erlang_nif_file_raw_post "#{pipeline_name}_worker_thread.cpp", """
      #pragma once
      
      void* #{pipeline_name}_worker_thread(void* ptr) {
        #{class_thread}* thread = (#{class_thread}*)ptr;
        
        if (thread->cpu_core_id) {
          std::string err;
          if (!thread_affinity_single_core_set(err, thread->thread, thread->cpu_core_id-1)) {
            fprintf(stderr, "pipeline thread error %s\\n", err.c_str());
            return ptr;
          }
        }
        
        
        #{class_node}** node_list = thread->node_list.data();
        size_t node_list_count    = thread->node_list.size();
        
        bool need_sleep = false;
        while (!thread->need_shutdown) {
          bool need_wait = true;
          for(size_t i=0;i<node_list_count;i++) {
            #{class_node}* node = node_list[i];
            bool res = node->fn(node, thread);
            need_wait &= !res;
            if (thread->need_shutdown) break;
          }
          if (need_wait) {
            atomic_thread_fence(std::memory_order_release);
            if (need_sleep) {
              std::this_thread::sleep_for(std::chrono::microseconds(thread->idle_delay_mcs));
            } else {
              // last hope before go to sleep. Maybe counters were outdated. Just 1 spinlock iteration
              need_sleep = true;
            }
            atomic_thread_fence(std::memory_order_acquire);
          } else {
            need_sleep = false;
          }
        }
        thread->started = false;
        return ptr;
      }
      
      """#"
    
    false
  
  emit_codebub  : (root, ctx)->
    erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
    {erlang_nif_module} = erlang_nif_package_node.data_hash
    
    pipeline_decl = root.data_hash.erlang_nif_pipeline_decl
    
    pipeline_name = pipeline_decl.name
    package_name  = erlang_nif_module.name
    
    class_node  = "#{pipeline_name.capitalize()}_node"
    class_task  = "#{pipeline_name.capitalize()}_task"
    class_thread= "#{pipeline_name.capitalize()}_thread"
    
    # ###################################################################################################
    for fn_decl in pipeline_decl.fn_decl_list
      fn_name = fn_decl.name
      
      if fn_decl.raw_fixed_code
        fn_cont = fn_decl.raw_fixed_code
      else
        cb_name = "erlang_nif_#{package_name}/pipeline_#{pipeline_name}/#{fn_name}.cpp"
        
        task_arg_list = []
        for field in root.data_hash.class_ast_node.data_hash.erlang_nif_class_decl.field_list
          if field.type
            task_arg_list.push """
              // #{field.type.ljust 10} #{field.name}
              """
          else
            [_skip, type, name] = /^(\S+)\s+(.*)$/.exec field.name
            task_arg_list.push """
              // #{type.ljust 10} #{name}
              """
        
        fn_cont = ctx.file_render cb_name, """
          bool res = false;
          while (i_ring->can_pull()) {
            if (!o_ring->get_free_nonbackpressure_push_size()) {
              return res;
            }
            #{class_task}* task = i_ring->pull();
            
            // TODO task process
            
            // on error
            // err_o_ring->push(task);
            // task fields:
            #{join_list task_arg_list, "  "}
            
            // on ok
            o_ring->push(task);
            res = true;
          }
          """
      
      # TODO port back to napi
      if fn_decl.raw_custom
        erlang_nif_file_raw_post "#{pipeline_name}_#{fn_name}.cpp", """
          #pragma once
          
          bool #{pipeline_name}_#{fn_name}(#{class_node}* node, #{class_thread}* thread) {
            #{make_tab fn_cont, "  "}
          }
          
          """
      else
        erlang_nif_file_raw_post "#{pipeline_name}_#{fn_name}.cpp", """
          #pragma once
          
          bool #{pipeline_name}_#{fn_name}(#{class_node}* node, #{class_thread}* thread) {
            node->heartbeat_counter++;
            
            if (node->pad_i_list.size() == 0) {
              return false;
            }
            
            if (node->pad_o_list.size() <= 1) {
              return false;
            }
            
            Message_ring<#{class_task}>* i_ring = node->pad_i_list[0];
            if (!i_ring) {
              return false;
            }
            if (!i_ring->can_pull()) {
              return false;
            }
            
            
            Message_ring<#{class_task}>* err_o_ring = node->pad_o_list[0];
            if (!err_o_ring) {
              return false;
            }
            if (!err_o_ring->push_and_get_free_nonbackpressure_push_size()) {
              return false;
            }
            
            Message_ring<#{class_task}>* o_ring = node->pad_o_list[1];
            if (!o_ring) {
              return false;
            }
            if (!o_ring->push_and_get_free_nonbackpressure_push_size()) {
              return false;
            }
            
            #{make_tab fn_cont, "  "}
            
            return res;
          }
          
          """
      
      # ?TODO перенести на nodegen
      erlang_nif_init_raw "#{pipeline_name}_global_registry_fn_list.push_back(#{pipeline_name}_#{fn_name});"
    
    false
  
  emit_codegen  : (root, ctx)->
    erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
    {erlang_nif_module} = erlang_nif_package_node.data_hash
    
    pipeline_decl = root.data_hash.erlang_nif_pipeline_decl
    
    pipeline_name = pipeline_decl.name
    package_name  = erlang_nif_module.name
    
    # ###################################################################################################
    erlang_nif_file_raw_pre "message_ring.hpp",  ctx.tpl_read "erlang_nif/message_ring.hpp"
    erlang_nif_file_raw_pre "pipeline_util.hpp", ctx.tpl_read "erlang_nif/pipeline_util.hpp"
    
    # ###################################################################################################
    #    
    #    pipeline require endpoints
    #    
    # ###################################################################################################
    # NOTE. ../.. == path костыль
    ctx.file_render "../../src/pipeline/pipeline.coffee", ctx.tpl_read "erlang_nif/pipeline.coffee"
    
    fn_jl = []
    for fn in pipeline_decl.fn_decl_list
      fn_jl.push "pipeline.fn_hash.#{fn.name.ljust 15}= fn_hash_idx++;"
    
    # NOTE. ../.. == path костыль
    ctx.file_render "../../src/pipeline/pipeline_#{pipeline_name}_default.coffee", """
      {Pipeline} = require "./pipeline"
      
      pipeline = new Pipeline
      pipeline.mod    = require "../#{package_name}"
      pipeline.prefix_set "#{pipeline_name.capitalize()}_"
      fn_hash_idx = 1
      pipeline.fn_hash.fan_1n_mod_in  = fn_hash_idx++
      pipeline.fn_hash.fan_n1_mod_out = fn_hash_idx++
      #{join_list fn_jl, ''}
      
      module.exports = pipeline
      
      ###
      # quick starter, boilerplate
      pipeline = require "./pipeline/pipeline_#{pipeline_name}_default"
      pipeline.default_layout()
      worker_thread = pipeline.thread_alloc()
      my_node = pipeline.node_create "erlang_nif_pipeline_easy_fn"
      worker_thread.node_attach_sync my_node
      
      pipeline.chain pipeline.node_i_list[0], my_node, pipeline.node_o_list[0]
      pipeline.start()
      
      task = pipeline.task_get()
      # TODO task set
      task.hello = "world"
      pipeline.task_push task
      
      loop
        ret = pipeline.task_pull()
        break if ret
        await setTimeout defer(), 10
      
      pipeline.task_pull_ack ret
      ###
      
      """#"
    
    false

def "erlang_nif_package erlang_nif_pipeline", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  name = name or "default"
  
  erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
  {erlang_nif_module} = erlang_nif_package_node.data_hash
  
  pipeline_decl = erlang_nif_module.pipeline_decl_get name
  
  root = mod_runner.current_runner.curr_root.tr_get "erlang_nif_pipeline", name, "def"
  bdh_node_module_name_assign_on_call root, module, "erlang_nif_pipeline"
  
  root.data_hash.erlang_nif_pipeline_decl ?= pipeline_decl
  root.policy_set_here_weak "idle_delay_mcs", 100
  root.policy_set_here_weak "task_saturation_threshold", 100
  
  # ###################################################################################################
  #    Костыль
  # ###################################################################################################
  pipeline_name = root.name
  
  class_node  = "#{pipeline_name.capitalize()}_node"
  class_task  = "#{pipeline_name.capitalize()}_task"
  class_thread= "#{pipeline_name.capitalize()}_thread"
  
  erlang_nif_class_include_raw """
    void* #{pipeline_name}_worker_thread(void* ptr);
    std::vector<bool (*)(#{class_node}*, #{class_thread}*)> #{pipeline_name}_global_registry_fn_list;
    std::vector<#{class_task}*> #{pipeline_name}_global_free_pipeline_task_list;
    i32 #{pipeline_name}_global_task_instance_uid = 0;
    i32 #{pipeline_name}_global_task_uid = 0;
    """
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# TODO use fn
# ###################################################################################################
#    erlang_nif_pipeline_fn
# ###################################################################################################
bdh_module_name_root module, "erlang_nif_pipeline_fn", {}

def "erlang_nif_pipeline erlang_nif_pipeline_fn", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  erlang_nif_pipeline_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_pipeline"
  root = erlang_nif_pipeline_node.tr_get "erlang_nif_pipeline_fn", name, "def"
  bdh_node_module_name_assign_on_call root, module, "erlang_nif_pipeline_fn"
  
  {erlang_nif_pipeline_decl} = erlang_nif_pipeline_node.data_hash
  
  fn_decl = erlang_nif_pipeline_decl.fn_decl_get name
  
  root.data_hash.erlang_nif_fn_decl ?= fn_decl
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    erlang_nif_pipeline_easy_fn
# ###################################################################################################
bdh_module_name_root module, "erlang_nif_pipeline_easy_fn",
  nodegen       : (root, ctx)->
    # init pipeline class for task
    ctx.walk_child_list_only_fn root
    
    pipeline_name = "easy_fn_#{root.name}"
    erlang_nif_pipeline_node = root.tr_get_try "erlang_nif_pipeline", pipeline_name, "def"
    
    class_name = "#{pipeline_name.capitalize()}_task"
    erlang_nif_class class_name, ()->
      fn_node = erlang_nif_pipeline_node.tr_get_try "erlang_nif_pipeline_fn", "easy_fn_impl_#{root.name}", "def"
      
      # BUG может перетасовывать аргументы
      arg_and_ret_list = []
      arg_and_ret_list.append fn_node.data_hash.erlang_nif_fn_decl.arg_list
      arg_and_ret_list.append fn_node.data_hash.erlang_nif_fn_decl.ret_list
      
      for v in arg_and_ret_list
        {name, type} = v
        erlang_nif_class_kt name, type
        if type == "buf"
          perr "WARNING do not use buf with easy_fn_ use buf_val. Otherwise safe references manually"
        if type == "buf_val"
          erlang_nif_class_field_raw """
            erlang_nif_ref #{name}_ref;
            """
      
      erlang_nif_fn "set", ()->
        erlang_nif_fn_sync_env()
        code_jl = []
        for v in arg_and_ret_list
          {name, type} = v
          # _ нужно чтобы не сработал ret
          erlang_nif_fn_arg "_#{name}", type
          if type == "buf_val"
            code_jl.push """
              if (_this->#{name} != _#{name}) {
                if (_this->#{name}_ref) {
                  erlang_nif_status status;
                  status = erlang_nif_delete_reference(env, _this->#{name}_ref);
                  if (status != erlang_nif_ok) {
                    err = new std::string("erlang_nif_delete_reference fail for #{name}. status=");
                    *err += std::to_string(status);
                    return;
                  }
                }
                _this->#{name} = _#{name};
                _this->#{name}_len = _#{name}_len;
                {
                  erlang_nif_status status;
                  status = erlang_nif_create_reference(env, _#{name}_val, 1, &_this->#{name}_ref);
                  if (status != erlang_nif_ok) {
                    err = new std::string("erlang_nif_create_reference fail for #{name}. status=");
                    *err += std::to_string(status);
                    return;
                  }
                }
              }
              """#"
          else if type in ["str", "buf"]
            code_jl.push """
              _this->#{name} = _#{name};
              _this->#{name}_len = _#{name}_len;
              """
          else
            code_jl.push """
              _this->#{name} = _#{name};
              """
        
        erlang_nif_fn_raw_fixed_code  """
          #{join_list code_jl, ""}
          """
      
      erlang_nif_fn "clear", ()->
        erlang_nif_fn_sync_env()
        code_jl = []
        for v in arg_and_ret_list
          {name, type} = v
          # _ нужно чтобы не сработал ret
          erlang_nif_fn_arg "_#{name}", type
          if type == "buf_val"
            code_jl.push """
              if (_this->#{name}_ref) {
                erlang_nif_status status;
                status = erlang_nif_delete_reference(env, _this->#{name}_ref);
                if (status != erlang_nif_ok) {
                  err = new std::string("erlang_nif_delete_reference fail for #{name}. status=");
                  *err += std::to_string(status);
                  return;
                }
              }
              _this->#{name}_ref= nullptr;
              _this->#{name}    = nullptr;
              _this->#{name}_val= nullptr;
              """#"
        
        erlang_nif_fn_raw_fixed_code  """
          #{join_list code_jl, ""}
          """
    
    true
  
  emit_codebub  : (root, ctx)->
    erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
    {erlang_nif_module} = erlang_nif_package_node.data_hash
    
    package_name  = erlang_nif_module.name
    
    pipeline_name = "easy_fn_#{root.name}"
    erlang_nif_pipeline_node = root.tr_get_try "erlang_nif_pipeline", pipeline_name, "def"
    
    fn_node = erlang_nif_pipeline_node.tr_get_try "erlang_nif_pipeline_fn", "easy_fn_impl_#{root.name}", "def"
    fn_node.data_hash.erlang_nif_fn_decl
    
    # BUG может перетасовывать аргументы
    arg_and_ret_list = []
    arg_and_ret_list.append fn_node.data_hash.erlang_nif_fn_decl.arg_list
    arg_and_ret_list.append fn_node.data_hash.erlang_nif_fn_decl.ret_list
    
    arg_call_list = []
    for v in arg_and_ret_list
      {name, type} = v
      arg_call_list.push name
    
    
    arg_no_ret_call_list= []
    ret_call_list       = []
    task_custom_cb_jl   = []
    task_buf_one_time_attach_jl = []
    for v in fn_node.data_hash.erlang_nif_fn_decl.arg_list
      {name, type} = v
      if type == "buf"
        task_buf_one_time_attach_jl.push """
          # not return, maybe needs to be deleted
          if task._#{name}?
            #{name} = task._#{name}
          else
            task._#{name} = #{name}
          """
      
      arg_no_ret_call_list.push name
      
    for v in fn_node.data_hash.erlang_nif_fn_decl.ret_list
      {name, type} = v
      if type == "buf"
        ret_call_list.push name
        task_custom_cb_jl.push """
          #{name} = task._#{name}
          """
        
        task_buf_one_time_attach_jl.push """
          if task._#{name}?
            #{name} = task._#{name}
          else
            task._#{name} = #{name}
          """
    
    err_ret_call_list = ["err"]
    err_ret_call_list.append ret_call_list
    
    arg_call_list_comma_str = ""
    arg_call_list_comma_str = "#{arg_call_list.join ", "}, " if arg_call_list.length
    
    arg_no_ret_call_list_comma_str = ""
    arg_no_ret_call_list_comma_str = "#{arg_no_ret_call_list.join ", "}, " if arg_no_ret_call_list.length
    
    cb_name = "erlang_nif_#{package_name}/pipeline_#{pipeline_name}/easy_fn__#{root.name}.coffee"
    root.data_hash.code_bub = ctx.file_render cb_name,  """
      module = @
      os = require "os"
      @pipeline = pipeline = require "./pipeline_#{pipeline_name}_default"
      pipeline.default_layout()
      for i in [0 ... os.cpus().length]
        worker_thread = pipeline.thread_alloc()
        my_node = pipeline.node_create "easy_fn_impl_#{root.name}"
        worker_thread.node_attach_sync my_node
        pipeline.chain pipeline.node_i_list[0], my_node, pipeline.node_o_list[0]
      
      do ()->
        loop
          ready_task = pipeline.task_pull()
          if !ready_task
            await setTimeout defer(), 10
            continue
          ready_task.cb()
          pipeline.task_pull_ack ready_task
      
      @started = false
      
      @fn = (#{arg_call_list.join ", "}, cb)->
        if !module.started
          module.started = true
          pipeline.start()
        
        task = pipeline.task_get()
        task.set_sync #{arg_call_list.join ", "}
        task.cb = cb
        pipeline.task_push task
      
      # NOTE Я вращаю буфера больше чем надо
      # неплохо бы некоторые буфера держать рядом с таской, а не переопределять каждый раз и не дергать reference'ы
      # но зато easy...
      # хочешь больше perf?
      # разкомментируй эту функцию
      # удали лишнее
      ###
      
      @fn_perf = (#{arg_no_ret_call_list_comma_str}cb)->
        if !module.started
          module.started = true
          pipeline.start()
        
        task = pipeline.task_get()
        #{join_list task_buf_one_time_attach_jl, "  "}
        # ВАЖНО. Если не менять эту функцию, то особо буста может и не быть
        # Передавать лучше только то, что меняется (начиная со 2-го раза)
        # TODO надо еще полировать генератор
        task.set_sync #{arg_call_list.join ", "}
        task.cb = ()->
          #{join_list task_custom_cb_jl, "    "}
          cb null, #{ret_call_list.join ", "}
        pipeline.task_push task
      ###
      
      ###
      # quick starter, boilerplate
      #{root.name} = require("./pipeline/easy_fn_#{root.name}").fn
      
      await #{root.name} #{arg_call_list_comma_str}defer(err); return cb err if err
      
      ###
      
      ###
      # NOTE maybe need some fixes
      #{root.name} = require("./pipeline/easy_fn_#{root.name}").fn_perf
      
      await #{root.name} #{arg_no_ret_call_list_comma_str}defer(#{err_ret_call_list.join ", "}); return cb err if err
      ###
      
      """#"
    
    false
  
  emit_codegen  : (root, ctx)->
    ctx.file_render "../../src/pipeline/easy_fn_#{root.name}.coffee", root.data_hash.code_bub
    
    false

def "erlang_nif_pipeline_easy_fn", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "erlang_nif_pipeline_easy_fn", name, "def"
  bdh_node_module_name_assign_on_call root, module, "erlang_nif_pipeline_easy_fn"
  
  mod_runner.current_runner.root_wrap root, ()->
    erlang_nif_pipeline "easy_fn_#{name}", ()->
      erlang_nif_pipeline_fn "easy_fn_impl_#{name}", ()->
        # HACK for easy use
        scope_fn()
  
  root

def "erlang_nif_fn_raw_custom", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  erlang_nif_fn_node = mod_runner.current_runner.curr_root
  {erlang_nif_fn_decl} = erlang_nif_fn_node.data_hash
  
  erlang_nif_fn_decl.raw_custom = true
  
  return