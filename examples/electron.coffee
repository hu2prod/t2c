project "template", ()->
  # cat ../*/gen/zz_main.coffee | grep service_port_offset | grep -v cat | sort -V
  policy_set "service_port_offset", 0 # replace with other number <1000 for non-conflicting services
  # WARNING snpm is not supported
  policy_set "package_manager", "pnpm"
  npm_i "fy"
  
  # ###################################################################################################
  #    
  #    backend
  #    
  # ###################################################################################################
  backend "", ()->
    policy_set "ws", true
    node = fn "dev_tools_open", ()->
    node.data_hash.codebub = """
      global_ctx?.main_window.webContents.openDevTools()
      cb null, {ok:true}
      """
    # fn "ep", ()->
  
  # ###################################################################################################
  #    
  #    frontend
  #    
  # ###################################################################################################
  # WARNING electron compat.
  #   Front-end should not use absolute links to assets (e.g. /asset/img.png)
  #   Front-end should not use http endpoints (not implemented)
  frontend "", ()->
    # frontend_mod_iced()
    # frontend_com "some_db"
    # frontend_com "some"
    # frontend_com_storybook "button"
    
    file_render "htdocs/dev_tools_handler.coffee", """
      document.addEventListener "keydown", (e)=>
        if e.which == Keymap.F12
          loc_opt = {
            switch : "dev_tools_open"
          }
          await wsrs_back.request loc_opt, defer(err); throw err if err
      """
    router ()->
      router_endpoint "", "Page_dashboard", "Dashboard"
  
  # ###################################################################################################
  #    
  #    link
  #    
  # ###################################################################################################
  backend_frontend_connect()
  
  # ###################################################################################################
  #    
  #    electron
  #    
  # ###################################################################################################
  # WARNING. Should be strictly after frontend and backend
  electron "", ()->
    # policy_set "maximize", true
    policy_set "dev_tools", true
    electron_frontend "", ()->
    electron_backend "", ()->
    # why wrappers are mandatory for dev?
    # because you want to add .desktop to specific binary, not to node_modules internal stuff
    electron_wrapper()
  
  starter_tmux "full", "dev", ()->
    starter_tmux_split_h ()->
      starter_tmux_split_v ()->
        starter_tmux_custom ""
      starter_tmux_split_v ()->
        starter_tmux_service "frontend "
        starter_tmux_service "backend "
