project "template", ()->
  # cat ../*/gen/zz_main.coffee | grep service_port_offset | grep -v cat | sort -V
  policy_set "service_port_offset", 0 # replace with other number <1000 for non-conflicting services
  policy_set "package_manager", "snpm"
  npm_i "fy"
  
  # ###################################################################################################
  #    
  #    db
  #    
  # ###################################################################################################
  db "", ()->
    db_migration "", ()->
      project_progress_db_create_inject()
      task_tracker_db_create_inject()
    
    db_migration "", ()->
      struct "point", ()->
        field "title", "str"
        field "note", "text"
        field "x", "i64"
        field "y", "i64"
        # field "type", "dyn_enum_some_type"
    
    db_backup()
  
  # ###################################################################################################
  #    
  #    backend
  #    
  # ###################################################################################################
  backend "", ()->
    policy_set "ws", true
    # fn "ep", ()->
  
  # ###################################################################################################
  #    
  #    frontend
  #    
  # ###################################################################################################
  frontend "", ()->
    # frontend_com "some_db"
    # frontend_com "some"
    
    front_com_rich_list_db "point", ()->
      # policy_set "save_on_create", false
    
    router ()->
      router_endpoint "", "Page_dashboard", "Dashboard"
      front_com_rich_list_db_router "point"
  
  # ###################################################################################################
  #    
  #    link
  #    
  # ###################################################################################################
  # backend_frontend_connect()
  db_backend_frontend_struct "point"
  # db_backend_frontend_struct "dyn_enum_some_type"
  
  project_progress {}, ()->
    project_progress_table_row_count "point"
  
  task_tracker()
  
  starter_tmux "full", "dev", ()->
    starter_tmux_split_h ()->
      starter_tmux_split_v ()->
        starter_tmux_custom ""
      starter_tmux_split_v ()->
        starter_tmux_service "frontend "
        starter_tmux_service "backend "
