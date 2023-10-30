module = @
fs = require "fs"
{execSync} = require "child_process"
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
  iced_compile
} = require "../common_import"
{
  deep_obj_set_strict
  deep_obj_set_weak
} = require "../../util/deep_obj_set"

# ###################################################################################################
#    
#    webcom
#    
# ###################################################################################################
server_engine_handler = require "webcom/lib/server_engine_handler"
# server_engine_handler = require "webcom/src/server_engine_handler"

iced_com_compile = (code, url_path)->
  server_engine_handler.eval "com.coffee", code, {
    url_path
  }

bundle_cached = null
webcom_get_bundle = ()->
  return bundle_cached if bundle_cached?
  delivery= require "webcom"
  {
    master_registry
    Webcom_bundle
  } = require "webcom/lib/client_configurator"
  
  bundle  = new Webcom_bundle master_registry
  # require "webcom-client-plugin-base/src/hotreload"
  require "webcom-client-plugin-base/src/react"
  require "webcom-client-plugin-base/src/net"
  require "webcom-client-plugin-base/src/wsrs"
  require "webcom-client-plugin-base/src/keyboard"
  
  # bundle.plugin_add "Webcom hotreload"
  bundle.plugin_add "Webcom net"
  bundle.plugin_add "Webcom react"
  bundle.plugin_add "ws request service"
  bundle.plugin_add "keymap"
  bundle.plugin_add "keyboard scheme"
  bundle.feature_hash.hotreload = false
  
  bundle_cached = bundle.code_gen()

