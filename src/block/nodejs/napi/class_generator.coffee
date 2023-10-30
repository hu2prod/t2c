{std_class_field_decl_type_hash} = require "./napi_decl"

@class_generator = (root, ctx, napi_module)->
  class_decl = root.data_hash.napi_class_decl
  
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
    if !napi_module.class_decl_hash[type]?
      throw new Error "class '#{type}' doesn't exists field=#{name} napi_class=#{class_decl.name}"
  
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
          field_list_jl.push "napi_value #{name}_val;"
        
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
  
  include_common_class_decl_jl = []
  include_common_class_jl = []
  class_hash = {}
  class_hash[class_name] = true # do not include yourself
  
  for v in class_decl.field_list
    {type, is_raw} = v
    continue if is_raw
    continue if std_class_field_decl_type_hash[type]
    
    type = type.capitalize()
    continue if class_hash[type]
    class_hash[type] = true
    
    include_common_class_decl_jl.push """
      class #{type};
      """
    
    include_common_class_jl.push """
      #include "../#{type}/class.hpp"
      """#"
  
  for type in class_decl.class_dep_list
    type = type.capitalize()
    continue if class_hash[type]
    class_hash[type] = true
    
    include_common_class_decl_jl.push """
      class #{type};
      """
    include_common_class_jl.push """
      #include "../#{type}/class.hpp"
      """#"
  
  ctx.file_render "src/#{class_name}/class.hpp", """
    #pragma once
    #include "../common.hpp"
    #{join_list include_common_class_decl_jl, ""}
    #{join_list include_common_class_jl, ""}
    
    extern u32 #{class_name}_tag;
    class #{class_name} {
      public:
      u32   _class_tag = #{class_name}_tag;
      bool  _deleted = false;
      #{join_list field_list_jl, "  "}
      
      napi_ref _wrapper;
      void free();
    };
    void #{class_name}_destructor(napi_env env, void* native_object, void* /*finalize_hint*/);
    
    napi_value #{class_name}_constructor(napi_env env, napi_callback_info info);
    
    """#"
  ctx.file_render "src/#{class_name}/class.cpp", """
    #pragma once
    #include "class.hpp"
    
    u32 #{class_name}_tag = #{class_decl.class_tag_idx};
    void #{class_name}::free() {
      if (this->_deleted) return;
      this->_deleted = true;
    }
    
    void #{class_name}_destructor(napi_env env, void* native_object, void* /*finalize_hint*/) {
      #{class_name}* _this = static_cast<#{class_name}*>(native_object);
      _this->free();
      delete _this;
    }
    
    napi_value #{class_name}_constructor(napi_env env, napi_callback_info info) {
      napi_status status;
      
      napi_value _js_this;
      status = napi_get_cb_info(env, info, nullptr, nullptr, &_js_this, nullptr);
      if (status != napi_ok) {
        napi_throw_error(env, nullptr, "Unable to create class #{class_name}");
        return nullptr;
      }
      
      #{class_name}* _this = new #{class_name}();
      #{join_list class_decl.code_init_list, "  "}
      
      status = napi_wrap(env, _js_this, _this, #{class_name}_destructor, nullptr /* finalize_hint */, &_this->_wrapper);
      if (status != napi_ok) {
        napi_throw_error(env, nullptr, "Unable to napi_wrap for class #{class_name}");
        return nullptr;
      }
      
      return _js_this;
    }
    
    """#"
  
  return
