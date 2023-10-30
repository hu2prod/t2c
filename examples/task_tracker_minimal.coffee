project "template", ()->
  # cat ../*/gen/zz_main.coffee | grep service_port_offset | grep -v cat | sort -V
  policy_set "service_port_offset", 0 # replace with other number <1000 for non-conflicting services
  policy_set "package_manager", "snpm"
  npm_i "fy"
  
  db "", ()->
    db_migration "", ()->
      task_tracker_db_create_inject()
  
  backend "", ()->
    policy_set "ws", true
  
  frontend "", ()->
    router ()->
      router_endpoint "", "Page_dashboard", "Dashboard"
  
  task_tracker()
  
  # starter_tmux "full", "dev", ()->
  #   starter_tmux_split_h ()->
  #     starter_tmux_split_v ()->
  #       starter_tmux_service "frontend "
  #       starter_tmux_service "backend "
