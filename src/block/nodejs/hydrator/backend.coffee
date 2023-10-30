module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  hydrator_def
  
  mod_runner
} = require "../../common_import"

policy_filter = (policy_obj)->
  return false if policy_obj.platform != "nodejs"
  return false if policy_obj.language != "iced"
  true

block_filter_gen = (type)->
  (root)->
    root.type == type

# ###################################################################################################
#    backend
# ###################################################################################################
bdh_module_name_root module, "backend",
  nodegen : (root, ctx)->
    # ###################################################################################################
    #    config
    # ###################################################################################################
    config()
    config_prefix = "back_"
    if root.name
      config_prefix = "back_#{root.name}_"
    npm_script_prefix = config_prefix
    file_prefix = config_prefix
    
    arg_prefix = "back-"
    if root.name
      arg_prefix = "back-#{root.name.split('_').join('-')}-"
    
    hot_reload_enabled= root.policy_get_val_use "hot_reload"
    ws_enabled    = root.policy_get_val_use "ws"
    http_enabled  = root.policy_get_val_use "http"
    static_enabled= root.policy_get_val_use "static"
    
    if !ws_enabled and !http_enabled and !static_enabled
      puts "WARNING. Backend without ws, http and static will not work. name=#{root.name}"
    
    # WARNING config_push in nodegen
    # возможно стоит даже усилить, что брать policy только с текущей node
    
    port_increment = mod_runner.current_runner.root.data_hash.get_autoport_offset("backend", root)
    
    ws_port   = root.policy_get_val_use "ws_port"
    http_port = root.policy_get_val_use "http_port"
    ws_port   += port_increment if root.policy_get_here_is_weak "ws_port"
    http_port += port_increment if root.policy_get_here_is_weak "http_port"
    
    if ws_enabled
      config_push "#{config_prefix}ws_port",    "int", ws_port
    
    if http_enabled or static_enabled
      config_push "#{config_prefix}http_port",  "int", http_port
    
    if hot_reload_enabled
      config_push "#{config_prefix}watch",      "bool"
    
    config_push "#{config_prefix}port_expose",  "bool", "true"
    
    # ###################################################################################################
    #    deps
    # ###################################################################################################
    npm_i "fy"
    if hot_reload_enabled
      npm_i "chokidar"
    
    if ws_enabled
      npm_i "ws"
    if http_enabled or static_enabled
      npm_i "express"
    
    # ###################################################################################################
    #    npm script
    # ###################################################################################################
    node_loop_sh()
    
    if hot_reload_enabled
      dev_script = "./loop.sh ./src/#{file_prefix}server.coffee --#{config_prefix}watch"
    else
      dev_script = "./loop.sh ./src/#{file_prefix}server.coffee"
    
    npm_script "#{npm_script_prefix}dev", dev_script
    npm_script "#{npm_script_prefix}prod", "./loop.sh ./src/#{file_prefix}server.coffee"
    npm_script "#{npm_script_prefix}prod_no_port_expose", "./loop.sh ./src/#{file_prefix}server.coffee --#{arg_prefix}port-expose=0"
    
    starter_tmux_set "backend #{root.name}", "dev", """
      cd #{ctx.curr_folder}
      npm run #{npm_script_prefix}dev
      """
    
    starter_tmux_set "backend #{root.name}", "prod", """
      cd #{ctx.curr_folder}
      npm run #{npm_script_prefix}prod
      """
    
    starter_tmux_set "backend #{root.name}", "prod_no_port_expose", """
      cd #{ctx.curr_folder}
      npm run #{npm_script_prefix}prod_no_port_expose
      """
    
    false
  
  emit_codegen: (root, ctx)->
    hot_reload_enabled= root.policy_get_val_use "hot_reload"
    ws_enabled    = root.policy_get_val_use "ws"
    http_enabled  = root.policy_get_val_use "http"
    static_enabled= root.policy_get_val_use "static"
    
    config_prefix = "back_"
    if root.name
      config_prefix = "back_#{root.name}_"
    file_prefix = config_prefix
    
    include_jl = []
    
    if ws_enabled or http_enabled
      include_jl.push 'fs      = require "fs"'
    if http_enabled
      include_jl.push '{URL}   = require "url"'
    if ws_enabled
      include_jl.push 'ws      = require "ws"'
    if http_enabled or static_enabled
      include_jl.push 'express = require "express"'
    
    
    aux_hot_reload = ""
    if hot_reload_enabled
      aux_hot_reload = """
        if config.#{config_prefix}watch
          do ()->
            chokidar = require "chokidar"
            watcher = chokidar.watch "src"
            await watcher.on "ready", defer()
            ### !pragma coverage-skip-block ###
            timeout = null
            handler = (path)->
              clearTimeout timeout if timeout
              timeout = setTimeout ()->
                puts "node file changed", path
                process.exit()
              , 100
            
            watcher.on "add",    handler
            watcher.on "change", handler
            watcher.on "unlink", handler
        
        """#"
    
    aux_ws_ep_collect = ""
    if ws_enabled or http_enabled
      # TODO endpoints collect manual + commented feed all code
      aux_ws_ep_collect = '''
        # ###################################################################################################
        #    ws/http endpoints collect
        # ###################################################################################################
        endpoint_file_list = fs.readdirSync __dirname+"/endpoint"
        endpoint_hash = {}
        for file in endpoint_file_list
          # protection from reading .swp files if nano was used
          continue if !/(\\.coffee|\\.js)$/.test file
          mod = require "./endpoint/#{file}"
          obj_set endpoint_hash, mod
        
        '''
    
    aux_http_ep_collect = ""
    if http_enabled
      aux_http_ep_collect = '''
        # ###################################################################################################
        #    http endpoints collect
        # ###################################################################################################
        http_endpoint_hash = {}
        endpoint_file_list = fs.readdirSync "src/http_only_endpoint"
        for file in endpoint_file_list
          mod = require "./http_only_endpoint/#{file}"
          obj_set http_endpoint_hash, mod
        
        '''
      
      aux_http_ep_collect += '''
        for k,v of endpoint_hash
          http_endpoint_hash[k] ?= v
        
        '''
    
    aux_ws_server = ""
    if ws_enabled
      # Важно. Поменяно API еще раз. Теперь не последний аргумент, а connection.list_get
      aux_ws_server = """
        # ###################################################################################################
        #    ws server
        # ###################################################################################################
        connection_uid = 1 # uid 0 == http persistant template
        wss = null
        connection_list_get = ()->Array.from wss.clients
        ws_handler = (connection, req)->
          connection.ip = req.socket.remoteAddress
          connection.__uid = connection_uid++
          connection.list_get = connection_list_get
          connection.on "message", (msg)->
            try
              data = JSON.parse msg
            catch err
              perr err
              return
            
            switch_key = data.switch
            if !fn = endpoint_hash[switch_key]
              return connection.send JSON.stringify
                switch      : switch_key
                request_uid : data.request_uid
                error       : "bad endpoint"
            
            fn data, (err, res)->
              if err
                perr err
                return connection.send JSON.stringify
                  switch      : switch_key
                  request_uid : data.request_uid
                  error       : err.message
              
              res = Object.assign {
                switch      : switch_key
                request_uid : data.request_uid
              }, res
              return connection.send json_encode res
            , null, null, (msg)->
              connection.send json_encode msg
            , connection
          connection.on "error", (error)->
            perr "ws connection error", error
          return
        
        if config.#{config_prefix}port_expose
          wss = new ws.Server port:config.#{config_prefix}ws_port
        else
          wss = new ws.Server port:config.#{config_prefix}ws_port, host:"localhost"
        wss.on "connection", ws_handler
        wss.on "error", (error)->
          perr "ws server error", error
        
        """#"
    
    aux_http_server = ""
    if http_enabled or static_enabled
      aux_http_server = '''
        # ###################################################################################################
        #    http server
        # ###################################################################################################
        app = express()
        
        '''
    
    
    # TODO LATER
    # if http_enabled_helmet
    #   aux_http_server += '''
    #     app.use require("helmet")()
    #     
    #     '''
    if static_enabled
      aux_http_server += '''
        app.use express.static "./static", dotfiles: "allow"
        
        '''
    
    # TODO http_query_array_support?
    ###
    npm_i "qs", "???version???"
    ###
    ###
    if config.http_query_array_support
      qs = require "qs"
    ###
    ###
    if config.http_query_array_support
      opt = qs.parse(url.search.substr 1)
    else
      opt = {}
      url.searchParams.forEach (v,k)->
        opt[k] = v
    ###
    if http_enabled
      aux_http_server += '''
        app.use (req, res)->
          try
            url = new URL req.url, "http://domain/"
          catch err
            return res.end ""
          
          switch_key = url.pathname.substr(1)
          if !fn = http_endpoint_hash[switch_key]
            return res.end JSON.stringify {
              switch: switch_key
              error : "bad endpoint"
            }, null, 2
          
          loc_opt = {}
          url.searchParams.forEach (v,k)->
            loc_opt[k] = v
          
          fn loc_opt, (err, loc_res, skip)->
            if err
              return res.end JSON.stringify {
                switch  : switch_key
                error   : err.message
              }, null, 2
            if !skip
              res_json = Object.assign {switch: switch_key}, loc_res
              res.end json_encode res_json
            return
          , req, res, (()->), null
        
        '''
    if http_enabled or static_enabled
      aux_http_server += """
        if config.#{config_prefix}port_expose
          app.listen config.#{config_prefix}http_port
        else
          app.listen config.#{config_prefix}http_port, "127.0.0.1"
        
        """
    
    listen_jl = []
    if ws_enabled
      listen_jl.push 'puts "[INFO]     ws://#{v.address}:#{config.'+config_prefix+'ws_port}"'
    if http_enabled or static_enabled
      listen_jl.push 'puts "[INFO]   http://#{v.address}:#{config.'+config_prefix+'http_port}"'
    
    aux_jl = []
    aux_jl.push aux_hot_reload      if aux_hot_reload
    aux_jl.push aux_ws_ep_collect   if aux_ws_ep_collect
    aux_jl.push aux_http_ep_collect if aux_http_ep_collect
    aux_jl.push aux_ws_server       if aux_ws_server
    aux_jl.push aux_http_server     if aux_http_server
    
    ###
    json_encode = (t)->
      try
        return JSON.stringify t
      catch err
        return JSON.stringify t, (key, value)->
          return value.toString() if typeof value == "bigint"
          return value
    ###
    ctx.file_render_exec "src/#{file_prefix}server.coffee", """
      #!/usr/bin/env iced
      ### !pragma coverage-skip-block ###
      os      = require "os"
      #{join_list include_jl, ''}
      require "fy"
      config  = require "./config"
      BigInt.prototype.toJSON = ()->@toString()
      Buffer.prototype.toJSON = ()->@toString "base64"
      json_encode = (t)->JSON.stringify t
      
      #{join_list aux_jl, ''}
      # ###################################################################################################
      puts "[INFO] listen:"
      for k,list of os.networkInterfaces()
        for v in list
          continue if v.family != "IPv4"
          continue if v.address == "127.0.0.1"
          #{join_list listen_jl, '    '}
          puts "[INFO]"
      
      """#"
    
    # ###################################################################################################
    #    Это единственный endpoint который не требует code_bubble
    #    Присутствует в http тоже чтобы упросить работу backend_ep
    # ###################################################################################################
    if ws_enabled or http_enabled
      ctx.file_render "src/endpoint/ping.coffee", '''
        @ping = (req, cb)->
          cb null, {ok:true}
        
        '''
    if http_enabled
      ctx.folder_render "src/http_only_endpoint"
    if static_enabled
      ctx.folder_render "static"
    
    false

