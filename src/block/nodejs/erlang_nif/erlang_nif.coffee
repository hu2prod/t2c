module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
  mod_config
  iced_compile
} = require "../../common_import"

erlang_nif_decl = require "./erlang_nif_decl"

# NOTE. по поводу именования
# erlang_nif package потому что npm package
# а с точки зрения С++ кода это erlang_nif module

# ###################################################################################################
#    erlang_nif_package
# ###################################################################################################
bdh_module_name_root module, "erlang_nif_package",
  nodegen       : (root, ctx)->
    npm_i "fy"
    npm_i "lock_mixin"
    npm_i "minimist"
    # for windows, fy dependencies, but samba + simlinks doesn't work
    npm_i "colors"
    npm_i "prettyjson"
    
    npm_script "build_erlang_nif", "./s1_linux_build.coffee --verbose"
    
    build2 "erlang_nif", "npm run build_erlang_nif"
    
    {erlang_nif_module} = root.data_hash
    
    project_node = root.type_filter_search "project"
    
    for _k, arch of project_node.data_hash.arch_hash
      # deep clone
      conf = JSON.parse JSON.stringify erlang_nif_module.target_config_default
      erlang_nif_module.target_config_arch_hash[arch.name] = conf
    
    erlang_nif_module.name   = root.name
    # TODO remove?
    erlang_nif_module.folder = ctx.curr_folder
    
    false
  
  emit_codegen  : (root, ctx)->
    {name} = root
    {erlang_nif_module} = root.data_hash
    
    project_node = root.type_filter_search "project"
    {os_hash} = project_node.data_hash
    
    if os_hash.linux
      ctx.file_render_exec "s1_linux_build.coffee", ctx.tpl_read "pkg/s1_linux_build.coffee"
    if os_hash.win
      ctx.file_render_exec "s1_win_build.coffee",   ctx.tpl_read "pkg/s1_win_build.coffee"
    
    # ###################################################################################################
    #    extra wrappers
    # ###################################################################################################
    path = "../src_c_erlang_nif/#{name}"
    # NOTE iced related
    ctx.file_render "src/#{name}.coffee", """
      fs = require "fs"
      path = __dirname+"/#{name}.node"
      module.exports = if fs.existsSync path
        require path
      else
        require #{JSON.stringify path}
      
      """#"
    
    # ###################################################################################################
    #    
    #    folder_wrap
    #    
    # ###################################################################################################
    old_folder = ctx.curr_folder
    ctx.curr_folder += "/src_c_erlang_nif/#{name}"
    
    ctx.walk_child_list_only_fn root
    
    # ###################################################################################################
    #    for each arch
    # ###################################################################################################
    for _k, arch of project_node.data_hash.arch_hash
      ctx.file_render "#{arch.name}/.gitignore", """
        build
        file_hash.json
        """
      
      target = {
        "target_name": "module"
        "sources": [ "../src/module.cpp" ]
      }
      if !erlang_nif_module.target_config_arch_hash[arch.name]
        throw new Error "!erlang_nif_module.target_config_arch_hash[#{arch.name}]. This can be caused by erlang_nif_package declared before arch"
      obj_set target, erlang_nif_module.target_config_arch_hash[arch.name]
      ctx.file_render "#{arch.name}/binding.gyp", JSON.stringify {
        "targets": [
          target
        ]
      }, null, 2
      
      package_json_cont = {
        "name"        : name
        "version"     : "1.0.0"
        "description" : ""
        "main"        : "index.js"
        "scripts"     : {
          "install": "node-gyp configure build"
          "install-verbose": "node-gyp configure build --verbose"
        }
        "keywords"    : []
        "author"      : ""
        "license"     : "MIT"
        "dependencies": {
          "node-gyp": "^7.0.0"
        }
      }
      ctx.file_render "#{arch.name}/package.json", JSON.stringify package_json_cont, null, 2
      
      ctx.file_render "#{arch.name}/index.js", """
        module.exports = require("./build/Release/module");
        
        """#"
      
    # ###################################################################################################
    #    misc
    # ###################################################################################################
    ctx.file_render "index.js", iced_compile """
      module.exports = require("./"+(global.arch ? #{JSON.stringify mod_config.curr_arch}))
      
      """#"
    
    # ###################################################################################################
    #    src
    # ###################################################################################################
    ctx.file_render "src/type.hpp",  ctx.tpl_read "erlang_nif/type.hpp"
    ctx.file_render "src/macro.hpp", ctx.tpl_read "erlang_nif/macro.hpp"
    
    
    # ###################################################################################################
    #    main
    # ###################################################################################################
    include_jl      = erlang_nif_module.include_list
    lib_include_jl  = erlang_nif_module.lib_include_list
    class_decl_jl   = []
    class_include_jl= []
    fn_include_jl   = []
    misc_pre_include_jl = []
    misc_post_include_jl= []
    
    init_jl         = clone erlang_nif_module.code_init_list
    fn_export_jl    = []
    class_export_jl = []
    
    for file_raw in erlang_nif_module.file_raw_pre_list
      misc_pre_include_jl.push "#include #{JSON.stringify file_raw.name}"
      ctx.file_render "src/#{file_raw.name}", file_raw.cont
    
    for file_raw in erlang_nif_module.file_raw_post_list
      misc_post_include_jl.push "#include #{JSON.stringify file_raw.name}"
      ctx.file_render "src/#{file_raw.name}", file_raw.cont
    
    for fn_decl in erlang_nif_module.fn_decl_list
      fn_include_jl.push "#include #{JSON.stringify fn_decl.name+'.cpp'}"
      
      if fn_decl.gen_sync
        fn_export_jl.push  "FN_EXPORT(#{fn_decl.name}_sync)"
      if fn_decl.gen_async
        fn_export_jl.push  "FN_EXPORT(#{fn_decl.name})"
    
    for class_decl in erlang_nif_module.class_decl_list
      if class_decl.is_fake
        class_decl_jl   .push class_decl.raw_class_decl_code    if class_decl.raw_class_decl_code
        class_include_jl.push class_decl.raw_class_include_code if class_decl.raw_class_include_code
        # class_export_jl ???
        continue
      
      class_name = class_decl.name
      class_decl_jl   .push "ErlNifResourceType* CLASS_DECL_#{class_name}_c_wrapper;"
      class_decl_jl   .push "class #{class_name};"
      class_include_jl.push "#include #{JSON.stringify class_name+'/class.cpp'}"
    
    class_export_inject_jl = []
    class_export_header_jl = []
    nif_c_wrap_jl = []
    erl_header_jl = []
    erl_header_export_jl = []
    for class_decl in erlang_nif_module.class_decl_list
      if class_decl.is_fake
        continue
      
      class_name = class_decl.name
      
      erl_header_jl.push """
        #{class_name.toLowerCase()}_constructor_nif() ->
          erlang:nif_error(nif_not_loaded).
        """
      erl_header_export_jl.push """
        #{class_name.toLowerCase()}_constructor_nif/0
        """
      class_export_inject_jl.push """
        {"#{class_name.toLowerCase()}_constructor_nif", 0, #{class_name}_constructor_nif, ERL_NIF_DIRTY_JOB_CPU_BOUND},
        """#"
      class_export_header_jl.push "ERL_NIF_TERM #{class_name}_constructor_cpp_nif(ErlNifEnv* envPtr, int argc, const ERL_NIF_TERM argv[]);"
      nif_c_wrap_jl.push """
        static ERL_NIF_TERM #{class_name}_constructor_nif(ErlNifEnv* envPtr, int argc, const ERL_NIF_TERM argv[]) {
          return #{class_name}_constructor_cpp_nif(envPtr, argc, argv);
        }
        """
      class_fn_decl_jl = []
      for fn_decl in class_decl.fn_decl_list
        fn_name = fn_decl.name
        if fn_decl.gen_sync and fn_decl.gen_async
          CLASS_METHOD = "CLASS_METHOD"
        else if !fn_decl.gen_sync and !fn_decl.gen_async
          throw new Error "!gen_sync and !gen_async fn_decl.name=#{fn_decl.name}"
        else if fn_decl.gen_sync
          CLASS_METHOD = "CLASS_METHOD_SYNC"
        else # if fn_decl.gen_async
          CLASS_METHOD = "CLASS_METHOD_ASYNC"
        
        class_fn_decl_jl.push "#{CLASS_METHOD}(#{class_name}, #{fn_name})"
        class_include_jl.push "#include #{JSON.stringify class_name+'/'+fn_name+'.cpp'}"
        
        class_export_inject_jl.push """
          {"#{class_name.toLowerCase()}_#{fn_name}_nif", #{fn_decl.arg_list.length+1}, #{class_name}_#{fn_name}_nif, ERL_NIF_DIRTY_JOB_CPU_BOUND},
          """#"
        class_export_header_jl.push "ERL_NIF_TERM #{class_name}_#{fn_name}_cpp_nif(ErlNifEnv* envPtr, int argc, const ERL_NIF_TERM argv[]);"
        nif_c_wrap_jl.push """
          static ERL_NIF_TERM #{class_name}_#{fn_name}_nif(ErlNifEnv* envPtr, int argc, const ERL_NIF_TERM argv[]) {
            return #{class_name}_#{fn_name}_cpp_nif(envPtr, argc, argv);
          }
          """
        erl_header_jl.push fn_decl.erl_header
        erl_header_export_jl.push fn_decl.erl_header_export
      
      # class_export_jl.push """
      #   CLASS_DEF(#{class_name})
      #   #{join_list class_fn_decl_jl, ''}
      #   CLASS_EXPORT(#{class_name})
      #   """
      class_export_jl.push """
        CLASS_DEF(#{class_name})
        """
    
    if fn_export_jl.length
      init_jl.unshift "erlang_nif_value __fn;"
    # if init_jl.length or fn_export_jl.length or class_export_jl.length
    #   init_jl.unshift "erlang_nif_status status;"
    
    # #{join_list fn_export_jl, "  "}
    # 
    ctx.file_render "src/module.cpp", """
      #include <node_api.h>
      
      #include <stdio.h>
      #include <stdlib.h>
      #include <string.h>
      #include "type.hpp"
      #include "macro.hpp"
      #{join_list include_jl, ""}
      
      #{join_list lib_include_jl, ""}
      
      #{join_list misc_pre_include_jl, ""}
      
      #{join_list class_decl_jl, ""}
      
      #{join_list class_include_jl, ""}
      
      #{join_list fn_include_jl, ""}
      
      #{join_list misc_post_include_jl, ""}
      
      ////////////////////////////////////////////////////////////////////////////////////////////////////
      bool #{name}_init(ErlNifEnv* envPtr, void** priv, ERL_NIF_TERM info) {
        #{join_list init_jl, "  "}
        
        ////////////////////////////////////////////////////////////////////////////////////////////////////
        #{join_list class_export_jl, "  "}
        
        ////////////////////////////////////////////////////////////////////////////////////////////////////
        
        return true;
      }
      /*
        #{join_list class_export_inject_jl, "  "}
      */
      /*
      #{join_list class_export_header_jl, ""}
      */
      /*
      #{join_list nif_c_wrap_jl, ""}
      */
      /*
      #{join_list erl_header_jl, ""}
      */
      /*
      #{erl_header_export_jl.join ", "}
      */
      
      """#"
    
    ctx.curr_folder = old_folder
    
    true


