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
    return false if root.policy_get_val_no_use("driver") != "sequelize"
    true

# ###################################################################################################
obj_set @, require "./db_common"

@sequelize_map_hash =
  i32   : "INTEGER"
  i64   : "BIGINT"
  f32   : "FLOAT"
  str   : "STRING"
  string: "STRING"
  text  : "TEXT"
  bool  : "BOOLEAN"
  json  : "JSONB"
  jsonb : "JSONB"
  date  : "DATE"
  # TODO buf (bytea)

@allowed_id_type_hash =
  i32   : true
  i64   : true
  str   : true
  string: true

@allowed_id_autoincrement_hash =
  i32   : true
  i64   : true
  str   : false
  string: false

@dyn_enum_id_type   = "i32"
@dyn_enum_base_sequelize_type = "JSONB"
@dyn_enum_validator = """
  function(val) {
    if (val == null) return;
    if (!(val instanceof Array)) {
      throw new Error("dyn enum should be array")
    }
    for(var i=0,len=val.length;i<len;i++) {
      if (typeof val[i] != "string" || typeof +val[i] != "number") {
        throw new Error("dyn enum should be array of string integers")
      }
    }
  }
  """#"

@child_id_list_validator  = """
  function(val) {
    if (val == null) return;
    if (!(val instanceof Array)) {
      throw new Error("child_id_list should be array")
    }
    for(var i=0,len=val.length;i<len;i++) {
      if (typeof val[i] != "string" || typeof +val[i] != "number") {
        throw new Error("child_id_list should be array of string integers")
      }
    }
  }
  """#"

# ###################################################################################################
field_list_parse = (opt)->
  {field_list} = opt
  migration_model_descriptor_jl = []
  migration_model_descriptor_no_key_hash = {}
  for field in field_list
    # t1c -> sequelize
    name = field.name
    type = field.type
    
    default_value     = undefined
    default_value_opt = field.default_value
    allow_null        = field.allow_null
    
    type_orig = type
    
    if !/^[_a-z][_a-z0-9]*$/.test name
      throw new Error "bad identifier for field name #{name}"
    
    basic_hash_jl = [
      "allowNull: #{JSON.stringify allow_null}"
    ]
    if module.sequelize_map_hash[type]
      basic_hash_jl.push "type: Sequelize.#{module.sequelize_map_hash[type]}"
      
      if default_value_opt?
        switch type
          when "bool"
            unless default_value_opt in [true, false]
              throw new Error "bad format for #{type} #{default_value_opt}"
            default_value = default_value_opt
          
          when "i32"
            if !/^\-?\d+$/.test default_value_opt
              throw new Error "bad format for #{type} #{default_value_opt}"
            default_value = +default_value_opt
          
          when "i64"
            if !/^\-?\d+$/.test default_value_opt
              throw new Error "bad format for #{type} #{default_value_opt}"
            default_value = default_value_opt
          
          when "f32"
            val = parseFloat default_value_opt
            if isFinite val
              throw new Error "bad format for #{type} #{default_value_opt}"
            default_value = val
          
          when "str", "string", "text"
            default_value = default_value_opt
          
          when "json", "jsonb"
            default_value = default_value_opt
            # try
            #   default_value = JSON.parse default_value_opt
            # catch e
            #   throw new Error "bad format for #{type} #{default_value_opt}. #{e.message}"
            
          else
            throw new Error "unimplemented default_value for #{type}"
        
    else if type.startsWith "enum"
      if !reg_ret = /^enum\((.+)\)$/.exec type
        throw new Error "bad enum #{type}"
      [_skip, value_list_str] = reg_ret
      value_list = value_list_str.split ","
      
      if default_value_opt?
        if value_list.has default_value_opt
          default_value = default_value_opt
        else if default_value_opt
          default_value = value_list[default_value_opt]
          if !default_value
            throw new Error "bad format for #{type} #{default_value_opt}. bad index"
        else
          throw new Error "bad format for #{type} #{default_value_opt}"
      
      basic_hash_jl.push "type: Sequelize.ENUM(#{JSON.stringify value_list})"
    else if type.startsWith "dyn_enum_"
      if !reg_ret = /^dyn_enum_(.+)$/.exec type
        throw new Error "bad dyn_enum #{type}"
      [_skip, dyn_enum_name] = reg_ret
      
      type = type.replace /^dyn_enum_/, ""
      
      basic_hash_jl.push "type: Sequelize.JSONB"
      if !allow_null
        # Нужно проверить
        # default_value = "[]"
        default_value = []
      
      if default_value_opt?
        throw new Error "default value is not expected for #{type}"
      
      basic_hash_jl.push """
        validate : {
          customValidator : #{make_tab module.dyn_enum_validator, '  '}
        }
        """
    else
      throw new Error "unknown type '#{type}'"
    
    if default_value != undefined
      basic_hash_jl.push "defaultValue: #{JSON.stringify default_value}"
    
    if custom_validator = field.custom_validator
      basic_hash_jl.push """
        validate : {
          customValidator : #{make_tab custom_validator, '  '}
        }
        """
    
    migration_model_descriptor_jl.push """
      #{JSON.stringify name} : {
        #{make_tab basic_hash_jl.join(',\n'), '  '}
      },
      """
    migration_model_descriptor_no_key_hash[name] = """
      {
        #{make_tab basic_hash_jl.join(',\n'), '  '}
      }
      """
  
  {migration_model_descriptor_jl, migration_model_descriptor_no_key_hash}

