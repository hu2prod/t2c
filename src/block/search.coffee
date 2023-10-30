module = @
fs = require "fs"
{execSync} = require "child_process"
mkdirp = require "mkdirp"
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
  mod_config
} = require "./common_import"

# TODO rework with hydrator
# add policy engine=meilisearch

# TODO tmux_starter

# ###################################################################################################
#    search
# ###################################################################################################
bdh_module_name_root module, "search",
  nodegen       : (root, ctx)->
    cache()
    npm_i "meilisearch"
    npm_i "lock_mixin"
    npm_i "minimist"
    gitignore "meilisearch-linux-amd64"
    
    db_path = "cache/meilisearch"
    db_path = "cache/meilisearch_#{root.name}" if root.name
    mkdirp.sync "cache/_meilisearch"
    
    # move to validate?
    for index in root.data_hash.index_list
      if !db_node = root.tr_get_deep "db", index.db_name
        throw new Error "can't find root.data_hash.db_name=#{index.db_name}"
      index.db_node = db_node
      index.db_type = db_node.policy_get_val_use "type"
    
    port_increment = mod_runner.current_runner.root.data_hash.get_autoport_offset("search", root)
    
    port =  root.policy_get_val_use "port"
    port += port_increment if root.policy_get_here_is_weak "port"
    
    config_push "meilisearch_connection_string", "str", JSON.stringify "http://127.0.0.1:#{port}"
    
    npm_script "search:start_dev"     , "./meilisearch-linux-amd64 --http-addr=127.0.0.1:#{port} --db-path=#{db_path} --no-analytics 2>&1 | tee cache/_meilisearch/meilisearch.log"
    npm_script "search:start"         , "./meilisearch-linux-amd64 --http-addr=127.0.0.1:#{port} --db-path=#{db_path} --no-analytics --log-level=WARN 2>&1 | tee cache/_meilisearch/meilisearch.log"
    # TODO 16000 policy
    npm_script "search:sync:all"      , "NODE_OPTIONS=--max_old_space_size=16000 ./src/search/sync.coffee"
    npm_script "search:sync:dry"      , "NODE_OPTIONS=--max_old_space_size=16000 ./src/search/sync.coffee --dry"
    # TODO
    # пока unimplemented
    # npm_script "search:sync:fast:all" , "NODE_OPTIONS=--max_old_space_size=16000 ./src/search/sync.coffee --fast"
    # npm_script "search:sync:fast:dry" , "NODE_OPTIONS=--max_old_space_size=16000 ./src/search/sync.coffee --dry --fast"
    
    for index in root.data_hash.index_list
      index_name = index.name
      
      npm_script "search:sync:#{index_name}", "NODE_OPTIONS=--max_old_space_size=16000 ./src/search/sync.coffee --index_name=#{index_name}"
    
    # TODO bigmap as ext block
    
    node = node_worker "meilisearch"
    node.data_hash.require_codebub =  'fs = require "fs"'
    node.data_hash.code_codebub =  '''
      if !/^[_a-z0-9]+$/i.test req.index_name
        return cb new Error "can't find index '#{req.index_name}'"
      
      mod_path = "../search/meili_#{req.index_name}.coffee"
      if !fs.existsSync require.resolve mod_path
        return cb new Error "can't find index '#{req.index_name}'"
      
      try
        mod = require mod_path
      catch err
        return cb err
      
      await mod.get_index defer(err, index); return cb err if err
      
      # NOTE semi-vulnerable, consider whitelist for methods
      if typeof index[req.method_name] != "function"
        return cb new Error "bad method '#{req.method_name}'"
      
      await index[req.method_name](req.req).cb defer(err, res); return cb err if err
      
      cb null, res
      '''#'
    
    starter_tmux_set "search #{root.name}", "dev", """
      cd #{ctx.curr_folder}
      npm run search:start_dev
      """
    
    starter_tmux_set "search #{root.name}", "prod", """
      cd #{ctx.curr_folder}
      npm run search:start
      """
    
    false
  
  emit_codegen  : (root, ctx)->
    ctx.tpl_copy "meilisearch-linux-amd64", "search", "."
    
    used_hash = {}
    for index in root.data_hash.index_list
      if index.db_type == "leveldb"
        if !used_hash.leveldb
          used_hash.leveldb = true
          ctx.file_render "src/search/meili_search_meta_leveldb.coffee", ctx.tpl_read "search/meili_search_meta_leveldb.coffee"
      else
        if !used_hash.db
          used_hash.db = true
          ctx.file_render "src/search/meili_search_meta.coffee", ctx.tpl_read "search/meili_search_meta.coffee"
    
    # ctx.tpl_copy "meili_search_meta.coffee", "search", "src/search"
    
    # TODO move to bigmap separate block
    ctx.file_render "src/util/bigmap.js", ctx.tpl_read "misc/bigmap.js"
    
    collection_sync_jl = []
    
    for index in root.data_hash.index_list
      index_name = index.name
      meili_util_file = "meili_#{index_name}"
      
      aux_db_patch = ""
      if index.db_name != ""
        aux_db_patch = """
          db = require "../#{index.db_name}"
          meili_search_meta_old = meili_search_meta
          meili_search_meta = (t)->
            t.db = db
            meili_search_meta_old t
          """#"
      
      file = "meili_search_meta"
      file = "meili_search_meta_leveldb" if index.db_type == "leveldb"
      
      aux_config_jl = []
      if index.db_type == "leveldb"
        table_description = index.db_node.data_hash.db.final_model_hash[index.table_name]
        
        key_field = null
        for k,field of table_description.field_hash
          key_field ?= field
          if field.is_key
            key_field = field
            break
        
        aux_config_jl.push """
          primary_key : #{JSON.stringify key_field.name}
          """
      
      if index.doc_transform
        aux_config_jl.push """
          doc_transform : #{index.doc_transform}
          """
      
      ctx.file_render "src/search/#{meili_util_file}.coffee", """
        meili_search_meta = require "./#{file}"
        #{aux_db_patch}
        obj_set @, meili_search_meta
          table_name: #{JSON.stringify index.table_name}
          index_name: #{JSON.stringify index_name}
          field_list: #{JSON.stringify index.field_list}
          #{join_list aux_config_jl, "  "}
        
        """#"
      
      collection_sync_jl.push """
        if !argv.index_name? or argv.index_name == #{JSON.stringify index_name}
          #{meili_util_file} = require "./#{meili_util_file}"
          if argv.fast
            await #{meili_util_file}.doc_sync_fast {}, defer(err); throw err if err
          else
            await #{meili_util_file}.doc_sync      {}, defer(err); throw err if err
        """#"
      
      # TODO backend endpoint for search
      # TODO inject update index to CRUD
    
    ctx.file_render_exec "src/search/sync.coffee", """
      #!/usr/bin/env iced
      ### !pragma coverage-skip-block ###
      argv = require("minimist")(process.argv.slice(2))
      
      #{join_list collection_sync_jl, ""}
      
      process.exit()
      
      """#"
    
    false
  
  emit_min_deps : (root, ctx, cb)->
    # Костыль
    # проблема в том, что cache создался на уровне project
    # и он будет выполняться очень сильно после текущей ноды
    mkdirp.sync "cache/meilisearch"
    cb null, false

def "search", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "search", name, "def"
  bdh_node_module_name_assign_on_call root, module, "search"
  root.data_hash.index_list ?= []
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root.policy_set_here_weak "port", 7700
  
  root

# TODO db_name
# TODO check table_name exists
def "search_db_index", (table_name, field_list_str, db_name, opt={})->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  search_node = mod_runner.current_runner.curr_root.type_filter_search "search"
  if !search_node
    project_node = mod_runner.current_runner.curr_root.type_filter_search "project"
    search_node = project_node.tr_get_type_only_here "search"
  
  if !search_node
    throw new Error "can't find search node"
  
  field_list = field_list_str.split /\s+/g
  search_node.data_hash.index_list.push {
    name : "#{table_name}__#{field_list.join '_'}"
    table_name
    field_list
    db_name : db_name ? ""
    doc_transform : opt.doc_transform
  }
  
  return
