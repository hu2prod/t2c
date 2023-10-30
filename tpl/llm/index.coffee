module = @
require "fy"
require "event_mixin"
require "lock_mixin"
axios = require "axios"
config = require "../config"
db = require "../db"

@ev = new Event_mixin
@debug_stop_on_request = config.llm_debug_stop_on_request

# ###################################################################################################
#    vendor
# ###################################################################################################
@vendor_hash = {}
@vendor_hash.openai = require "./vendor/openai"
do ()=>
  for _vendor_name, vendor of module.vendor_hash
    vendor.queue_load_fn()
  
  for _vendor_name, vendor of module.vendor_hash
    vendor.on "llm_gen_complete", (e)->
      module.ev.dispatch "llm_gen_complete", e
    vendor.on "llm_gen", (e)->
      module.ev.dispatch "llm_gen", e
    
  return

# ###################################################################################################
#    API
# ###################################################################################################
@db_check_lock = new Lock_mixin
# fire and forget (returns task (for task.id))
@task_push = (opt, cb)->
  {
    parent_state_id
    ref_id_cb
  } = opt
  opt.vendor ?= config.llm_default_vendor
  if !vendor = module.vendor_hash[opt.vendor]
    return cb new Error "unknown vendor"
  
  try
    vendor_req = vendor.build_request_fn opt
  catch err
    return cb err
  
  text_i_json = JSON.stringify vendor_req
  parent_state_id ?= null
  where = {
    parent_state_id
    vendor : opt.vendor
    text_i_json
  }
  # optimistic
  await db.llm_state.findOne({where,raw:true}).cb defer(err, task); return cb err if err
  
  # pessimistic
  if !task
    await module.db_check_lock.wrap cb, defer(cb)
    await db.llm_state.findOne({where,raw:true}).cb defer(err, task); return cb err if err
  
  if task
    ref_id_cb? task.id
    if task.status in ["DONE", "ERROR_UNKNOWN", "ERROR_RATE_LIMIT"]
      # re-broadcast. Consumer should be idempotent anyway
      # useful if UI element don't listen for callback, but perform bulk monitoring
      module.ev.dispatch "llm_gen_complete", task
    return cb null, task, vendor
  
  if module.debug_stop_on_request
    puts JSON.stringify opt, null, 2
    puts opt.req
    process.exit()
  doc = {
    status : "SCHEDULED"
  }
  obj_set doc, where
  await db.llm_state.create(doc).cb defer(err, task2); return cb err if err
  task = task2.get plain:true
  ref_id_cb? task.id
  
  vendor.task_push task
  cb null, task, vendor

ref_id_cb_dict = new Map
@ev.on "llm_gen_complete", (task)->
  return if !cb = ref_id_cb_dict.get task.id
  ref_id_cb_dict.delete task.id
  
  if task.status in ["ERROR_UNKNOWN", "ERROR_RATE_LIMIT"]
    return cb new Error(task.status), task
  if task.status in ["DONE"]
    return cb null, task
  
  return cb new Error "unknown status"

@call = (opt, cb)->
  opt.ref_id_cb = (id)->
    ref_id_cb_dict.set id, cb
  await module.task_push opt, defer(err, task, vendor); return cb err if err
  return

@task_to_res = (res)->
  JSON.parse(res.text_o_json).compose_result

# ###################################################################################################
#    resume
# ###################################################################################################
do ()->
  cb = (err)->
    perr err if err
  await module.db_check_lock.wrap cb, defer(cb)
  
  where = {
    status : ["SCHEDULED", "IN_PROGRESS", "PAUSED"]
  }
  await db.llm_state.findAll({where,raw:true}).cb defer(err, task_list); return cb err if err
  if task_list.length
    puts "PENDING #{task_list.length} request(s)"
  task_list.sort (a,b)->a.id-b.id
  
  filter_task_list = []
  for task in task_list
    if !vendor = module.vendor_hash[task.vendor]
      perr "unknown vendor #{task.vendor}"
      continue
    
    filter_task_list.push task
  
  id_list = []
  for task in filter_task_list
    id_list.push task.id
  
  update_hash = {
    status : "SCHEDULED"
  }
  where = {
    id: id_list
  }
  await db.llm_state.update(update_hash, {where}).cb defer(err, _res); return cb err if err
  
  for task in filter_task_list
    vendor.task_push task
  
  cb()
  return
