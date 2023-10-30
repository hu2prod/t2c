project "template", ()->
  policy_set "package_manager", "snpm"
  npm_i "fy"
  
  db "", ()->
    db_migration "", ()->
      # project_progress_db_create_inject()
      struct "point", ()->
        field "title", "str"
        field "x", "i64"
        field "y", "i64"
    
    db_backup()
  
  backend "", ()->
    policy_set "ws", true
    fn "ep", ()->
    # endpoint_pubsub "ep_pubsub", ()->
  
  
  
  
  # backend_frontend_connect()
  db_backend_struct "point"
  # db_backend_frontend_struct "point"
  
  # project_progress {}, ()->
  #   project_progress_table_row_count "point"
  
  starter_tmux "full", "dev", ()->
    starter_tmux_split_h ()->
      starter_tmux_split_v ()->
        # starter_tmux_service "frontend "
        starter_tmux_service "backend "
