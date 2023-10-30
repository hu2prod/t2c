project "cw_ext", ()->
  # cat ../*/gen/zz_main.coffee | grep service_port_offset | grep -v cat | sort -V
  policy_set "service_port_offset", 0 # replace with other number <1000 for non-conflicting services
  policy_set "package_manager", "snpm"
  npm_i "fy"
  
  browser_ext "", ()->
    browser_ext_background ()->
      browser_ext_background_event "capture_success"
    
    browser_ext_page "my_page", ()->
    browser_ext_content_script null, null, ()->
      browser_ext_widget "", "my_page", ()->
        policy_set "trigger_on_button", true
        policy_set "trigger_on_hotkey", true
        policy_set "hotkey_action_name",         "capture_widget"
        policy_set "hotkey_action_description",  "Capture widget"
        policy_set "hotkey",                     "Ctrl+Shift+F"
      
      browser_ext_command "capture", ()->
        policy_set "trigger_on_button", true
        policy_set "trigger_on_hotkey", true
        policy_set "hotkey_action_name",         "capture"
        policy_set "hotkey_action_description",  "Capture"
        policy_set "hotkey",                     "Ctrl+Shift+S"
  
  backend "", ()->
    policy_set "ws", true
    
    fn "capture", ()->
  
  browser_ext_backend_connect {}, ()->
    policy_set "host", "192.168.88.56"
  
  task_tracker()
  
  starter_tmux "full", "dev", ()->
    starter_tmux_split_h ()->
      starter_tmux_split_v ()->
        # TODO make browser_ext
        # starter_tmux_service "frontend "
        starter_tmux_service "backend "
