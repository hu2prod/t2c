module = @
fs = require "fs"
os = require "os"
{spawn, exec, execSync} = require "child_process"
require "lock_mixin"
runner    = require "../engine/runner.coffee"
require "../block_import"
topo_sort = require "./topo_sort"

# неудобно смотреть ошибки когда загораживает js stacktrace
exec_sync_pp = (cmd, opt)->
  obj_set opt, {stdio:"inherit"}
  err = null
  try
    execSync cmd, opt
    return
  catch _err
    err = _err
  
  if !global.is_test
    process.exit(1)
  throw err

@task_dep_cl_list_hash =
  "build2": ["build1"]
  "test"  : ["build1", "build2"]
  "reload": ["build1", "build2"]

@task_to_fn = {}

@check_monorepo = (opt)->
  fs.existsSync "#{opt.root_folder}/monorepo.json"

@task_to_fn.build1 = @task_build1_direct = (opt, cb)->
  await runner.go opt, defer(err); return cb err if err
  cb()

@task_to_fn.build2 = @task_build2_direct = (opt, cb)->
  conf = {
    root_ent_list : []
    ent_hash      : {}
  }
  walk_collect = (path, is_root)->
    return if !fs.existsSync "#{path}/build2.json"
    loc_conf = JSON.parse fs.readFileSync "#{path}/build2.json"
    if is_root
      conf.root_ent_list = loc_conf.ent_list
    
    for ent in loc_conf.ent_list
      ent.path = path
      conf.ent_hash[ent.name] = ent
    
    # for file in loc_conf.ext_import_file_list
      # walk_collect file, false
    return
  
  walk_collect opt.root_folder, true
  
  ent_run = (ent, cb)->
    return cb() if ent.done
    for dep in ent.dependency_list
      sub_ent = conf.ent_hash[dep]
      if !sub_ent
        return cb new Error "unknown dependency '#{dep}'"
      await ent_run sub_ent, defer(err); return cb err if err
    
    # TODO async
    exec_sync_pp ent.payload, {cwd: ent.path}
    
    ent.done = true
    cb()
  
  # can be parallel
  for ent in conf.root_ent_list
    await ent_run ent, defer(err); return cb err if err
  
  cb()

# ###################################################################################################
#    
# ###################################################################################################
@task_build1 = (opt, cb)->
  await module.task_build1_direct opt, defer(err); return cb err if err
  
  if !module.check_monorepo opt
    return cb()
  
  loc_opt = clone opt
  loc_opt.task_list = ["build1"]
  await module.multi_task loc_opt, defer(err); return cb err if err
  
  cb()

@task_build2 = (opt, cb)->
  await module.task_build1_direct opt, defer(err); return cb err if err
  # SUBOPTIMAL
  await module.task_build2_direct opt, defer(err); return cb err if err
  
  if !module.check_monorepo opt
    return cb()
  
  loc_opt = clone opt
  loc_opt.task_list = ["build1", "build2"]
  await module.multi_task loc_opt, defer(err); return cb err if err
  
  cb()

# ###################################################################################################
#    multi_task
# ###################################################################################################
# ВАЖНО task_list должен быть упорядочен
@multi_task = (opt, cb)->
  monorepo_conf_file = "#{opt.root_folder}/monorepo.json"
  try
    conf = JSON.parse fs.readFileSync monorepo_conf_file
  catch err
    return cb err
  
  repo_conf_hash = {}
  for repo in conf.repo_list
    monorepo_conf_file = "#{opt.root_folder}/#{repo}/monorepo.json"
    try
      repo_conf = JSON.parse fs.readFileSync monorepo_conf_file
    catch err
      return cb err
    repo_conf_hash[repo] = repo_conf
  
  cl_task_list = []
  for task in opt.task_list
    if cl_dep_list = module.task_dep_cl_list_hash[task]
      cl_task_list.uappend cl_dep_list
    
    cl_task_list.upush task
  
  # ###################################################################################################
  #    DAG build
  # ###################################################################################################
  task_repo_hash = {}
  for task in cl_task_list
    for k, repo of repo_conf_hash
      name = "#{task}::#{repo.name}"
      task_repo = {
        name
        task
        repo
        _i_link_list : []
        _o_link_list : []
      }
      task_repo_hash[name] = task_repo
  
  for k, src in task_repo_hash
    {task,repo} = src
    if require_hash = repo.task_require_hash[task]
      for k,target_repo_name of require_hash
        dst = task_repo_hash["#{task}::#{target_repo_name}"]
        if !dst
          throw new Error "Unexpected monorepo.json repo=#{repo.name} task_require_hash[#{task}] target_repo_name=#{target_repo_name}"
        
        src._o_link_list.push dst
        dst._i_link_list.push src
  
  for task in opt.task_list
    continue if !cl_dep_list = module.task_dep_cl_list_hash[task]
    for task in cl_task_list
      for k, repo of repo_conf_hash
        dst_name = "#{task}::#{repo.name}"
        dst = task_repo_hash[dst_name]
        for src_task in cl_dep_list
          src_name = "#{src_task}::#{repo.name}"
          src = task_repo_hash[src_name]
          
          src._o_link_list.push dst
          dst._i_link_list.push src
  
  task_repo_conf_list = Object.values task_repo_hash
  if task_repo_conf_list.length == 0
    return cb()
  
  topo_sort task_repo_conf_list
  
  # ###################################################################################################
  #    locked run
  # ###################################################################################################
  lock = new Lock_mixin
  # runner пока не умеет в раздельные контексты
  # Более того runner синхронный (хоть и имеет асинхронный интерфейс), а значит не будет параллелизации
  # нужно оборачивать в worker
  # lock.$limit = os.cpus().length
  
  lock_hash = {}
  for task,repo_hash of conf.task_mex_group_hash
    for repo,_v of repo_hash
      lock_hash["#{task}::#{repo}"] = new Lock_mixin
  
  err_throw = null
  task_in_progress_list = []
  await
    for task_repo in task_repo_conf_list
      loc_cb = defer()
      do (task_repo, loc_cb)->
        {task, repo} = task_repo
        if extra_lock = lock_hash[task_repo.name]
          await extra_lock.wrap loc_cb, defer(loc_cb)
        await lock.wrap loc_cb, defer(loc_cb)
        # TODO better reporter. All tasks in progress
        
        task_in_progress_list.push task_repo.name
        puts "wip=#{task_in_progress_list.length} #{task_repo.name} start"
        
        fn = module.task_to_fn[task]
        if !fn
          err_throw = new Error "unknown task '#{task}'"
          return loc_cb()
        
        loc_opt = clone opt
        loc_opt.root_folder = opt.root_folder + "/#{repo.name}"
        loc_opt.verbose_repo_prefix = repo.name
        
        await fn loc_opt, defer(err);
        
        task_in_progress_list.remove task_repo.name
        if err
          err_throw = err
          puts "wip=#{task_in_progress_list.length} #{task_repo.name} FAIL", err
        else
          puts "wip=#{task_in_progress_list.length} #{task_repo.name} ok"
        
        loc_cb()
  
  if err_throw
    return cb err_throw
  
  return cb()