# ###################################################################################################
#    
#    electron
#    
# ###################################################################################################
bdh_module_name_root module, "electron",
  nodegen       : (root, ctx)->
    npm_i_dev "electron"
    npm_i_dev "electron-builder"
    
    npm_i "iced-runtime"
    npm_i "event_mixin"
    
    # npm_script "electron:start", "electron ./electron_app/main.js"
    # npm_script "electron:build", "electron-builder --publish=never"
    npm_script "electron:start", "cd ./electron_app && electron ."
    npm_script "electron:build", "cd ./electron_app && electron-builder --publish=never"
    npm_script "electron:build:fast", "cd ./electron_app && electron-builder --dir"
    # gitignore "electron_app"
    gitignore "electron_build"
    npmrc """
      node-linker=hoisted
      """
    
    # build_mac_app_category = root.policy_get_val_use "build_mac_app_category"
    # icons build/icons
    
    project_node = root.type_filter_search "project"
    package_json_node = project_node.tr_get_type_only_here "package_json"
    if !package_json_node
      throw new Error "!package_json_node"
    
    electron_frontend_node = root.tr_get_type_only_here "electron_frontend"
    if !electron_frontend_node
      throw new Error "no electron_frontend"
    
    # ###################################################################################################
    #    package.json
    # ###################################################################################################
    project_node = root.type_filter_search "project"
    package_json_node = project_node.tr_get_type_only_here "package_json"
    if !package_json_node
      throw new Error "!package_json_node"
    
    build_app_id = root.policy_get_val_use "build_app_id"
    package_json = deep_clone package_json_node.data_hash.package_json
    
    obj_set package_json, {
      main    : "./main.js"
      homepage: "https://example.com" # TODO policy
      build: {
        directories: {
          output: "../electron_build"
        }
        files: [
          "**/*"
        ]
        appId       : build_app_id
        productName : project_node.name # TODO policy
        
        # TODO enable as policy later
        # "mac": {
          # "category": build_mac_app_category
        # }
        
        # "win": {
          # "target": ["nsis"]
        # }
        
        linux: {
          target: [
            # "AppImage"
            "deb"
          ]
        }
      }
      # YES, replace
      scripts : {
        "start": "electron ."
        "build": "electron-builder --publish=never"
      }
    }
    
    root.data_hash.package_json = package_json
    
    false
  
  emit_codebub : (root, ctx)->
    root.data_hash.main_require_codebub = ctx.file_render "electron_main_require.coffee", """
      ###
      process.env.SEQUELIZE_HOST = "192.168.88.63"
      ###
      """#"
    root.data_hash.main_pre_codebub = ctx.file_render "electron_main_pre.coffee", """
      # recipe for editor
      ###
      if !app.requestSingleInstanceLock()
        app.quit()
        # так менее надежно, но сильно быстрее 0.5s -> 0.35s
        # process.exit()
        return
      
      app.on "second-instance", (event, argv, working_directory) ->
        {main_window} = global_ctx
        return if !main_window
        if main_window.isMinimized()
          main_window.restore()
        
        main_window.focus()
        
        if argv.length >= 2 && argv[1]
          main_window.webContents.send "ws_emu_data_be_fe", {
            switch : "ext_file_open"
            argv
          }
      
      ###
      """#"
    root.data_hash.main_post_codebub = ctx.file_render "electron_main_post.coffee", """
      ###
      # TODO typical recipes
      ###
      """#"
    root.data_hash.main_window_post_codebub = ctx.file_render "electron_main_window_post.coffee", """
      ###
      # give me ctrl-W
      # don't react on alt (messes up dev tools)
      main_window.setMenu null
      ###
      """#"
    
    false
  
  emit_codegen: (root, ctx)->
    dist_name        = root.policy_get_val_use "dist_name"
    dist_description = root.policy_get_val_use "dist_description"
    dist_version     = root.policy_get_val_use "dist_version"
    maximize         = root.policy_get_val_use "maximize"
    dev_tools        = root.policy_get_val_use "dev_tools"
    
    # ###################################################################################################
    #    package.json
    # ###################################################################################################
    
    # под вопросом. Возможно obj_set
    # package_json.scripts = {
    #   "start": "electron ."
    #   "build": "electron-builder --publish=never"
    # }
    
    ctx.file_render "electron_app/package.json", JSON.stringify root.data_hash.package_json, null, 2
    
    # ###################################################################################################
    #    node_modules mirror
    # ###################################################################################################
    # Прим. потом можно будет как-то назначить какие модули уходят в electron
    if !fs.existsSync "electron_app/node_modules"
      execSync "ln -s ../node_modules node_modules", {cwd : "electron_app"}
    
    # ###################################################################################################
    #    main.js
    # ###################################################################################################
    # TODO policy width, height
    # TODO policy maximized
    
    ###
        const menu = Menu.buildFromTemplate([
          {
            label: app.name,
            submenu: [
              {
                click: () => main_window.webContents.send('update-counter', 1),
                label: 'Increment'
              },
              {
                click: () => main_window.webContents.send('update-counter', -1),
                label: 'Decrement'
              }
            ]
          }
        ])
        Menu.setApplicationMenu(menu)
    ###
    
    ###
        // main_window.webContents.openDevTools()
    ###
    
    ###
      main_window.webContents.send("ws_emu_data_be_fe")
    ###
    
    # TODO tail require + iced
    
    electron_backend_node = root.tr_get_type_only_here "electron_backend"
    # if !electron_backend_node
    #   throw new Error "no electron_backend"
    
    aux_backend_require = ""
    aux_backend_on_window_create = ""
    if electron_backend_node
      aux_backend_require = """
        const backend = require("./backend.js")
        const frame_id_to_emu_connection_map = new Map();
        ipcMain.on("ws_emu_data_fe_be", (event, data)=> {
          const emu_connection = frame_id_to_emu_connection_map.get(event.sender.id)
          if (!emu_connection) {
            console.log("WARNING. Lost message", event, data);
            return;
          }
          emu_connection.dispatch("message", data)
        })
        """
      
      aux_backend_on_window_create = """
        emu_connection = new backend.Websocket_like_electron_connection
        emu_connection.target_window = main_window
        
        const id = main_window.webContents.id;
        frame_id_to_emu_connection_map.set(id, emu_connection)
        main_window.on("close", ()=>{
          emu_connection.dispatch("close")
          frame_id_to_emu_connection_map.delete(id)
        })
        """
    
    aux_maximize = ""
    if maximize
      aux_maximize = """
        main_window.maximize()
        """
    
    aux_dev_tools = ""
    if dev_tools
      aux_dev_tools = """
        main_window.webContents.openDevTools()
        """
    
    ctx.file_render "electron_app/main.js", """
      global.iced = require("iced-runtime")
      const {app, BrowserWindow, ipcMain, Menu} = require("electron")
      const path = require("node:path")
      #{iced_compile root.data_hash.main_require_codebub, bare:true}
      
      #{aux_backend_require}
      global.global_ctx = {
        main_window : null
      }
      
      function createWindow () {
        var main_window = new BrowserWindow({
          width : 800,
          height: 600,
          webPreferences: {
            preload: path.join(__dirname, "preload.js")
          }
        })
        global_ctx.main_window = main_window
        // main_window.loadFile("htdocs/index.html")
        main_window.loadFile(path.join(__dirname,"htdocs/index.html"))
        #{make_tab aux_dev_tools, "  "}
        #{make_tab aux_maximize, "  "}
        #{make_tab aux_backend_on_window_create, "  "}
        #{make_tab iced_compile(root.data_hash.main_window_post_codebub, bare:true), "  "}
      }
      
      #{iced_compile root.data_hash.main_pre_codebub, bare:true}
      
      // This method will be called when Electron has finished
      // initialization and is ready to create browser windows.
      // Some APIs can only be used after this event occurs.
      app.whenReady().then(() => {
        createWindow()
        app.on("activate", function () {
          // On macOS it's common to re-create a window in the app when the
          // dock icon is clicked and there are no other windows open.
          if (BrowserWindow.getAllWindows().length === 0)
            createWindow()
        })
      })
      
      // Quit when all windows are closed, except on macOS. There, it's common
      // for applications and their menu bar to stay active until the user quits
      // explicitly with Cmd + Q.
      app.on("window-all-closed", function () {
        if (process.platform !== "darwin") app.quit()
      });
      
      /////////////////////////////////////////////////////////////////////////////////////////////////////
      //   custom
      /////////////////////////////////////////////////////////////////////////////////////////////////////
      #{iced_compile root.data_hash.main_post_codebub, bare:true}
    """
    false

