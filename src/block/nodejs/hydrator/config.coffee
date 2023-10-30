module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  hydrator_def
  
  mod_runner
} = require "../../common_import"

policy_filter = (policy_obj)->
  return false if policy_obj.platform != "nodejs"
  return false if policy_obj.language != "iced"
  true

block_filter_gen = (type)->
  (root)->
    root.type == type

@allowed_type_hash =
  bool    : true
  int     : true
  i32     : true
  f32     : true
  f64     : true
  str     : true
  str_list: true

# ###################################################################################################
#    config
# ###################################################################################################
bdh_module_name_root module, "config",
  nodegen       : (root, ctx)->
    npm_i "fy"
    npm_i "minimist"
    npm_i "dotenv-flow"
    
    false
  
  validator     : (root, ctx)->
    for k,v of root.data_hash.name_to_config_ent_hash
      if !module.allowed_type_hash[v.type]
        throw new Error "bad or unimplemented config type=#{v.type} name=#{k}"
    false
  
  emit_codegen  : (root, ctx)->
    # TODO arch autodetect
    curr_arch = "node16-linux-x64"
    config_jl = []
    
    for k,v of root.data_hash.name_to_config_ent_hash
      aux = ""
      if v.default_value
        aux = ", #{v.default_value}"
      config_jl.push "#{v.type.ljust 4} #{JSON.stringify v.name}#{aux}"
    
    ctx.file_render "src/config.coffee", """
      module = @
      require "fy"
      require("events").EventEmitter.defaultMaxListeners = Infinity
      global.arch = #{JSON.stringify curr_arch}
      argv = require("minimist")(process.argv.slice(2))
      config = Object.assign(require("dotenv-flow").config({silent:!!global.is_fork}).parsed || {}, process.env)
      for k,v of argv
        config[k.toUpperCase().split("-").join("_")] = v
      
      bool = (name, default_value = "0", config_name = name.toUpperCase())->
        module[name] = !!+(config[config_name] ? default_value)
      
      i32 = int  = (name, default_value = "0", config_name = name.toUpperCase())->
        module[name] = +(config[config_name] ? default_value)
      
      f32 = f64  = (name, default_value = "0", config_name = name.toUpperCase())->
        module[name] = +(config[config_name] ? default_value)
      
      str  = (name, default_value = "", config_name = name.toUpperCase())->
        module[name] = config[config_name] ? default_value
      
      str_list  = (name, default_value = "", config_name = name.toUpperCase())->
        module[name] = (config[config_name] ? default_value).split(",").filter (t)->t != ""
      
      # ###################################################################################################
      #{join_list config_jl, ""}
      
      """#"
    false

hydrator_def policy_filter, block_filter_gen("config"), (root)->
  bdh_node_module_name_assign_on_call root, module, "config"
  return
