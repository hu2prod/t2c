module = @
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

###
TODO rework
if mod_runner.current_runner.curr_root.type != "browser_ext"
use child_list walk:
  --content_script_list
  --widget_list
  ?build_import_list

подчистить лишние emit_codebub emit_min_deps, etc
###

# ###################################################################################################
#    browser_ext
# ###################################################################################################
bdh_module_name_root module, "browser_ext",
  nodegen       : (root, ctx)->
    be_name = "browser_ext"
    if root.name
      be_name = "browser_ext_#{root.name}"
    
    project_node = root.type_filter_search "project"
    app_name = root.name or project_node.name
    
    root.data_hash.be_name = be_name
    root.data_hash.app_name = app_name
    root.data_hash.dev_folder  = "#{be_name}/#{be_name}_dev"
    root.data_hash.build_folder= "#{be_name}/#{be_name}"
    
    ctx.walk_child_list_only_fn root
    
    page_hash = root.typed_ref_hash.browser_ext_page ? {}
    page_list = Object.values page_hash
    
    for cs in root.data_hash.content_script_list
      resource_list = []
      for widget in cs.data_hash.widget_list
        widget_page_name = widget.data_hash.page_name
        if !page = page_hash[widget_page_name]
          throw new Error "widget '#{widget.name}' use page '#{widget_page_name}' but page is not defined"
        
        page.data_hash.is_widget_sandboxed = true
        resource_list.upush "page_#{widget_page_name}/*"
      
      if resource_list.length
        resource_list.upush "1_init_and_modules/*"
        resource_list.upush "generic/*"
        resource_list.upush "page_wrap_inner.js"
        # doens't work properly
        # browser_ext_manifest {
          # web_accessible_resources: [{
            # resources : resource_list
            # matches   : cs.data_hash.match_list
            # extension_ids: []
          # }]
        # }
        
        obj = {
          web_accessible_resources: [{
            resources : resource_list
            matches   : cs.data_hash.match_list
            # extension_ids: [] # пустой массив невалиден в firefox
          }]
        }
        deep_obj_set_strict root.data_hash.dev_manifest_json,   obj
        deep_obj_set_strict root.data_hash.build_manifest_json, obj
    
    for page in page_list
      page_name = "page_#{page.name}"
      folder_wrap "#{be_name}/#{page_name}", ()->
        config()
        frontend "browser_ext_#{root.name}_page_#{page_name}", ()->
          policy_set "start_script", false
    
    if page_list.length
      npm_script "browser_ext_dev", "./loop.sh ./#{be_name}/#{be_name}_front_server.coffee --watch"
      node_loop_sh()
      starter_tmux_set "browser_ext #{root.name}", "dev", """
        cd #{ctx.curr_folder}
        npm run browser_ext_dev
        """
    
    root.data_hash.page_list = page_list
    
    # еще раз, т.к. frontend
    false
  
  validator     : (root, ctx)->
    false
  
  emit_codebub  : (root, ctx)->
    false
  
  emit_codegen  : (root, ctx)->
    {
      be_name
      app_name
      dev_folder
      build_folder
      page_list
      content_script_list
    } = root.data_hash
    
    display_name        = root.policy_get_val_use "display_name"
    display_description = root.policy_get_val_use "display_description"
    display_version     = root.policy_get_val_use "display_version"
    
    project_node = root.type_filter_search "project"
    
    # ###################################################################################################
    #    manifest.json
    # ###################################################################################################
    common_manifest_middleware = (manifest_json)->
      if page_list.length
        manifest_json.content_security_policy = {
          extension_pages : "default-src 'self'; connect-src ws:; img-src *"
          # ?TODO remove. == default
          sandbox         : "sandbox allow-scripts allow-forms allow-popups allow-modals; script-src 'self' 'unsafe-inline' 'unsafe-eval'; child-src 'self'"
        }
    
    manifest_json = {
      manifest_version : 3
      name        : "(dev) #{display_name}"
      description : "(dev) #{display_description}"
      version     : "#{display_version}.9999"
    }
    common_manifest_middleware manifest_json
    
    obj_set manifest_json, root.data_hash.dev_manifest_json
    
    ctx.file_render "#{dev_folder}/manifest.json", JSON.stringify manifest_json, null, 2
    
    
    manifest_json = {
      manifest_version : 3
      name        : display_name
      description : display_description
      version     : display_version
    }
    common_manifest_middleware manifest_json
    
    obj_set manifest_json, root.data_hash.build_manifest_json
    ctx.file_render "#{build_folder}/manifest.json", JSON.stringify manifest_json, null, 2
    
    # ###################################################################################################
    #    page dev server
    # ###################################################################################################
    if page_list.length
      fe_server_start_jl = []
      fe_server_start_jl.push """
        delivery= require "webcom"
        {
          master_registry
          Webcom_bundle
        } = require "webcom/lib/client_configurator"
        
        bundle  = new Webcom_bundle master_registry
        
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
        
        
        
        page_service_hash = {}
        """#"
      
      for page in page_list
        page_name = "page_#{page.name}"
        frontend_name = "browser_ext_#{root.name}_page_#{page_name}"
        config_prefix = "front_#{frontend_name}_"
        
        fe_server_start_jl.push """
          do ()->
            config = require "./page_#{page.name}/src/config.coffee"
            service = delivery.start {
              htdocs    : "#{be_name}/page_#{page.name}/htdocs"
              hotreload : !!config.watch
              title     : "Browser ext  page page my page"
              bundle
              no_port_expose : config.#{config_prefix}no_port_expose
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
                return false if full_path.startsWith "#{be_name}/page_#{page.name}/htdocs"
                true
            }
            page_service_hash[#{JSON.stringify page.name}] = service
          
          """#"
      
      ctx.file_render_exec "#{be_name}/#{be_name}_front_server.coffee", """
        #!/usr/bin/env iced
        #{join_list fe_server_start_jl, ""}
        
        module.exports = {
          page_service_hash
        }
        """
    
    # ###################################################################################################
    #    page_wrap_inner
    # ###################################################################################################
    has_pages_for_wrap = false
    for cs in content_script_list
      has_pages_for_wrap = true if cs.data_hash.widget_list.length
    
    if has_pages_for_wrap
      # Не в tpl т.к. могут быть разные API которые нужно будет эмулировать через policy
      # Но если этого не будет, то, конечно. нужно переместить в tpl
      
      content = iced_compile """
        # ###################################################################################################
        #    utils
        # ###################################################################################################
        req_uid = 0
        cb_hash = {}
        listener_list = []
        
        addEventListener "message", (event)->
          # TODO check origin?
          req = event.data
          if req.sender != "page_wrap"
            for cb in listener_list
              try
                # TODO better polyfill for 2nd arg
                cb req, {}, (res)->
                  res.sender  = req.sender
                  res.req_uid = req.req_uid
                  parent.postMessage(req, "*")
              catch e
                console.error e
            return
          return if !req.req_uid?
          v = cb_hash[req.req_uid]
          if !v
            console.error "possible timeout req_uid=\#{req.req_uid}"
            return
          delete cb_hash[req.req_uid]
          err = null
          if req.error
            err = new Error req.error
          try
            v.cb err, req
          catch e
            console.error e
          return
        
        setInterval ()->
          now = Date.now()
          delete_key_list = []
          for k,v of cb_hash
            if now > v.timeout_ts
              delete_key_list.push k
          
          for k in delete_key_list
            v = cb_hash[k]
            delete cb_hash[k]
            try
              v.cb new Error "timeout"
            catch e
              console.error e
          return
        , 100
        
        # ###################################################################################################
        #    API
        # ###################################################################################################
        window.chrome ?= {}
        window.browser ?= window.chrome
        chrome.runtime ?= {}
        chrome.runtime.onMessage ?= {}
        chrome.runtime.sendMessage ?= (_skip_target, req, _skip_opt, cb)->
          req.req_uid = req_uid++
          req.sender  = "page_wrap"
          cb_hash[req.req_uid] = {
            cb
            timeout_ts : Date.now() + 10000
          }
          parent.postMessage(req, "*")
          return
        
        chrome.runtime.onMessage.addListener = (cb)->
          listener_list.push cb
          return
        
        """#"
      ctx.file_render "#{dev_folder   }/page_wrap_inner.js", content
      ctx.file_render "#{build_folder }/page_wrap_inner.js", content
    
    # ###################################################################################################
    
    false
  
  emit_min_deps : (root, ctx, cb)->
    cb null, false

