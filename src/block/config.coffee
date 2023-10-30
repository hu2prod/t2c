module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "./common_import"

class @Config_ent
  name          : ""
  type          : ""
  default_value : ""

# ###################################################################################################
#    config
# ###################################################################################################
def "config", (scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # BUG. Уже +1 уровень вложенности от проекта даст проблему, что будет сгенерирован паразитный config
  # А он же перелупит все значения
  # Как минимум в валидации нужно проверять, что нет вложенных конфигов с одной и той же папкой
  
  # BUG. Ок. старый bug теперь не актуальный. Теперь новый прикол. Мы имеем только 1 конфиг на проект
  project_node = mod_runner.current_runner.curr_root.type_filter_search "project"
  root = project_node.tr_get "config", "config", "def"
  # root = mod_runner.current_runner.curr_root.tr_get "config", "config", "def"
  root.data_hash.name_to_config_ent_hash ?= {}
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root

# ###################################################################################################
#    config_push
# ###################################################################################################
def "config_push", (name, type, default_value="")->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # BUG. Ок. старый bug теперь не актуальный. Теперь новый прикол. Мы имеем только 1 конфиг на проект
  project_node = mod_runner.current_runner.curr_root.type_filter_search "project"
  root = project_node.tr_get_try "config", "config"
  # root = mod_runner.current_runner.curr_root.tr_get_try "config", "config"
  if !root
    throw new Error "config_push should be called after config"
  
  if c_ent = root.data_hash.name_to_config_ent_hash[name]
    if c_ent.type != type
      throw new Error "config_ent conflict name=#{name} old_type=#{c_ent.type} new_type=#{type}"
    if c_ent.default_value != default_value
      throw new Error "config_ent conflict name=#{name} old_default_value=#{c_ent.default_value} new_default_value=#{default_value}"
  else
    root.data_hash.name_to_config_ent_hash[name] = c_ent = new module.Config_ent
    c_ent.name = name
    c_ent.type = type
    c_ent.default_value = default_value
  
  root
