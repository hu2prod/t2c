module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "../common_import"


# ###################################################################################################
#    db_backend_struct
# ###################################################################################################
bdh_module_name_root module, "db_backend_struct",
  emit_codegen  : (root, ctx)->
    # TODO. Еще запрефиксовать имя БД. Т.к. БД может быть больше 1
    # Отдельный вопрос policy для такого
    # TODO. search тоже может быть больше 1
    
    model_name = root.name
    
    has_create    = root.policy_get_val_use "has_create"
    has_read      = root.policy_get_val_use "has_read"
    has_read_list = root.policy_get_val_use "has_read_list"
    has_update    = root.policy_get_val_use "has_update"
    has_delete    = root.policy_get_val_use "has_delete"
    has_search    = root.policy_get_val_use "has_search"
    
    if has_search
      project_node = root.type_filter_search "project"
      
      search_node = project_node.tr_get_type_only_here "search"
      
      for index in search_node.data_hash.index_list
        continue if index.table_name != model_name
        root.data_hash.search_index_name_list.upush index.name
    
    if !db_node = root.tr_get_deep "db", root.data_hash.db_name
      throw new Error "can't find root.data_hash.db_name=#{root.data_hash.db_name}"
    
    if !model = db_node.data_hash.db.final_model_hash[model_name]
      puts "available models:"
      for k,v of db_node.data_hash.db.final_model_hash
        puts "  #{k}"
      throw new Error "db doesn't have model=#{model_name}"
    
    # ###################################################################################################
    #    
    # ###################################################################################################
    require_jl = []
    
    db_type   = db_node.policy_get_val_use("type")
    db_driver = db_node.policy_get_val_use("driver")
    switch db_type
      when "postgres" # TODO other db supported by sequelize
        switch db_driver
          when "sequelize"
            require_jl.push """
              db = require "../db"
              """#"
          else
            throw new Error "unsupported db_type db_type=#{db_type} db_driver=#{db_driver}"
      
      when "leveldb"
        switch db_driver
          when "raw"
            require_jl.push """
              db = require "../leveldb"
              """#"
          else
            throw new Error "unsupported combination db_type=#{db_type} db_driver=#{db_driver}. Try db_driver=raw"
      
      else
        throw new Error "unsupported db_type db_type=#{db_type} db_driver=#{db_driver}. Hint: if it is supported by sequelize, just patch t2c switch"
    
    for index in root.data_hash.search_index_name_list
      meili_util_file = "meili_#{index}"
      require_file = "../search/#{meili_util_file}"
      require_jl.push """
        #{meili_util_file} = require #{JSON.stringify require_file}
        """
    
    field_transform_jl = []
    for field_name, field of model.field_hash
      switch field.type
        when "buf"
          field_transform_jl.push """
            if req[#{JSON.stringify field_name}]?
              req[#{JSON.stringify field_name}] = Buffer.from req[#{JSON.stringify field_name}], \"base64\"
            """
    
    # TODO make for multiple key fields
    pk_field = "id"
    for field_name, field of model.field_hash
      if field.is_key
        pk_field = field_name
    
    # db_mixin_fix
    if pk_field != "id"
      field_transform_jl.unshift """
        if req.id?
          req.#{pk_field} = req.id
        """
    aux_field_transform = """
      #{join_list field_transform_jl, ''}
      """
    
    code_jl = []
    
    if has_read
      code_jl.push """
        @#{model_name}_get = (req, cb)->
          # TODO ACL
          #{make_tab aux_field_transform, "  "}
          where = #{JSON.stringify pk_field} : req.#{pk_field}
          await db.#{model_name}.findOne({where,raw:true}).cb defer(err, res); return cb err if err
          # TODO serialize for browser
          cb null, {res}
        
        
        """
    
    if has_read_list
      limit = root.policy_get_val_use "limit"
      code_jl.push """
        @#{model_name}_list = (req, cb)->
          # TODO ACL
          where = {}
          limit = #{limit}
          
          if req.limit
            if typeof req.limit != "number" or !isFinite req.limit or req.limit <= 0
              return cb new Error "req.limit not number > 0"
            limit = Math.min limit, req.limit
          
          loc_opt = {
            where
            raw   : true
            # order : [["id", "ASC"]]
            # https://github.com/sequelize/sequelize/issues/11288
            order : [[db.sequelize.literal("id"), "ASC"]]
          }
          if isFinite limit
            loc_opt.limit = limit
          
          if req.order_rev
            # loc_opt.order = [["id", "DESC"]]
            # https://github.com/sequelize/sequelize/issues/11288
            loc_opt.order = [[db.sequelize.literal("id"), "DESC"]]
          
          if req.offset
            switch typeof req.offset
              when "number"
                if !isFinite req.offset
                  return cb new Error "req.offset is not finite"
                if req.offset < 0
                  return cb new Error "req.offset < 0"
                loc_opt.offset = req.offset
              when "string"
                if !/^\\d+$/.test req.offset
                  return cb new Error "req.offset is non numerical string"
                loc_opt.offset = req.offset
              else
                return cb new Error "bad req.offset"
          
          await db.#{model_name}.findAll(loc_opt).cb defer(err, db_res_list); return cb err if err
          
          total_count = db_res_list.length
          if db_res_list.length <= limit
            loc_opt = {
              where
            }
            await db.#{model_name}.count(loc_opt).cb defer(err, total_count); return cb err if err
          
          # TODO serialize for browser
          cb null, {
            list : db_res_list
            total_count
          }
        
        
        """#"
    
    if has_create
      search_jl = []
      if root.data_hash.search_index_name_list.length
        # TODO fix id
        search_jl.push """
          doc.id = res.id
          """
      
      for index in root.data_hash.search_index_name_list
        meili_util_file = "meili_#{index}"
        search_jl.push """
          await #{meili_util_file}.doc_insert doc, defer(err); return cb err if err
          """
      
      
      code_jl.push """
        @#{model_name}_create = (req, cb)->
          # TODO ACL
          # TODO select only needed fields
          # TODO sanitize
          #{make_tab aux_field_transform, "  "}
          doc = clone req
          delete doc.switch
          delete doc.request_uid
          await db.#{model_name}.create(doc).cb defer(err, res); return cb err if err
          
          #{join_list search_jl, "  "}
          
          cb null, #{JSON.stringify pk_field} : res.#{pk_field}
        
        
        """
    
    if has_update
      search_jl = []
      # TODO fixme for aux_field_transform but inside meta
      for index in root.data_hash.search_index_name_list
        meili_util_file = "meili_#{index}"
        # TODO update pk_field
        search_jl.push """
          await #{meili_util_file}.doc_update_by_id req.id, defer(err); return cb err if err
          """
      
      code_jl.push """
        @#{model_name}_update = (req, cb)->
          # TODO ACL
          # TODO select only needed fields
          # TODO sanitize
          #{make_tab aux_field_transform, "  "}
          where = #{JSON.stringify pk_field} : req.#{pk_field}
          
          update_hash = clone req
          delete update_hash.switch
          delete update_hash.request_uid
          delete update_hash.#{pk_field}
          await db.#{model_name}.update(update_hash, {where}).cb defer(err, res); return cb err if err
          
          #{join_list search_jl, "  "}
          
          cb null
        
        
        """
    
    if has_delete
      search_jl = []
      for index in root.data_hash.search_index_name_list
        meili_util_file = "meili_#{index}"
        # TODO pk_field
        search_jl.push """
          await #{meili_util_file}.doc_delete_by_id req.id, defer(err); return cb err if err
          """
      
      code_jl.push """
        @#{model_name}_delete = (req, cb)->
          # TODO ACL
          #{make_tab aux_field_transform, "  "}
          where = #{JSON.stringify pk_field} : req.#{pk_field}
          await db.#{model_name}.destroy({where}).cb defer(err, res); return cb err if err
          
          #{join_list search_jl, "  "}
          
          cb null
        
        
        """
    
    ctx.file_render "src/endpoint/db_model_#{model_name}.coffee", """
      #{join_list require_jl, ""}
      
      #{join_list code_jl, ""}
      """#"
    
    project_node = root.type_filter_search "project"
    has_search    = root.policy_get_val_use "has_search"
    if has_search
      search_node = project_node.tr_get_type_only_here "search"
      for index in search_node.data_hash.index_list
        continue if index.table_name != model_name
        ###
        # NOTE db was not touched, but you can make
        # NOTE commented part will not work with leveldb
        id_list = []
        for id in res.hits
          id_list.push id
        await db.#{index.table_name}.findAll({where:{id:id_list}, raw:true}).cb defer(err, db_doc_list); return cb err if err
        ###
        ctx.file_render "src/endpoint/#{index.name}_search.coffee", """
          meili_#{index.name} = require "../search/meili_#{index.name}"
          db = require "../#{index.db_name or 'db'}"
          
          @#{index.name}_search = (req, cb)->
            await meili_#{index.name}.doc_search {search:req.search}, defer(err, res); return cb err if err
            
            cb null, {
              search:res
            }
          """#"
    
    false