def "electron", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "electron", name, "def"
  bdh_node_module_name_assign_on_call root, module, "electron"
  
  project_node = root.type_filter_search "project"
  root.policy_set_here_weak "display_title", root.name or project_node.name
  
  
  # TODO policy CSP
  root.policy_set_here_weak "dist_name", root.name or project_node.name
  root.policy_set_here_weak "dist_description", ""
  root.policy_set_here_weak "dist_version", "0.0.1"
  root.policy_set_here_weak "maximize",  false
  root.policy_set_here_weak "dev_tools", false
  
  root.policy_set_here_weak "build_app_id", "com.author.app_name"
  # root.policy_set_here_weak "build_mac_app_category", "public.app-category.developer-tools"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    electron_frontend
# ###################################################################################################
bdh_module_name_root module, "electron_frontend",
  nodegen       : (root, ctx)->
    # ###################################################################################################
    #    
    # ###################################################################################################
    {frontend_node} = root.data_hash
    dst_needs_pubsub_mod = frontend_node.data_hash.ws_mod_sub
    
    # ###################################################################################################
    #    
    # ###################################################################################################
    root.data_hash.script_list = []
    root.data_hash.coffee_script_list = []
    root.data_hash.coffee_script_com_list = []
    root.data_hash.include_script_list = []
    root.data_hash.include_script_com_list = []
    root.data_hash.include_css_list = []
    root.data_hash.copy_list = []
    
    # ###################################################################################################
    #    
    # ###################################################################################################
    htdocs = "htdocs"
    # TODO look for frontend_node.name for proper htdocs
    walk = (dir)->
      file_list = fs.readdirSync dir
      file_list.sort()
      for file in file_list
        full_file = "#{dir}/#{file}"
        if fs.statSync(full_file).isDirectory()
          walk full_file
          continue
        
        if file.endsWith ".com.coffee"
          root.data_hash.include_script_com_list.push full_file
          root.data_hash.coffee_script_com_list.push full_file
        else if file.endsWith ".coffee"
          root.data_hash.include_script_list.push full_file
          root.data_hash.coffee_script_list.push full_file
        else if file.endsWith ".js"
          root.data_hash.include_script_list.push full_file
          root.data_hash.script_list.push full_file
        else if file.endsWith ".css"
          root.data_hash.include_css_list.push full_file
        else if /\.(bmp|ico|png|jpe?g|gif|svg|webp)$/i.test file
          # image assets
          # webp пока наказан?
          root.data_hash.copy_list.push full_file
        else if /\.(mp3|wav|m4a|acc|ogg)$/i.test file
          # audio assets
          root.data_hash.copy_list.push full_file
        else if /\.(avi|mp4|flv|mkv|m4v|webm|3gp)$/i.test file
          # video assets
          # webm пока наказан?
          # 3gp ???
          root.data_hash.copy_list.push full_file
        else if /\.(woff2?|ttf|otf|eot)$/i.test file
          # font assets
          root.data_hash.copy_list.push full_file
        else
          root.data_hash.copy_list.push full_file
          # puts "unknown format #{file}. Didn't copied"
          puts "unknown format #{file}. Copied anyway"
        # zip, rar - SKIP
        # WebGL: glb, gltf - SKIP
        # doc pdf, doc, xls, docx, xlsx - SKIP
      
      return
    if fs.existsSync htdocs
      walk htdocs
    
    false
  
  emit_codebub  : (root, ctx)->
    root.data_hash.preload_codebub = ctx.file_render "electron_preload.coffee", """
      ###
      # TODO typical recipes
      ###
      """#"
    
    false
  
  emit_codegen  : (root, ctx)->
    # ###################################################################################################
    #    
    # ###################################################################################################
    {frontend_node} = root.data_hash
    dst_needs_pubsub_mod = frontend_node.data_hash.ws_mod_sub
    
    # ###################################################################################################
    #    
    # ###################################################################################################
    # TODO webcom bundle
    # _iced.compile t, bare:true, runtime:"inline"
    # src/block/nodejs
    react_path = __dirname+"/../../../"+"node_modules/webcom-engine-vendor/react_min"
    ctx.file_render "electron_app/htdocs/1react.js",     fs.readFileSync "#{react_path}/1react.js", "utf-8"
    ctx.file_render "electron_app/htdocs/2react-dom.js", fs.readFileSync "#{react_path}/2react-dom.js", "utf-8"
    
    ctx.file_render "electron_app/htdocs/bundle.coffee", webcom_get_bundle()
    
    for src in root.data_hash.script_list
      dst = src.replace /^htdocs\//, ""
      cont = fs.readFileSync src, "utf-8"
      # TODO check is file exists (not -> ignore cache)
      # TODO apply cache
      ctx.file_render "electron_app/htdocs/#{dst}", cont
    for src in root.data_hash.coffee_script_list
      dst = src.replace /^htdocs\//, ""
      continue if dst == "_network_and_db/1_connect.coffee"
      cont = fs.readFileSync src, "utf-8"
      # TODO check is file exists (not -> ignore cache)
      # TODO apply cache
      ctx.file_render "electron_app/htdocs/#{dst}", iced_compile cont
    for src in root.data_hash.coffee_script_com_list
      dst = src.replace /^htdocs\//, ""
      cont = fs.readFileSync src, "utf-8"
      # TODO check is file exists (not -> ignore cache)
      # TODO apply cache
      ctx.file_render "electron_app/htdocs/#{dst}", iced_com_compile cont, dst
    for src in root.data_hash.copy_list
      dst = src.replace /^htdocs\//, ""
      ctx.file_render "electron_app/htdocs/#{dst}", fs.readFileSync src
    
    # ###################################################################################################
    #    
    # ###################################################################################################
    # TODO optional ws_mod_sub
    aux_ws_mod_pubsub = ""
    
    if dst_needs_pubsub_mod
      aux_ws_mod_pubsub = '''
        ws_mod_sub ws_back, wsrs_back
        '''
    
    ctx.file_render "electron_app/htdocs/_network_and_db/1_connect.coffee", iced_compile """
      # ###################################################################################################
      #    decl
      # ###################################################################################################
      class Websocket_like_electron
        @uid: 0
        uid : 0
        
        event_mixin @
        constructor:()->
          event_mixin_constructor @
          @uid = Websocket_like_electron.uid++
          setTimeout ()=>
            @dispatch "reconnect"
          , 0
        
        delete : ()->
          @close()
        
        close : ()->
          perr "close is not available"
        
        send : (msg)->
          electronAPI.ws_emu_send msg
        
        write : @prototype.send
        
        ws_init : ()->
          perr "ws_init is not available"
        
        ws_reconnect : ()->
          perr "ws_reconnect is not available"
      
      # ###################################################################################################
      #    
      # ###################################################################################################
      window.ws_back  = new Websocket_like_electron
      
      electronAPI.ws_emu_on_data (data)->
        ws_back.dispatch "data", data
      
      window.wsrs_back= new Ws_request_service ws_back
      #{aux_ws_mod_pubsub}
      
      
      # loop
      #   await wsrs_back.request {switch: "ping"}, defer(err), timeout:1000
      #   if err
      #     perr "ping hang/error -> reconnect backend=emu", err.message
      #     # ws_back.ws_reconnect()
      #   await setTimeout defer(), 1000
      
      """#"
    
    # ###################################################################################################
    #    preload.js
    # ###################################################################################################
    # я не знаю для чего может понадобится отключать FE и BE
    # Пока неотключаемое
    
    ctx.file_render "electron_app/preload.js", """
      const { contextBridge, ipcRenderer } = require("electron")
      
      contextBridge.exposeInMainWorld("electronAPI", {
        ws_emu_send: (msg) => {
          ipcRenderer.send("ws_emu_data_fe_be", msg)
        },
        ws_emu_on_data: (handler) => {
          ipcRenderer.on("ws_emu_data_be_fe", (_event, data)=>{
            handler(data)
          })
        }
      });
      
      /////////////////////////////////////////////////////////////////////////////////////////////////////
      //   custom
      /////////////////////////////////////////////////////////////////////////////////////////////////////
      #{iced_compile root.data_hash.preload_codebub}
    """
    
    # ###################################################################################################
    #    index.html
    # ###################################################################################################
    # TODO better content
    # --renderer
    # compiled style
    # <script src="./renderer.js"></script>
    
    display_title    = root.policy_get_val_use "display_title"
    
    # LATER/NEVER fill file_list, framework_style_hash
    code_css_jl = []
    script_jl   = []
    
    for css_file in root.data_hash.include_css_list
      code_css_jl.push fs.readFileSync css_file, "utf-8"
    
    script_jl.push "<script src=\"./1react.js\"></script>"
    script_jl.push "<script src=\"./2react-dom.js\"></script>"
    script_jl.push "<script src=\"./bundle.coffee\"></script>"
    script_jl.push "<script src=\"./_webcom_emu.js\"></script>"
    ctx.file_render "electron_app/htdocs/_webcom_emu.js", """
      var config_hot_reload = false;
      var config_hot_reload_port = 0;
      var start_ts = Date.now();
      var file_list = [];
      var framework_style_hash = {};
      """
    
    for src in root.data_hash.include_script_com_list
      dst = src.replace /^htdocs\//, ""
      script_jl.push "<script src=\"./#{dst}\"></script>"
    for src in root.data_hash.include_script_list
      dst = src.replace /^htdocs\//, ""
      script_jl.push "<script src=\"./#{dst}\"></script>"
    
    # TODO make customizeable
    # с другой стороны а что такого нельзя сделать простым 1_custom.coffee в htdocs?
    ctx.file_render "electron_app/htdocs/index.html", """
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8">
          <meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:">
          
          <title>#{display_title}</title>
          <style>
            #{join_list code_css_jl, "      "}
          </style>
        </head>
        <body>
          <div id="mount_point"></div>
          #{join_list script_jl, "    "}
        </body>
      </html>
    """
    false