def "browser_ext", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "browser_ext", name, "def"
  bdh_node_module_name_assign_on_call root, module, "browser_ext"
  root.data_hash.content_script_list ?= []
  root.data_hash.dev_manifest_json   ?= {}
  root.data_hash.build_manifest_json ?= {}
  root.data_hash.build_import_list   ?= []
  
  project_node = root.type_filter_search "project"
  
  root.policy_set_here_weak "display_name", root.name or project_node.name
  root.policy_set_here_weak "display_description", ""
  root.policy_set_here_weak "display_version", "0.0.1"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
def "browser_ext_manifest", (obj, mask = "*")->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  {data_hash} = mod_runner.current_runner.curr_root.type_filter_search "browser_ext"
  
  if mask in ["dev", "*"]
    deep_obj_set_strict data_hash.dev_manifest_json,   obj
  if mask in ["build", "*"]
    deep_obj_set_strict data_hash.build_manifest_json, obj
  
  return

def "browser_ext_manifest_weak", (obj, mask = "*")->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  {data_hash} = mod_runner.current_runner.curr_root.type_filter_search "browser_ext"
  
  if mask in ["dev", "*"]
    deep_obj_set_weak data_hash.dev_manifest_json,   obj
  if mask in ["build", "*"]
    deep_obj_set_weak data_hash.build_manifest_json, obj
  
  return