def "db_backend_struct", (name, name_opt = {}, crud_flag = "crlud", scope_fn=()->)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # TODO db selector
  # TODO backend selector
  project_node = mod_runner.current_runner.curr_root.type_filter_search "project"
  
  name_opt.db ?= ""
  name_opt.backend ?= ""
  db_node = project_node.tr_get_try "db", name_opt.db
  if !db_node
    throw new Error "db not found"
  
  backend_node = project_node.tr_get_try "backend", name_opt.backend
  if !backend_node
    throw new Error "backend not found"
  
  # ###################################################################################################
  # TODO register file
  # mod_runner.current_runner.root_wrap backend_node, ()->
    # fn ""
  
  # ###################################################################################################
  root = mod_runner.current_runner.curr_root.tr_get "db_backend_struct", name, "def"
  bdh_node_module_name_assign_on_call root, module, "db_backend_struct"
  
  root.policy_set_here_weak "has_create",     crud_flag.includes "c"
  root.policy_set_here_weak "has_read",       crud_flag.includes "r"
  root.policy_set_here_weak "has_read_list",  crud_flag.includes "l"
  root.policy_set_here_weak "has_update",     crud_flag.includes "u"
  root.policy_set_here_weak "has_delete",     crud_flag.includes "d"
  root.policy_set_here_weak "has_search",     false
  root.policy_set_here_weak "limit",          "1000"
  
  root.data_hash.db_name      ?= name_opt.db
  root.data_hash.backend_name ?= name_opt.backend
  root.data_hash.search_index_name_list ?= []
  root.data_hash.frontend     ?= false
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    backend_frontend_connect
# ###################################################################################################
bdh_module_name_root module, "backend_frontend_connect",
  nodegen       : (root, ctx)->
    project_node = root.type_filter_search "project"
    backend_node = project_node.tr_get_try "backend",   root.data_hash.backend_name
    frontend_node= project_node.tr_get_try "frontend",  root.data_hash.frontend_name
    
    # TODO
    ctx.inject_to frontend_node, ()->
      frontend_mod_iced()
      # # only if data path
      # frontend_mod_provider()
      if root.data_hash.model_name_list.length
        frontend_mod_db_mixin()
    
    false
  
  emit_codegen     : (root, ctx)->
    src_name_opt = ""
    # TODO WTF? remove?
    # src_name_opt = "_#{src.name}" if src.name
    
    project_node = root.type_filter_search "project"
    backend_node = project_node.tr_get_try "backend",   root.data_hash.backend_name
    frontend_node= project_node.tr_get_try "frontend",  root.data_hash.frontend_name
    
    ws_port = backend_node.policy_get_val_use "ws_port"
    # костыли. Неплохо бы функцию для получения порта, а не вот это вот в каждом
    port_increment = mod_runner.current_runner.root.data_hash.get_autoport_offset("backend", backend_node)
    ws_port += port_increment if backend_node.policy_get_here_is_weak "ws_port"
    
    # TODO move to policy?
    dst_needs_pubsub_mod = frontend_node.data_hash.ws_mod_sub
    # for dst_point in dst.point_list
    #   if dst_point.refresh_mode == "pubsub"
    #     dst_needs_pubsub_mod = true
    #     break
    
    ws_back_url = "ws_back_url#{src_name_opt}"
    ws_back     = "ws_back#{src_name_opt}"
    wsrs_back   = "wsrs_back#{src_name_opt}"
    
    aux_ws_mod_pubsub = ""
    if dst_needs_pubsub_mod
      aux_ws_mod_pubsub = """
        ws_mod_sub #{ws_back}, #{wsrs_back}
        """
    
    ctx.file_render "htdocs/_network_and_db/1_connect#{src_name_opt}.coffee", """
      #{ws_back_url} = "ws://\#{location.hostname}:#{ws_port}"
      window.#{ws_back}  = new Websocket_wrap #{ws_back_url}
      window.#{wsrs_back}= new Ws_request_service #{ws_back}
      #{aux_ws_mod_pubsub}
      
      loop
        await #{wsrs_back}.request {switch: "ping"}, defer(err), timeout:1000
        if err
          perr "ping hang/error -> reconnect backend=#{root.data_hash.backend_name} \#{#{ws_back_url}}", err.message
          #{ws_back}.ws_reconnect()
        await setTimeout defer(), 1000
      
      """#"
    
    # TODO. BUG. АЙ, db_mixin должен знать по какому wsrs общаться с БД
    for model_name in root.data_hash.model_name_list
      ctx.file_render "htdocs/db_model/#{model_name}.coffee", """
        class window.#{model_name.capitalize()}
          db_mixin @, #{JSON.stringify model_name}
          constructor : ()->
            db_mixin_constructor @, #{JSON.stringify model_name}
        
        """
    
    false