def "electron electron_frontend", (name)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "electron_frontend", name, "def"
  bdh_node_module_name_assign_on_call root, module, "electron_frontend"
  
  project_node = root.type_filter_search "project"
  frontend_node = project_node.tr_get_try "frontend", name
  if !frontend_node
    throw new Error "can't find frontend name=#{name} for electron_frontend wrapper"
  root.data_hash.frontend_node = frontend_node
  
  
  project_node = root.type_filter_search "project"
  root.policy_set_here_weak "display_title", root.name or project_node.name
  
  return

# ###################################################################################################
#    electron_backend
# ###################################################################################################
bdh_module_name_root module, "electron_backend",
  nodegen       : (root, ctx)->
    root.data_hash.file_js_list = []
    root.data_hash.file_coffee_list = []
    # ###################################################################################################
    #    
    # ###################################################################################################
    dir = "src"
    walk = (dir)->
      file_list = fs.readdirSync dir
      file_list.sort()
      for file in file_list
        full_file = "#{dir}/#{file}"
        if fs.statSync(full_file).isDirectory()
          walk full_file
          continue
        
        if file.endsWith ".coffee"
          root.data_hash.file_coffee_list.push full_file
        else if file.endsWith ".js"
          root.data_hash.file_js_list.push full_file
        else
          puts "WARNING. don't know how to handle #{full_file}"
      
      return
    
    if fs.existsSync dir
      walk dir
    
    false
  
  emit_codegen  : (root, ctx)->
    endpoint_list = []
    
    for file in root.data_hash.file_js_list
      ctx.file_render "electron_app/#{file}", fs.readFileSync file, "utf-8"
    
    for file in root.data_hash.file_coffee_list
      dst = file.replace /\.coffee$/, ".js"
      ctx.file_render "electron_app/#{dst}", iced_compile fs.readFileSync file, "utf-8"
      # WARNING hardcode backend ""
      if file.startsWith "src/endpoint"
        endpoint_list.push """
          obj_set(endpoint_hash, require(#{JSON.stringify './'+dst}))
          """
    
    # суперкостыль
    
    ctx.file_render "electron_app/backend.js", iced_compile """
      {ipcMain} = require("electron")
      require("fy")
      require("event_mixin")
      
      # ###################################################################################################
      #    
      # ###################################################################################################
      endpoint_hash = {}
      #{join_list endpoint_list}
      
      # ###################################################################################################
      #    COMPAT
      # ###################################################################################################
      emu_connection_list = []
      connection_uid = 1 # uid 0 == http persistant template
      connection_list_get = ()->emu_connection_list
      
      # REMOVED JSON.parse JSON.stringify
      ws_handler = (connection, req)->
        connection.ip = req.socket.remoteAddress
        connection.__uid = connection_uid++
        connection.list_get = connection_list_get
        connection.on "message", (data)->
          switch_key = data.switch
          if !fn = endpoint_hash[switch_key]
            return connection.send {
              switch      : switch_key
              request_uid : data.request_uid
              error       : "bad endpoint"
            }
          
          fn data, (err, res)->
            if err
              perr err
              return connection.send {
                switch      : switch_key
                request_uid : data.request_uid
                error       : err.message
              }
            
            res = Object.assign {
              switch      : switch_key
              request_uid : data.request_uid
            }, res
            return connection.send res
          , null, null, (msg)->
            connection.send msg
          , connection
        connection.on "error", (error)->
          perr "ws connection error", error
        return
      
      # ###################################################################################################
      #    
      # ###################################################################################################
      class Websocket_like_electron_connection
        target_window : null
        
        event_mixin @
        constructor : ()->
          event_mixin_constructor @
          emu_connection_list.push @
          @once "close", ()=>
            emu_connection_list.remove @
          
          ws_handler @, {
            socket : {
              remoteAddress : "127.0.0.1"
            }
          }
        
        send : (msg)->
          # HACK for compat
          if typeof msg == "string"
            try
              msg = JSON.parse msg
            catch err
              
          
          @target_window.webContents.send("ws_emu_data_be_fe", msg)
      
      
      # ###################################################################################################
      #    
      # ###################################################################################################
      
      this.Websocket_like_electron_connection = Websocket_like_electron_connection
      """
    
    
    false
  
  # TODO
  # KEEP. Review at 01.01.2024
  # emit_min_deps : (root, ctx, cb)->
  #   # package_manager = root.policy_get_val_use "package_manager"
  #   
  #   # electron, кажется не понимает snpm
  #   package_manager = "npm"
  #   {
  #     npm_i_list_fn
  #     pnpm_i_list_fn
  #     snpm_i_list_fn
  #   } = require "./package_json"
  #   switch package_manager
  #     when "npm"
  #       pm_fn = npm_i_list_fn
  #     when "pnpm"
  #       pm_fn = pnpm_i_list_fn
  #     when "snpm"
  #       pm_fn = snpm_i_list_fn
  #     
  #     else
  #       return cb new Error "unknown package_manager '#{package_manager}'"
  #   
  #   # FIXED
  #   folder = ctx.curr_folder+"/electron_app"
  #   # COPYPASTE
  #   package_json = JSON.parse fs.readFileSync "#{folder}/package.json"
  #   need_install_list = []
  #   for package_name, package_version of package_json.dependencies
  #     path_to_module = "#{folder}/node_modules/#{package_name}"
  #     if !fs.existsSync path_to_module
  #       # TODO other prefixes
  #       if package_version.startsWith "github"
  #         need_install_list.push package_version
  #       else
  #         need_install_list.push "#{package_name}@#{package_version}"
  #       continue
  #     
  #     if package_version.startsWith "github"
  #       # TODO check ... I don't know what, freshest commit in cache?
  #       continue
  #     
  #     target_package_json_file = "#{path_to_module}/package.json"
  #     if !fs.existsSync target_package_json_file
  #       need_install_list.push "#{package_name}@#{package_version}"
  #       continue
  #     
  #     mod_package_json = JSON.parse fs.readFileSync target_package_json_file
  #     if !semver.satisfies mod_package_json.version, package_version
  #       need_install_list.push "#{package_name}@#{package_version}"
  #   
  #   if need_install_list.length
  #     # FIXED
  #     puts "need_install_list (electron):"
  #     for v in need_install_list
  #       puts "  #{v}"
  #     await pm_fn folder, need_install_list, defer(err); return cb err if err
  #   
  #   cb()