def "erlang_nif_package", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "erlang_nif_package", name, "def"
  bdh_node_module_name_assign_on_call root, module, "erlang_nif_package"
  root.data_hash.erlang_nif_module ?= new erlang_nif_decl.Erlang_nif_module
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    file injectors
# ###################################################################################################
# немного особенные команды. Вызываются на codebub phase
def "erlang_nif_package erlang_nif_file_raw_pre", (name, code)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
  {erlang_nif_module} = erlang_nif_package_node.data_hash
  
  file_raw = erlang_nif_module.file_raw_pre_get name
  file_raw.cont = code
  file_raw

def "erlang_nif_package erlang_nif_file_raw_post", (name, code)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
  {erlang_nif_module} = erlang_nif_package_node.data_hash
  
  file_raw = erlang_nif_module.file_raw_post_get name
  file_raw.cont = code
  file_raw

# ###################################################################################################
#    code injectors
# ###################################################################################################
def "erlang_nif_package erlang_nif_init_raw", (code)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
  {erlang_nif_module} = erlang_nif_package_node.data_hash
  
  erlang_nif_module.code_init_get code

def "erlang_nif_package erlang_nif_include", (code)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
  {erlang_nif_module} = erlang_nif_package_node.data_hash
  
  for line in code.split "\n"
    continue if !line
    erlang_nif_module.include_get line
  return

