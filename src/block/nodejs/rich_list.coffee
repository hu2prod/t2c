module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "../common_import"

# ###################################################################################################
#    front_com_rich_list
# ###################################################################################################
bdh_module_name_root module, "front_com_rich_list",
  nodegen       : (root, ctx)->
    com_list = [
      "button"
      "checkbox" # for rich_list_dyn_enum_editor
      "tooltip"  # for text_cut
      "text_cut" # for rich_list_dyn_enum_editor
      "text_input"
      "number_input"
      "textarea"
      "textarea_json"
      "select"
      "select_radio"
      "table"
      "rich_list_list_multi_renderer"
      "spinner"
    ]
    for com in com_list
      frontend_com_storybook com
    
    frontend_mod_bind2()
    
    frontend_storybook_file "util/text_cut.coffee"
    
    false
  
  validator : (root, ctx)->
    table_name    = root.policy_get_val_no_use "table_name"
    if table_name
      project_node = mod_runner.current_runner.curr_root.type_filter_search "project"
      db_backend_struct = project_node.tr_get_try "db_backend_struct", table_name
      if !db_backend_struct
        throw new Error "db_backend_frontend_struct table_name=#{table_name} not found"
      
      if !db_backend_struct.data_hash.frontend
        throw new Error "db_backend_struct table_name=#{table_name} does not include frontend. Should use db_backend_frontend_struct"
      
      db_node = project_node.tr_get_try "db", db_backend_struct.data_hash.db_name
      if !db_node.data_hash.db.final_model_hash[table_name]
        # TODO levelstein
        puts "defined models:"
        for k,v of db_node.data_hash.db.final_model_hash
          puts "  #{k}"
        throw new Error "table_name #{table_name} is missing"
    
    false
  
  emit_codegen  : (root, ctx)->
    save_on_edit  = root.policy_get_val_use "save_on_edit"
    save_on_create= root.policy_get_val_use "save_on_create"
    policy_create = root.policy_get_val_use "create"
    policy_delete = root.policy_get_val_use "delete"
    policy_clone  = root.policy_get_val_use "clone"
    item_per_page_count     = root.policy_get_val_use "item_per_page_count"
    item_per_page_count_list= root.policy_get_val_use "item_per_page_count_list"
    table_name    = root.policy_get_val_use "table_name"
    
    editor_field_list = []
    if table_name
      project_node = mod_runner.current_runner.curr_root.type_filter_search "project"
      db_backend_struct = project_node.tr_get_try "db_backend_struct", table_name
      db_node = project_node.tr_get_try "db", db_backend_struct.data_hash.db_name
      model = db_node.data_hash.db.final_model_hash[table_name]
      for k, field of model.field_hash
        {name, type, rich_list_conf} = field
        obj = {name, type}
        if rich_list_conf
          obj_set obj, rich_list_conf
        editor_field_list.push obj
    
    
    # TODO manual editor_field_list option (non-db rich_list mode)
    
    # TODO filter_descriptor_list from data_hash
    filter_descriptor_list = []
    
    config = """
      filter_key_to_filter_descriptor_hash : {}
      filter_descriptor_list: #{make_tab JSON.stringify(filter_descriptor_list, null, 2), "  "}
      editor_field_list     : #{make_tab JSON.stringify(editor_field_list, null, 2), "  "}
      view_type_list        : ["table"]
      
      save_on_edit  : #{JSON.stringify save_on_edit}
      save_on_create: #{JSON.stringify save_on_create}
      delete        : #{JSON.stringify policy_delete}
      item_per_page_count     : #{item_per_page_count}
      item_per_page_count_list: #{JSON.stringify item_per_page_count_list}
      key_width     : #{model?.rich_list_key_width    ? 300}
      value_width   : #{model?.rich_list_value_width  ? 300}
    """#"
    
    # ###################################################################################################
    #    db com wrapper
    # ###################################################################################################
    if table_name
      aux_mount_jl = []
      if policy_create
        aux_mount_jl.push """
          @create = ()->new db_obj_bp
          """
      
      if policy_clone
        aux_mount_jl.push """
          @clone = (old_obj)->
            new_obj = new db_obj_bp
            for k,v of old_obj
              continue if k == "id"
              continue if typeof v == "function"
              new_obj[k] = v
            return new_obj
          """#"
      
      ctx.file_render "htdocs/rich_list/_com/#{root.name}_db.com.coffee", """
        module.exports =
          state :
            loading : true
          
          create : null
          clone  : null
          mount : ()->
            @config = {
              #{make_tab config, "      "}
            }
            @db_obj_bp = db_obj_bp = window[#{JSON.stringify table_name.capitalize()}]
            if !db_obj_bp
              perr "WARNING. Missing table #{table_name}"
            @data_controller = new Data_filter_controller_full_list
            await db_obj_bp.list {}, defer(err, db_list); throw err if err
            @data_controller.full_list = db_list
            @data_controller.filtered_list_refresh()
            
            #{join_list aux_mount_jl, "    "}
            
            @set_state loading : false
          
          render : ()->
            if @state.loading
              Spinner {}
            else
              Rich_list_#{root.name} {
                data_controller : @data_controller
                create : @create
                clone  : @clone
              }
        """
    
    # ###################################################################################################
    #    com aux
    # ###################################################################################################
    policy_top_pager        = root.policy_get_val_use "top_pager"
    policy_top_page_count   = root.policy_get_val_use "top_page_count"
    policy_top_view_selector= root.policy_get_val_use "top_view_selector"
    
    policy_bottom_pager         = root.policy_get_val_use "bottom_pager"
    policy_bottom_page_count    = root.policy_get_val_use "bottom_page_count"
    policy_bottom_view_selector = root.policy_get_val_use "bottom_view_selector"
    
    top_pager = ""
    top_page_count = ""
    top_view_selector = ""
    bottom_pager = ""
    bottom_page_count = ""
    bottom_view_selector = ""
    
    code = """
      Rich_list_pager {
        data_controller : @props.data_controller
        on_change : ()=>
          @filter_list()
          @force_update()
      }
      """
    
    top_pager   = code if policy_top_pager
    bottom_pager= code if policy_bottom_pager
    
    code = """
      Rich_list_page_item_count_select {
        data_controller : @props.data_controller
        on_change : ()=>
          @filter_list()
          @force_update()
      }
      """
    top_page_count    = code if policy_top_page_count
    bottom_page_count = code if policy_bottom_page_count
    
    code = """
      Rich_list_view_selector {
        data_controller : @props.data_controller
        on_change : ()=>
          @force_update()
      }
      """
    
    top_view_selector    = code if policy_top_view_selector
    bottom_view_selector = code if policy_bottom_view_selector
    
    
    filter_code = ""
    if filter_descriptor_list.length
      filter_code = """
        Rich_list_filter_left_renderer {
          ref : "filter"
          data_controller : @props.data_controller
          on_change : ()=>
            @filter_list()
            @force_update()
          on_change_hover : (filter_key, filter_value_list)=>
            filter_value_hash = {}
            for v in filter_value_list
              filter_value_hash[v] = true
            
            @filter_key        = filter_key
            @filter_value_hash = filter_value_hash
            
            @hover_filter_list()
            @refs.list.on_change_hover()
        }
        """#"
    
    
    # ###################################################################################################
    #    com compile
    # ###################################################################################################
    # TODO object inspector do not generate if not used
    aux_col_list = ""
    if root.data_hash.col_list_code
      aux_col_list = """
      col_list : #{root.data_hash.col_list_code}
      """
    
    ctx.file_render "htdocs/rich_list/_com/#{root.name}.com.coffee", """
      module.exports =
        state :
          selected_item : null
        
        mount : ()->
          @config = {
            #{make_tab config, "      "}
          }
          for filter in @config.filter_descriptor_list
            @config.filter_key_to_filter_descriptor_hash[filter.key] = filter
          
          @props.data_controller.view_type_list           = @config.view_type_list
          @props.data_controller.filter_descriptor_list   = @config.filter_descriptor_list
          @props.data_controller.item_per_page_count      = @config.item_per_page_count
          @props.data_controller.item_per_page_count_list = @config.item_per_page_count_list
          @filter_list()
          
          await dyn_enum_load @config, defer(err, found); throw err if err
          if found
            @filter_list()
            @force_update()
          return
        
        filter_list : ()->
          @props.data_controller.filtered_list_refresh()
          @hover_filter_list()
          return
        
        hover_filter_key : null
        hover_filter_value_hash : {}
        hover_filter_list : ()->
          {
            hover_filter_key
            hover_filter_value_hash
          } = @
          for v in @props.data_controller.filtered_list
            v.hover = hover_filter_value_hash[v[hover_filter_key]]
          return
        
        
        # ###################################################################################################
        #    object inspector
        # ###################################################################################################
        oi_unselect : ()->
          @state.selected_item.selected = false
          @hover_filter_list()
          @set_state selected_item : null
        
        oi_clone : ()->
          new_db_item = @props.clone @state.selected_item
          await new_db_item.save [], defer(err); throw err if err
          # TODO display error in UI
          
          @props.data_controller.full_list.push new_db_item
          @filter_list()
          @set_state selected_item : new_db_item
        
        oi_delete : ()->
          return if !confirm("Are you sure you want delete '\#{@state.selected_item.title}' id=\#{@state.selected_item.id}?")
          await @state.selected_item.delete defer(err); throw err if err
          @props.data_controller.full_list.remove @state.selected_item
          @filter_list()
          @set_state selected_item : null
        
        oi_create : ()->
          new_db_item = @props.create()
          # ensure no error on create
          for field in @config.editor_field_list
            continue if field.allow_null
            if field.type in ["str", "text"]
              new_db_item[field.name] = ""
            else if /^dyn_enum_/.test field.type
              new_db_item[field.name] = []
          
          if @config.save_on_create
            await new_db_item.save [], defer(err); throw err if err
            @props.data_controller.full_list.push new_db_item
            @filter_list()
          
          @set_state selected_item : new_db_item
        
        oi_on_save : (field_list, cb)->
          if !@state.selected_item.id
            # Временный микрокостыль
            # Сам db mixin должен знать список полей
            # TODO FIXME
            field_list = @config.editor_field_list.map (t)->t.name
          
          is_create = !@state.selected_item.id?
          await @state.selected_item.save field_list, defer(err); return cb err if err
          
          if is_create
            @props.data_controller.full_list.push @state.selected_item
          @filter_list()
          @force_update()
          cb()
        
        # ###################################################################################################
        #    list
        # ###################################################################################################
        # NOTE содержимое можно удалить или закомментировать, если нет фильтра
        list_on_hover_item : (item)->
          return if !@refs.filter
          for filter in @props.data_controller.filter_descriptor_list
            if item
              my_value = item.attr_hash[filter.key]
              for value in filter.value_list
                value.hover = value.value == my_value
            else
              for value in filter.value_list
                value.hover = false
          # TODO update nested hover for tree filter
          
          @refs.filter.on_change_hover()
        
        list_on_select_item : (item)->
          if @state.selected_item
            @state.selected_item.selected = false
          item.selected = true
          @set_state {
            selected_item : item
          }
          @hover_filter_list()
        
        render : ()->
          table
            tbody {
              style:
                verticalAlign : "top"
            }
              tr
                td {
                  colSpan : 2
                }
                  div {
                    style:
                      float : "right"
                  }
                    div {
                      style:
                        display: "flex"
                    }
                      #{make_tab top_pager,         "                "}
                      #{make_tab top_page_count,    "                "}
                      #{make_tab top_view_selector, "                "}
                td
                  if @state.selected_item
                    Button {
                      label   : "Unselect"
                      on_click: ()=>@oi_unselect()
                    }
                    if @props.clone
                      Button {
                        label   : "Clone"
                        on_click: ()=>@oi_clone()
                      }
                    if @config.delete and @state.selected_item.id?
                      Button {
                        label   : "Delete"
                        on_click: ()=>@oi_delete()
                        style:
                          color : "#F00"
                      }
                  if @props.create and !@state.selected_item
                    Button {
                      label   : "Create"
                      on_click: ()=>@oi_create()
                    }
              tr
                td {
                  style : @props.filter_style ? {}
                }
                  #{make_tab filter_code, "            "}
                td {
                  style : @props.list_style ? {}
                }
                  table {
                    class : "table_layout"
                    style :
                      width : "100%"
                  }
                    tbody
                      tr
                        td
                          Rich_list_list_multi_renderer {
                            ref : "list"
                            data_controller : @props.data_controller
                            #{make_tab aux_col_list, "                      "}
                            on_hover_item  : (item)=>@list_on_hover_item   item
                            on_select_item : (item)=>@list_on_select_item  item
                          }
                      tr
                        td
                          div {
                            style:
                              float : "right"
                          }
                            div {
                              style:
                                display: "flex"
                            }
                              #{make_tab bottom_pager,         "                        "}
                              #{make_tab bottom_page_count,    "                        "}
                              #{make_tab bottom_view_selector, "                        "}
                td {
                  style: @props.editor_style ? {}
                }
                  if @state.selected_item
                    Rich_list_item_editor {
                      key_width   : @props.editor_key_width   ? @config.key_width
                      value_width : @props.editor_value_width ? @config.value_width
                      value       : @state.selected_item
                      config      : @config
                      on_save     : (field_list, cb)=>@oi_on_save(field_list, cb)
                    }
      """#"
    
    false

