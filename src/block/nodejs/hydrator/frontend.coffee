module = @
fs = require "fs"
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  hydrator_def
  
  mod_runner
  mod_config
} = require "../../common_import"

policy_filter = (policy_obj)->
  return false if policy_obj.platform != "nodejs"
  return false if policy_obj.language != "iced"
  true

block_filter_gen = (type)->
  (root)->
    root.type == type

# ###################################################################################################
#    util
# ###################################################################################################
# copypasted t1c
com_resolve_cache_dict = new Map
com_resolve = (opt)->
  {name} = opt
  if found = com_resolve_cache_dict.get name
    return found
  
  found = null
  walk = (dir, com_path, rel_path)->
    return if found
    file_list = fs.readdirSync dir
    for loc_file in file_list
      full_file = "#{dir}/#{loc_file}"
      rel_path_curr = "#{rel_path}/#{loc_file}"
      if fs.lstatSync(full_file).isDirectory()
        if loc_file[0] == "_"
          walk full_file, com_path, rel_path_curr
        else
          if com_path
            walk full_file, "#{com_path}_#{loc_file}", rel_path_curr
          else
            walk full_file, loc_file, rel_path_curr
      else
        if /\.com\.coffee$/.test loc_file
          last_com_name = loc_file.replace /\.com\.coffee$/, ""
          if com_path.endsWith last_com_name
            com_name = com_path
          else if last_com_name.startsWith com_path
            com_name = last_com_name
          else
            com_name = com_path + "_" + last_com_name
          
          com_name = com_name.replace /_index$/, ""
          if com_name == name
            found = {
              com_name
              com_path
              file : loc_file
              full_file
              rel_path
              rel_path_file : rel_path_curr
            }
            return
  
  if !mod_config.local_config.story_book_path
    throw new Error "local_config.story_book_path is not configured"
  walk mod_config.local_config.story_book_path+"/htdocs", "", ""
  
  com_resolve_cache_dict.set name, found
  found

com_found_copy = (opt)->
  {
    full_file
    rel_path
    rel_path_file
    htdocs
    ctx
  } = opt
  cont = fs.readFileSync full_file, "utf-8"
  ctx.file_render "#{htdocs}/#{rel_path_file}", cont
  
  # redundant copy (all dir)
  src_dir = mod_config.local_config.story_book_path+"/htdocs"+rel_path
  dst_dir = "#{htdocs}/#{rel_path}"
  ctx.copy dst_dir, src_dir
  # related_file_list = fs.readdirSync src_dir
  # for v in related_file_list
    # src = "#{src_dir}/#{v}"
    # dst = "#{htdocs}/#{rel_path}/#{v}"
    # ctx.file_render dst, fs.readFileSync src, "utf-8"
  
  for line in cont.split "\n"
    line = line.trim()
    continue if !line
    if reg_ret = /^[A-Z][_a-z0-9]+/.exec line
      [com_name] = reg_ret
      # TODO enable puts только на 1 какой-то фазе (init1 или resolve?)
      # puts "possible component include #{com_name}"
      found = com_resolve {name: com_name.toLowerCase()}
      if found
        found.ctx = ctx
        found.htdocs = htdocs
        com_found_copy found
  return

