module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  hydrator_def
  
  mod_runner
  mod_config
} = require "../../common_import"

policy_filter = (policy_obj)->
  return false if policy_obj.platform != "nodejs"
  return false if policy_obj.language != "iced"
  true

block_filter_gen = (type)->
  (root)->
    return false if root.type != type
    return false if root.policy_get_val_no_use("type") != "leveldb"
    true

# ###################################################################################################
obj_set @, require "./db_common"
obj_set @, require "./leveldb_generators"

banned_field_name_hash = {}
do ()->
  list = """
    # my loc vars
    cb
    doc
    key
    val
    k
    v
    key_buf
    val_buf
    err
    _err
    err_ret
    extra_err
    db
    loc_db
    model
    model_list
    ret
    ret_list
    exists
    exists_before
    ret_val_buf
    it
    walk
    walk_continue
    suffix
    suffix_list
    suffix_buf
    suffix_key
    _suffix_key
    metadata
    where
    attributes
    fast_request
    need_read_val
    found
    opt
    expd_length
    res
    offset
    buf
    found_list
    filter_found
    update_count
    update_hash
    key_buf_list
    k2
    v2
    delete_count
    delete_count_sup
    actually_deleted
    
    # my glob var
    p
    puts
    obj_set
    perr
    
    # my file-glob var
    module
    buf_pool
    config
    fs
    __metadata
    leveldown
    mkdirp
    Lock_mixin
    
    # control flow
    for
    in
    of
    if
    else
    while
    switch
    case
    when
    throw
    loop
    break
    continue
    
    # iced
    await
    defer
    unless
    or
    and
    on
    off
    
    # operators+
    instanceof
    typeof
    new
    function
    return
    class
    var
    
    # reserved values
    null
    undefined
    void
    this
    require
    global
    true
    false
    
    # global names
    Error
    Promise
    JSON
    """.split("\n")
  for v in list
    continue if !v
    continue if v.startsWith "#"
    banned_field_name_hash[v] = true
  return

# ###################################################################################################
#    db
# ###################################################################################################
bdh_module_name_root module, "db",
  nodegen       : (root, ctx)->
    npm_i "leveldown"
    npm_i "mkdirp"
    if root.policy_get_val_use("bson_ext")
      npm_i "bson-ext"
    else
      npm_i "bson" # потому что bson-ext имеет приколы
    
    npm_i "lock_mixin"
    mod_buf_pool()
    cache()
    
    project_node  = root.type_filter_search "project"
    project_name  = project_node.name
    root.data_hash.database_name = root.name or project_name
    
    config_prefix = "leveldb_"
    if root.name
      config_prefix = "leveldb_#{root.name}_"
    
    root.data_hash.config_prefix = config_prefix
    
    config()
    config_push "#{config_prefix}path", "str", JSON.stringify "cache/leveldb/#{root.data_hash.database_name}"
    
    false
  
  validator     : (root, ctx)->
    {db} = root.data_hash
    if db.migration_list.length > 1
      puts "WARNING. leveldb raw driver doesn't support migrations yet"
    
    for _k, model of db.final_model_hash
      field_list = Object.values model.field_hash
      if field_list.length == 0
        throw new Error "leveldb doesn't support models with no fields. model=#{model.name}"
      
      for field in field_list
        if banned_field_name_hash[field.name]
          throw new Error "bad field name. field.name=#{field.name}"
      
      # edge case'ы когда key/val encoder генерирует пустое
      # и когда в аргументах какая-то фигня
      key_field_count = 0
      val_field_count = 0
      for field in field_list
        continue if field.suffix
        if field.is_key
          key_field_count++
        else
          val_field_count++
      
      if key_field_count == 0
        if val_field_count == 0
          throw new Error "No field that can be used as key. model=#{model.name}"
        val_field_count--
        key_field_count++
      
      if val_field_count == 0
        throw new Error "No field that can be used as val. model=#{model.name}"
      
      for field in field_list
        if field.suffix
          if field.type in ["json", "buf"]
            throw new Error "suffix can't be json or buf. model=#{model.name}"
          if field.type in ["f32", "f64"]
            puts "WARNING. Suffix f32 or f64 is really bad idea. model=#{model.name}"
    
    false
  
  emit_codegen  : (root, ctx)->
    {
      db
      config_prefix
    } = root.data_hash
    
    ctx.tpl_copy "util/buf_pool.coffee", "misc", "src"
    
    # ###################################################################################################
    #    metadata
    # ###################################################################################################
    list2hash = (t)->
      ret = {}
      for v in t
        ret[v.name] = v
      ret
    
    model = {
      name : "__metadata"
      field_hash : list2hash [
        {
          name : "db_name"
          type : "str"
          # key  : true
          suffix: true
        }
        {
          name : "db_suffix"
          type : "buf"
          is_key  : true
        }
        {
          name : "count"
          type : "i64"
        }
        {
          name : "autoincrement"
          type : "i64"
        }
      ]
    }
    
    leveldb_src_path = "leveldb"
    leveldb_src_path = "leveldb_#{root.name}" if root.name != "leveldb"
    bson_ext = root.policy_get_val_use("bson_ext")
    
    # Прим. На самом деле количество обновлений metadata будет конечным
    # но меня все-равно не радует то, что metadata при обновлении может обновлять себя еще раз
    ctx.file_render "src/#{leveldb_src_path}/model/#{model.name}.coffee", module.model_code_gen model, {config_prefix, metadata : false, bson_ext}
    
    # ###################################################################################################
    #    models
    # ###################################################################################################
    # fix autoincrement
    for migration in db.migration_list
      for _k,model of migration.model_hash
        model.final_model.autoincrement = model.autoincrement
    
    for _k, model of db.final_model_hash
      ctx.file_render "src/#{leveldb_src_path}/model/#{model.name}.coffee", module.model_code_gen model, {config_prefix, metadata : true, bson_ext}
    
    # ###################################################################################################
    model_require_jl = []    
    close_jl = []
    model_require_jl.push """
      @__metadata = require "./model/__metadata"
      """#"
    close_jl.push """
      await module.__metadata.close defer(err); return cb err if err
      """
    
    for _k, model of db.final_model_hash
      model_require_jl.push """
        @#{model.name} = require "./model/#{model.name}"
        """#"
      close_jl.push """
        await module.#{model.name}.close defer(err); return cb err if err
        """
    
    ctx.file_render "src/#{leveldb_src_path}/index.coffee", """
      module = @
      #{join_list model_require_jl, ""}
      @close = (cb)->
        #{join_list close_jl, "  "}
        cb()
      
      # dummy
      @sequelize =
        literal : ()->
      """
    
    false

