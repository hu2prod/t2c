require "fy"
fs = require "fs"
walk = (root)->
  ent_list = fs.readdirSync root
  ent_list.natsort()
  
  file_list = []
  for ent in ent_list
    # TODO os portable
    full_path = "#{root}/#{ent}"
    if fs.lstatSync(full_path).isDirectory()
      walk full_path
      continue
    
    file_list.push full_path
  
  for full_path in file_list
    require full_path
  
  return

walk "#{__dirname}/block"