module = @
class @Napi_module
  name  : ""
  folder: ""
  
  target_config_arch_hash : {}
  target_config_default   : {}
  
  # TODO через mixin'ы
  include_list : []
  include_hash : {}
  lib_include_list : []
  lib_include_hash : {}
  file_raw_pre_list : []
  file_raw_pre_hash : {}
  file_raw_post_list : []
  file_raw_post_hash : {}
  file_raw_header_pre_list : []
  file_raw_header_pre_hash : {}
  code_init_list : []
  code_init_hash : {}
  fn_decl_list : []
  fn_decl_hash : {}
  class_decl_list : []
  class_decl_hash : {}
  pipeline_decl_list : []
  pipeline_decl_hash : {}
  compile_file_list : []
  compile_file_hash : {}
  
  class_tag_hash : {}
  class_tag_idx_counter : 1
  
  constructor:()->
    @target_config_arch_hash = {}
    @target_config_default = {
      "cflags"   : []
      "cflags_cc": []
      link_settings : {
        libraries : []
      }
    }
    
    @file_raw_pre_list = []
    @file_raw_pre_hash = {}
    @file_raw_post_list = []
    @file_raw_post_hash = {}
    @file_raw_header_pre_list = []
    @file_raw_header_pre_hash = {}
    @code_init_list = []
    @code_init_hash = {}
    @fn_decl_list = []
    @fn_decl_hash = {}
    @class_decl_list = []
    @class_decl_hash = {}
    @pipeline_decl_list = []
    @pipeline_decl_hash = {}
    @compile_file_list = []
    @compile_file_hash = {}
    @class_tag_hash = {}
  
  include_get : (name)->
    if !ret = @include_hash[name]
      @include_hash[name] = ret = name
      @include_list.push ret
    ret
  
  lib_include_get : (name)->
    if !ret = @lib_include_hash[name]
      @lib_include_hash[name] = ret = name
      @lib_include_list.push ret
    ret
  
  file_raw_pre_get : (name)->
    if !ret = @file_raw_pre_hash[name]
      @file_raw_pre_hash[name] = ret = new module.Napi_file_raw
      @file_raw_pre_list.push ret
      ret.name = name
    ret
  
  file_raw_header_pre_get : (name)->
    if !ret = @file_raw_header_pre_hash[name]
      @file_raw_header_pre_hash[name] = ret = new module.Napi_file_raw
      @file_raw_header_pre_list.push ret
      ret.name = name
    ret
  
  file_raw_post_get : (name)->
    if !ret = @file_raw_post_hash[name]
      @file_raw_post_hash[name] = ret = new module.Napi_file_raw
      @file_raw_post_list.push ret
      ret.name = name
    ret
  
  # may be suboptimal, but almost copypaste == will work
  # name == code
  code_init_get : (name)->
    if !ret = @code_init_hash[name]
      @code_init_hash[name] = ret = name
      @code_init_list.push ret
      ret.name = name
    ret
  
  fn_decl_get : (name)->
    if !ret = @fn_decl_hash[name]
      @fn_decl_hash[name] = ret = new module.Napi_fn_decl
      @fn_decl_list.push ret
      ret.name = name
    ret
  
  class_decl_get : (name)->
    if !ret = @class_decl_hash[name]
      @class_decl_hash[name] = ret = new module.Napi_class_decl
      @class_decl_list.push ret
      ret.name = name
      if idx = @class_tag_hash[name]
        ret.class_tag_idx = idx
      else
        ret.class_tag_idx = @class_tag_hash[name] = @class_tag_idx_counter++
    ret
  
  pipeline_decl_get : (name)->
    if !ret = @pipeline_decl_hash[name]
      @pipeline_decl_hash[name] = ret = new module.Napi_pipeline_decl
      @pipeline_decl_list.push ret
      ret.name = name
    ret
  
  compile_file_get : (name)->
    if !ret = @compile_file_hash[name]
      @compile_file_hash[name] = ret = name
      @compile_file_list.push ret
      ret.name = name
    ret

class @Napi_file_raw
  name : ""
  cont : ""

