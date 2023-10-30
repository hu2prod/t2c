module = @
fs = require "fs"
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
  mod_config
} = require "../common_import"

# ###################################################################################################
#    llm
# ###################################################################################################
bdh_module_name_root module, "llm",
  nodegen  : (root, ctx)->
    npm_i "event_mixin"
    npm_i "lock_mixin"
    npm_i "axios"
    
    config()
    config_push "openai_api_key_list",   "str_list", JSON.stringify ""
    
    # TODO uppercase
    env "OPENAI_API_KEY_LIST=#{mod_config.local_config.openai_api_key_list}"

    #config_push "openai_llm_model", "str", JSON.stringify "gpt-3.5-turbo"
    config_push "openai_llm_model", "str", JSON.stringify "gpt-4"
    
    # для не upgrade account
    # 3 - не натыкался на rate limit
    # 10 - гарантированно натыкался на rate limit
    config_push "openai_max_parallel_req_per_key", "int", JSON.stringify "3"

    # подумать
    #config_push "llm_default_vendor", "str", JSON.stringify ""
    config_push "llm_default_vendor", "str", JSON.stringify "openai"
    config_push "llm_debug_stop_on_request", "bool", JSON.stringify "false"
    
    false
  
  emit_codegen : (root, ctx)->
    file_list = [
      "index.coffee"
      "def.coffee"
      "proxy.coffee"
      "vendor/openai.coffee"
    ]
    for file in file_list
      ctx.file_render "src/llm/#{file}", ctx.tpl_read "llm/#{file}"
    false

def "llm", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "llm", "llm", "def"
  bdh_node_module_name_assign_on_call root, module, "llm"
  
  root

# ###################################################################################################
#    llm db
# ###################################################################################################
bdh_module_name_root module, "llm_db",
  nodegen  : (root, ctx)->
    ctx.inject_to root.parent, ()->
      # Прим. не будет работать с leveldb т.к. leveldb не поддерживает пока enum
      struct "llm_state", ()->
        field "parent_state_id", "i64?"
        field "key_id", "i32?"
        field "vendor", "str"
        field "text_i_json", "text" # raw request
        field "text_o_json", "text?" # raw response
        
        # NOTE IDLE not used
        field "status", "enum(IDLE,SCHEDULED,PAUSED,IN_PROGRESS,ERROR_STREAM,ERROR_UNKNOWN,ERROR_RATE_LIMIT,DONE)"
        field "priority", "i32",
          default_value : 0
        field "in_queue_at", "i64",
          default_value : 0
        field "done_at", "i64",
          default_value : 0
        field "error", "text",
          default_value : ""
      
    false

# WTF
# def "db_migraion llm_db", ()->
def "llm_db", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  root = mod_runner.current_runner.curr_root.tr_get "llm_db", "llm_db", "def"
  bdh_node_module_name_assign_on_call root, module, "llm_db"
  
  root
