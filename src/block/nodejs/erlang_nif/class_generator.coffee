{std_class_field_decl_type_hash} = require "./erlang_nif_decl"

@class_generator = (root, ctx, erlang_nif_module)->
  class_decl = root.data_hash.erlang_nif_class_decl
  
  class_name = class_decl.name
  field_list_jl = []
  # TODO
  aux_class_init_code = ""
  
  # ###################################################################################################
  #    check
  # ###################################################################################################
  for v in class_decl.field_list
    {name, type} = v
    continue if std_class_field_decl_type_hash[type]
    continue if v.is_raw
    if !erlang_nif_module.class_decl_hash[type]?
      throw new Error "class '#{type}' doesn't exists field=#{name} erlang_nif_class=#{class_decl.name}"
  
  # ###################################################################################################
  #    field_list
  # ###################################################################################################
  for v in class_decl.field_list
    {name, type, is_array} = v
    if v.is_raw
      name = name.replace /;$/, ""
      field_list_jl.push "#{name};"
    else
      switch type
        when "bool", "i32", "i64", "u32", "u64", "f32", "f64"
          if !is_array
            field_list_jl.push "#{type} #{name};"
          else
            field_list_jl.push "std::vector<#{type}> #{name};"
        
        when "str"
          if is_array
            return cb new Error "str[] is not supported. Use str_slow[] instead"
          
          field_list_jl.push "char*   #{name};"
          field_list_jl.push "size_t  #{name}_len;"
        
        when "str_slow"
          if is_array
            field_list_jl.push "std::vector<std::string> #{name};"
          else
            field_list_jl.push "std::string #{name};"
        
        when "buf"
          if is_array
            return cb new Error "buf[] is not supported. Use vec[] instead"
          
          field_list_jl.push "u8*     #{name};"
          field_list_jl.push "size_t  #{name}_len;"
        
        when "buf_val"
          if is_array
            return cb new Error "buf[] is not supported. Use vec[] instead"
          
          field_list_jl.push "u8*     #{name};"
          field_list_jl.push "size_t  #{name}_len;"
          field_list_jl.push "erlang_nif_value #{name}_val;"
        
        when "vec"
          if is_array
            field_list_jl.push "std::vector<std::vector<u8>> #{name};"
          else
            field_list_jl.push "std::vector<u8> #{name};"
        
        when "vec_u8", "vec_u16", "vec_u32", "vec_u64", "vec_i8", "vec_i16", "vec_i32", "vec_i64"
          if is_array
            field_list_jl.push "std::vector<std::vector<#{type.replace 'vec_', ''}>> #{name};"
          else
            field_list_jl.push "std::vector<#{type.replace 'vec_', ''}> #{name};"
        
        else
          if !is_array
            field_list_jl.push "#{type}* #{name};"
          else
            field_list_jl.push "std::vector<#{type}*> #{name};"
  
  # ###################################################################################################
  #    code
  # ###################################################################################################
  # Прим. #pragma once не является стандартом. Имеет проблемы при одинаковых именах файлов
  # https://www.reddit.com/r/cpp/comments/ajltg/whats_wrong_with_pragma_once/
  # https://stackoverflow.com/questions/1143936/pragma-once-vs-include-guards
  # Но ИМХО пускай будет #pragma once
  
  ctx.file_render "src/#{class_name}/class.cpp", """
    #pragma once
    
    u32 #{class_name}_tag = #{class_decl.class_tag_idx};
    class #{class_name} {
      public:
      u32   _class_tag = #{class_name}_tag;
      bool  _deleted = false;
      #{join_list field_list_jl, "  "}
      
      ERL_NIF_TERM _wrapper;
    };
    struct #{class_name}_c_wrapper {
      #{class_name}* obj;
    };
    static void #{class_name}_destructor(ErlNifEnv* envPtr, void* obj) {
      #{class_name}_c_wrapper* _this = static_cast<#{class_name}_c_wrapper*>(obj);
      delete _this->obj;
      enif_release_resource(_this);
    }
    
    ERL_NIF_TERM #{class_name}_constructor_cpp_nif(ErlNifEnv* envPtr, int argc, const ERL_NIF_TERM argv[]) {
      #{class_name}* _this = new #{class_name}();
      #{join_list class_decl.code_init_list, "  "}
      #{class_name}_c_wrapper* wrapper = (#{class_name}_c_wrapper*)enif_alloc_resource(CLASS_DECL_#{class_name}_c_wrapper, sizeof(struct #{class_name}_c_wrapper));
      wrapper->obj = _this;
      
      _this->_wrapper = enif_make_resource(envPtr, wrapper);
      
      return _this->_wrapper;
    }
    
    """#"
  
  return
