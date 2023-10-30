module = @
fs = require "fs"
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
  mod_config
} = require "../common_import"

tpl_mirror = (ctx, file)->
  if !mod_config.local_config.story_book_path
    throw new Error "local_config.story_book_path is not configured"
  ctx.file_render "htdocs/#{file}", fs.readFileSync mod_config.local_config.story_book_path+"/htdocs/#{file}", "utf-8"

# ###################################################################################################
#    frontend_mod_bind2
# ###################################################################################################
bdh_module_name_root module, "frontend_mod_bind2",
  emit_codegen  : (root, ctx)->
    tpl_mirror ctx, "1_init_and_modules/bind2.coffee"
    false

def "frontend_mod_bind2", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "frontend_mod_bind2", "frontend_mod_bind2", "def"
  bdh_node_module_name_assign_on_call root, module, "frontend_mod_bind2"
  
  root

# ###################################################################################################
#    frontend_mod_iced
# ###################################################################################################
bdh_module_name_root module, "frontend_mod_iced",
  emit_codegen  : (root, ctx)->
    tpl_mirror ctx, "1_init_and_modules/1_iced_runtime.coffee"
    false

def "frontend_mod_iced", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "frontend_mod_iced", "frontend_mod_iced", "def"
  bdh_node_module_name_assign_on_call root, module, "frontend_mod_iced"
  
  root

# ###################################################################################################
#    frontend_mod_ws_sub
# ###################################################################################################
bdh_module_name_root module, "frontend_mod_ws_sub",
  emit_codegen  : (root, ctx)->
    tpl_mirror ctx, "1_init_and_modules/ws_mod_sub.coffee"
    false

def "frontend_mod_ws_sub", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "frontend_mod_ws_sub", "frontend_mod_ws_sub", "def"
  bdh_node_module_name_assign_on_call root, module, "frontend_mod_ws_sub"
  
  mod_runner.current_runner.curr_root.data_hash.ws_mod_sub = true
  
  root

# ###################################################################################################
#    frontend_mod_db_mixin
# ###################################################################################################
bdh_module_name_root module, "frontend_mod_db_mixin",
  emit_codegen  : (root, ctx)->
    tpl_mirror ctx, "1_init_and_modules/experimental/db_mixin.coffee"
    false

def "frontend_mod_db_mixin", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "frontend_mod_db_mixin", "frontend_mod_db_mixin", "def"
  bdh_node_module_name_assign_on_call root, module, "frontend_mod_db_mixin"
  
  root

# ###################################################################################################
#    frontend_mod_rel_mouse_coords
# ###################################################################################################
bdh_module_name_root module, "frontend_mod_rel_mouse_coords",
  emit_codegen  : (root, ctx)->
    tpl_mirror ctx, "1_init_and_modules/1_rel_mouse_coords.coffee"
    false

def "frontend_mod_rel_mouse_coords", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "frontend_mod_rel_mouse_coords", "frontend_mod_rel_mouse_coords", "def"
  bdh_node_module_name_assign_on_call root, module, "frontend_mod_rel_mouse_coords"
  
  root

# ###################################################################################################
#    frontend_mod_global_mouse_up
# ###################################################################################################
bdh_module_name_root module, "frontend_mod_global_mouse_up",
  emit_codegen  : (root, ctx)->
    tpl_mirror ctx, "1_init_and_modules/1_global_mouse_up.coffee"
    false

def "frontend_mod_global_mouse_up", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "frontend_mod_global_mouse_up", "frontend_mod_global_mouse_up", "def"
  bdh_node_module_name_assign_on_call root, module, "frontend_mod_global_mouse_up"
  
  root

# ###################################################################################################
#    frontend_vendor_dayjs
# ###################################################################################################
bdh_module_name_root module, "frontend_vendor_dayjs",
  emit_codegen  : (root, ctx)->
    tpl_mirror ctx, "_vendor/dayjs.min.js"
    false

def "frontend_vendor_dayjs", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "frontend_vendor_dayjs", "frontend_vendor_dayjs", "def"
  bdh_node_module_name_assign_on_call root, module, "frontend_vendor_dayjs"
  
  mod_runner.current_runner.curr_root.data_hash.ws_mod_sub = true
  
  root

# ###################################################################################################
#    frontend_vendor_dayjs_relative
# ###################################################################################################
bdh_module_name_root module, "frontend_vendor_dayjs_relative",
  emit_codegen  : (root, ctx)->
    tpl_mirror ctx, "_vendor/relativeTime.js"
    false

def "frontend_vendor_dayjs_relative", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "frontend_vendor_dayjs_relative", "frontend_vendor_dayjs_relative", "def"
  bdh_node_module_name_assign_on_call root, module, "frontend_vendor_dayjs_relative"
  
  mod_runner.current_runner.curr_root.data_hash.ws_mod_sub = true
  
  root

# TODO frontend_mod_provider
