{std_fn_decl_type_hash} = require "./erlang_nif_decl"

@fn_generator = (root, ctx, erlang_nif_module)->
  fn_decl = root.data_hash.erlang_nif_fn_decl
  
  fn_name = fn_decl.name
  {
    arg_list
    ret_list
    parent_class_name
  } = fn_decl
  
  # always
  fn_decl.gen_async = false
  fn_decl.gen_env = false
  
  # if fn_decl.gen_async and fn_decl.gen_env
  #   throw new Error "gen_async and gen_env are mutually exclusive"
  
  # ###################################################################################################
  #    
  #    generic
  #    
  # ###################################################################################################
  cpp_arg_decl_list = []
  cpp_arg_call_list = []
  
  cpp_arg_decl_list_type_pad = 12
  
  # ###################################################################################################
  #    this patch
  # ###################################################################################################
  if parent_class_name
    type = "#{parent_class_name}*"
    cpp_arg_decl_list.push "#{type.ljust cpp_arg_decl_list_type_pad} _this"
    cpp_arg_call_list.push "_this"
  
  # ###################################################################################################
  #    arg
  # ###################################################################################################
  for v, idx in arg_list
    {name, type} = v
    switch type
      when "bool", "i32", "i64", "u32", "u64", "f32", "f64"
        cpp_arg_decl_list.push "#{type.ljust cpp_arg_decl_list_type_pad} #{name}"
        
        cpp_arg_call_list.push name
      
      when "str", "str_no_free"
        cpp_arg_decl_list.push "#{'char*' .ljust cpp_arg_decl_list_type_pad} #{name}"
        cpp_arg_decl_list.push "#{'size_t'.ljust cpp_arg_decl_list_type_pad} #{name}_len"
        
        cpp_arg_call_list.push name
        cpp_arg_call_list.push "#{name}_len"
      
      when "buf"
        cpp_arg_decl_list.push "#{'u8*'   .ljust cpp_arg_decl_list_type_pad} #{name}"
        cpp_arg_decl_list.push "#{'size_t'.ljust cpp_arg_decl_list_type_pad} #{name}_len"
        
        cpp_arg_call_list.push name
        cpp_arg_call_list.push "#{name}_len"
      
      when "buf_val"
        cpp_arg_decl_list.push "#{'u8*'       .ljust cpp_arg_decl_list_type_pad} #{name}"
        cpp_arg_decl_list.push "#{'size_t'    .ljust cpp_arg_decl_list_type_pad} #{name}_len"
        cpp_arg_decl_list.push "#{'erlang_nif_value'.ljust cpp_arg_decl_list_type_pad} #{name}_val"
        
        cpp_arg_call_list.push name
        cpp_arg_call_list.push "#{name}_len"
        cpp_arg_call_list.push "#{name}_val"
      
      else
        cpp_arg_decl_list.push "#{(type+'*').ljust cpp_arg_decl_list_type_pad} #{name}"
        
        cpp_arg_call_list.push name
  
  # ###################################################################################################
  #    ret
  # ###################################################################################################
  vector_impl_ret = (name, type)->
    cpp_arg_decl_list.push "#{(type+'*&').ljust cpp_arg_decl_list_type_pad} #{name}"
    cpp_arg_decl_list.push "#{'size_t&'.ljust cpp_arg_decl_list_type_pad} #{name}_len"
    
    cpp_arg_call_list.push name
    cpp_arg_call_list.push "#{name}_len"
    return
  
  for ret, ret_idx in ret_list
    {name, type} = ret
    
    switch type
      when "bool", "i32", "i64", "u32", "u64", "f32", "f64"
        cpp_arg_decl_list.push "#{(type+'&').ljust cpp_arg_decl_list_type_pad} #{name}"
        cpp_arg_call_list.push name
      
      when "str", "str_static"
        vector_impl_ret name, "char"
      
      when "str_simple_craft"
        cpp_arg_decl_list.push "#{'std::string*'.ljust cpp_arg_decl_list_type_pad} #{name}"
        cpp_arg_call_list.push name
      
      when "buf", "buf_static"
        perr "NOTE return buffer is highly not recommended fn_name=#{fn_name}"
        perr "  also do not forget to set #{type}_len"
        
        vector_impl_ret name, "u8"
      
      when "buf_val"
        cpp_arg_decl_list.push "#{'erlang_nif_value&'.ljust cpp_arg_decl_list_type_pad} #{name}_val"
        cpp_arg_call_list.push "_ret_#{name}"
      
      else
        if ret.is_raw
          throw new Error "ret.is_raw unimplemented [1]"
        
        cpp_arg_decl_list.push "#{(type+'*&').ljust cpp_arg_decl_list_type_pad} #{name}"
        cpp_arg_call_list.push name
  
  # ###################################################################################################
  #    
  #    codegen
  #    
  # ###################################################################################################
  if parent_class_name
    cb_name     = "erlang_nif_#{erlang_nif_module.name}/erlang_nif_class_#{parent_class_name}/fn_#{fn_name}.cpp"
    fn_file_name= "src/#{parent_class_name}/#{fn_name}.cpp"
    fn_name     = "#{parent_class_name}_#{fn_name}"
  else
    cb_name     = "erlang_nif_#{erlang_nif_module.name}/erlang_nif_fn_#{fn_name}.cpp"
    fn_file_name= "src/#{fn_name}.cpp"
  
  if fn_decl.raw_fixed_code
    fn_cont_use_code_bubble = false
    fn_cont = fn_decl.raw_fixed_code
  else
    fn_cont_use_code_bubble = true
    fn_cont = """
      /*
        #{make_tab cpp_arg_decl_list.join(',\n'), '  '}
      */
      // TODO put your code here
      // #{fn_name}(#{cpp_arg_call_list.join ', '});
      err = new std::string("unimplemented #{fn_name}");
      """#"
  
  cpp_arg_call_ext_list = []
  if fn_decl.gen_env
    cpp_arg_call_ext_list.push "env"
  cpp_arg_call_ext_list.push "err"
  cpp_arg_call_ext_list.append cpp_arg_call_list
  
  # ###################################################################################################
  #    check
  # ###################################################################################################
  # TODO move to validator
  for v in arg_list
    {name, type} = v
    continue if std_fn_decl_type_hash[type]
    if !erlang_nif_module.class_decl_hash[type]?
      throw new Error "class '#{type}' doesn't exists arg=#{name} erlang_nif_fn=#{fn_decl.name}"
  
  # ###################################################################################################
  #    
  #    sync
  #    
  # ###################################################################################################
  aux_sync = ""
  if fn_decl.gen_sync
    status_check = (fn)->
      """
      if (status != erlang_nif_ok) {
        fprintf(stderr, "status = %d\\n", status);
        erlang_nif_throw_error(env, nullptr, "#{fn} FAIL");
        return ret_dummy;
      }
      """#"
    
    # ###################################################################################################
    #    cpp_arg_head
    # ###################################################################################################
    arg_list_length = arg_list.length
    arg_list_length++ if parent_class_name
    if arg_list_length
      cpp_arg_head = "FN_ARG_HEAD(#{arg_list_length})"
    else
      cpp_arg_head = "FN_ARG_HEAD_EMPTY"
    
    if parent_class_name
      cpp_arg_head += "\nFN_ARG_THIS(#{parent_class_name})"
    
    # ###################################################################################################
    #    arg
    # ###################################################################################################
    cpp_erlang_nif_arg_jl   = []
    cpp_sync_clear_jl = []
    
    for v, idx in arg_list
      {name, type} = v
      switch type
        when "bool", "i32", "i64", "u32", "u64", "f32", "f64"
          cpp_erlang_nif_arg_jl.push "FN_ARG_#{type.toUpperCase()}(#{name})"
          # no cpp_sync_clear_jl
        when "str"
          cpp_erlang_nif_arg_jl.push "FN_ARG_STR(#{name})"
          cpp_sync_clear_jl.push "free(#{name});"
        when "str_no_free"
          cpp_erlang_nif_arg_jl.push "FN_ARG_STR(#{name})"
          # no cpp_sync_clear_jl
        when "buf"
          cpp_erlang_nif_arg_jl.push "FN_ARG_BUF(#{name})"
          # no cpp_sync_clear_jl
        when "buf_val"
          cpp_erlang_nif_arg_jl.push "FN_ARG_BUF_VAL(#{name})"
          # no cpp_sync_clear_jl
        else
          cpp_erlang_nif_arg_jl.push "FN_ARG_CLASS(#{type}, #{name})"
          # no cpp_sync_clear_jl
    
    # ###################################################################################################
    #    ret
    # ###################################################################################################
    cpp_sync_ret_decl_list = []
    vector_impl_ret = (name, type)->
      cpp_sync_ret_decl_list.push "#{type}* #{name} = nullptr;"
      cpp_sync_ret_decl_list.push "size_t #{name}_len;"
    
    
    for ret, ret_idx in ret_list
      {name, type} = ret
      
      switch type
        when "bool", "i32", "i64", "u32", "u64", "f32", "f64"
          cpp_sync_ret_decl_list.push "#{type} #{name};"
        
        when "str", "str_static"
          vector_impl_ret name, "char"
        
        when "str_simple_craft"
          cpp_sync_ret_decl_list.push "std::string* #{name} = new std::string();"
        
        when "buf", "buf_static"
          vector_impl_ret name, "u8"
        
        when "buf_val"
          cpp_sync_ret_decl_list.push "FN_DECL_RET_BUF_VAL(#{name})"
        
        else
          cpp_sync_ret_decl_list.push "#{type}* #{name} = nullptr;"
    
    # ###################################################################################################
    cpp_ret_sync  = ""
    
    if ret_list.length == 0
      cpp_ret_sync = """
        return enif_make_atom(envPtr, "ok");
        """#"
    else if ret_list.length == 1
      {name, type} = ret = ret_list[0]
      switch type
        when "bool", "i32", "i64", "u32", "u64", "f32", "f64"
          cpp_ret_sync = "FN_RET_#{type.toUpperCase()}(#{name})"
        
        when "str"  
          cpp_ret_sync = "FN_RET_STR_FREE(#{name})"
        
        when "str_static"
          cpp_ret_sync = "FN_RET_STR(#{name})"
        
        when "str_simple_craft"
          cpp_ret_sync = "FN_RET_STR_SIMPLE_CRAFT(#{name})"
        
        when "buf"
          cpp_ret_sync = "FN_RET_BUF_FREE(#{name})"
        
        when "buf_static"
          cpp_ret_sync = "FN_RET_BUF(#{name})"
          
        when "buf_val"
          cpp_ret_sync = "return _ret_#{name};"
        
        else
          cpp_ret_sync = "FN_RET_REF(#{name})"
    else # if ret_list.length > 1
      cpp_ret_sync_jl = []
      for ret, ret_idx in ret_list
        {name, type} = ret
        
        switch type
          when "bool", "i32", "i64", "u32", "u64", "f32", "f64"
            cpp_ret_sync_jl.push "FN_RET_#{type.toUpperCase()}_CREATE(#{name})"
          
          when "str"
            cpp_ret_sync_jl.push "FN_RET_STR_FREE_CREATE(#{name})"
          
          when "str_static"
            cpp_ret_sync_jl.push "FN_RET_STR_CREATE(#{name})"
          
          when "str_simple_craft"
            cpp_ret_sync_jl.push "FN_RET_STR_SIMPLE_CRAFT_CREATE(#{name})"
          
          when "buf"
            cpp_ret_sync_jl.push "FN_RET_BUF_FREE_CREATE(#{name})"
          
          when "buf_static"
            cpp_ret_sync_jl.push "FN_RET_BUF_CREATE(#{name})"
          
          when "buf_val"
            "ok"
          
          else
            cpp_ret_sync_jl.push "FN_RET_REF_CREATE(#{name})"
        
        cpp_ret_sync_jl.push """
          status = erlang_nif_set_element(env, ret_array_wrap, #{ret_idx}, _ret_#{name});
          #{status_check "erlang_nif_set_element ret_idx=#{ret_idx}"}
          """#"
      throw new Error "unimplemented return list"
      cpp_ret_sync = """
        erlang_nif_value ret_array_wrap;
        status = erlang_nif_create_array_with_length(env, #{ret_list.length}, &ret_array_wrap);
        #{status_check 'erlang_nif_create_array_with_length'}
        #{join_list cpp_ret_sync_jl, ""}
        return ret_array_wrap;
        """
    
    cpp_impl_call_sync = ""
    if cpp_sync_ret_decl_list.length
      cpp_impl_call_sync = """
        #{join_list cpp_sync_ret_decl_list, ""}
        
        """
    
    cpp_impl_call_sync += """
      _#{fn_name}_impl(#{cpp_arg_call_ext_list.join ', '});
      """
    
    # ###################################################################################################
    #    code
    # ###################################################################################################
    
    aux_sync = """
      ////////////////////////////////////////////////////////////////////////////////////////////////////
      //   sync
      ////////////////////////////////////////////////////////////////////////////////////////////////////
      ERL_NIF_TERM #{fn_name}_cpp_nif(ErlNifEnv* envPtr, int argc, const ERL_NIF_TERM argv[]) {
        #{make_tab cpp_arg_head, "  "}
        ////////////////////////////////////////////////////////////////////////////////////////////////////
        #{join_list cpp_erlang_nif_arg_jl, "  "}
        
        ////////////////////////////////////////////////////////////////////////////////////////////////////
        std::string *err = nullptr;
        #{make_tab cpp_impl_call_sync, "  "}
        if (err) {
          ERL_NIF_TERM ret = error(envPtr, err->c_str());
          delete err;
          return ret;
        }
        
        #{join_list cpp_sync_clear_jl, "  "}
        
        ////////////////////////////////////////////////////////////////////////////////////////////////////
        #{make_tab cpp_ret_sync, "  "}
      }
      
      """
  
  # ###################################################################################################
  #    
  #    async
  #    
  # ###################################################################################################
  # aux_async = ""
  # if fn_decl.gen_async
  #   throw new Error "UNREACH"
  #   async_status_check = (fn)->
  #     """
  #     if (status != erlang_nif_ok) {
  #       fprintf(stderr, "status = %d\\n", status);
  #       erlang_nif_throw_error(env, nullptr, "#{fn} FAIL");
  #       _worker_ctx_#{fn_name}_clear(env, worker_ctx);
  #       return;
  #     }
  #     """#"
  #   
  #   # ###################################################################################################
  #   #    cpp_arg_head
  #   # ###################################################################################################
  #   cpp_arg_head = "FN_ARG_HEAD(#{arg_list.length + 1})"
  #   
  #   if parent_class_name
  #     cpp_arg_head += "\nFN_ARG_THIS(#{parent_class_name})"
  #   
  #   # ###################################################################################################
  #   #    
  #   #    cpp_erlang_nif_arg_async_jl
  #   #    
  #   # ###################################################################################################
  #   cpp_erlang_nif_arg_async_jl = []
  #   
  #   for v, idx in arg_list
  #     {name, type} = v
  #     switch type
  #       # scalars
  #       when "bool", "i32", "i64", "u32", "u64", "f32", "f64"
  #         cpp_erlang_nif_arg_async_jl.push "FN_ARG_#{type.toUpperCase()}(#{name})"
  #       when "str", "str_no_free"
  #         cpp_erlang_nif_arg_async_jl.push "FN_ARG_STR(#{name})"
  #       when "buf", "buf_val"
  #         cpp_erlang_nif_arg_async_jl.push "FN_ARG_BUF_VAL(#{name})"
  #       else
  #         cpp_erlang_nif_arg_async_jl.push "FN_ARG_CLASS_VAL(#{type}, #{name})"
  #   
  #   # ###################################################################################################
  #   #    
  #   #    struct
  #   #    
  #   # ###################################################################################################
  #   # Уйдет в struct decl
  #   cpp_arg_struct_decl_jl = []
  #   
  #   # Как инициализировать
  #   cpp_worker_ctx_init_jl = []
  #   # Как присваивать аргументы
  #   cpp_arg_struct_assign_in_jl = []
  #   # Как передавать аргументы
  #   cpp_arg_call_worker_ctx_list = []
  #   
  #   # Как чистить struct после использования
  #   cpp_arg_struct_clear_jl = []
  #   
  #   # ###################################################################################################
  #   #    this patch
  #   # ###################################################################################################
  #   if parent_class_name
  #     cpp_arg_call_worker_ctx_list.push "worker_ctx->_this"
  #     cpp_arg_struct_decl_jl      .push "#{parent_class_name}* _this;"
  #     cpp_arg_struct_assign_in_jl .push "worker_ctx->_this = _this;"
  #   
  #   # ###################################################################################################
  #   #    
  #   #    struct decl + clear (after execute)
  #   #    
  #   # ###################################################################################################
  #   # ###################################################################################################
  #   #    arg
  #   # ###################################################################################################
  #   ref_clear_impl = (name)->
  #     cpp_arg_struct_decl_jl.push "erlang_nif_ref #{name}_ref;"
  #     cpp_arg_struct_clear_jl.push """
  #       if (worker_ctx->#{name}_ref) {
  #         status = erlang_nif_delete_reference(env, worker_ctx->#{name}_ref);
  #         if (status != erlang_nif_ok) {
  #           printf("status = %d\\n", status);
  #           erlang_nif_throw_error(env, nullptr, "erlang_nif_delete_reference fail for #{name}");
  #           return;
  #         }
  #       }
  #       """#"
  #   
  #   for v, idx in arg_list
  #     {name, type} = v
  #     switch type
  #       when "bool", "i32", "i64", "u32", "u64", "f32", "f64"
  #         cpp_arg_struct_decl_jl.push "#{type} #{name};"
  #         # no cpp_arg_struct_clear_jl
  #       
  #       when "str"
  #         cpp_arg_struct_decl_jl.push "char* #{name};"
  #         cpp_arg_struct_decl_jl.push "size_t #{name}_len;"
  #         cpp_arg_struct_clear_jl.push "free(worker_ctx->#{name});"
  #       
  #       when "str_no_free"
  #         cpp_arg_struct_decl_jl.push "char* #{name};"
  #         cpp_arg_struct_decl_jl.push "size_t #{name}_len;"
  #       
  #       when "buf"
  #         cpp_arg_struct_decl_jl.push "u8* #{name};"
  #         cpp_arg_struct_decl_jl.push "size_t #{name}_len;"
  #         ref_clear_impl name
  #       
  #       else
  #         cpp_arg_struct_decl_jl.push "#{type}* #{name};"
  #         ref_clear_impl name
  #   
  #   # ###################################################################################################
  #   #    ret
  #   # ###################################################################################################
  #   # COPYPASTE arg_list
  #   # no cpp_arg_struct_clear_jl for all
  #   # no refs for all
  #   for v, idx in ret_list
  #     {name, type} = v
  #     switch type
  #       when "bool", "i32", "i64", "u32", "u64", "f32", "f64"
  #         cpp_arg_struct_decl_jl.push "#{type} #{name};"
  #       
  #       # TODO str_static???
  #       when "str", "str_no_free"
  #         cpp_arg_struct_decl_jl.push "char* #{name};"
  #         cpp_arg_struct_decl_jl.push "size_t #{name}_len;"
  #       
  #       when "str_simple_craft"
  #         cpp_arg_struct_decl_jl.push "std::string* #{name};"
  #       
  #       when "buf"
  #         cpp_arg_struct_decl_jl.push "u8* #{name};"
  #         cpp_arg_struct_decl_jl.push "size_t #{name}_len;"
  #       
  #       when "buf_val"
  #         cpp_arg_struct_decl_jl.push "u8* #{name};"
  #         cpp_arg_struct_decl_jl.push "size_t #{name}_len;"
  #         cpp_arg_struct_decl_jl.push "erlang_nif_value #{name}_val;"
  #       
  #       else
  #         cpp_arg_struct_decl_jl.push "#{type}* #{name};"
  #   
  #   # ###################################################################################################
  #   #    
  #   #    struct init + assign
  #   #    
  #   # ###################################################################################################
  #   ref_init_assign_impl = (name)->
  #     cpp_worker_ctx_init_jl.push """
  #       worker_ctx->#{name}_ref = nullptr;
  #       """
  #     cpp_arg_struct_assign_in_jl.push """
  #       status = erlang_nif_create_reference(env, #{name}_val, 1, &worker_ctx->#{name}_ref);
  #       if (status != erlang_nif_ok) {
  #         printf("status = %d\\n", status);
  #         erlang_nif_throw_error(env, nullptr, "Unable to create reference for #{name}. erlang_nif_create_reference");
  #         _worker_ctx_#{fn_name}_clear(env, worker_ctx);
  #         return ret_dummy;
  #       }
  #       """#"
  #   
  #   for v, idx in arg_list
  #     {name, type} = v
  #     cpp_arg_struct_assign_in_jl.push "worker_ctx->#{name} = #{name};"
  #     switch type
  #       when "bool", "i32", "i64", "u32", "u64", "f32", "f64"
  #         # no cpp_worker_ctx_init_jl
  #         # no extra assign
  #         "ok"
  #       
  #       when "str", "str_no_free"
  #         # no cpp_worker_ctx_init_jl
  #         cpp_arg_struct_assign_in_jl.push """
  #           worker_ctx->#{name}_len = #{name}_len;
  #           """
  #       
  #       when "buf"
  #         cpp_arg_struct_assign_in_jl.push """
  #           worker_ctx->#{name}_len = #{name}_len;
  #           """
  #         ref_init_assign_impl name
  #       
  #       else
  #         ref_init_assign_impl name
  #   
  #   # ###################################################################################################
  #   #    
  #   #    struct call
  #   #    
  #   # ###################################################################################################
  #   for v, idx in arg_list
  #     {name, type} = v
  #     switch type
  #       when "bool", "i32", "i64", "u32", "u64", "f32", "f64"
  #         cpp_arg_call_worker_ctx_list.push "worker_ctx->#{name}"
  #       
  #       when "str", "str_no_free"
  #         cpp_arg_call_worker_ctx_list.push "worker_ctx->#{name}"
  #         cpp_arg_call_worker_ctx_list.push "worker_ctx->#{name}_len"
  #       
  #       when "buf"
  #         cpp_arg_call_worker_ctx_list.push "worker_ctx->#{name}"
  #         cpp_arg_call_worker_ctx_list.push "worker_ctx->#{name}_len"
  #       
  #       else
  #         cpp_arg_call_worker_ctx_list.push "worker_ctx->#{name}"
  #   
  #   for v, idx in ret_list
  #     {name, type} = v
  #     switch type
  #       when "bool", "i32", "i64", "u32", "u64", "f32", "f64"
  #         cpp_arg_call_worker_ctx_list.push "worker_ctx->#{name}"
  #       
  #       when "str"
  #         cpp_arg_call_worker_ctx_list.push "worker_ctx->#{name}"
  #         cpp_arg_call_worker_ctx_list.push "worker_ctx->#{name}_len"
  #       
  #       when "str_simple_craft"
  #         cpp_arg_call_worker_ctx_list.push "worker_ctx->#{name}"
  #       
  #       when "buf"
  #         cpp_arg_call_worker_ctx_list.push "worker_ctx->#{name}"
  #         cpp_arg_call_worker_ctx_list.push "worker_ctx->#{name}_len"
  #       
  #       when "buf_val"
  #         cpp_arg_call_worker_ctx_list.push "worker_ctx->#{name}"
  #         cpp_arg_call_worker_ctx_list.push "worker_ctx->#{name}_len"
  #         cpp_arg_call_worker_ctx_list.push "worker_ctx->#{name}_val"
  #       
  #       else
  #         cpp_arg_call_worker_ctx_list.push "worker_ctx->#{name}"
  #   
  #   # ###################################################################################################
  #   #    
  #   #    ret cpp_ret_async
  #   #    
  #   # ###################################################################################################
  #   if ret_list.length == 0
  #     cpp_ret_async = """
  #       status = erlang_nif_call_function(env, global, callback, 0, call_argv, &result);
  #       #{async_status_check 'erlang_nif_call_function'}
  #       _worker_ctx_#{fn_name}_clear(env, worker_ctx);
  #       """#"
  #   else
  #     # unified
  #     cpp_ret_async_wrap_jl = []
  #     for ret, ret_idx in ret_list
  #       {name, type} = ret
  #       if ret_list.length == 1
  #         ret_tmp_name = "call_argv[1]"
  #       else
  #         ret_tmp_name = "_ret_#{name}"
  #         cpp_ret_async_wrap_jl.push "erlang_nif_value #{ret_tmp_name};"
  #       
  #       switch type
  #         when "bool"
  #           cpp_ret_async_wrap_jl.push """
  #             status = erlang_nif_get_boolean(env, worker_ctx->#{name}, &#{ret_tmp_name});
  #             #{async_status_check 'erlang_nif_get_boolean'}
  #             """
  #         when "i32"
  #           cpp_ret_async_wrap_jl.push """
  #             status = erlang_nif_create_int32(env, worker_ctx->#{name}, &#{ret_tmp_name});
  #             #{async_status_check 'erlang_nif_create_int32'}
  #             """
  #         when "i64"
  #           cpp_ret_async_wrap_jl.push """
  #             status = erlang_nif_create_bigint_int64(env, worker_ctx->#{name}, &#{ret_tmp_name});
  #             #{async_status_check 'erlang_nif_create_bigint_int64'}
  #             """
  #         when "u32"
  #           cpp_ret_async_wrap_jl.push """
  #             status = erlang_nif_create_uint32(env, worker_ctx->#{name}, &#{ret_tmp_name});
  #             #{async_status_check 'erlang_nif_create_uint32'}
  #             """
  #         when "u64"
  #           cpp_ret_async_wrap_jl.push """
  #             status = erlang_nif_create_bigint_uint64(env, worker_ctx->#{name}, &#{ret_tmp_name});
  #             #{async_status_check 'erlang_nif_create_bigint_uint64'}
  #             """
  #         when "f32"
  #           cpp_ret_async_wrap_jl.push """
  #             status = erlang_nif_create_double(env, (f64)worker_ctx->#{name}, &#{ret_tmp_name});
  #             #{async_status_check 'erlang_nif_create_double'}
  #             """
  #         when "f64"
  #           cpp_ret_async_wrap_jl.push """
  #             status = erlang_nif_create_double(env, worker_ctx->#{name}, &#{ret_tmp_name});
  #             #{async_status_check 'erlang_nif_create_double'}
  #             """
  #         when "str", "str_static"
  #           cpp_ret_async_wrap_jl.push """
  #             status = erlang_nif_create_string_utf8(env, worker_ctx->#{name}, worker_ctx->#{name}_len, &#{ret_tmp_name});
  #             #{async_status_check 'erlang_nif_create_string_utf8'}
  #             """
  #         when "str_simple_craft"
  #           cpp_ret_async_wrap_jl.push """
  #             status = erlang_nif_create_string_utf8(env, worker_ctx->#{name}->c_str(), worker_ctx->#{name}->size(), &#{ret_tmp_name});
  #             #{async_status_check 'erlang_nif_create_string_utf8'}
  #             """
  #         when "buf", "buf_static"
  #           cpp_ret_async_wrap_jl.push """
  #             {
  #               void* _ret_tmp;
  #               status = erlang_nif_create_buffer_copy(env, worker_ctx->#{name}_len, worker_ctx->#{name}, &_ret_tmp, &#{ret_tmp_name});
  #               #{async_status_check 'erlang_nif_create_buffer_copy'}
  #             }
  #             """
  #         when "buf_val"
  #           cpp_ret_async_wrap_jl.push """
  #             {
  #               #{ret_tmp_name} = worker_ctx->#{name}_val;
  #             }
  #             """
  #         
  #         else
  #           # TODO FIXME тут должен быть не undefined, а null
  #           cpp_ret_async_wrap_jl.push """
  #             if (!worker_ctx->#{name}) {
  #               status = erlang_nif_get_undefined(env, &#{ret_tmp_name});
  #               #{make_tab async_status_check('erlang_nif_get_undefined'), "  "}
  #             } else {
  #               status = erlang_nif_get_reference_value(env, worker_ctx->#{name}->_wrapper, &#{ret_tmp_name});
  #               #{make_tab async_status_check('erlang_nif_get_reference_value'), "  "}
  #             }
  #             """
  #       
  #       if ret_list.length > 1
  #         cpp_ret_async_wrap_jl.push """
  #           status = erlang_nif_set_element(env, call_argv[1], #{ret_idx}, _ret_#{name});
  #           #{async_status_check "erlang_nif_set_element ret_idx=#{ret_idx}"}
  #           """#"
  #     
  #     if ret_list.length == 1
  #       cpp_ret_async = """
  #         status = erlang_nif_get_undefined(env, &call_argv[0]);
  #         #{async_status_check 'erlang_nif_get_undefined'}
  #         #{join_list cpp_ret_async_wrap_jl, ""}
  #         
  #         status = erlang_nif_call_function(env, global, callback, 2, call_argv, &result);
  #         #{async_status_check 'erlang_nif_call_function'}
  #         _worker_ctx_#{fn_name}_clear(env, worker_ctx);
  #         """#"
  #     else
  #       cpp_ret_async = """
  #         status = erlang_nif_get_undefined(env, &call_argv[0]);
  #         #{async_status_check 'erlang_nif_get_undefined'}
  #         status = erlang_nif_create_array_with_length(env, #{ret_list.length}, &call_argv[1]);
  #         #{async_status_check 'erlang_nif_create_array_with_length'}
  #         
  #         #{join_list cpp_ret_async_wrap_jl, ""}
  #         
  #         status = erlang_nif_call_function(env, global, callback, 2, call_argv, &result);
  #         #{async_status_check 'erlang_nif_call_function'}
  #         _worker_ctx_#{fn_name}_clear(env, worker_ctx);
  #         """#"
  #   
  #   # ###################################################################################################
  #   #    code
  #   # ###################################################################################################
  #   cpp_arg_call_worker_ctx_list.unshift "worker_ctx->err"
  #   aux_async = """
  #     ////////////////////////////////////////////////////////////////////////////////////////////////////
  #     //   async
  #     ////////////////////////////////////////////////////////////////////////////////////////////////////
  #     struct Worker_ctx_#{fn_name} {
  #       #{join_list cpp_arg_struct_decl_jl, "  "}
  #       
  #       std::string* err;
  #       erlang_nif_ref callback_reference;
  #       erlang_nif_async_work work;
  #     };
  #     
  #     void _worker_ctx_#{fn_name}_clear(erlang_nif_env env, struct Worker_ctx_#{fn_name}* worker_ctx) {
  #       if (worker_ctx->err) {
  #         delete worker_ctx->err;
  #         worker_ctx->err = nullptr;
  #       }
  #       erlang_nif_status status;
  #       #{join_list cpp_arg_struct_clear_jl, "  "}
  #       
  #       status = erlang_nif_delete_async_work(env, worker_ctx->work);
  #       if (status != erlang_nif_ok) {
  #         printf("status = %d\\n", status);
  #         erlang_nif_throw_error(env, nullptr, "erlang_nif_delete_async_work fail");
  #       }
  #       delete worker_ctx;
  #     }
  #     
  #     void _execute_#{fn_name}(erlang_nif_env env, void* _data) {
  #       struct Worker_ctx_#{fn_name}* worker_ctx = (struct Worker_ctx_#{fn_name}*)_data;
  #       _#{fn_name}_impl(#{cpp_arg_call_worker_ctx_list.join ', '});
  #     }
  #     
  #     void _complete_#{fn_name}(erlang_nif_env env, erlang_nif_status execute_status, void* _data) {
  #       erlang_nif_status status;
  #       struct Worker_ctx_#{fn_name}* worker_ctx = (struct Worker_ctx_#{fn_name}*)_data;
  #       
  #       ////////////////////////////////////////////////////////////////////////////////////////////////////
  #       //    prepare for callback (common parts)
  #       ////////////////////////////////////////////////////////////////////////////////////////////////////
  #       erlang_nif_value callback;
  #       status = erlang_nif_get_reference_value(env, worker_ctx->callback_reference, &callback);
  #       if (status != erlang_nif_ok) {
  #         printf("status = %d\\n", status);
  #         erlang_nif_throw_error(env, nullptr, "Unable to get referenced callback (erlang_nif_get_reference_value)");
  #         _worker_ctx_#{fn_name}_clear(env, worker_ctx);
  #         return;
  #       }
  #       status = erlang_nif_delete_reference(env, worker_ctx->callback_reference);
  #       if (status != erlang_nif_ok) {
  #         printf("status = %d\\n", status);
  #         erlang_nif_throw_error(env, nullptr, "Unable to delete reference callback_reference");
  #         _worker_ctx_#{fn_name}_clear(env, worker_ctx);
  #         return;
  #       }
  #       
  #       erlang_nif_value global;
  #       status = erlang_nif_get_global(env, &global);
  #       if (status != erlang_nif_ok) {
  #         printf("status = %d\\n", status);
  #         erlang_nif_throw_error(env, nullptr, "Unable to create return value global (erlang_nif_get_global)");
  #         _worker_ctx_#{fn_name}_clear(env, worker_ctx);
  #         return;
  #       }
  #       ////////////////////////////////////////////////////////////////////////////////////////////////////
  #       if (execute_status != erlang_nif_ok) {
  #         // avoid code duplication
  #         if (!worker_ctx->err) {
  #           worker_ctx->err = new std::string("execute_status != erlang_nif_ok");
  #         }
  #       }
  #       
  #       if (worker_ctx->err) {
  #         erlang_nif_helper_error_cb(env, worker_ctx->err->c_str(), callback);
  #         _worker_ctx_#{fn_name}_clear(env, worker_ctx);
  #         return;
  #       }
  #       
  #       ////////////////////////////////////////////////////////////////////////////////////////////////////
  #       //    callback OK
  #       ////////////////////////////////////////////////////////////////////////////////////////////////////
  #       erlang_nif_value result;
  #       erlang_nif_value call_argv[2];
  #       
  #       #{make_tab cpp_ret_async, "  "}
  #     }
  #     
  #     erlang_nif_value #{fn_name}(erlang_nif_env env, erlang_nif_callback_info info) {
  #       #{make_tab cpp_arg_head, "  "}
  #       ////////////////////////////////////////////////////////////////////////////////////////////////////
  #       #{join_list cpp_erlang_nif_arg_async_jl, "  "}
  #       erlang_nif_value callback = argv[arg_idx];
  #       
  #       ////////////////////////////////////////////////////////////////////////////////////////////////////
  #       Worker_ctx_#{fn_name}* worker_ctx = new Worker_ctx_#{fn_name};
  #       worker_ctx->err = nullptr;
  #       #{join_list cpp_worker_ctx_init_jl, "  "}
  #       status = erlang_nif_create_reference(env, callback, 1, &worker_ctx->callback_reference);
  #       if (status != erlang_nif_ok) {
  #         printf("status = %d\\n", status);
  #         erlang_nif_helper_error_cb(env, "Unable to create reference for callback. erlang_nif_create_reference", callback);
  #         delete worker_ctx;
  #         return ret_dummy;
  #       }
  #       
  #       // NOTE no free utf8 string
  #       erlang_nif_value async_resource_name;
  #       status = erlang_nif_create_string_utf8(env, "dummy", 5, &async_resource_name);
  #       if (status != erlang_nif_ok) {
  #         printf("status = %d\\n", status);
  #         erlang_nif_throw_error(env, nullptr, "Unable to create value async_resource_name set to 'dummy'");
  #         delete worker_ctx;
  #         return ret_dummy;
  #       }
  #       
  #       #{join_list cpp_arg_struct_assign_in_jl, "  "}
  #       
  #       status = erlang_nif_create_async_work(
  #         env,
  #         nullptr,
  #         async_resource_name,
  #         _execute_#{fn_name},
  #         _complete_#{fn_name},
  #         (void*)worker_ctx,
  #         &worker_ctx->work
  #       );
  #       if (status != erlang_nif_ok) {
  #         printf("status = %d\\n", status);
  #         erlang_nif_throw_error(env, nullptr, "erlang_nif_create_async_work fail");
  #         _worker_ctx_#{fn_name}_clear(env, worker_ctx);
  #         return ret_dummy;
  #       }
  #       
  #       status = erlang_nif_queue_async_work(env, worker_ctx->work);
  #       if (status != erlang_nif_ok) {
  #         erlang_nif_throw_error(env, nullptr, "erlang_nif_queue_async_work fail");
  #         _worker_ctx_#{fn_name}_clear(env, worker_ctx);
  #         return ret_dummy;
  #       }
  #       
  #       
  #       return ret_dummy;
  #     }
  #     
  #     """#"
  
  cpp_arg_decl_ext_list = []
  if fn_decl.gen_env
    cpp_arg_decl_ext_list.push "#{'erlang_nif_env'.ljust cpp_arg_decl_list_type_pad} env"
  
  cpp_arg_decl_ext_list.push "#{'std::string*&'.ljust cpp_arg_decl_list_type_pad} err"
  cpp_arg_decl_ext_list.append cpp_arg_decl_list
  
  # ###################################################################################################
  # костыли, чтобы меньше copypaste
  erl_skip_arg_list_jl = []
  if parent_class_name
    erl_skip_arg_list_jl.push "_this"
  
  for v, idx in arg_list
    erl_skip_arg_list_jl.push "_#{v.name}"
  fn_decl.erl_header = """
    #{fn_name.toLowerCase()}_nif(#{erl_skip_arg_list_jl.join ', '}) ->
      erlang:nif_error(nif_not_loaded).
    """
  fn_decl.erl_header_export = """
    #{fn_name.toLowerCase()}_nif/#{erl_skip_arg_list_jl.length}
    """
  {
    cb_name
    fn_cont
    fn_cont_use_code_bubble
    file_render_name: fn_file_name
    file_render_fn  : (fn_cont)->
      """
      void _#{fn_name}_impl(
        #{make_tab cpp_arg_decl_ext_list.join(',\n'), '  '}
      ) {
        #{make_tab fn_cont, "  "}
      }
      
      #{aux_sync}
      """#"
  }