# ###################################################################################################
#    frontend
# ###################################################################################################
bdh_module_name_root module, "frontend",
  nodegen       : (root, ctx)->
    config()
    
    config_prefix = "front_"
    if root.name
      config_prefix = "front_#{root.name}_"
    npm_script_prefix = config_prefix
    file_prefix = config_prefix
    
    arg_prefix = "front-"
    if root.name
      arg_prefix = "front-#{root.name.split('_').join('-')}-"
    
    npm_i "fy"
    npm_i "webcom"
    npm_i "webcom-client-plugin-base"
    npm_i "webcom-engine-vendor"
    
    # ###################################################################################################
    ctx.walk_child_list_only_fn root
    idx = root.child_list.length
    
    # WARNING config_push in nodegen
    port_increment = mod_runner.current_runner.root.data_hash.get_autoport_offset("frontend", root)
    
    ws_hotreload_port = root.policy_get_val_use "ws_hotreload_port"
    http_port         = root.policy_get_val_use "http_port"
    ws_hotreload_port += port_increment if root.policy_get_here_is_weak "ws_hotreload_port"
    http_port         += port_increment if root.policy_get_here_is_weak "http_port"
    
    config_push "#{config_prefix}ws_hotreload_port","int", ws_hotreload_port
    config_push "#{config_prefix}http_port",        "int", http_port
    config_push "#{config_prefix}port_expose",      "bool", "true"
    config_push "#{config_prefix}watch",            "bool"
    
    if root.policy_get_val_use "start_script"
      node_loop_sh()
      
      npm_script "#{npm_script_prefix}dev",  "./loop.sh ./src/#{file_prefix}server.coffee --#{arg_prefix}watch"
      npm_script "#{npm_script_prefix}prod", "./loop.sh ./src/#{file_prefix}server.coffee"
      npm_script "#{npm_script_prefix}prod_no_port_expose", "./loop.sh ./src/#{file_prefix}server.coffee --#{arg_prefix}port-expose=0"
      
      starter_tmux_set "frontend #{root.name}", "dev", """
        cd #{ctx.curr_folder}
        npm run #{npm_script_prefix}dev
        """
      
      starter_tmux_set "frontend #{root.name}", "prod", """
        cd #{ctx.curr_folder}
        npm run #{npm_script_prefix}prod
        """
      
      starter_tmux_set "frontend #{root.name}", "prod_no_port_expose", """
        cd #{ctx.curr_folder}
        npm run #{npm_script_prefix}prod_no_port_expose
        """
    
    ctx.walk_child_list_only_fn root, idx
    
    # ###################################################################################################
    {
      com_hash
      node_com_hash
      node_storybook_com_hash
      storybook_file_hash
      router_is_active
      route_list
      storybook_copy_list
    } = root.data_hash
    
    for k, node of root.data_hash.node_com_hash
      com_path = "#{node.data_hash.folder}/#{node.name.toLowerCase()}.com.coffee"
      if node.data_hash.code
        com_hash[com_path] = {
          path : com_path
          is_manual : false
          code : node.data_hash.code
        }
      else
        com_hash[com_path] = {
          path : com_path
          is_manual : true
          code : """
            module.exports =
              render : ()->
                div "hello #{node.name}"
            
            """#"
        }
    
    com_path = "htdocs/app.com.coffee"
    if !com_hash[com_path]
      # NOTE frontend_com не поможет т.к. определит в _app_control
      if router_is_active
        # TODO warning что надо удалить code bubble чтобы заработало
        com_hash[com_path] = {
          path : com_path
          is_manual : true
          code : """
            module.exports =
              render : ()->
                Page_router {}
            
            """#"
        }
      else
        com_hash[com_path] = {
          path : com_path
          is_manual : true
          code : """
            module.exports =
              render : ()->
                div "hello #{root.name}"
            
            """#"
        }
    
    for route in route_list
      com_name = route.data_hash.com.toLowerCase()
      com_path = "htdocs/page/#{com_name}.com.coffee"
      continue if com_hash[com_path]
      
      com_hash[com_path] ?= {
        path : com_path
        is_manual : true
        code : """
          module.exports =
            render : ()->
              Page_wrap @props
                div "hello #{com_name}"
          
          """#"
      }
    
    # ###################################################################################################
    #    router component
    # ###################################################################################################
    encoded_list = []
    for route in route_list
      continue if route.data_hash.is_parametric
      encoded_list.push {
        path  : JSON.stringify route.data_hash.path
        com   : JSON.stringify route.data_hash.com.capitalize()
        title : JSON.stringify route.data_hash.title
      }
    
    path_max_length = 0
    com_max_length  = 0
    title_max_length= 0
    for v in encoded_list
      path_max_length = Math.max path_max_length , v.path .length
      com_max_length  = Math.max com_max_length  , v.com  .length
      title_max_length= Math.max title_max_length, v.title.length
    
    path_max_length++   if path_max_length  & 1
    com_max_length++    if com_max_length   & 1
    title_max_length++  if title_max_length & 1
    
    route2com_hash_jl   = []
    for v in encoded_list
      route2com_hash_jl.push """
        {path : #{v.path.rjust path_max_length}, com : #{v.com.rjust com_max_length} , title: #{v.title.rjust title_max_length}}
        """
    
    route_parametric_jl = []
    for route in route_list
      continue if !route.data_hash.is_parametric
      param_list = []
      
      path = RegExp.escape route.data_hash.path
      path_regex = path.replace /<(.+?)>/g, (full, name)->
        param_list.push name
        "(.*)"
      
      route_parametric_jl.push """
        if reg_ret = /^#{path_regex}$/.exec path
          [_skip, #{param_list.join ', '}] = reg_ret
          return #{route.data_hash.com.capitalize()} {
            #{make_tab param_list.join('\n'), '    '}
          }
        """
    
    com_path = "htdocs/page/router.com.coffee"
    # if !com_hash[com_path]
    com_hash[com_path] = {
      path : com_path
      is_manual : false
      # TODO переделать
      code : """
        module.exports =
          route_path_hash : {}
          mount : ()->
            window.route_list = [
              #{join_list route2com_hash_jl, '      '}
            ]
            
            @route_path_hash = {}
            for v in route_list
              @route_path_hash[v.path] = v
            
            return
          
          render : ()->
            Router_multi {
              render : (hash)=>
                @path = path = hash[""]?.path or ""
                if com = @route_path_hash[path]
                  if !window[com.com]
                    div "No \#{com.com} component"
                  else
                    window[com.com] com
                else
                  #{join_list route_parametric_jl, '          '}
                  div "404"
            }
          
        """#"
    }
    
    # ###################################################################################################
    #    storybook_copy_list
    # ###################################################################################################
    for k, node of node_storybook_com_hash
      storybook_copy_list.push node.data_hash.found
    
    true
  
  emit_codebub : (root, ctx)->
    {
      com_hash
    } = root.data_hash
    
    for _k, com of com_hash
      escaped_path = com.path.split("/").join("_")
      cb_name = "frontend_#{root.name}/#{escaped_path}"
      if com.is_manual
        com.code = ctx.file_render cb_name, com.code
    
    false
  
  emit_codegen : (root, ctx)->
    ###
    TODO move to policy
      front_cache
      bundle
      front_title
    
    ###
    config_prefix = "front_"
    if root.name
      config_prefix = "front_#{root.name}_"
    file_prefix = config_prefix
    
    front_title = root.name or root.parent.name
    front_title = front_title.split("_").join(" ")
    front_title = front_title.capitalize()
    
    ctx.file_render_exec "src/#{file_prefix}server.coffee", """
      #!/usr/bin/env iced
      ### !pragma coverage-skip-block ###
      delivery= require "webcom"
      {
        master_registry
        Webcom_bundle
      } = require "webcom/lib/client_configurator"
      config = require "./config"
      {cache} = require("./#{file_prefix}cache")
      
      bundle  = new Webcom_bundle master_registry
      # skip on build
      if 0 == h_count cache
        require "webcom-client-plugin-base/src/hotreload"
        require "webcom-client-plugin-base/src/react"
        require "webcom-client-plugin-base/src/net"
        require "webcom-client-plugin-base/src/wsrs"
        require "webcom-client-plugin-base/src/keyboard"
        
        bundle.plugin_add "Webcom hotreload"
        bundle.plugin_add "Webcom net"
        bundle.plugin_add "Webcom react"
        bundle.plugin_add "ws request service"
        bundle.plugin_add "keymap"
        bundle.plugin_add "keyboard scheme"
        bundle.feature_hash.hotreload = true
      
      service = delivery.start {
        htdocs    : "htdocs"
        hotreload : !!config.#{config_prefix}watch
        title     : #{JSON.stringify front_title}
        bundle
        no_port_expose : !config.#{config_prefix}port_expose
        port      : config.#{config_prefix}http_port
        ws_port   : config.#{config_prefix}ws_hotreload_port
        watch_root: true
        allow_hard_stop : true
        engine    : {
          HACK_remove_module_exports : true
          # HACK_onChange : true
        }
        # vendor    : "react"
        vendor    : "react_min"
        gz        : true
        chokidar  :
          # avoid symlinks
          ignored : /(node_modules)/
        watcher_ignore : (event, full_path)->
          return false if full_path.startsWith "htdocs"
          true
      }
      
      obj_set service.cache, cache
      
      module.exports = service
      """#"
    
    
    ctx.file_render "src/#{file_prefix}cache.coffee", """
      ### !pragma coverage-skip-block ###
      module.exports = {}
      
      """
    
    # ###################################################################################################
    #    htdocs
    # ###################################################################################################
    # TODO policy htdocs_path
    ctx.file_render "htdocs/z_bootstrap.coffee", '''
      window.bootstrap = ()->
        ReactDOM.render(
          React.createElement(App),
          document.getElementById("mount_point")
        )
      window.bootstrap()
      
      '''
    
    {
      com_hash
      storybook_copy_list
      storybook_file_hash
    } = root.data_hash
    
    for _k, com of com_hash
      escaped_path = com.path.split("/").join("_")
      cb_name = "frontend_#{root.name}/#{escaped_path}"
      ctx.file_render com.path, com.code
    
    for found in storybook_copy_list
      found.ctx = ctx
      found.htdocs = "htdocs" # TODO from policy
      com_found_copy found
    
    for path of storybook_file_hash
      src = mod_config.local_config.story_book_path+"/htdocs/"+path
      dst = "htdocs/"+path
      ctx.file_render dst, fs.readFileSync src, "utf-8"
    
    false


