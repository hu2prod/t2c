fs = require "fs"
mod_file  = require "../util/file"
exec      = require "../util/exec"
gitignore = require "../util/gitignore"

module.exports = (opt, cb)->
  project_name  = process.cwd().split("/").last()
  
  puts "NOTE if you want to publish this and don't want to generator stuff go to public then run"
  puts "  echo '.' >> gen/.gitignore"
  # Прим. именно так т.к. иначе факт игнорирования папки уйдет в публику
  # TODO сделать отдельный блок под это
  
  if !fs.existsSync ".git"
    exec "git init"
  
  mod_file.push_ne "gen/zz_main.coffee", """
    project #{JSON.stringify project_name}, ()->
      policy_set "package_manager", "snpm"
      npm_i "fy"
    
    """#"
  
  cb()