def "backend_frontend_connect", (name_opt = {}, scope_fn=()->)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # TODO. backend может быть в другом проекте внтури одной monorepo
  
  project_node = mod_runner.current_runner.curr_root.type_filter_search "project"
  
  name_opt.backend  ?= ""
  name_opt.frontend ?= ""
  
  # NOTE frontend, backend могут быть еще не определены
  if !backend_node = project_node.tr_get_try "backend", name_opt.backend
    throw new Error "backend name=#{name_opt.backend} not found"
  
  if !frontend_node = project_node.tr_get_try "frontend", name_opt.frontend
    throw new Error "frontend name=#{name_opt.frontend} not found"
  
  key = "#{name_opt.backend}_#{name_opt.frontend}"
  root = mod_runner.current_runner.curr_root.tr_get "backend_frontend_connect", key, "def"
  bdh_node_module_name_assign_on_call root, module, "backend_frontend_connect"
  
  root.data_hash.frontend_name  ?= name_opt.frontend
  root.data_hash.backend_name   ?= name_opt.backend
  root.data_hash.model_name_list?= []
  root.data_hash.fn_list        ?= []
  root.data_hash.data_point_list?= []
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    composite blocks
# ###################################################################################################
def "search_db_backend_struct", (name, name_opt = {}, crud_flag = "crlud", scope_fn=()->)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # TODO search selector
  project_node = mod_runner.current_runner.curr_root.type_filter_search "project"
  
  name_opt.search ?= ""
  search_node = project_node.tr_get_try "search", name_opt.search
  if !search_node
    throw new Error "search not found"
  
  # ###################################################################################################
  root = db_backend_struct name, name_opt, crud_flag, scope_fn
  root.policy_set_here "has_search", true
  
  root

def "db_backend_frontend_struct", (name, name_opt = {}, crud_flag = "crlud", scope_fn=()->)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # ###################################################################################################
  root = db_backend_struct name, name_opt, crud_flag, scope_fn
  root.data_hash.frontend = true
  
  node = backend_frontend_connect name_opt
  node.data_hash.model_name_list.upush name
  
  root

def "search_db_backend_frontend_struct", (name, name_opt = {}, crud_flag = "crlud", scope_fn=()->)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # ###################################################################################################
  root = search_db_backend_struct name, name_opt, crud_flag, scope_fn
  root.data_hash.frontend = true
  
  node = backend_frontend_connect name_opt
  node.data_hash.model_name_list.upush name
  
  root