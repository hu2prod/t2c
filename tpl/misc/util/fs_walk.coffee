require "fy"
fs = require "fs"
mod_path = require "path"
@walk_sync = (opt)->
  {
    dir
    dir_fn
    file_fn
  } = opt
  max_depth = opt.max_depth ? Infinity
  symlink   = opt.symlink   ? true
  natsort   = opt.natsort   ? true
  walk = (dir, depth)->
    depth++
    
    file_list = fs.readdirSync dir
    file_list.natsort() if natsort
    for file in file_list
      full_file = mod_path.join dir, file
      stat = fs.lstatSync full_file
      continue if !symlink and stat.isSymbolicLink()
      if stat.isDirectory()
        dir_fn? full_file, file
        if depth < max_depth
          walk full_file, depth
      else
        file_fn? full_file, file
  
  walk dir, 0

@walk = (opt, cb)->
  {
    dir
    dir_fn
    file_fn
  } = opt
  max_depth = opt.max_depth ? Infinity
  symlink   = opt.symlink   ? true
  natsort   = opt.natsort   ? true
  walk = (dir, depth, cb)->
    depth++
    
    await fs.readdir dir, defer(err, file_list); return cb err if err
    file_list.natsort() if natsort
    for file in file_list
      full_file = mod_path.join dir, file
      await fs.lstat full_file, defer(err, stat); return cb err if err
      continue if !symlink and stat.isSymbolicLink()
      if stat.isDirectory()
        if dir_fn
          await dir_fn full_file, file, defer(err); return cb err if err
        if depth < max_depth
          await walk full_file, depth, defer(err); return cb err if err
      else
        if file_fn
          await file_fn full_file, file, defer(err); return cb err if err
    cb()
  
  walk dir, 0, cb
  