# ###################################################################################################
#    db
# ###################################################################################################
bdh_module_name_root module, "db",
  nodegen       : (root, ctx)->
    root.data_hash.db.migration_idx = 0
    npm_i "sequelize"
    npm_i "sequelize-cli"
    npm_i "pg"
    
    npm_script "db:create"          , "sequelize-cli db:create"
    npm_script "db:migrate"         , "sequelize-cli db:migrate"
    npm_script "db:migrate:undo"    , "sequelize-cli db:migrate:undo"
    npm_script "db:migrate:undo:all", "sequelize-cli db:migrate:undo:all"
    
    project_node  = root.type_filter_search "project"
    project_name  = project_node.name
    root.data_hash.database_name = root.name or "#{project_name}_database_development"
    
    env "SEQUELIZE_USERNAME=postgres"
    env "SEQUELIZE_PASSWORD=#{mod_config.local_config.sequelize_password}"
    env "SEQUELIZE_DATABASE=#{root.data_hash.database_name}"
    env "SEQUELIZE_HOST=127.0.0.1"
    env "SEQUELIZE_DIALECT=postgres"
    env "SEQUELIZE_LOGGING=0"
    
    false
  
  validator     : (root, ctx)->
    # TODO
    # Проверить что в корне есть только 1 db
    # sequelize-cli не будет нормально работать если добавить префиксы
    # а если не добавлять то разные entity db друг друга перезапишут
    
    false
  
  emit_codegen  : (root, ctx)->
    {db} = root.data_hash
    
    # Прим. предложение ctx.file_render_ne
    # TODO rename to singular model, seeder, migration
    ctx.file_render ".sequelizerc", """
      path = require("path");
      
      module.exports = {
        "config"          : path.resolve("src/db/config.js"),
        "models-path"     : path.resolve("src/db/models"),
        "seeders-path"    : path.resolve("src/db/seeders"),
        "migrations-path" : path.resolve("src/db/migrations")
      };
      """#"
    
    ctx.file_render "src/db/config.js", """
      var config = Object.assign(require("dotenv-flow").config({silent:true}).parsed || {}, process.env)
      module.exports = {
        development: {
          username: config.SEQUELIZE_USERNAME,
          password: config.SEQUELIZE_PASSWORD,
          database: config.SEQUELIZE_DATABASE,
          host    : config.SEQUELIZE_HOST,
          dialect : config.SEQUELIZE_DIALECT,
          logging : !!+config.SEQUELIZE_LOGGING
        },
        test: {
          username: config.SEQUELIZE_USERNAME,
          password: config.SEQUELIZE_PASSWORD,
          database: config.SEQUELIZE_DATABASE,
          host    : config.SEQUELIZE_HOST,
          dialect : config.SEQUELIZE_DIALECT,
          logging : !!+config.SEQUELIZE_LOGGING
        },
        production: {
          username: config.SEQUELIZE_USERNAME,
          password: config.SEQUELIZE_PASSWORD,
          database: config.SEQUELIZE_DATABASE,
          host    : config.SEQUELIZE_HOST,
          dialect : config.SEQUELIZE_DIALECT,
          logging : !!+config.SEQUELIZE_LOGGING
        }
      };
      """#"
    
    ctx.file_render "src/db/models/index.js", '''
      "use strict";
      
      const fs = require("fs");
      const path = require("path");
      const Sequelize = require("sequelize");
      const basename = path.basename(__filename);
      const env = process.env.NODE_ENV || "development";
      const config = require(__dirname + "/../config.js")[env];
      const db = {};
      
      let sequelize;
      if (config.use_env_variable) {
        sequelize = new Sequelize(process.env[config.use_env_variable], config);
      } else {
        sequelize = new Sequelize(config.database, config.username, config.password, config);
      }
      
      fs
        .readdirSync(__dirname)
        .filter(file => {
          return (file.indexOf(".") !== 0) && (file !== basename) && (file.slice(-3) === ".js");
        })
        .forEach(file => {
          const model = require(path.join(__dirname, file))(sequelize, Sequelize.DataTypes);
          db[model.name] = model;
        });
      
      Object.keys(db).forEach(modelName => {
        if (db[modelName].associate) {
          db[modelName].associate(db);
        }
      });
      
      db.sequelize = sequelize;
      db.Sequelize = Sequelize;
      
      module.exports = db;
      
      '''#'
    
    # ###################################################################################################
    #    models
    # ###################################################################################################
    for _k, model of db.final_model_hash
      field_list = Object.values model.field_hash
      id_type = "BIGINT"
      id_autoIncrement = true
      filtered_field_list = []
      for field in field_list
        {name, type} = field
        
        if name == "id"
          if !module.allowed_id_type_hash[type]
            throw new Error "not allowed id type #{type}"
          id_type = module.sequelize_map_hash[type]
          id_autoIncrement = module.allowed_id_autoincrement_hash[type]
          # extra protection
          if !id_type
            throw new Error "not allowed id type #{type} [2]"
          if !id_autoIncrement?
            throw new Error "not allowed id type #{type} [2]"
          continue
        
        filtered_field_list.push field
      
      field_list = filtered_field_list
      loc_opt = {
        field_list
      }
      {migration_model_descriptor_jl} = field_list_parse loc_opt
      
      # missing? model.name -> model.name.capitalize()
      ctx.file_render "src/db/models/#{model.name}.js", """
        \"use strict\";
        const {
          Model
        } = require(\"sequelize\");
        
        module.exports = (sequelize, Sequelize) => {
          class #{model.name} extends Model {
            /**
             * Helper method for defining associations.
             * This method is not a part of Sequelize lifecycle.
             * The `models/index` file will call this method automatically.
             */
            static associate(models) {
              // define association here
            }
          };
          #{model.name}.init({
            #{make_tab migration_model_descriptor_jl.join('\n'), '    '}
          }, {
            sequelize,
            freezeTableName : true,
            modelName: #{JSON.stringify model.name},
          });
          return #{model.name};
        };
        
        """#"
    
    # ###################################################################################################
    #    migration
    # ###################################################################################################
    
    model_hash = {}
    for migration, migration_idx in db.migration_list
      migration_pos_jl = []
      migration_neg_jl = []
      
      # ###################################################################################################
      #    model create and model field add
      # ###################################################################################################
      # TODO also field remove ???
      for _k, model of migration.model_hash
        if !model_hash[model.name]
          model_hash[model.name] = true
          # COPYPASTE
          field_list = Object.values model.field_hash
          id_type = "BIGINT"
          id_autoIncrement = true
          filtered_field_list = []
          for field in field_list
            {name, type} = field
            
            if name == "id"
              if !module.allowed_id_type_hash[type]
                throw new Error "not allowed id type #{type}"
              id_type = module.sequelize_map_hash[type]
              id_autoIncrement = module.allowed_id_autoincrement_hash[type]
              # extra protection
              if !id_type
                throw new Error "not allowed id type #{type} [2]"
              if !id_autoIncrement?
                throw new Error "not allowed id type #{type} [2]"
              continue
            
            filtered_field_list.push field
          
          field_list = filtered_field_list
          loc_opt = {
            field_list
          }
          {migration_model_descriptor_jl} = field_list_parse loc_opt
          # COPYPASTE END
          
          migration_pos_jl.push """
            await queryInterface.createTable(#{JSON.stringify model.name}, {
              id: {
                allowNull: false,
                autoIncrement: #{JSON.stringify id_autoIncrement},
                primaryKey: true,
                type: Sequelize.#{id_type}
              },
              #{make_tab migration_model_descriptor_jl.join('\n'), '  '}
              createdAt: {
                allowNull: false,
                type: Sequelize.DATE
              },
              updatedAt: {
                allowNull: false,
                type: Sequelize.DATE
              }
            }, { transaction: transaction });
            """#"
          migration_neg_jl.push """
            await queryInterface.dropTable(#{JSON.stringify model.name}, {transaction: transaction});
            """#"
          
        else
          field_list = []
          for k, field of model.field_hash
            continue if field.migration_idx != migration_idx
            field_list.push field
          
          if field_list.length
            loc_opt = {
              field_list
            }
            {migration_model_descriptor_no_key_hash} = field_list_parse loc_opt
            
            for field, field_descriptor of migration_model_descriptor_no_key_hash
              migration_pos_jl.push """
                await queryInterface.addColumn(#{JSON.stringify model.name}, #{JSON.stringify field}, #{field_descriptor}, {transaction: transaction});
                """
              migration_neg_jl.push """
                await queryInterface.removeColumn(#{JSON.stringify model.name}, #{JSON.stringify field}, {transaction: transaction});
                """
      
      for _k, index_descriptor of migration.index_hash
        {table_name, field_list} = index_descriptor
        # TODO check fields exist
        
        index_opt = {}
        index_opt.unique = true if index_descriptor.is_unique
        
        # HACKY transaction inject
        index_opt_json = JSON.stringify index_opt, null, 2
        if index_opt_json == "{}"
          index_opt_json = "{transaction: transaction}"
        else
          index_opt_json = index_opt_json.substr(0, index_opt_json.length-1)+"\n,  transaction: transaction\n}"
        
        migration_pos_jl.push """
          await queryInterface.addIndex(#{JSON.stringify table_name}, #{JSON.stringify field_list}, #{index_opt_json});
          """
        migration_neg_jl.push """
          await queryInterface.removeIndex(#{JSON.stringify table_name}, #{JSON.stringify field_list}, #{index_opt_json});
          """
      
      migration_name = migration.name or "migration_#{migration_idx}"
      ctx.file_render "src/db/migrations/#{migration_name}.js", """
        module.exports = {
          up: (queryInterface, Sequelize) => {
            return queryInterface.sequelize.transaction(async (transaction) => {
              #{join_list migration_pos_jl, '      '}
            });
          },
          down: (queryInterface, Sequelize) => {
            return queryInterface.sequelize.transaction(async (transaction) => {
              #{join_list migration_neg_jl, '      '}
            });
          }
        };
        """#"
    
    # ###################################################################################################
    #    
    # ###################################################################################################
    # Потом тут будет worker policy
    
    # TODO LATER, чтобы не захламляло
    # ctx.file_render "src/db/index.coffee", """
    ctx.file_render "src/db.coffee", """
      module.exports = require "./db/models"
      
      """#"
    
    false

