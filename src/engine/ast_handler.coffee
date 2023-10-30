fs = require "fs"
mkdirp = require "mkdirp"

# ###################################################################################################
#    common parts for context
# ###################################################################################################
folder_mixin = (athis)->
  athis.prototype.curr_folder = "."
  athis.prototype.folder_stack_list = []
  
  athis.prototype.folder_push = (nest_path)->
    @folder_stack_list.push @curr_folder
    @curr_folder += "/#{nest_path}"
    return
  
  athis.prototype.folder_pop = ()->
    if @folder_stack_list.length == 0
      throw new Error "bad folder_pop. @folder_stack_list.length == 0"
    
    @curr_folder = @folder_stack_list.pop()
    return
  
  athis.prototype.folder_wrap = (nest_path, cb)->
    @folder_push nest_path
    cb()
    @folder_pop()
    return
  
  
  athis.prototype.folder_render = (rel_path)->
    # TODO os separator
    path = @curr_folder + "/" + rel_path
    mkdirp.sync path
  
  athis.prototype.exists = (rel_path)->
    path = @curr_folder + "/" + rel_path
    fs.existsSync path
  
  athis.prototype.file_render = (file, cont)->
    encoding = null
    encoding = "utf-8" if typeof cont == "string"
    # TODO os separator
    path = @curr_folder + "/" + file
    check_path = "override/" + file
    if fs.existsSync check_path
      puts "OVERRIDE", path
      cont = fs.readFileSync check_path, encoding
    
    # ###################################################################################################
    #    missing parent folder create
    # ###################################################################################################
    part_list = path.split "/"
    part_list.pop()
    folder = part_list.join "/"
    if !fs.existsSync folder
      mkdirp.sync folder
    
    # ###################################################################################################
    #    replace file only if content doesn't match
    # ###################################################################################################
    if fs.existsSync path
      cmp_cont = fs.readFileSync path, encoding
      if encoding
        need_write = cont != cmp_cont
      else
        need_write = !cont.equals cmp_cont
      
      if need_write
        p "need write #{path}"
    else
      need_write = true
    
    if need_write
      fs.writeFileSync path, cont
    
    path
  
  athis.prototype.copy = (dst, src)->
    if !fs.lstatSync(src).isDirectory()
      # @file_render dst, fs.readFileSync src, "utf-8"
      @file_render dst, fs.readFileSync src
      return
    
    file_list = fs.readdirSync src
    file_list.sort()
    for file in file_list
      @folder_render dst
      new_src = src+"/"+file
      new_dst = dst+"/"+file
      @copy new_dst, new_src
    
    return
  
  athis.prototype.file_render_ne = (file, cont)->
    # TODO os separator
    path = @curr_folder + "/" + file
    check_path = "override/" + file
    if fs.existsSync check_path
      puts "OVERRIDE", path
      cont = fs.readFileSync check_path, "utf-8"
    
    # ###################################################################################################
    #    missing parent folder create
    # ###################################################################################################
    part_list = path.split "/"
    part_list.pop()
    folder = part_list.join "/"
    if !fs.existsSync folder
      mkdirp.sync folder
    
    # ###################################################################################################
    if !fs.existsSync path
      fs.writeFileSync path, cont
    
    path
  
  athis.prototype.file_render_exec = (file, cont)->
    path = @file_render file, cont
    fs.chmodSync path, 0o744
    path
  
  athis.prototype.file_render_exec_ne = (file, cont)->
    path = @file_render_ne file, cont
    if fs.existsSync path
      fs.chmodSync path, 0o744
    path
  
  athis.prototype.tpl_read = (path)->
    fs.readFileSync __dirname+"/../../tpl/"+path, "utf-8"
  
  athis.prototype.tpl_copy = (file, src_dir, dst_dir)->
    dst_file = "#{dst_dir}/#{file}"
    
    part_list = dst_file.split "/"
    part_list.pop()
    folder = part_list.join "/"
    if !fs.existsSync folder
      mkdirp.sync folder
    
    if !fs.existsSync dst_file
      puts "copy #{file}"
      fs.copyFileSync __dirname+"/../../tpl/#{src_dir}/"+file, dst_file
    return
  
  athis.prototype.file_delete = (file, cont)->
    path = @curr_folder + "/" + file
    if fs.existsSync path
      fs.unlinkSync path
    return
  

folder_mixin_constructor = (athis)->
  athis.folder_stack_list = []

# ###################################################################################################
#    Phase context
# ###################################################################################################
class @Phase_context_nodegen
  hydrator_fn : null
  walk_fn : null
  walk_child_list_only_fn : null
  folder_mixin @
  constructor:()->
    folder_mixin_constructor @

class @Phase_context_validator
  walk_fn : null
  folder_mixin @
  constructor:()->
    folder_mixin_constructor @
  

class @Phase_context_emit_code_bubble
  walk_fn : null
  walk_child_list_only_fn : null
  folder_mixin @
  constructor:()->
    folder_mixin_constructor @
  
  # overwrite
  file_render : (file, cont)->
    path = @curr_folder + "/" + file
    if fs.existsSync path
      return fs.readFileSync path, "utf-8"
    
    # ###################################################################################################
    #    missing parent folder create
    # ###################################################################################################
    part_list = path.split "/"
    part_list.pop()
    folder = part_list.join "/"
    if !fs.existsSync folder
      mkdirp.sync folder
    
    # ###################################################################################################
    fs.writeFileSync path, cont
    
    cont

class @Phase_context_emit_codegen
  walk_fn : null
  walk_child_list_only_fn : null
  folder_mixin @
  constructor:()->
    folder_mixin_constructor @
  

class @Phase_context_emit_min_deps
  # walk_fn : null
  walk_child_list_only_fn : null
  folder_mixin @
  constructor:()->
    folder_mixin_constructor @