def "browser_ext_permission", (permission)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  {data_hash} = mod_runner.current_runner.curr_root.type_filter_search "browser_ext"
  
  browser_ext_manifest {
    permissions : [permission]
  }
  
  return

def "browser_ext_host_permission", (permission)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  {data_hash} = mod_runner.current_runner.curr_root.type_filter_search "browser_ext"
  
  browser_ext_manifest {
    host_permissions : [permission]
  }
  
  return

# ###################################################################################################
#    browser_ext_content_script
# ###################################################################################################
bdh_module_name_root module, "browser_ext_content_script",
  nodegen       : (root, ctx)->
    {name} = root
    {match} = root.data_hash
    
    # TODO remove root.data_hash.match
    # use only root.data_hash.match_list
    match ?= "*://*/*"
    cs_name = "content_script_#{name}"
    if match == "*://*/*"
      if !name
        cs_name = "content_script_all"
    
    root.data_hash.cs_name = cs_name
    
    match_list = []
    if match instanceof Array
      match_list = match
    else
      match_list.push match
    
    root.parent.data_hash.content_script_list.upush root
    
    root.data_hash.match_list = match_list
    
    
    # WARNING nodegen browser_ext_manifest
    # А вот интересно будет ли работать только с matches без host_permissions
    for v in match_list
      browser_ext_host_permission v
    
    browser_ext_permission "tabs"
    browser_ext_manifest {
      content_scripts: [{
        js: [
          "#{cs_name}.js"
        ]
        matches: match_list
      }]
    }
    
    false
  
  validator     : (root, ctx)->
    false
  
  emit_codebub  : (root, ctx)->
    false
  
  emit_codegen  : (root, ctx)->
    # Пока одинаковые
    # HMR для content_script не возможен (но не widget page части) 
    #   Придется перезагрузить вообще все страницы в браузере к которым применяется match_list
    {
      cs_name
      widget_list
      command_list
    } = root.data_hash
    ext_node = root.type_filter_search "browser_ext"
    {
      dev_folder
      build_folder
      app_name
    } = ext_node.data_hash
    
    root_jl   = []
    iframe_list = []
    switch_jl = []
    
    for command in command_list
      continue if !command.data_hash.cs_codebub
      
      command_prefix = "command"
      if command.name
        command_prefix = "command_#{command.name}"
      
      root_jl.push command.data_hash.cs_codebub
      switch_jl.push """
        when "#{command_prefix}"
          sendResponse
            switch  : "#{command_prefix}"
            response: #{JSON.stringify cs_name}
          
          #{command_prefix}()
        """#"
    
    for widget in widget_list
      widget_prefix = "widget"
      if widget.name
        widget_prefix = "widget_#{widget.name}"
      widget_page_name = widget.data_hash.page_name
      
      aux_overlay_on_click_close = ""
      if widget.data_hash.overlay_on_click_close
        aux_overlay_on_click_close = """
          #{widget_prefix}_overlay_div.onclick = ()->
            #{widget_prefix}_close()
            return
          
          """
      
      iframe_list.push "#{widget_prefix}_iframe"
      root_jl.push """
        #{widget_prefix}_iframe = null
        #{widget_prefix}_overlay_div = null
        #{widget_prefix}_old_body_overflow = null
        #{widget_prefix}_old_body_padding_right = null
        
        #{widget_prefix}_open =()->
          return if #{widget_prefix}_overlay_div
          #{widget_prefix}_overlay_div = document.createElement "div"
          #{widget_prefix}_overlay_div.id = "#{app_name}_OVERLAY"
          #{widget_prefix}_overlay_div.style = '''
            position: fixed;
            width: 100vw;
            height: 100vh;
            background: rgba(0, 0, 0, 0.25);
            top: 0;
            left: 0;
            border: 0 none;
            z-index: 214748364700;
            transition: all 0.1s;
            display: flex;
            flex: 1;
            justify-content: center;
            align-items: center;
            '''
          #{widget_prefix}_iframe = document.createElement "iframe"
          #{widget_prefix}_iframe.style = '''
            width : #{widget.data_hash.size_x}px;
            height: #{widget.data_hash.size_y}px;
            border: 0 none;
            border-radius: 15px;
            box-shadow: 0px 9px 23px rgba(0, 0, 0, 0.1);
            background: white;
            transition: all 0.1s;
            '''
          #{widget_prefix}_overlay_div.appendChild(#{widget_prefix}_iframe)
          document.body.appendChild(#{widget_prefix}_overlay_div)
          
          #{widget_prefix}_old_body_overflow = document.body.style.overflow
          document.body.style.overflow = "hidden"
          
          #{widget_prefix}_old_body_padding_right = document.body.style.paddingRight;
          scroll_width = window.innerWidth - document.body.scrollWidth;
          document.body.style.paddingRight = scroll_width+"px";
          #{widget_prefix}_iframe.src = chrome.runtime.getURL("page_#{widget_page_name}/page_#{widget_page_name}.html");
          
          #{make_tab aux_overlay_on_click_close, "  "}
          return
        
        #{widget_prefix}_close = ()->
          return if !#{widget_prefix}_overlay_div
          
          document.body.removeChild(#{widget_prefix}_overlay_div)
          document.body.style.overflow = #{widget_prefix}_old_body_overflow
          
          document.body.style.paddingRight = #{widget_prefix}_old_body_padding_right
          
          #{widget_prefix}_overlay_div      = null
          #{widget_prefix}_iframe           = null
          #{widget_prefix}_old_body_overflow= null
          return
        
        #{widget_prefix}_toggle = ()->
          if #{widget_prefix}_overlay_div
            #{widget_prefix}_close()
          else
            #{widget_prefix}_open()
          return
        
        """#"'
      
      switch_jl.push """
        when "#{widget_prefix}_open"
          sendResponse
            switch  : "#{widget_prefix}_open"
            response: #{JSON.stringify cs_name}
          
          #{widget_prefix}_open()
        
        when "#{widget_prefix}_close"
          sendResponse
            switch  : "#{widget_prefix}_close"
            response: #{JSON.stringify cs_name}
          
          #{widget_prefix}_close()
        
        when "#{widget_prefix}_toggle"
          sendResponse
            switch  : "#{widget_prefix}_toggle"
            response: #{JSON.stringify cs_name}
          
          #{widget_prefix}_toggle()
        
        """#"
    
    if widget_list.length
      root_jl.push """
        get_first_active_iframe = ()->
          for v in [#{iframe_list.join ", "}]
            return v if v
          null
        
        chrome.runtime.onMessage.addListener (request, sender, sendResponse)->
          return if sender.tab # background only
          get_first_active_iframe()?.postMessage request, "*"
        
        correct_origin = chrome.runtime.getURL("") # TODO recheck
        addEventListener "message", (event)->
          if event.origin != correct_origin
            console.error "ignored message from \#{event.origin}"
            return
          req = event.data
          
          chrome.runtime.sendMessage null, req, {}, (response)->
            get_first_active_iframe()?.postMessage response, "*"
        """#"
    
    cs_content = iced_compile """
      window.chrome ?= window.browser
      #{join_list root_jl, ""}
      chrome.runtime.onMessage.addListener (request, sender, sendResponse)->
        return if sender.tab
        return if !request?.switch
        switch request.switch
          when "runtime_ping"
            sendResponse
              switch  : "runtime_ping"
              response: #{JSON.stringify cs_name}
            
          #{join_list switch_jl, "    "}
      
      """#"
    ctx.file_render "#{dev_folder   }/#{cs_name}.js", cs_content
    ctx.file_render "#{build_folder }/#{cs_name}.js", cs_content
    
    false
  
  emit_min_deps : (root, ctx, cb)->
    cb null, false