hydrator_def policy_filter, block_filter_gen("backend"), (root)->
  bdh_node_module_name_assign_on_call root, module, "backend"
  return

# ###################################################################################################
#    
#    inside backend
#    
# ###################################################################################################
block_filter_gen = (type)->
  (root)->
    return false if root.type != type
    return false if !root.parent
    # Возможно в некоторых случаях не сработает
    return false if root.parent.type != "backend"
    true

# ###################################################################################################
#    fn -> endpoint
# ###################################################################################################
bdh_module_name_root module, "endpoint",
  emit_codebub : (root, ctx)->
    name = "backend_#{root.parent.name}/endpoint_#{root.name}.coffee"
    root.data_hash.codebub ?= ctx.file_render name, """
      
      cb new Error "unimplemented"
      # cb null, {ok:true}
      # HTTP
      # http_req
      # http_res.setHeader "Content-type", "image/png"
      # http_res.end "cont"
      # cb null, {ok:true}, true
      
      """#"
    
    name = "backend_#{root.parent.name}/endpoint_#{root.name}_require.coffee"
    root.data_hash.require_codebub ?= ctx.file_render name, ""
    
    true
  
  emit_codegen : (root, ctx)->
    # TODO extra args for http
    # if root.parent.policy_get_val_use "ws"
    if root.policy_get_val_use "ws"
      ctx.file_render "src/endpoint/#{root.name}.coffee", """
        #{root.data_hash.require_codebub}
        @[#{JSON.stringify root.name}] = (req, cb)->
          #{make_tab root.data_hash.codebub, "  "}
        
        """#"
    else
      # Прим. Там еще 2 параметра, которые не используются для http (ws_send и ws_connection, как я понимаю)
      ctx.file_render "src/http_only_endpoint/#{root.name}.coffee", """
        #{root.data_hash.require_codebub}
        @[#{JSON.stringify root.name}] = (req, cb, http_req, http_res)->
          #{make_tab root.data_hash.codebub, "  "}
        
        """#"
    true