def "erlang_nif_package erlang_nif_lib_include", (code)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
  {erlang_nif_module} = erlang_nif_package_node.data_hash
  
  for line in code.split "\n"
    continue if !line
    erlang_nif_module.lib_include_get line
  return

# ###################################################################################################
#    config
# ###################################################################################################
arch_filter_check = (arch_filter, target)->
  return true if !arch_filter
  if typeof arch_filter == "string"
    if arch_filter == target
      return true
  else if arch_filter instanceof Array
    if arch_filter.has target
      return true
  else if arch_filter instanceof RegExp
    if arch_filter.test target
      return true
  else
    throw new Error "unimplemented arch_filter #{arch_filter.constructor.name}"
  false

# ###################################################################################################
#    erlang_nif_config_lib
# ###################################################################################################
bdh_module_name_root module, "erlang_nif_config_lib",
  nodegen       : (root, ctx)->
    {
      lib
      arch_filter
    } = root.data_hash
    
    erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
    {erlang_nif_module} = erlang_nif_package_node.data_hash
    
    for k, conf of erlang_nif_module.target_config_arch_hash
      continue if !arch_filter_check arch_filter, k
      
      conf.link_settings.libraries.upush lib
    
    false
  

def "erlang_nif_package erlang_nif_config_lib", (lib, arch_filter)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  key = "#{lib}_#{JSON.stringify arch_filter}"
  root = mod_runner.current_runner.curr_root.tr_get "erlang_nif_config_lib", key, "def"
  bdh_node_module_name_assign_on_call root, module, "erlang_nif_config_lib"
  root.data_hash.lib = lib
  root.data_hash.arch_filter = arch_filter
  
  
  root