def "electron electron_backend", (name)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "electron_backend", name, "def"
  bdh_node_module_name_assign_on_call root, module, "electron_backend"
  
  project_node = root.type_filter_search "project"
  backend_node = project_node.tr_get_try "backend", name
  if !backend_node
    throw new Error "can't find backend name=#{name} for electron_backend wrapper"
  root.data_hash.backend_node = backend_node
  
  return

# ###################################################################################################
#    electron_wrapper
# ###################################################################################################
bdh_module_name_root module, "electron_wrapper",
  nodegen       : (root, ctx)->
    project_node = root.type_filter_search "project"
    # TODO должно быть одинаковое имя с package.json внутри electron_app
    # неплохо бы в electron иметь data_hash.app_package_name
    # чтобы один источник правды
    
    gitignore "electron_wrapper_build"
    # почему-то вписалось в начало package_json.scripts
    npm_script "electron:wrapper:start", "cd ./electron_wrapper_build/linux-unpacked && ./#{project_node.name}"
    npm_script "electron:wrapper:build", "cd ./electron_wrapper_app && electron-builder --publish=never"
    npm_script "electron:wrapper:build:fast", "cd ./electron_wrapper_app && electron-builder --dir"
    false
  
  emit_codegen: (root, ctx)->
    # ###################################################################################################
    #    package.json
    # ###################################################################################################
    electron_node = root.parent
    
    package_json = deep_clone electron_node.data_hash.package_json
    obj_set package_json, {
      scripts : {
        build: "electron-builder --publish=never"
        "build:fast": "electron-builder --dir"
      }
      main: "./main.js"
    }
    delete package_json.dependencies
    package_json.build.directories.output = "../electron_wrapper_build"
    package_json.build.files = [
      "**/*"
    ]
    
    ctx.file_render "electron_wrapper_app/package.json", JSON.stringify package_json, null, 2
    
    # ###################################################################################################
    #    node_modules mirror
    # ###################################################################################################
    # Прим. потом можно будет как-то назначить какие модули уходят в electron
    if !fs.existsSync "electron_wrapper_app/node_modules"
      execSync "ln -s ../node_modules node_modules", {cwd : "electron_wrapper_app"}
    
    # ###################################################################################################
    #    
    # ###################################################################################################
    ctx.file_render "electron_wrapper_app/main.js", """
      const path = require("path");
      
      // electron_wrapper_build/linux-unpacked/resources/app.asar
      process.chdir(path.join(__dirname, "../../../../electron_app"));
      
      require("../../../../electron_app/main.js");
      """
    
    false

def "electron electron_wrapper", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "electron_wrapper", "electron_wrapper", "def"
  bdh_node_module_name_assign_on_call root, module, "electron_wrapper"
  
  return

###
TODO
icon
###
