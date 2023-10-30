mod_task= require "../util/task"
watch_wrap = require "./_watch_wrap"

module.exports = (opt, drop_cb)->
  dir_list = ["gen", "code_bubble", "override"]
  run = (cb)->
    loc_opt = {
      root_folder       : process.cwd()
      # verbose_phase_name: true
      verbose_bench     : true
    }
    await mod_task.task_build1 loc_opt, defer(err);
    perr err if err
    cb()
  
  watch_wrap dir_list, run
  return