hydrator_def policy_filter, block_filter_gen("function"), (root)->
  root.parent.policy_set_here_weak "ws", true
  bdh_node_module_name_assign_on_call root, module, "endpoint"
  return

# ###################################################################################################
#    arg
# ###################################################################################################
bdh_module_name_root module, "arg", {}

hydrator_def policy_filter, block_filter_gen("arg"), (root)->
  bdh_node_module_name_assign_on_call root, module, "arg"
  return

# ###################################################################################################
#    fn -> endpoint
# ###################################################################################################
bdh_module_name_root module, "endpoint_pubsub",
  nodegen : (root, ctx)->
    root.policy_set_here_weak "key", false
    root.policy_set_here_weak "ev",  false
    
    ctx.walk_child_list_only_fn root
    idx = root.child_list.length
    
    key_enabled = root.policy_get_val_use "key"
    ev_enabled  = root.policy_get_val_use "ev"
    if ev_enabled
      npm_i "event_mixin"
    
    ctx.walk_child_list_only_fn root, idx
    
    true
  
  emit_codebub: (root, ctx)->
    key_enabled = root.policy_get_val_use "key"
    ev_enabled  = root.policy_get_val_use "ev"
    
    if key_enabled
      broadcast_fn    = "broadcast_key_fn"
      endpoint_channel= "endpoint_channel_key"
    else
      broadcast_fn    = "broadcast_fn"
      endpoint_channel= "endpoint_channel"
    
    broadcast_code = ""
    if ev_enabled
      if key_enabled
        broadcast_code = """
          TODO_ev = new Event_mixin # TODO REMOVE me
          TODO_ev.on "TODO_event", ()->
            #{broadcast_fn}()
          """#"
      else
        broadcast_code = """
          TODO_ev = new Event_mixin # TODO REMOVE me
          TODO_ev.on "TODO_event", (event)->
            #{broadcast_fn}(event.TODO_key)
          """#"
    else
      if key_enabled
        broadcast_code = """
          do ()->
            loop
              if false # TODO
                broadcast_fn("TODO_key")
              await setTimeout defer(), 1000
          """#"
      else
        broadcast_code = """
          do ()->
            loop
              if false # TODO
                broadcast_fn()
              await setTimeout defer(), 1000
          """#"
    
    name = "backend_#{root.parent.name}/endpoint_pubsub_#{root.name}.coffee"
    root.data_hash.codebub ?= ctx.file_render name, """
      {#{broadcast_fn}} = #{endpoint_channel} @,
        name    : #{JSON.stringify root.name}
        # interval: 1000
        fn      : (req, cb)->
          cb()
      
      #{broadcast_code}
      
      """#"
    
    true
  
  emit_codegen : (root, ctx)->
    key_enabled = root.policy_get_val_use "key"
    ev_enabled  = root.policy_get_val_use "ev"
    
    # COPYPASTE
    if key_enabled
      broadcast_fn    = "broadcast_key_fn"
      endpoint_channel= "endpoint_channel_key"
    else
      broadcast_fn    = "broadcast_fn"
      endpoint_channel= "endpoint_channel"
    
    # TODO move to mod
    if key_enabled
      ctx.file_render "src/util/endpoint_channel_key.coffee", ctx.tpl_read "back/util/endpoint_channel_key.coffee"
    else
      ctx.file_render "src/util/endpoint_channel.coffee", ctx.tpl_read "back/util/endpoint_channel.coffee"
    
    
    include_jl = [
      """
      #{endpoint_channel} = require "../util/#{endpoint_channel}"
      """#"
    ]
    if ev_enabled
      include_jl.push 'require "event_mixin"'
    
    # TODO
    # А хорошая идея
    # ctx.file_render "src/endpoint_pubsub/#{root.name}.coffee"
    
    ctx.file_render "src/endpoint/#{root.name}.coffee", """
      #{join_list include_jl, ""}
      
      #{make_tab root.data_hash.codebub, ""}
      
      """#"
    
    true

hydrator_def policy_filter, block_filter_gen("endpoint_pubsub"), (root)->
  bdh_node_module_name_assign_on_call root, module, "endpoint_pubsub"
  return
