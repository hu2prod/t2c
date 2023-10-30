module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "../common_import"

def "project_progress_db_create_inject", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  struct "project_progress_point", ()->
    field "value", "json"
  
  return

# ###################################################################################################
#    project_progress
# ###################################################################################################
bdh_module_name_root module, "project_progress",
  nodegen       : (root, ctx)->
    project_node = root.type_filter_search "project"
    backend_node = project_node.tr_get_try "backend",   root.data_hash.backend_name
    frontend_node= project_node.tr_get_try "frontend",  root.data_hash.frontend_name
    
    connect_node = backend_frontend_connect {
      backend : root.data_hash.backend_name
      frontend: root.data_hash.frontend_name
    }
    db_backend_frontend_struct "project_progress_point"
    # костыль
    ctx.walk_fn connect_node
    
    ctx.inject_to frontend_node, ()->
      frontend_mod_ws_sub()
      frontend_mod_rel_mouse_coords() # canvas controller
      frontend_vendor_dayjs()
      frontend_com_storybook "chart_linear_time"
      
      # TODO align
      point_part_list_decl_jl = []
      point_part_list_clear_jl = []
      point_part_list_pop_jl = []
      point_part_list_push_jl = []
      for v in root.data_hash.progress_point_part_list
        point_part_list_decl_jl.push "#{v.res_name}_list : []"
        point_part_list_clear_jl.push "@#{v.res_name}_list.clear()"
        point_part_list_pop_jl.push "@#{v.res_name}_list.pop()"
        point_part_list_push_jl.push """
          @#{v.res_name}_list.push [t, value.#{v.res_name}] if value.#{v.res_name}?
          """
      
      # TODO make table layout
      # TODO size policy
      chart_refresh_jl = []
      chart_render_jl = []
      for v in root.data_hash.progress_point_part_list
        chart_refresh_jl.push "@refs.chart_#{v.res_name}?.refresh()"
        
        pretty_name = v.res_name.replace(/_/g, " ").capitalize()
        chart_render_jl.push """
          td
            Chart_linear_time {
              ref     : "chart_#{v.res_name}"
              value   : @#{v.res_name}_list
              label_y : #{JSON.stringify pretty_name}
              sx : 800
              sy : 500
              min_y   : 0
            }
          """#"
      
      com = frontend_com "Page_project_progress"
      com.data_hash.folder = "htdocs/page"
      com.data_hash.code = """
        module.exports =
          #{join_list point_part_list_decl_jl, "  "}
          last_live_point     : null
          last_live_point_used: false
          
          mount : ()->
            simple_sub_endpoint @, "project_progress", (data)=>
              update = ()=>
                if @last_live_point_used
                  #{join_list point_part_list_pop_jl, "          "}
                
                value = @last_live_point = data.value
                
                t = new Date value.capture_ts
                #{join_list point_part_list_push_jl, "        "}
                @last_live_point_used = true
              
              if @db_init_load_complete
                update()
              else
                # prevent strange animation
                setTimeout update, 10
              
              @chart_refresh()
            
            @db_refresh()
          
          unmount : ()->
            @unmount_default()
            clearInterval @int
          
          db_init_load_complete : false
          db_refresh : ()->
            await Project_progress_point.list {limit:10000}, defer(err, pp_list); throw err if err
            
            #{join_list point_part_list_clear_jl, "    "}
            
            for v in pp_list
              {value} = v
              t = new Date value.capture_ts
              #{join_list point_part_list_push_jl, "      "}
            
            if value = @last_live_point
              t = new Date value.capture_ts
              #{join_list point_part_list_push_jl, "      "}
              @last_live_point_used = true
            
            @db_init_load_complete = true
            @chart_refresh()
          
          chart_refresh : ()->
            #{join_list chart_refresh_jl, "    "}
          
          render : ()->
            Page_wrap @props
              table
                tbody
                  tr
                    #{join_list chart_render_jl, "            "}
        
        """#"
      
      # TODO policy
      router ()->
        router_endpoint "project_progress", "Page_project_progress", "Progress"
    
    false
  
  # TODO validate
  # table exists
  # field exists
  
  emit_codegen  : (root, ctx)->
    # TODO use
    # root.data_hash.progress_point_part_list
    ###
    Нужен worker который будет poll'ить DB и писать project_progress_point
    ###
    
    point_make_request_jl = []
    point_make_name_list = []
    table_name_max_width = 0
    for v in root.data_hash.progress_point_part_list
      table_name_max_width = Math.max table_name_max_width, v.table_name
    
    table_name_max_width = table_name_max_width | 1
    
    # TODO policy parallel
    # TODO align 'return cb err if err'
    for v in root.data_hash.progress_point_part_list
      switch v.type
        when "table_row_count"
          point_make_request_jl.push """
            await db.#{v.table_name.ljust table_name_max_width}.count({}).cb defer(err, #{v.res_name.ljust table_name_max_width+6}); return cb err if err
          """
          point_make_name_list.push v.res_name
        
        when "table_field_sum"
          p "NOTE: table_field_sum is not supported yet (not checked)"
          attributes = """
            [sequelize.fn("sum", sequelize.col(#{JSON.stringify v.field_name})), "sum"]
          """#"
          # TODO tmp_val for res
          point_make_request_jl.push """
            await db.#{v.table_name.ljust table_name_max_width}.findAll({attributes:#{attributes},raw: true}).cb defer(err, res); return cb err if err
            #{v.res_name} = res[#{JSON.stringify v.field_name}]
          """
          point_make_name_list.push v.res_name
    
    point_default_jl = point_make_name_list.map (t)->t+" : -1"
    
    # TODO move to mod
    ctx.file_render "src/util/endpoint_channel.coffee", ctx.tpl_read "back/util/endpoint_channel.coffee"
    
    # TODO policy for time interval for checkpoint
    ctx.file_render "src/endpoint/project_progress.coffee", """
      db = require "../db"
      endpoint_channel = require "../util/endpoint_channel"
      
      # ###################################################################################################
      #    
      # ###################################################################################################
      project_progress_point_get = (_opt, cb)->
        #{join_list point_make_request_jl, "  "}
        
        doc = {
          value: {
            #{join_list point_make_name_list, "      "}
            capture_ts : Date.now()
            # TODO display_ts
          }
        }
        cb null, doc
      
      project_progress_point_make = (_opt, cb)->
        await project_progress_point_get {},            defer(err, doc);  return cb err if err
        await db.project_progress_point.create(doc).cb  defer(err, res);  return cb err if err
        
        cb null, doc
      
      # ###################################################################################################
      last_live_point = {
        value : {
          #{join_list point_default_jl, "    "}
          capture_ts : Date.now()
        }
      }
      last_live_point_json = JSON.stringify last_live_point
      {broadcast_fn} = endpoint_channel @,
        name    : "project_progress"
        # interval: 1000
        fn      : (req, cb)->
          cb null, last_live_point
      
      do ()->
        loop
          await project_progress_point_get {}, defer(err, new_last_live_point);
          if err
            perr err
          else
            # Прим. т.к. capture_ts сейчас постоянно меняется, то проверка всегда будет !=
            new_last_live_point_json = JSON.stringify new_last_live_point
            if last_live_point_json != new_last_live_point_json
              last_live_point_json = new_last_live_point_json
              last_live_point      = new_last_live_point
              broadcast_fn()
          await setTimeout defer(), 10000
      
      do ()->
        last_point = null
        await db.project_progress_point.findOne({order: [ [ 'id', 'DESC' ]]}).cb defer(err, last_point);
        
        # do not crash all app for 1 feature
        if err
          perr err
          return
        
        loop
          t_diff = Date.now() - (last_point?.value.capture_ts ? 0)
          # each hour
          if t_diff > 1*60*60*1000
            puts "project progress snapshot", new Date
            await project_progress_point_make {}, defer(err, new_last_point)
            if err
              perr err
            else
              last_point = new_last_point
          await setTimeout defer(), 60000
        return
      """#"
    
    false