hydrator_def policy_filter, block_filter_gen("frontend"), (root)->
  bdh_node_module_name_assign_on_call root, module, "frontend"
  return

# ###################################################################################################
#    frontend_com
# ###################################################################################################
block_filter_gen = (type)->
  (root)->
    return false if root.type != type
    # Возможно в некоторых случаях не сработает
    return false if root.parent.type != "frontend"
    true

bdh_module_name_root module, "frontend_com", {}

hydrator_def policy_filter, block_filter_gen("frontend_com"), (root)->
  bdh_node_module_name_assign_on_call root, module, "frontend_com"
  return

# ###################################################################################################
#    frontend_com_storybook
# ###################################################################################################
block_filter_gen = (type)->
  (root)->
    return false if root.type != type
    # Возможно в некоторых случаях не сработает
    return false if root.parent.type != "frontend"
    true

bdh_module_name_root module, "frontend_com_storybook",
  nodegen : (root, ctx)->
    if !found = com_resolve {name: root.name}
      # TODO написать ближайшие варианты имен
      throw new Error "can't find storybook com #{root.name}"
    
    root.data_hash.found = found
    
    false

hydrator_def policy_filter, block_filter_gen("frontend_com_storybook"), (root)->
  bdh_node_module_name_assign_on_call root, module, "frontend_com_storybook"
  return

