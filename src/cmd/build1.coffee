mod_task = require "../util/task"

module.exports = (opt, cb)->
  loc_opt = {
    root_folder       : process.cwd()
    # verbose_phase_name: true
    verbose_bench     : true
  }
  await mod_task.task_build1 loc_opt, defer(err); return cb err if err
  
  cb()