def "frontend front_com_rich_list", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "front_com_rich_list", name, "def"
  bdh_node_module_name_assign_on_call root, module, "front_com_rich_list"
  
  root.policy_set_here_weak "table_name", ""
  
  root.policy_set_here_weak "create", true
  root.policy_set_here_weak "delete", true
  root.policy_set_here_weak "clone",  true
  root.policy_set_here_weak "save_on_edit",   true # false -> save on click button "save"
  root.policy_set_here_weak "save_on_create", true
  root.policy_set_here_weak "item_per_page_count", Infinity
  root.policy_set_here_weak "item_per_page_count_list", [10, 20, 50, 100]
  # root.policy_set_here_weak "view_type_list", ["table"]
  
  root.policy_set_here_weak "top_pager",            false
  root.policy_set_here_weak "top_page_count",       false
  root.policy_set_here_weak "top_view_selector",    false
  
  root.policy_set_here_weak "bottom_pager",         false
  root.policy_set_here_weak "bottom_page_count",    false
  root.policy_set_here_weak "bottom_view_selector", false
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

def "frontend front_com_rich_list_db", (name, scope_fn)->
  root = front_com_rich_list name, scope_fn
  policy = root.policy_get "table_name"
  policy.val = name
  root

# Немного больше кода в gen, но пока не знаю как по-другому безопасно сделать
def "router front_com_rich_list_db_router", (name, page_name)->
  if !page_name
    page_name = "RL #{name}"
  
  router_endpoint "rich_list_#{name}", "page_rich_list_#{name}", page_name
  com = frontend_com "page_rich_list_#{name}"
  com.data_hash.folder = "htdocs/page"
  com.data_hash.code = """
    module.exports =
      render : ()->
        Page_wrap @props
          Rich_list_#{name}_db {}
    """
  
  null
