module = @
fs = require "fs"
mkdirp = require "mkdirp"
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
  mod_config
  iced_compile
} = require "../../common_import"

napi_decl = require "./napi_decl"

# NOTE. по поводу именования
# napi package потому что npm package
# а с точки зрения С++ кода это napi module

# ###################################################################################################
#    napi_package
# ###################################################################################################
bdh_module_name_root module, "napi_package",
  nodegen       : (root, ctx)->
    npm_i "fy"
    npm_i "lock_mixin"
    npm_i "minimist"
    # for windows, fy dependencies, but samba + simlinks doesn't work
    npm_i "colors"
    npm_i "prettyjson"
    
    npm_script "build_napi", "./s1_linux_build.coffee --verbose"
    
    build2 "napi", "npm run build_napi"
    
    {napi_module} = root.data_hash
    
    project_node = root.type_filter_search "project"
    
    for _k, arch of project_node.data_hash.arch_hash
      # deep clone
      conf = JSON.parse JSON.stringify napi_module.target_config_default
      napi_module.target_config_arch_hash[arch.name] = conf
    
    napi_module.name   = root.name
    # TODO remove?
    napi_module.folder = ctx.curr_folder
    
    false
  
  emit_codegen  : (root, ctx)->
    {name} = root
    {napi_module} = root.data_hash
    
    project_node = root.type_filter_search "project"
    {os_hash} = project_node.data_hash
    
    if os_hash.linux
      ctx.file_render_exec "s1_linux_build.coffee", ctx.tpl_read "pkg/s1_linux_build.coffee"
    if os_hash.win
      ctx.file_render_exec "s1_win_build.coffee",   ctx.tpl_read "pkg/s1_win_build.coffee"
    
    # ###################################################################################################
    #    extra wrappers
    # ###################################################################################################
    path = "../src_c_napi/#{name}"
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
    ctx.curr_folder += "/src_c_napi/#{name}"
    mkdirp.sync ctx.curr_folder
    
    ctx.walk_child_list_only_fn root
    
    # ###################################################################################################
    #    compile_file_list
    # ###################################################################################################
    compile_file_list = napi_module.compile_file_list
    
    code_unit_hash = {}
    for fn_decl in napi_module.fn_decl_list
      code_unit_hash[fn_decl.code_unit] ?= {jl:[]}
      code_unit_hash[fn_decl.code_unit].jl.upush """
        #include "../#{fn_decl.name}.cpp"
        """#"
    
    for class_decl in napi_module.class_decl_list
      continue if class_decl.is_fake
      code_unit_hash["class__#{class_decl.name}"] ?= {jl:[]}
      code_unit_hash["class__#{class_decl.name}"].jl.upush """
        #include "../#{class_decl.name}/class.cpp"
        """#"
      
      for fn_decl in class_decl.fn_decl_list
        code_unit_hash[fn_decl.code_unit] ?= {jl:[]}
        code_unit_hash[fn_decl.code_unit].jl.upush """
          #include "../#{class_decl.name}/#{fn_decl.name}.cpp"
          """#"
    
    for pipeline_decl in napi_module.pipeline_decl_list
      for fn_decl in pipeline_decl.fn_decl_list
        code_unit_hash[fn_decl.code_unit] ?= {jl:[]}
        code_unit_hash[fn_decl.code_unit].jl.upush """
          #include "../#{pipeline_decl.name}/#{fn_decl.name}.cpp"
          """#"
      
      # code_unit_hash[pipeline_decl.name] ?= {jl:[]}
      # for v in pipeline_decl.defered_render_list
      #   continue if !v.name.endsWith ".cpp"
      #   
      #   path = v.name.replace /^src\//, ""
      #   code_unit_hash[pipeline_decl.name].jl.upush """
      #     #include "../#{path}"
      #     """#"
      
      # костыль HARDCODE
      code_unit_hash[pipeline_decl.name] ?= {jl:[]}
      code_unit_hash[pipeline_decl.name].jl.upush """
        #include "../#{pipeline_decl.name}/fan_1n_mod_in.cpp"
        """#"
      code_unit_hash[pipeline_decl.name].jl.upush """
        #include "../#{pipeline_decl.name}/fan_n1_mod_out.cpp"
        """#"
      code_unit_hash[pipeline_decl.name].jl.upush """
        #include "../#{pipeline_decl.name}/worker_thread.cpp"
        """#"
    
    for code_unit_name, code_unit of code_unit_hash
      if code_unit_name == ""
        puts code_unit
        throw new Error "detected empty name for code_unit"
      file_name = "code_unit/#{code_unit_name}.cpp"
      
      compile_file_list.push file_name
      ctx.file_render "src/#{file_name}", """
        #{join_list code_unit.jl, ""}
        """
    
    compile_file_list.push "module.cpp"
    # wrap to folder
    for v,i in compile_file_list
      compile_file_list[i] = "../src/#{v}"
    
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
        "sources": compile_file_list
      }
      if !napi_module.target_config_arch_hash[arch.name]
        throw new Error "!napi_module.target_config_arch_hash[#{arch.name}]. This can be caused by napi_package declared before arch"
      obj_set target, napi_module.target_config_arch_hash[arch.name]
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
          # "install": "node-gyp configure build"
          "install": "node-gyp configure build -j max"
          "install-verbose": "node-gyp configure build --verbose"
        }
        "keywords"    : []
        "author"      : ""
        "license"     : "MIT"
        "dependencies": {
          # "node-gyp": "^7.0.0"
          "node-gyp": "^9.4.0"
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
    ctx.file_render "src/type.hpp",  ctx.tpl_read "napi/type.hpp"
    ctx.file_render "src/macro.hpp", ctx.tpl_read "napi/macro.hpp"
    ctx.file_render "src/macro.cpp", ctx.tpl_read "napi/macro.cpp"
    
    
    # ###################################################################################################
    #    main
    # ###################################################################################################
    include_jl      = napi_module.include_list
    lib_include_jl  = napi_module.lib_include_list
    class_decl_jl   = []
    class_include_header_jl= []
    # TODO REMOVE
    # class_include_jl= []
    class_include_fn_jl= []
    fn_include_jl   = []
    misc_pre_header_include_jl = []
    misc_pre_include_jl = []
    misc_post_include_jl= []
    compile_file_list = []
    
    init_jl         = clone napi_module.code_init_list
    fn_export_jl    = []
    class_export_jl = []
    
    for file_raw in napi_module.file_raw_header_pre_list
      misc_pre_header_include_jl.push "#include #{JSON.stringify file_raw.name}"
      ctx.file_render "src/#{file_raw.name}", file_raw.cont
    
    for file_raw in napi_module.file_raw_pre_list
      misc_pre_include_jl.push "#include #{JSON.stringify file_raw.name}"
      ctx.file_render "src/#{file_raw.name}", file_raw.cont
    
    for file_raw in napi_module.file_raw_post_list
      misc_post_include_jl.push "#include #{JSON.stringify file_raw.name}"
      ctx.file_render "src/#{file_raw.name}", file_raw.cont
    
    for fn_decl in napi_module.fn_decl_list
      fn_include_jl.push "#include #{JSON.stringify fn_decl.name+'.hpp'}"
      
      if fn_decl.gen_sync
        fn_export_jl.push  "FN_EXPORT(#{fn_decl.name}_sync)"
      if fn_decl.gen_async
        fn_export_jl.push  "FN_EXPORT(#{fn_decl.name})"
    
    for class_decl in napi_module.class_decl_list
      if class_decl.is_fake
        class_decl_jl      .push class_decl.raw_class_decl_code    if class_decl.raw_class_decl_code
        class_include_fn_jl.push class_decl.raw_class_include_code if class_decl.raw_class_include_code
        # class_export_jl ???
        continue
      
      class_name = class_decl.name
      class_decl_jl   .push "class #{class_name};"
      class_include_header_jl.push "#include #{JSON.stringify class_name+'/class.hpp'}"
      # TODO REMOVE
      # class_include_jl.push "#include #{JSON.stringify class_name+'/class.cpp'}"
    
    for class_decl in napi_module.class_decl_list
      continue if class_decl.is_fake
      
      class_name = class_decl.name
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
        class_include_fn_jl.push "#include #{JSON.stringify class_name+'/'+fn_name+'.hpp'}"
      
      class_export_jl.push """
        CLASS_DEF(#{class_name})
        #{join_list class_fn_decl_jl, ''}
        CLASS_EXPORT(#{class_name})
        """
    
    for pipeline_decl in napi_module.pipeline_decl_list
      for v in pipeline_decl.defered_render_list
        continue if !v.name.endsWith ".hpp"
        path = v.name.replace /^src\//, ""
        fn_include_jl.push "#include #{JSON.stringify path}"
      
      # for fn_decl in pipeline_decl.fn_decl_list
        # path = "#{pipeline_decl.name}/#{fn_decl.name}.hpp"
        # fn_include_jl.push "#include #{JSON.stringify path}"
      
    
    if fn_export_jl.length
      init_jl.unshift "napi_value __fn;"
    if init_jl.length or fn_export_jl.length or class_export_jl.length
      init_jl.unshift "napi_status status;"
    
    # Прим. Включение всех class decl'ов везде несколько затратно
    # Но я не знаю как по другому угодить всем
    
    # TODO remove
    # TODO remove also building above
    ###
      #{join_list class_decl_jl, ""}
      
      #{join_list class_include_header_jl, ""}
    ###
    
    ctx.file_render "src/common.hpp", """
      #pragma once
      #include <node_api.h>
      
      #include <stdio.h>
      #include <stdlib.h>
      #include <string.h>
      #include "type.hpp"
      #include "macro.hpp"
      
      #{join_list include_jl, ""}
      
      #{join_list misc_pre_header_include_jl, ""}
      
      """#"
    ###
      // TODO REMOVE
      #{join_list class_include_jl, ""}
    ###
    ctx.file_render "src/module.cpp", """
      #include "common.hpp"
      #include "macro.cpp"
      
      #{join_list lib_include_jl, ""}
      
      #{join_list misc_pre_include_jl, ""}
      
      #{join_list class_decl_jl, ""}
      
      #{join_list class_include_header_jl, ""}
      
      #{join_list class_include_fn_jl, ""}
      
      #{join_list fn_include_jl, ""}
      
      #{join_list misc_post_include_jl, ""}
      
      ////////////////////////////////////////////////////////////////////////////////////////////////////
      napi_value Init(napi_env env, napi_value exports) {
        #{join_list init_jl, "  "}
        
        ////////////////////////////////////////////////////////////////////////////////////////////////////
        #{join_list fn_export_jl, "  "}
        
        ////////////////////////////////////////////////////////////////////////////////////////////////////
        #{join_list class_export_jl, "  "}
        
        ////////////////////////////////////////////////////////////////////////////////////////////////////
        
        return exports;
      }
      
      NAPI_MODULE(NODE_GYP_MODULE_NAME, Init)
      
      """#"
    
    ctx.curr_folder = old_folder
    
    class_tag_file_name = "src_c_napi/#{root.name}/class_tag.json"
    fs.writeFileSync class_tag_file_name, JSON.stringify root.data_hash.napi_module.class_tag_hash, null, 2
    
    true


def "napi_package", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "napi_package", name, "def"
  bdh_node_module_name_assign_on_call root, module, "napi_package"
  if !root.data_hash.napi_module
    root.data_hash.napi_module = new napi_decl.Napi_module
    
    class_tag_file_name = "src_c_napi/#{name}/class_tag.json"
    if fs.existsSync class_tag_file_name
      root.data_hash.napi_module.class_tag_hash = JSON.parse fs.readFileSync class_tag_file_name
      max_value = 1
      for k,v of root.data_hash.napi_module.class_tag_hash
        max_value = Math.max max_value, v
      root.data_hash.napi_module.class_tag_idx_counter = max_value+1
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    file injectors
# ###################################################################################################
# немного особенные команды. Вызываются на codebub phase
def "napi_package napi_file_raw_pre", (name, code)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  napi_package_node = mod_runner.current_runner.curr_root.type_filter_search "napi_package"
  {napi_module} = napi_package_node.data_hash
  
  file_raw = napi_module.file_raw_pre_get name
  file_raw.cont = code
  file_raw

def "napi_package napi_file_raw_post", (name, code)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  napi_package_node = mod_runner.current_runner.curr_root.type_filter_search "napi_package"
  {napi_module} = napi_package_node.data_hash
  
  file_raw = napi_module.file_raw_post_get name
  file_raw.cont = code
  file_raw

def "napi_package napi_file_header_raw_pre", (name, code)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  napi_package_node = mod_runner.current_runner.curr_root.type_filter_search "napi_package"
  {napi_module} = napi_package_node.data_hash
  
  file_raw = napi_module.file_raw_header_pre_get name
  file_raw.cont = code
  file_raw
# ###################################################################################################
#    code injectors
# ###################################################################################################
def "napi_package napi_init_raw", (code)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  napi_package_node = mod_runner.current_runner.curr_root.type_filter_search "napi_package"
  {napi_module} = napi_package_node.data_hash
  
  napi_module.code_init_get code

def "napi_package napi_include", (code)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  napi_package_node = mod_runner.current_runner.curr_root.type_filter_search "napi_package"
  {napi_module} = napi_package_node.data_hash
  
  for line in code.split "\n"
    continue if !line
    napi_module.include_get line
  return

def "napi_package napi_lib_include", (code)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  napi_package_node = mod_runner.current_runner.curr_root.type_filter_search "napi_package"
  {napi_module} = napi_package_node.data_hash
  
  for line in code.split "\n"
    continue if !line
    napi_module.lib_include_get line
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
#    napi_config_lib
# ###################################################################################################
bdh_module_name_root module, "napi_config_lib",
  nodegen       : (root, ctx)->
    {
      lib
      arch_filter
    } = root.data_hash
    
    napi_package_node = mod_runner.current_runner.curr_root.type_filter_search "napi_package"
    {napi_module} = napi_package_node.data_hash
    
    for k, conf of napi_module.target_config_arch_hash
      continue if !arch_filter_check arch_filter, k
      
      conf.link_settings.libraries.upush lib
    
    false
  

def "napi_package napi_config_lib", (lib, arch_filter)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  key = "#{lib}_#{JSON.stringify arch_filter}"
  root = mod_runner.current_runner.curr_root.tr_get "napi_config_lib", key, "def"
  bdh_node_module_name_assign_on_call root, module, "napi_config_lib"
  root.data_hash.lib = lib
  root.data_hash.arch_filter = arch_filter
  
  
  root

# ###################################################################################################
#    napi_config_include
# ###################################################################################################
bdh_module_name_root module, "napi_config_include",
  nodegen       : (root, ctx)->
    {
      path
      arch_filter
    } = root.data_hash
    
    napi_package_node = mod_runner.current_runner.curr_root.type_filter_search "napi_package"
    {napi_module} = napi_package_node.data_hash
    
    for k, conf of napi_module.target_config_arch_hash
      continue if !arch_filter_check arch_filter, k
      
      conf.include_dirs ?= []
      conf.include_dirs.upush path
    false

def "napi_package napi_config_include", (path, arch_filter)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  key = "#{path}_#{JSON.stringify arch_filter}"
  root = mod_runner.current_runner.curr_root.tr_get "napi_config_include", key, "def"
  bdh_node_module_name_assign_on_call root, module, "napi_config_include"
  root.data_hash.path = path
  root.data_hash.arch_filter = arch_filter
  
  
  root

# ###################################################################################################
#    napi_config_cflags_cc
# ###################################################################################################
bdh_module_name_root module, "napi_config_cflags_cc",
  nodegen       : (root, ctx)->
    {
      flag
      arch_filter
    } = root.data_hash
    
    napi_package_node = mod_runner.current_runner.curr_root.type_filter_search "napi_package"
    {napi_module} = napi_package_node.data_hash
    
    for k, conf of napi_module.target_config_arch_hash
      continue if !arch_filter_check arch_filter, k
      
      conf.cflags_cc ?= []
      conf.cflags_cc.upush flag
    false

def "napi_package napi_config_cflags_cc", (flag, arch_filter)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  key = "#{flag}_#{JSON.stringify arch_filter}"
  root = mod_runner.current_runner.curr_root.tr_get "napi_config_cflags_cc", key, "def"
  bdh_node_module_name_assign_on_call root, module, "napi_config_cflags_cc"
  root.data_hash.flag = flag
  root.data_hash.arch_filter = arch_filter
  
  root

# ###################################################################################################
#    napi_config_obj_set
# ###################################################################################################
bdh_module_name_root module, "napi_config_obj_set",
  nodegen       : (root, ctx)->
    {
      obj
      arch_filter
    } = root.data_hash
    
    napi_package_node = mod_runner.current_runner.curr_root.type_filter_search "napi_package"
    {napi_module} = napi_package_node.data_hash
    
    for k, conf of napi_module.target_config_arch_hash
      continue if !arch_filter_check arch_filter, k
      
      obj_set conf, obj
    false

def "napi_package napi_config_obj_set", (obj, arch_filter)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  key = "#{JSON.stringify obj}_#{JSON.stringify arch_filter}"
  root = mod_runner.current_runner.curr_root.tr_get "napi_config_obj_set", key, "def"
  bdh_node_module_name_assign_on_call root, module, "napi_config_obj_set"
  root.data_hash.obj = obj
  root.data_hash.arch_filter = arch_filter
  
  root

# ###################################################################################################
#    thread_util
# ###################################################################################################
bdh_module_name_root module, "napi_thread_util",
  emit_codegen  : (root, ctx)->
    ctx.file_render "src/thread_util.hpp", ctx.tpl_read "napi/thread_util.hpp"
    ctx.file_render "src/thread_util.cpp", ctx.tpl_read "napi/thread_util.cpp"
    false


def "napi_package napi_thread_util", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  napi_include """
    #include "thread_util.hpp"
    """#"
  
  napi_package_node = mod_runner.current_runner.curr_root.type_filter_search "napi_package"
  {napi_module} = napi_package_node.data_hash
  napi_module.compile_file_get "thread_util.cpp"
  
  root = mod_runner.current_runner.curr_root.tr_get "napi_thread_util", "napi_thread_util", "def"
  bdh_node_module_name_assign_on_call root, module, "napi_thread_util"
  
  root

