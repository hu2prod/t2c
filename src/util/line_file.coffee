fs = require "fs"
@push = (file, text_add)->
  if !fs.existsSync file
    fs.writeFileSync file, text_add+"\n"
    return
  
  cont = fs.readFileSync file, "utf-8"
  line_list = cont.split "\n"
  line_add_list = text_add.split "\n"
  line_hash = {}
  for v in line_list
    line_hash[v] = true
  
  filter_add_line_list = []
  for line in line_add_list
    continue if line_hash[line]
    filter_add_line_list.push line
  
  cont += "\n" if !cont.endsWith "\n"
  for line_add in filter_add_line_list
    cont += line_add + "\n"
  
  fs.writeFileSync file, cont

# @push_check = (file, text_add, text_check)->
#   if !fs.existsSync file
#     fs.writeFileSync file, text_add+"\n"
#     return
#   
#   cont = fs.readFileSync file, "utf-8"
#   line_list = cont.split "\n"
#   line_add_list = text_add.split "\n"
#   line_hash = {}
#   for v in line_list
#     if v.includes text_check
#       return
#     line_hash[v] = true
#   
#   filter_add_line_list = []
#   for line in line_add_list
#     continue if line_hash[line]
#     filter_add_line_list.push line
#   
#   cont += "\n" if !cont.endsWith "\n"
#   for line_add in filter_add_line_list
#     cont += line_add + "\n"
#   
#   fs.writeFileSync file, cont