def "browser_ext_content_script", (name, match, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  if mod_runner.current_runner.curr_root.type != "browser_ext"
    throw new Error "current_runner.curr_root.type != 'browser_ext'"
  
  root = mod_runner.current_runner.curr_root.tr_get "browser_ext_content_script", name, "def"
  bdh_node_module_name_assign_on_call root, module, "browser_ext_content_script"
  
  # Прим. Немного странная локация для command_list
  root.data_hash.widget_list  ?= []
  root.data_hash.command_list ?= []
  root.data_hash.match ?= match
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    browser_ext_widget
# ###################################################################################################
bdh_module_name_root module, "browser_ext_widget",
  nodegen       : (root, ctx)->
    # TODO widget should call browser_ext_command
    trigger_on_hotkey = root.policy_get_val_use "trigger_on_hotkey"
    trigger_on_button = root.policy_get_val_use "trigger_on_button"
    hk_action_name= root.policy_get_val_use "hotkey_action_name"
    hk_action_desc= root.policy_get_val_use "hotkey_action_description"
    
    hk_obj = {}
    if trigger_on_hotkey
      hk_default    = root.policy_get_val_use "hotkey"
      commands = {}
      hk_obj = {
        suggested_key : {
          default: hk_default
        }
        description : hk_action_desc
      }
      for os_name in ["mac", "windows", "chromeos", "linux"]
        if value = root.policy_get_val_use_default "widget_hotkey_#{os_name}", ""
          hk_obj.suggested_key[os_name] = value
    
    if trigger_on_button
      root.data_hash.button_action = true
      browser_ext_button_action_weak()
      # WARNING nodegen browser_ext_manifest
      browser_ext_manifest {
        commands :
          "_execute_action" : hk_obj
      }
      browser_ext_manifest {
        commands
      }
    else if trigger_on_hotkey
      root.data_hash.button_action = false
      root.data_hash.action_name = hk_action_name
      commands[hk_action_name] = hk_obj
      browser_ext_manifest {
        commands
      }
    
    false
  
  validator     : (root, ctx)->
    false
  
  emit_codebub  : (root, ctx)->
    false
  
  emit_codegen  : (root, ctx)->
    false
  
  emit_min_deps : (root, ctx, cb)->
    cb null, false

def "browser_ext_content_script browser_ext_widget", (name, page_name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "browser_ext_widget", name, "def"
  bdh_node_module_name_assign_on_call root, module, "browser_ext_widget"
  
  root.policy_set_here_weak "trigger_on_button",  false
  root.policy_set_here_weak "trigger_on_hotkey",  false
  
  if name
    root.policy_set_here_weak "hotkey_action_name",        "open widget #{name}"
    root.policy_set_here_weak "hotkey_action_description", "Open widget #{name}"
  else
    root.policy_set_here_weak "hotkey_action_name",        "open widget"
    root.policy_set_here_weak "hotkey_action_description", "Open widget"
  
  root.data_hash.size_x    ?= 630
  root.data_hash.size_y    ?= 630
  root.data_hash.overlay_on_click_close ?= true
  root.data_hash.page_name ?= page_name
  
  cs_node = root.type_filter_search "browser_ext_content_script"
  cs_node.data_hash.widget_list.upush root
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
def "browser_ext_button_action_weak", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root
  
  ext_node    = root.type_filter_search "browser_ext"
  project_node= root.type_filter_search "project"
  app_name = ext_node.name or project_node.name
  
  browser_ext_manifest_weak {
    action : {
      # TODO fixme with policy on browser_ext
      default_title : app_name
      default_popup : ""
    }
  }
  
  return

# ###################################################################################################
#    browser_ext_background
# ###################################################################################################
bdh_module_name_root module, "browser_ext_background",
  nodegen       : (root, ctx)->
    browser_ext_manifest {
      background: {
        service_worker: "background/index.js"
      }
    }
    false
  
  validator     : (root, ctx)->
    false
  
  emit_codebub  : (root, ctx)->
    ext_node = root.type_filter_search "browser_ext"
    be_name = "browser_ext"
    if ext_node.name
      be_name = "browser_ext_#{ext_node.name}"
    
    name = "#{be_name}/zz_background_script.coffee"
    root.data_hash.codebub_background_script = ctx.file_render name, ""
    false
  
  emit_codegen  : (root, ctx)->
    ext_node = root.type_filter_search "browser_ext"
    {
      dev_folder
      build_folder
      build_import_list
      content_script_list
    } = ext_node.data_hash
    
    file_list = [
      "generic/1_fix_window.js"
      "generic/generic.js"
      "generic/event_mixin.js"
      "generic/websocket.js"
      "generic/ws_request_service.js"
      "1_init_and_modules/promise_cb.js"
      "1_init_and_modules/1_iced_runtime.js"
    ]
    for v in file_list
      ctx.file_render "#{dev_folder   }/#{v}", ctx.tpl_read "browser_ext/#{v}"
      ctx.file_render "#{build_folder }/#{v}", ctx.tpl_read "browser_ext/#{v}"
    
    jl = []
    for file in file_list
      jl.push """
        importScripts(#{JSON.stringify "../"+file});
      """#"
    for file in build_import_list
      jl.push """
        importScripts(#{JSON.stringify file});
      """
    
    background_index_cont = """
      #{join_list jl, ""}
      importScripts("zz_background_script.js"); 
      """#"
    
    ctx.file_render "#{dev_folder   }/background/index.js", background_index_cont
    ctx.file_render "#{build_folder }/background/index.js", background_index_cont
    
    
    
    # ###################################################################################################
    #    zz_background_script.js
    # ###################################################################################################
    background_aux_jl = []
    
    # TODO ws connect in background_aux_jl
    
    need_message_bus= false
    on_command_jl   = []
    message_bus_jl  = []
    
    background_aux_jl.append root.data_hash.code_jl
      
    if root.data_hash.event_list.length
      need_message_bus = true
      for event in root.data_hash.event_list
        background_aux_jl.push event.data_hash.codebub
        
        message_bus_jl.push """
          when "event_#{event.name}"
            cb = (err, res)->
              perr err if err
              # FIXME
              # sendResponse не будет работать если внутри обработчика event будет хоть какой-то асинхронный вызов
              # нужно посылать сообщение
              # res ?= {}
              # res.switch  = "event_#{event.name}"
              # res.response= "background_script"
              # if err
              #   res.err = err
              # sendResponse res
            
            await chrome.tabs.query {active: true, currentWindow: true}, defer(tabs)
            request.tab = tabs[0]
            event_#{event.name} request, cb
          
          """#"
    
    # TODO
    # be.hotkey_list
    # ->
    # on_command_jl
    
    for cs in content_script_list
      for command in cs.data_hash.command_list
        background_aux_jl.push command.data_hash.bg_codebub
        
        command_prefix = "command"
        if command.name
          command_prefix = "command_#{command.name}"
        
        trigger_on_button = command.policy_get_val_use "trigger_on_button"
        trigger_on_hotkey = command.policy_get_val_use "trigger_on_hotkey"
        if trigger_on_hotkey and !trigger_on_button
          on_command_jl.push """
            when "#{command.name}"
              await chrome.tabs.query {active: true, currentWindow: true}, defer(tabs)
              tab = tabs[0]
              #{command_prefix} tab
            """#"
        
        if trigger_on_button
          need_message_bus = true
          background_aux_jl.push """
            chrome.action.onClicked.addListener (tab)->
              #{command_prefix} tab
            
            """
          message_bus_jl.push """
            when "button_open"
              sendResponse
                "switch"  : "button_open"
                "response": "background_script"
              
              await chrome.tabs.query {active: true, currentWindow: true}, defer(tabs)
              tab = tabs[0]
              #{command_prefix} tab
            """#"
      
      # TODO all should work mostly with command_list
      for widget in cs.data_hash.widget_list
        trigger_on_button = widget.policy_get_val_use "trigger_on_button"
        trigger_on_hotkey = widget.policy_get_val_use "trigger_on_hotkey"
        if trigger_on_button or trigger_on_hotkey
          widget_prefix = "widget"
          if widget.name
            widget_prefix = "widget_#{widget.name}"
          
          background_aux_jl.push """
            #{widget_prefix}_toggle = (tab)->
              loc_opt = {
                switch : "#{widget_prefix}_toggle"
              }
              await chrome.tabs.sendMessage tab.id, loc_opt, {}, defer(response)
              if !response
                console.error "tab (content_script) response undefined"
                return
              
            """#"
        
        
        if trigger_on_hotkey and !trigger_on_button
          on_command_jl.push """
            when "#{widget.data_hash.action_name}"
              await chrome.tabs.query {active: true, currentWindow: true}, defer(tabs)
              tab = tabs[0]
              loc_opt = {
                switch: "#{widget_prefix}_toggle"
              }
              await chrome.tabs.sendMessage tab.id, loc_opt, {}, defer(response)
              if !response
                console.error "tab (content_script) response undefined"
                return
              
            """#"
        
        if trigger_on_button
          need_message_bus = true
          background_aux_jl.push """
            chrome.action.onClicked.addListener (tab)->
              #{widget_prefix}_toggle tab
            
            """
          message_bus_jl.push """
            when "button_open"
              sendResponse
                "switch"  : "button_open"
                "response": "background_script"
              
              await chrome.tabs.query {active: true, currentWindow: true}, defer(tabs)
              tab = tabs[0]
              #{widget_prefix}_toggle tab
            """#"
    
    if need_message_bus
      background_aux_jl.push """
        chrome.runtime.onMessage.addListener (request, sender, sendResponse)->
          return if !request?.switch
          switch request.switch
            when "runtime_ping"
              sendResponse
                "switch"  : "runtime_ping"
                "response": "background_script"
            
            #{join_list message_bus_jl, "    "}
            # TODO messages from content_script
      """#"
    
    if on_command_jl.length
      background_aux_jl.push """
        chrome.commands.onCommand.addListener (command)->
          switch command
            #{join_list on_command_jl, "    "}
      """#"
    
    zz_background_script_cont = iced_compile """
      window.chrome ?= window.browser
      #{join_list background_aux_jl, ""}
      
      #{root.data_hash.codebub_background_script}
      """
    
    ctx.file_render "#{dev_folder   }/background/zz_background_script.js", zz_background_script_cont
    ctx.file_render "#{build_folder }/background/zz_background_script.js", zz_background_script_cont
    
    
    false
  
  emit_min_deps : (root, ctx, cb)->
    cb null, false

def "browser_ext browser_ext_background", (scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "browser_ext_background", "browser_ext_background", "def"
  bdh_node_module_name_assign_on_call root, module, "browser_ext_background"
  
  root.data_hash.event_list ?= []
  root.data_hash.code_jl ?= []
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    browser_ext_page
# ###################################################################################################
bdh_module_name_root module, "browser_ext_page",
  nodegen       : (root, ctx)->
    page_name = "page_#{root.name}"
    
    browser_ext_manifest {
      sandbox :
        pages : ["#{page_name}/#{page_name}.html"]
    }
    false
  
  validator     : (root, ctx)->
    false
  
  emit_codebub  : (root, ctx)->
    false
  
  emit_codegen  : (root, ctx)->
    ext_node = root.type_filter_search "browser_ext"
    {
      app_name
      dev_folder
      build_folder
    } = ext_node.data_hash
    
    page_name = "page_#{root.name}"
    
    # TODO policy
    title = "#{app_name}"
    if root.name
      title = "#{app_name} - #{root.name}"
    
    script_jl = []
    
    script_path_list = [
      "../generic/generic.js"
      "../generic/event_mixin.js"
      "../1_init_and_modules/promise_cb.js"
      "../1_init_and_modules/1_iced_runtime.js"
    ]
    if root.data_hash.is_widget_sandboxed
      script_path_list.push "../page_wrap_inner.js"
    
    # TODO all other scripts from directory
    for script_path in script_path_list
      script_jl.push """
        <script src=#{JSON.stringify script_path}></script>
        """
    
    ctx.file_render "#{dev_folder}/#{page_name}/#{page_name}.html", """
      <!doctype html>
      <html>
        <head>
          <title>#{title}</title>
        </head>
        <body>
          <div id="mount_point"></div>
          #{join_list script_jl, "    "}
        </body>
      </html>
      """#"
    
    ctx.file_render "#{build_folder}/#{page_name}/#{page_name}.html", """
      <!doctype html>
      <html>
        <head>
          <title>#{title}</title>
        </head>
        <body>
          <div id="mount_point"></div>
          #{join_list script_jl, "    "}
        </body>
      </html>
      """#"
    false
  
  emit_min_deps : (root, ctx, cb)->
    cb null, false

def "browser_ext_page", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "browser_ext_page", name, "def"
  bdh_node_module_name_assign_on_call root, module, "browser_ext_page"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    browser_ext_command
# ###################################################################################################
bdh_module_name_root module, "browser_ext_command",
  nodegen       : (root, ctx)->
    trigger_on_hotkey = root.policy_get_val_use "trigger_on_hotkey"
    trigger_on_button = root.policy_get_val_use "trigger_on_button"
    hk_action_name= root.policy_get_val_use "hotkey_action_name"
    hk_action_desc= root.policy_get_val_use "hotkey_action_description"
    
    hk_obj = {}
    if trigger_on_hotkey
      hk_default    = root.policy_get_val_use "hotkey"
      commands = {}
      hk_obj = {
        suggested_key : {
          default: hk_default
        }
        description : hk_action_desc
      }
      for os_name in ["mac", "windows", "chromeos", "linux"]
        if value = root.policy_get_val_use_default "hotkey_#{os_name}", ""
          hk_obj.suggested_key[os_name] = value
    
    if trigger_on_button
      root.data_hash.button_action = true
      browser_ext_button_action_weak()
      # WARNING nodegen browser_ext_manifest
      browser_ext_manifest {
        commands :
          "_execute_action" : hk_obj
      }
      browser_ext_manifest {
        commands
      }
    else if trigger_on_hotkey
      root.data_hash.button_action = false
      root.data_hash.action_name = hk_action_name
      commands[hk_action_name] = hk_obj
      browser_ext_manifest {
        commands
      }
    
    false
  
  validator     : (root, ctx)->
    false
  
  emit_codebub  : (root, ctx)->
    ext_node = root.type_filter_search "browser_ext"
    be_name = "browser_ext"
    if ext_node.name
      be_name = "browser_ext_#{ext_node.name}"
    
    
    command_prefix = "command"
    if root.name
      command_prefix = "command_#{root.name}"
    
    name = "#{be_name}/command_#{root.name}_bg.coffee"
    root.data_hash.bg_codebub = ctx.file_render name, """
      #{command_prefix} = (tab)->
        # you can modify background code
        loc_opt = {
          switch : "#{command_prefix}"
        }
        await chrome.tabs.sendMessage tab.id, loc_opt, {}, defer(response)
        if !response
          console.error "tab (content_script) response undefined"
          return
      
      """#"
    
    name = "#{be_name}/command_#{root.name}_cs.coffee"
    root.data_hash.cs_codebub = ctx.file_render name, """
      #{command_prefix} = ()->
        # put your content script code here
      """
    
    false
  
  emit_codegen  : (root, ctx)->
    false
  
  emit_min_deps : (root, ctx, cb)->
    cb null, false

def "browser_ext_content_script browser_ext_command", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "browser_ext_command", name, "def"
  bdh_node_module_name_assign_on_call root, module, "browser_ext_command"
  
  root.policy_set_here_weak "trigger_on_button",  false
  root.policy_set_here_weak "trigger_on_hotkey",  false
  
  root.policy_set_here_weak "hotkey_action_name",        name ? "Command"
  root.policy_set_here_weak "hotkey_action_description", ""
  
  cs_node = root.type_filter_search "browser_ext_content_script"
  cs_node.data_hash.command_list.upush root
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    browser_ext_background_event
# ###################################################################################################
bdh_module_name_root module, "browser_ext_background_event",
  emit_codebub  : (root, ctx)->
    ext_node = root.type_filter_search "browser_ext"
    be_name = "browser_ext"
    if ext_node.name
      be_name = "browser_ext_#{ext_node.name}"
    
    name = "#{be_name}/event_#{root.name}.coffee"
    root.data_hash.codebub = ctx.file_render name, """
      event_#{root.name} = (req, cb)->
        # put your code here
        console.log req
        cb()
      
      """
    
    false

def "browser_ext_background browser_ext_background_event", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "browser_ext_background_event", name, "def"
  bdh_node_module_name_assign_on_call root, module, "browser_ext_background_event"
  
  root.parent.data_hash.event_list.push root
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    browser_ext_backend_connect
# ###################################################################################################
bdh_module_name_root module, "browser_ext_backend_connect",
  nodegen       : (root, ctx)->
    project_node    = mod_runner.current_runner.curr_root.type_filter_search "project"
    backend_node    = project_node.tr_get_try "backend", root.data_hash.backend_name
    browser_ext_node= project_node.tr_get_try "browser_ext", root.data_hash.browser_ext_name
    background_node = browser_ext_node.tr_get_try "browser_ext_background", "browser_ext_background"
    
    ws_port = backend_node.policy_get_val_use "ws_port"
    # костыли. Неплохо бы функцию для получения порта, а не вот это вот в каждом
    port_increment = mod_runner.current_runner.root.data_hash.get_autoport_offset("backend", backend_node)
    ws_port += port_increment if backend_node.policy_get_here_is_weak "ws_port"
    
    
    src_name_opt = ""
    ws_back_url = "ws_back_url#{src_name_opt}"
    ws_back     = "ws_back#{src_name_opt}"
    wsrs_back   = "wsrs_back#{src_name_opt}"
    
    host = root.policy_get_val_use "host"
    # TODO wss
    background_node.data_hash.code_jl.upush """
      #{ws_back_url} = "ws://#{host}:#{ws_port}"
      window.#{ws_back}  = new Websocket_wrap #{ws_back_url}
      window.#{wsrs_back}= new Ws_request_service #{ws_back}
      
      """#"
    # TODO LATER
    # #{aux_ws_mod_pubsub}
    
    false

def "browser_ext_backend_connect", (name_opt = {}, scope_fn=()->)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  project_node = mod_runner.current_runner.curr_root.type_filter_search "project"
  
  name_opt.backend  ?= ""
  name_opt.browser_ext ?= ""
  
  # NOTE browser_ext, backend могут быть еще не определены
  if !backend_node = project_node.tr_get_try "backend", name_opt.backend
    throw new Error "backend name=#{name_opt.backend} not found"
  
  if !browser_ext_node = project_node.tr_get_try "browser_ext", name_opt.browser_ext
    throw new Error "browser_ext name=#{name_opt.browser_ext} not found"
  
  
  key = "#{name_opt.backend}_#{name_opt.browser_ext}"
  root = mod_runner.current_runner.curr_root.tr_get "browser_ext_backend_connect", key, "def"
  bdh_node_module_name_assign_on_call root, module, "browser_ext_backend_connect"
  
  root.data_hash.browser_ext_name ?= name_opt.browser_ext
  root.data_hash.backend_name     ?= name_opt.backend
  
  root.policy_set_here_weak "host", "localhost"
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root  