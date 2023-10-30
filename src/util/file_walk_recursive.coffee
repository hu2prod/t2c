fs = require "fs"

module.exports = (root_folder)->
  ordered_file_list = []
  walk = (root_folder)->
    ent_list = fs.readdirSync root_folder
    ent_list.natsort()
    
    dir_list  = []
    for ent in ent_list
      full_path = "#{root_folder}/#{ent}"
      if fs.lstatSync(full_path).isDirectory()
        dir_list.push full_path
      else
        ordered_file_list.push full_path
    for dir in dir_list
      walk dir
    
    return
  
  walk root_folder
  
  ordered_file_list
