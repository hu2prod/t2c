module = @
require "fy/codegen"
fs = require "fs"
mkdirp = require "mkdirp"

# ###################################################################################################
#    basic
# ###################################################################################################
# @mkdirp = (path)->
#   mkdirp.sync path
# 
# @push = (file, cont_add)->
#   part_list = file.split "/"
#   part_list.pop()
#   if part_list.length
#     mkdirp.sync part_list.join "/"
#   
#   if !fs.existsSync file
#     fs.writeFileSync file, cont_add
#     return true
#   
#   cont = fs.readFileSync file, "utf-8"
#   
#   if cont != cont_add
#     perr "old", cont
#     perr "new", cont_add
#     perr "old", cont.length
#     perr "new", cont_add.length
#     throw new Error "file '#{file}' push failed. content mismatch"
#   
#   # fs.writeFileSync file, cont_add
#   return false
# 
# @push_exec = (file, cont_add)->
#   module.push file, cont_add
#   fs.chmodSync file, 0o744

# if not exists
@push_ne = (file, cont_add)->
  part_list = file.split "/"
  part_list.pop()
  if part_list.length
    mkdirp.sync part_list.join "/"
  
  if !fs.existsSync file
    puts "create #{file}"
    fs.writeFileSync file, cont_add
    return true
  
  return false

# @push_ne_exec = (file, cont_add)->
#   module.push_ne file, cont_add
#   fs.chmodSync file, 0o744
# 
# @push_exec_ne = @push_ne_exec

# ###################################################################################################
#    tpl
# ###################################################################################################
@tpl_read = (file)->
  fs.readFileSync __dirname+"/../../tpl/"+file, "utf-8"

# @tpl_read_bin = (file)->
  # fs.readFileSync __dirname+"/../../tpl/"+file

# @tpl_copy = (file, src_dir, dst_dir)->
  # src_file = __dirname+"/../../tpl/#{src_dir}/"+file
  # dst_file = "#{dst_dir}/#{file}"
  # fs.copyFileSync src_file, dst_file
  # return
