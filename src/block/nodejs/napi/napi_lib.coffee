module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
  mod_config
  iced_compile
} = require "../../common_import"

napi_decl = require "./napi_decl"

# ###################################################################################################
#    napi_lib
# ###################################################################################################
bdh_module_name_root module, "napi_lib",
  nodegen       : (root, ctx)->
    folder = "src_c_lib/#{root.name}"
    
    project_node = root.type_filter_search "project"
    
    for _k, arch of project_node.data_hash.arch_hash
      arch_name = arch.name
      build2 "napi", "cd #{folder} && ./build_#{arch_name}.sh"
    false
  
  validator     : (root, ctx)->
    false
  
  emit_codebub  : (root, ctx)->
    {name} = root
    project_node = root.type_filter_search "project"
    
    codebub_arch_hash = root.data_hash.codebub_arch_hash ?= {}
    
    for _k, arch of project_node.data_hash.arch_hash
      arch_name = arch.name
      switch arch.os
        when "linux"
          cb_name = "napi_lib_#{name}/build_#{arch_name}.sh"
          codebub_arch_hash[arch_name] = ctx.file_render cb_name, """
            #!/bin/bash
            set -e
            
            rm -rf build_#{arch_name} 2>/dev/null || echo "skip rm build_#{arch_name}"
            cd repo
            
            # PLS replace
            exit 1
            
            # rm -rf build 2>/dev/null || echo "skip rm build"
            # mkdir build
            # cd build
            # ./configure
            # OR
            # cmake $* ..
            # make -j$(nproc)
            # cd ..
            # mv build ../build_#{arch_name}
            """#"
        
        when "win"
          cb_name = "napi_lib_#{name}/build_#{arch_name}.bat"
          
          # TODO move to validator
          {visual_studio_path} = mod_config.local_config
          if !visual_studio_path
            throw new Error "!local_config.visual_studio_path"
          
          codebub_arch_hash[arch_name] = ctx.file_render cb_name, """
            rd /s /q build_#{arch_name}
            
            cd repo
            mkdir build_win
            cd build_win
            "#{visual_studio_path}\\BuildTools\\Common7\\IDE\\CommonExtensions\\Microsoft\\CMake\\CMake\\bin\\cmake" .. -A x64
            "#{visual_studio_path}\\BuildTools\\Common7\\IDE\\CommonExtensions\\Microsoft\\CMake\\CMake\\bin\\cmake" --build . --config Release
            
            cd ..
            move build_win ..\\build_#{arch_name}
            cd ..
            
            """#"
    
    {opt} = root.data_hash
    if opt.url
      cb_name = "napi_lib_#{name}/clone.sh"
      
      aux_commit_or_branch = ""
      if opt.commit
        aux_commit_or_branch = """
        cd repo
        git checkout #{opt.commit}
        """
      
      if opt.branch
        aux_commit_or_branch = """
        cd repo
        git checkout #{opt.branch}
        """
      
      root.data_hash.codebub_clone ?= ctx.file_render cb_name, """
        #!/bin/bash
        set -e
        
        git clone --recursive #{opt.url} repo
        #{aux_commit_or_branch}
        
        """#"
      
    
    false
  
  emit_codegen  : (root, ctx)->
    {name} = root
    folder = "src_c_lib/#{root.name}"
    ctx.file_render_exec "#{folder}/.gitignore", """
      file_hash.json
      build/
      build_*/
      """
    
    project_node = root.type_filter_search "project"
    {codebub_arch_hash} = root.data_hash
    
    for _k, arch of project_node.data_hash.arch_hash
      arch_name = arch.name
      
      switch arch.os
        when "linux"
          ctx.file_render_exec "#{folder}/build_#{arch_name}.sh", codebub_arch_hash[arch_name]
        
        when "win"
          switch arch.arch
            when "x64", "x86"
              target_arch = arch.arch
              # NOTE unused
            else
              throw new Error "unknown win arch '#{arch.arch}'"
          
          # NOTE win build is not in pipeline
          # build2 "napi", "cd #{folder} && ./build_#{arch_name}.bat"
          ctx.file_render_exec "#{folder}/build_#{arch_name}.bat", codebub_arch_hash[arch_name]
    
    {opt} = root.data_hash
    if opt.url
      ctx.file_render_exec "#{folder}/clone.sh", root.data_hash.codebub_clone
    false

def "napi_lib", (name, opt, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "napi_lib", name, "def"
  bdh_node_module_name_assign_on_call root, module, "napi_lib"
  
  root.data_hash.opt ?= opt
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root
