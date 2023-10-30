module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "../common_import"

def "task_tracker_db_create_inject", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  struct "task_tracker_iteration", ()->
    # пока непонятно какое из полей я буду использовать
    # field "snapshot", "json?"
    # field "diff",     "json"
  
  struct "task_tracker_todo_item", ()->
    field "title",          "str"
    field "description",    "text"
    field "done",           "bool"
    field "in_todo_list",   "bool"
    
    field "ml_description", "text?" # for embedding
    
    # dyn_enum_ task_tracker_ todo_item_group
    field "group", "dyn_enum_task_tracker_todo_item_group"
    
    field "importance_tier",  "i32?"
    field "refine_tier",      "i32?"
    field "wtf_tier",         "i32?"
    field "prev_iter_importance_tier",  "i32?"
    field "prev_iter_refine_tier",      "i32?"
    field "prev_iter_wtf_tier",         "i32?"
    field "last_tier_edit_ts","i64" # TODO timestamp type
    field "iteration_id",     "i64"
    
    field "order",            "i32"
    # estimate_tsi???
    # _time_point_list ?
  
  return

# ###################################################################################################
#    task_tracker
# ###################################################################################################
bdh_module_name_root module, "task_tracker",
  nodegen       : (root, ctx)->
    project_node = root.type_filter_search "project"
    backend_node = project_node.tr_get_try "backend",   root.data_hash.backend_name
    frontend_node= project_node.tr_get_try "frontend",  root.data_hash.frontend_name
    
    connect_node = backend_frontend_connect {
      backend : root.data_hash.backend_name
      frontend: root.data_hash.frontend_name
    }
    db_backend_frontend_struct "task_tracker_iteration"
    db_backend_frontend_struct "task_tracker_todo_item"
    # db_backend_frontend_struct "dyn_enum_task_tracker_todo_item_group"
    # костыль
    ctx.walk_fn connect_node
    
    ctx.inject_to frontend_node, ()->
      frontend_mod_bind2()
      frontend_mod_rel_mouse_coords()
      frontend_mod_global_mouse_up()
      frontend_com_storybook "select"
      frontend_com_storybook "text_input"
      frontend_com_storybook "number_input"
      frontend_com_storybook "checkbox"
      frontend_com_storybook "textarea"
      frontend_com_storybook "tab_bar"
      
      com = frontend_com "Page_task_tracker"
      com.data_hash.folder = "htdocs/page"
      com.data_hash.code = """
        module.exports =
          render : ()->
            Page_wrap @props
              Xtree_task_todo_db {}
        """
      
      # TODO policy
      router ()->
        router_endpoint "task_tracker", "Page_task_tracker", "Todo tool"
    
    false
  
  validator     : (root, ctx)->
    false
  
  emit_codebub  : (root, ctx)->
    false
  
  emit_codegen  : (root, ctx)->
    # TODO rename xtree_task_todo -> task_tracker
    # TODO refactor + remove old_db_model_emulator.coffee
    file_name_list= """
      action_manager.coffee
      lang_switch.coffee
      levenshtein.coffee
      model.coffee
      node_gui.com.coffee
      old_db_model_emulator.coffee
      style.css
      task_object_inspector.com.coffee
      xtree_style.css
      xtree_task_todo.com.coffee
      xtree_task_todo_db.com.coffee
      """.split "\n"
    
    for file_name in file_name_list
      ctx.file_render "htdocs/xtree_task_todo/#{file_name}", ctx.tpl_read "task_tracker/xtree_task_todo/#{file_name}"
    false
  
  emit_min_deps : (root, ctx, cb)->
    cb null, false

def "task_tracker", (name_opt = {}, scope_fn)->
  name_opt.db       ?= ""
  name_opt.backend  ?= ""
  name_opt.frontend ?= ""
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # TODO. backend может быть в другом проекте внтури одной monorepo
  
  project_node = mod_runner.current_runner.curr_root.type_filter_search "project"
  if !db_node = project_node.tr_get_try "db", name_opt.db
    throw new Error "db name=#{name_opt.db} not found"
  
  if !backend_node = project_node.tr_get_try "backend", name_opt.backend
    throw new Error "backend name=#{name_opt.backend} not found"
  
  if !frontend_node = project_node.tr_get_try "frontend", name_opt.frontend
    throw new Error "frontend name=#{name_opt.frontend} not found"
  
  root = mod_runner.current_runner.curr_root.tr_get "task_tracker", "task_tracker", "def"
  bdh_node_module_name_assign_on_call root, module, "task_tracker"
  
  root.data_hash.db_name        ?= name_opt.db
  root.data_hash.backend_name   ?= name_opt.backend
  root.data_hash.frontend_name  ?= name_opt.frontend
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root
