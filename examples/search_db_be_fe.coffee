project "template", ()->
  # cat ../*/gen/zz_main.coffee | grep service_port_offset | grep -v cat | sort -V
  policy_set "service_port_offset", 0 # replace with other number <1000 for non-conflicting services
  policy_set "package_manager", "snpm"
  npm_i "fy"
  
  db "", ()->
    db_migration "", ()->
      # project_progress_db_create_inject()
      # task_tracker_db_create_inject()
      struct "point", ()->
        field "title", "str"
        field "x", "i64"
        field "y", "i64"
    
    db_backup()
  
  backend "", ()->
    policy_set "ws", true
    fn "ep", ()->
    # endpoint_pubsub "ep_pubsub", ()->
  
  # TODO recheck
  search "", ()->
    search_db_index "point", "title"
  
  frontend "", ()->
    frontend_mod_bind2()
    frontend_mod_iced()
    frontend_com_storybook "button"
    front_com_rich_list_db "point", ()->
      # policy_set "save_on_create", false
    
    router ()->
      router_endpoint "", "Page_dashboard", "Dashboard"
      # router_endpoint "route", "Page_some_name", "Title"
      # router_endpoint "route_<name>", "Page_some_name", "Title"
      front_com_rich_list_db_router "point"
    
  
  # backend_frontend_connect()
  # db_backend_struct "point"
  # db_backend_frontend_struct "point"
  search_db_backend_frontend_struct "point"
  
  # project_progress {}, ()->
  #   project_progress_table_row_count "point"
  
  # task_tracker()
  
  starter_tmux "full", "dev", ()->
    starter_tmux_split_h ()->
      starter_tmux_split_v ()->
        starter_tmux_custom ""
        starter_tmux_service "search "
      starter_tmux_split_v ()->
        starter_tmux_service "frontend "
        starter_tmux_service "backend "