def "project_progress", (name_opt = {}, scope_fn)->
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
  
  # есть вопрос с ключем. Т.к. он должен вешаться на db + backend (там есть worker который трекает прогресс)
  # key = "#{db_name}_#{backend_name}_#{frontend_name}"
  # root = mod_runner.current_runner.curr_root.tr_get "project_progress", key, "def"
  root = mod_runner.current_runner.curr_root.tr_get "project_progress", "project_progress", "def"
  bdh_node_module_name_assign_on_call root, module, "project_progress"
  
  root.data_hash.db_name        ?= name_opt.db
  root.data_hash.backend_name   ?= name_opt.backend
  root.data_hash.frontend_name  ?= name_opt.frontend
  root.data_hash.progress_point_part_list ?= []
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

def "project_progress project_progress_table_row_count", (table_name)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  mod_runner.current_runner.curr_root.data_hash.progress_point_part_list.push {
    type : "table_row_count"
    table_name
    res_name : "#{table_name}_count"
  }
  
  return

def "project_progress project_progress_table_field_sum", (table_name, field_name)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  mod_runner.current_runner.curr_root.data_hash.progress_point_part_list.push {
    type : "table_field_sum"
    table_name
    field_name
    res_name : "#{table_name}_#{field_name}_count"
  }
  
  return