# ###################################################################################################
#    frontend_storybook_file
# ###################################################################################################
block_filter_gen = (type)->
  (root)->
    return false if root.type != type
    # Возможно в некоторых случаях не сработает
    return false if root.parent.type != "frontend"
    true

bdh_module_name_root module, "frontend_storybook_file",
  # TODO validate
  nodegen : (root, ctx)->
    if !fs.existsSync mod_config.local_config.story_book_path+"/htdocs/"+root.name
      throw new Error "can't find storybook file #{root.name}"
    
    false

hydrator_def policy_filter, block_filter_gen("frontend_storybook_file"), (root)->
  bdh_node_module_name_assign_on_call root, module, "frontend_storybook_file"
  return


# ###################################################################################################
#    router
# ###################################################################################################
bdh_module_name_root module, "router",
  nodegen       : (root, ctx)->
    root.parent.data_hash.router_is_active = true
    frontend_com_storybook "router_multi"
    false
  
  emit_codegen  : (root, ctx)->
    for com_name in "nav wrap tab_bar_router".split /\s+/g
      ctx.file_render "htdocs/page/_com/#{com_name}.com.coffee", ctx.tpl_read "front/_com/#{com_name}.com.coffee"
    
    ctx.file_render "htdocs/page/_com/style.css", ctx.tpl_read "front/_com/style.css"
    false

hydrator_def policy_filter, block_filter_gen("router"), (root)->
  bdh_node_module_name_assign_on_call root, module, "router"
  return

# ###################################################################################################
#    router_endpoint
# ###################################################################################################
block_filter_gen = (type)->
  (root)->
    return false if root.type != type
    # Возможно в некоторых случаях не сработает
    return false if root.parent.parent?.type != "frontend"
    true

bdh_module_name_root module, "router_endpoint",
  nodegen       : (root, ctx)->
    root.parent.parent.data_hash.route_list.upush root
    # p "root.parent.parent.data_hash.route_list", root.parent.parent.data_hash.route_list.length
    false

hydrator_def policy_filter, block_filter_gen("router_endpoint"), (root)->
  bdh_node_module_name_assign_on_call root, module, "router_endpoint"
  return
