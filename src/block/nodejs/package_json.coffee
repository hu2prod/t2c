module = @
fs = require "fs"
{exec} = require "child_process"
semver = require "semver"
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
  mod_config
} = wtf = require "../common_import"

# ###################################################################################################
#    utils
# ###################################################################################################
# NOTE
# npm, pnpm can/will change order of dependencies to alphabetical order
# snpm will not
npm_i_list_fn = (folder, list, cb)->
  cmd = "npm i #{list.join ' '}"
  await exec cmd, {cwd: folder}, defer(err); return cb err if err
  cb()

pnpm_i_list_fn= (folder, list, cb)->
  cmd = "pnpm i #{list.join ' '}"
  await exec cmd, {cwd: folder}, defer(err); return cb err if err
  cb()

snpm_i_list_slow_fn= (folder, list, cb)->
  # не требует списка, сам прочитает package.json
  cmd = "snpm i"
  
  await exec cmd, {cwd: folder}, defer(err); return cb err if err
  
  cb()

snpm_lock = new Lock_mixin
snpm_i_list_fast_fn= (folder, list, cb)->
  await snpm_lock.wrap cb, defer(cb)
  
  snpm_path = mod_config.local_config.snpm_path
  
  install = require "#{snpm_path}/src/install"
  await install {cwd: folder, quiet: true}, defer(err)
  
  cb err

snpm_i_list_fn= (folder, list, cb)->
  if snpm_path = mod_config.local_config?.snpm_path
    if fs.existsSync snpm_path
      snpm_i_list_fast_fn folder, list, cb
      return
    else
      puts "WARNING. local_config misconfiguration. snpm_path=#{snpm_path} not exists"
  snpm_i_list_slow_fn folder, list, cb

# костыль
@npm_i_list_fn  = npm_i_list_fn
@pnpm_i_list_fn = pnpm_i_list_fn
@snpm_i_list_fn = snpm_i_list_fn

# ###################################################################################################
#    package_json
# ###################################################################################################
bdh_module_name_root module, "package_json",
  # Подумать надо ли какая-то валидация
  # TODO нужно проверять что нет вложенных package_json
  # Неплохо бы как-то проверять что нет нескольких package_json с 1 папкой
  # Но это нельзя проверить из самого package_json
  #   Хотя, можно просто это будет делаться несколько раз (если не поставить флаг на корень)
  emit_codegen  : (root, ctx)->
    cont = root.data_hash.package_json
    ctx.file_render "package.json", JSON.stringify cont, null, 2
    false
  
  emit_min_deps : (root, ctx, cb)->
    package_manager = root.policy_get_val_use "package_manager"
    switch package_manager
      when "npm"
        pm_fn = npm_i_list_fn
      when "pnpm"
        pm_fn = pnpm_i_list_fn
      when "snpm"
        pm_fn = snpm_i_list_fn
      
      else
        return cb new Error "unknown package_manager '#{package_manager}'"
    
    folder = ctx.curr_folder
    package_json = JSON.parse fs.readFileSync "#{folder}/package.json"
    need_install_list = []
    for package_name, package_version of package_json.dependencies
      path_to_module = "#{folder}/node_modules/#{package_name}"
      if !fs.existsSync path_to_module
        # TODO other prefixes
        if package_version.startsWith "github"
          need_install_list.push package_version
        else
          need_install_list.push "#{package_name}@#{package_version}"
        continue
      
      if package_version.startsWith "github"
        # TODO check ... I don't know what, freshest commit in cache?
        continue
      
      target_package_json_file = "#{path_to_module}/package.json"
      if !fs.existsSync target_package_json_file
        need_install_list.push "#{package_name}@#{package_version}"
        continue
      
      mod_package_json = JSON.parse fs.readFileSync target_package_json_file
      if !semver.satisfies mod_package_json.version, package_version
        need_install_list.push "#{package_name}@#{package_version}"
    
    if need_install_list.length
      puts "need_install_list:"
      for v in need_install_list
        puts "  #{v}"
      await pm_fn folder, need_install_list, defer(err); return cb err if err
    
    cb()

def "package_json", ()->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  # немного под вопросом на какой root вешать
  # Т.к. gitignore может быть глобальным, а может быть на конкнетную папку
  
  root = mod_runner.current_runner.curr_root.tr_get "package_json", "package_json", "def"
  bdh_node_module_name_assign_on_call root, module, "package_json"
  root.data_hash.package_json ?= {}
  
  root