hydrator_def policy_filter, block_filter_gen("db"), (root)->
  bdh_node_module_name_assign_on_call root, module, "db"
  
  root.policy_set_here_weak "db_worker", false
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
    
    migration = root.data_hash.migration ? db.migration_get()
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
    return false if root.policy_get_val_no_use("driver") != "sequelize"
    return false if root.parent.type != "db_migration"
    true

bdh_module_name_root module, "struct",
  nodegen       : (root, ctx)->
    if !db_node = root.type_filter_search "db"
      throw new Error "can't find any node with type db"
    
    {migration} = root.parent.data_hash
    model = migration.model_get root.name
    root.data_hash.model = model
    if root.data_hash.rich_list_key_width
      root.data_hash.model.final_model.rich_list_key_width = root.data_hash.rich_list_key_width
    if root.data_hash.rich_list_value_width
      root.data_hash.model.final_model.rich_list_value_width = root.data_hash.rich_list_value_width
    
    ctx.walk_child_list_only_fn root
    
    for k, field of model.field_hash
      if field.type.startsWith "dyn_enum_"
        type = field.type.replace /^dyn_enum_/, ""
        ctx.inject_to root.parent, ()->
          db_dyn_enum type
    
    
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
    return false if root.policy_get_val_no_use("driver") != "sequelize"
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
    
    migration_node      = root.type_filter_search "db_migration"
    field.migration_idx ?= migration_node.data_hash.migration.idx
    
    root.data_hash.field = field
    
    false