hydrator_def policy_filter, block_filter_gen("db"), (root)->
  bdh_node_module_name_assign_on_call root, module, "db"
  
  root.policy_set_here_weak "db_worker", false
  root.policy_set_here_weak "bson_ext", false
  root.data_hash.db ?= new module.DB
  
  return

# ###################################################################################################
#    db_migration
# ###################################################################################################
bdh_module_name_root module, "db_migration",
  nodegen       : (root, ctx)->
    if !db_node = root.type_filter_search "db"
      throw new Error "can't find any node with type db"
    
    {db} = db_node.data_hash
    
    migration = db.migration_get()
    migration.name = root.name
    
    root.data_hash.migration = migration
    
    false

hydrator_def policy_filter, block_filter_gen("db_migration"), (root)->
  bdh_node_module_name_assign_on_call root, module, "db_migration"
  return

# ###################################################################################################
#    struct
# ###################################################################################################
block_filter_gen = (type)->
  (root)->
    return false if root.type != type
    return false if !root.type_filter_search "db"
    return false if root.policy_get_val_no_use("type")  != "leveldb"
    return false if root.policy_get_val_no_use("driver")!= "raw"
    return false if root.parent.type != "db_migration"
    true

bdh_module_name_root module, "struct",
  nodegen       : (root, ctx)->
    if !db_node = root.type_filter_search "db"
      throw new Error "can't find any node with type db"
    
    {migration} = root.parent.data_hash
    model = migration.model_get root.name
    root.data_hash.model = model
    
    model.autoincrement = root.policy_get_val_use_default("autoincrement", true)
    
    ctx.walk_child_list_only_fn root
    
    true

hydrator_def policy_filter, block_filter_gen("struct"), (root)->
  bdh_node_module_name_assign_on_call root, module, "struct"
  return

# ###################################################################################################
#    field
# ###################################################################################################
block_filter_gen = (type)->
  (root)->
    return false if root.type != type
    return false if !root.type_filter_search "db"
    return false if root.policy_get_val_no_use("type")  != "leveldb"
    return false if root.policy_get_val_no_use("driver")!= "raw"
    return false if root.parent.type != "struct"
    true

bdh_module_name_root module, "field",
  nodegen       : (root, ctx)->
    if !db_node = root.type_filter_search "db"
      throw new Error "can't find any node with type db"
    
    {db} = db_node.data_hash
    
    {model} = root.parent.data_hash
    {type, opt} = root.data_hash
    field = model.field_get root.name
    field.type = type
    if opt.allow_null?
      field.allow_null = opt.allow_null
    if opt.default_value?
      field.default_value = opt.default_value
    if opt.custom_validator?
      field.custom_validator = opt.custom_validator
    if opt.rich_list_conf?
      field.rich_list_conf = opt.rich_list_conf
    if opt.key?
      field.is_key = opt.key
    if opt.suffix?
      field.suffix = opt.suffix
    if opt.as_string?
      field.as_string = opt.as_string
    
    migration_node      = root.type_filter_search "db_migration"
    field.migration_idx ?= migration_node.data_hash.migration.idx
    
    root.data_hash.field = field
    
    false

hydrator_def policy_filter, block_filter_gen("field"), (root)->
  bdh_node_module_name_assign_on_call root, module, "field"
  return