# В режиме pipeline используются только поля name, и raw_fixed_code
class @Napi_fn_decl
  name      : ""
  arg_list  : []
  arg_hash  : {}
  ret_list  : [] # тоже Napi_fn_arg
  ret_hash  : {}
  class_dep_list : []
  class_dep_hash : {}
  gen_sync  : true
  gen_async : true
  gen_env   : false
  parent_class_name : ""
  raw_fixed_code : ""
  code_unit : ""
  is_raw    : false # for pipeline
  
  constructor:()->
    @arg_list = []
    @arg_hash = {}
    @ret_list = []
    @ret_hash = {}
    @class_dep_list = []
    @class_dep_hash = {}
  
  arg_get : (name)->
    if !ret = @arg_hash[name]
      @arg_hash[name] = ret = new module.Napi_fn_arg
      @arg_list.push ret
      ret.name = name
    ret
    
  ret_get : (name)->
    if !ret = @ret_hash[name]
      @ret_hash[name] = ret = new module.Napi_fn_arg
      @ret_list.push ret
      ret.name = name
    ret
  
  class_dep_get : (name)->
    if !ret = @class_dep_hash[name]
      @class_dep_hash[name] = ret = name
      @class_dep_list.push ret
      ret.name = name
    ret

class @Napi_fn_arg
  name : ""
  type : ""
  is_raw  : false
  is_array: false

# ###################################################################################################
#    class
# ###################################################################################################
class @Napi_class_field_decl
  name : ""
  type : ""
  is_array : false

class @Napi_class_decl
  name : ""
  is_fake : false
  raw_class_decl_code   : ""
  raw_class_include_code: ""
  
  class_tag_idx : 0
  code_init_list : []
  code_init_hash : {}
  fn_decl_list : []
  fn_decl_hash : {}
  field_list : []
  field_hash : {}
  class_dep_list : []
  class_dep_hash : {}
  
  constructor:()->
    @code_init_list = []
    @code_init_hash = {}
    @fn_decl_list = []
    @fn_decl_hash = {}
    @field_list = []
    @field_hash = {}
    @class_dep_list = []
    @class_dep_hash = {}
  
  code_init_get : (name)->
    if !ret = @code_init_hash[name]
      @code_init_hash[name] = ret = name
      @code_init_list.push ret
      ret.name = name
    ret
  
  fn_decl_get : (name)->
    if !ret = @fn_decl_hash[name]
      @fn_decl_hash[name] = ret = new module.Napi_fn_decl
      @fn_decl_list.push ret
      ret.name = name
    ret
  
  field_get : (name)->
    if !ret = @field_hash[name]
      @field_hash[name] = ret = new module.Napi_class_field_decl
      @field_list.push ret
      ret.name = name
    ret
  
  class_dep_get : (name)->
    if !ret = @class_dep_hash[name]
      @class_dep_hash[name] = ret = name
      @class_dep_list.push ret
      ret.name = name
    ret

# ###################################################################################################
#    pipeline
# ###################################################################################################
class @Napi_pipeline_decl
  name    : ""
  defered_render_list : []
  defered_render_hash : {}
  fn_decl_list : []
  fn_decl_hash : {}
  
  # полу-костыль
  task_saturation_threshold : 100
  
  constructor:()->
    @defered_render_list = []
    @defered_render_hash = {}
    @fn_decl_list = []
    @fn_decl_hash = {}
  
  defered_render_get : (name, cont)->
    if !ret = @defered_render_hash[name]
      @defered_render_hash[name] = ret = {
        name
        cont
      }
      @defered_render_list.push ret
      ret.name = name
    ret
  
  fn_decl_get : (name)->
    if !ret = @fn_decl_hash[name]
      # @fn_decl_hash[name] = ret = new module.Napi_pipeline_fn_decl
      @fn_decl_hash[name] = ret = new module.Napi_fn_decl
      @fn_decl_list.push ret
      ret.name = name
    ret
  
# class @Napi_pipeline_fn_decl
  # name : ""

# ###################################################################################################
#    const
# ###################################################################################################
@std_fn_decl_type_hash =
  "bool": true
  "i32" : true
  "i64" : true
  "u32" : true
  "u64" : true
  "f32" : true
  "f64" : true
  "str" : true
  "str_no_free" : true
  "str_static"  : true
  "str_simple_craft" : true
  "buf" : true
  "buf_val" : true
  # TODO all vec?

@std_class_field_decl_type_hash =
  "bool": true
  "i32" : true
  "i64" : true
  "u32" : true
  "u64" : true
  "f32" : true
  "f64" : true
  "str" : true
  "str_slow" : true
  "buf" : true
  "buf_val" : true
  "vec" : true
  "vec_u8"  : true
  "vec_u16" : true
  "vec_u32" : true
  "vec_u64" : true
  "vec_i8"  : true
  "vec_i16" : true
  "vec_i32" : true
  "vec_i64" : true
