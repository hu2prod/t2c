module = @
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  mod_runner
} = require "../common_import"

# TODO make portable (not only nodejs)
# NOTE iced only. TODO move to hydrator
# ###################################################################################################
#    node_worker
# ###################################################################################################
bdh_module_name_root module, "node_worker",
  nodegen       : (root, ctx)->
    npm_i "node-worker-threads-pool"
    npm_i "iced-coffee-script"
    false
  
  validator     : (root, ctx)->
    if !/^[_a-z][_a-z0-9]*$/.test root.name
      return cb new Error "bad identifier for worker_name #{root.name}"
    false
  
  emit_codebub  : (root, ctx)->
    if !root.data_hash.require_codebub
      if ctx.exists path = "worker_require_#{root.name}.coffee"
        root.data_hash.require_codebub = ctx.render path, ""
    
    if !root.data_hash.code_codebub
      root.data_hash.code_codebub = ctx.render "worker_#{root.name}.coffee", """
        # put your code here
        cb null, {
          ok: true
        }
        """
    
    false
  
  emit_codegen  : (root, ctx)->
    worker_name = root.name
    
    require_code = root.data_hash.require_codebub
    code = root.data_hash.code_codebub
    
    ctx.file_render "./src/worker/_#{worker_name}.coffee", """
      module = @
      require "fy"
      {parentPort, workerData} = require "worker_threads"
      #{require_code}
      
      job = (req, cb)->
        #{make_tab code, '  '}
      
      # moved here because istanbul error
      job_bucket = (req, cb)->
        err_res_list = new Array req.req_list.length
        await
          for task, task_idx in req.req_list
            loc_cb = defer()
            do (task, task_idx, loc_cb)->
              await job task, defer(err, res)
              err_res_list[task_idx] = {err,res,req_uid:task.req_uid}
              loc_cb()
        
        cb null, {err_res_list}
      
      handler = (req, cb)->
        switch req.switch
          when "ping"
            cb()
          
          when "reinit"
            # put your code here
            cb()
          
          when "job"
            job req, cb
          
          when "job_bucket"
            job_bucket req, cb
          
          when "close"
            # TODO code for free all resources
            cb()
        
        return
      
      parentPort?.on "message", (req) =>
        handler req, (err, res)->
          parentPort.postMessage({err, res, req_uid:req.req_uid, switch:req.switch})
      
      """#"
    
    ctx.file_render "./src/worker/_#{worker_name}_wrap.js", """
      require("iced-coffee-script").register()
      global.is_fork = true
      module.exports = require("./_#{worker_name}")
      
      """#"
    
    ctx.file_render "./src/worker/#{worker_name}.coffee", """
      module = @
      os = require "os"
      {StaticPool} = require "node-worker-threads-pool"
      cpu_core_count = os.cpus().length
      if /Ryzen/.test os.cpus()[0].model
        # LOL faster, ryzen's "hyperthreading"
        cpu_core_count = Math.max 1, cpu_core_count // 2
      
      @_worker_pool = worker_pool = new StaticPool {
        size : cpu_core_count
        task : require.resolve "./_#{worker_name}_wrap.js"
      }
      
      @job = (req, cb)->
        loc_opt = {
          switch : "job"
        }
        obj_set loc_opt, req
        await worker_pool.exec(loc_opt).cb defer(err, wrap); return cb err if err
        {err, res} = wrap
        cb err, res
      
      @_job_bucket_queue_list = []
      # TODO config
      bucket_threshold_count = 100
      bucket_threshold_ms    = 10
      
      _job_bucket_loop_launched = false
      _job_bucket_loop_launch = ()->
        return if _job_bucket_loop_launched
        _job_bucket_loop_launched = true
        while module._job_bucket_queue_list.length
          start_ts = Date.now()
          loop
            now = Date.now()
            if module._job_bucket_queue_list.length > bucket_threshold_count or now - start_ts > bucket_threshold_ms
              loc_job_bucket_queue_list     = module._job_bucket_queue_list.slice(0, bucket_threshold_count)
              module._job_bucket_queue_list = module._job_bucket_queue_list.slice bucket_threshold_count
              do (loc_job_bucket_queue_list)->
                req_list = []
                for loc_job in loc_job_bucket_queue_list
                  req_list.push loc_job.req
                
                loc_opt = {
                  switch : "job_bucket"
                  req_list
                }
                await worker_pool.exec(loc_opt).cb defer(err, wrap);
                if !err
                  {err, res} = wrap
                
                if err
                  for loc_job, idx in loc_job_bucket_queue_list
                    loc_job.cb err
                  return
                
                {err_res_list} = res
                for loc_job, idx in loc_job_bucket_queue_list
                  {err:loc_err, res:loc_res} = err_res_list[idx]
                  loc_job.cb loc_err, loc_res
                
                return
              break
            await setTimeout defer(), 1
          await setTimeout defer(), 1
        
        _job_bucket_loop_launched = false
      
      @job_auto_bucket = (req, cb)->
        module._job_bucket_queue_list.push {req, cb}
        _job_bucket_loop_launch()
      
      @_broadcast_req = (req, cb)->
        err_ret = null
        await
          for worker in worker_pool.workers
            loc_cb = defer()
            do (worker, loc_cb)->
              await worker.run(req, {timeout:req.timeout}).cb defer(err, res)
              if !err
                err = res.err
              err_ret = err if err
              loc_cb()
        cb err_ret
      
      @reinit = (opt, cb)->
        loc_opt = {switch : "reinit"}
        obj_set loc_opt, opt
        await module._broadcast_req loc_opt, defer(err); return cb err if err
        cb()
      
      @close = (cb)->
        loc_opt = {switch : "close"}
        await module._broadcast_req loc_opt, defer(err); return cb err if err
        cb()
      
      """#"
    false

def "node_worker", (name, scope_fn)->
  if !mod_runner.current_runner.curr_root
    throw new Error "!current_runner.curr_root"
  
  if !name
    throw new Error "missing name"
  
  root = mod_runner.current_runner.curr_root.tr_get "node_worker", name, "def"
  bdh_node_module_name_assign_on_call root, module, "node_worker"
  root.data_hash.require_codebub ?= ""
  root.data_hash.code_codebub ?= ""
  
  mod_runner.current_runner.root_wrap root, scope_fn
  
  root