# ###################################################################################################
#    erlang_nif_config_include
# ###################################################################################################
bdh_module_name_root module, "erlang_nif_config_include",
  nodegen       : (root, ctx)->
    {
      path
      arch_filter
    } = root.data_hash
    
    erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
    {erlang_nif_module} = erlang_nif_package_node.data_hash
    
    for k, conf of erlang_nif_module.target_config_arch_hash
      continue if !arch_filter_check arch_filter, k
      
      conf.include_dirs ?= []
      conf.include_dirs.upush path
    false

def "erlang_nif_package erlang_nif_config_include", (path, arch_filter)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  key = "#{path}_#{JSON.stringify arch_filter}"
  root = mod_runner.current_runner.curr_root.tr_get "erlang_nif_config_include", key, "def"
  bdh_node_module_name_assign_on_call root, module, "erlang_nif_config_include"
  root.data_hash.path = path
  root.data_hash.arch_filter = arch_filter
  
  
  root

# ###################################################################################################
#    erlang_nif_config_cflags_cc
# ###################################################################################################
bdh_module_name_root module, "erlang_nif_config_cflags_cc",
  nodegen       : (root, ctx)->
    {
      flag
      arch_filter
    } = root.data_hash
    
    erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
    {erlang_nif_module} = erlang_nif_package_node.data_hash
    
    for k, conf of erlang_nif_module.target_config_arch_hash
      continue if !arch_filter_check arch_filter, k
      
      conf.cflags_cc ?= []
      conf.cflags_cc.upush flag
    false

def "erlang_nif_package erlang_nif_config_cflags_cc", (flag, arch_filter)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  key = "#{flag}_#{JSON.stringify arch_filter}"
  root = mod_runner.current_runner.curr_root.tr_get "erlang_nif_config_cflags_cc", key, "def"
  bdh_node_module_name_assign_on_call root, module, "erlang_nif_config_cflags_cc"
  root.data_hash.flag = flag
  root.data_hash.arch_filter = arch_filter
  
  root

# ###################################################################################################
#    erlang_nif_config_obj_set
# ###################################################################################################
bdh_module_name_root module, "erlang_nif_config_obj_set",
  nodegen       : (root, ctx)->
    {
      obj
      arch_filter
    } = root.data_hash
    
    erlang_nif_package_node = mod_runner.current_runner.curr_root.type_filter_search "erlang_nif_package"
    {erlang_nif_module} = erlang_nif_package_node.data_hash
    
    for k, conf of erlang_nif_module.target_config_arch_hash
      continue if !arch_filter_check arch_filter, k
      
      obj_set conf, obj
    false

def "erlang_nif_package erlang_nif_config_obj_set", (obj, arch_filter)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  key = "#{JSON.stringify obj}_#{JSON.stringify arch_filter}"
  root = mod_runner.current_runner.curr_root.tr_get "erlang_nif_config_obj_set", key, "def"
  bdh_node_module_name_assign_on_call root, module, "erlang_nif_config_obj_set"
  root.data_hash.obj = obj
  root.data_hash.arch_filter = arch_filter
  
  root

# ###################################################################################################
#    thread_util
# ###################################################################################################
bdh_module_name_root module, "erlang_nif_thread_util",
  emit_codegen  : (root, ctx)->
    ctx.file_render "src/thread_util.hpp", ctx.tpl_read "erlang_nif/thread_util.hpp"
    false


def "erlang_nif_package erlang_nif_thread_util", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  erlang_nif_include """
    #include "thread_util.hpp"
    """#"
  
  root = mod_runner.current_runner.curr_root.tr_get "erlang_nif_thread_util", "erlang_nif_thread_util", "def"
  bdh_node_module_name_assign_on_call root, module, "erlang_nif_thread_util"
  
  root