hydrator_def policy_filter, block_filter_gen("field"), (root)->
  bdh_node_module_name_assign_on_call root, module, "field"
  return

# ###################################################################################################
#    db_index
# ###################################################################################################
block_filter_gen = (type)->
  (root)->
    return false if root.type != type
    # return false if !root.type_filter_search "db"
    return false if root.policy_get_val_no_use("driver") != "sequelize"
    return false if root.parent.type != "struct"
    true

bdh_module_name_root module, "db_index",
  nodegen       : (root, ctx)->
    if !db_node = root.type_filter_search "db"
      throw new Error "can't find any node with type db"
    
    {db} = db_node.data_hash
    
    {field_list_str} = root.data_hash
    {model} = root.parent.data_hash
    {migration} = root.parent.parent.data_hash
    
    key = "#{model.name}_#{field_list_str}"
    db_index = migration.index_get key
    db_index.table_name = model.name
    db_index.field_list = field_list_str.split " "
    if db_index.field_list.has "unique"
      db_index.field_list.remove "unique"
      db_index.is_unique = true
    
    false

hydrator_def policy_filter, block_filter_gen("db_index"), (root)->
  bdh_node_module_name_assign_on_call root, module, "db_index"
  return

# ###################################################################################################
#    db_dyn_enum
# ###################################################################################################
block_filter_gen = (type)->
  (root)->
    return false if root.type != type
    return false if !root.type_filter_search "db"
    return false if root.policy_get_val_no_use("driver") != "sequelize"
    return false if root.parent.type != "db_migration"
    true

bdh_module_name_root module, "db_dyn_enum",
  nodegen       : (root, ctx)->
    {name} = root
    ctx.inject_to root.parent, ()->
      struct "dyn_enum_#{name}", ()->
        field "title",    "str"
        field "order",    "i32",
          default_value : 0
        field "deleted",  "bool",
          default_value : false
        field "value",    "json",
          allow_null    : true
          default_value : null
        field "child_id_list",  "json",
          default_value : []
          custom_validator : module.dyn_enum_validator
    
    false

hydrator_def policy_filter, block_filter_gen("db_dyn_enum"), (root)->
  bdh_node_module_name_assign_on_call root, module, "db_dyn_enum"
  return

