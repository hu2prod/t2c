# ###################################################################################################
#    db_list_sync
# ###################################################################################################
# window.db_list_sync = (opt, on_end)->
#   {
#     list
#     collection
#     entity
#     wrap
#     unwrap
#     _where
#   } = opt
#   _where ?= {}
#   
#   wrap    ?= (t)->t
#   unwrap  ?= (t)->t
#   
#   # await db.collection(collection).find _where, {_id:1, "last_edit_ts":1}, defer(err, db_id_list); return perr err if err
#   
#   # TODO no limit on backend
#   # maxint?
#   # await Task_tracker_todo_item.list {}, defer(err, )
#   await db.collection(collection).find _where, {_id:1, "last_edit_ts":1}, defer(err, db_id_list); return perr err if err
#   # ###################################################################################################
#   #    clear all items that missing
#   # ###################################################################################################
#   refresh_list = []
#   
#   store_id_hash = {}
#   for wrap_store_task in list
#     store_task = unwrap wrap_store_task
#     store_id_hash[store_task._id] = store_task
#     store_id_hash._dead = true
#   
#   for v in db_id_list
#     if store_task = store_id_hash[v._id]
#       if store_task.last_edit_ts != v.last_edit_ts
#         refresh_list.push store_task
#       store_task._dead = false
#   
#   new_task_list = []
#   for wrap_store_task in list
#     store_task = unwrap wrap_store_task
#     new_task_list.push store_task if !store_task._dead
#   
#   # keep reference
#   list.clear()
#   list.append new_task_list
#   # ###################################################################################################
#   #    Add all new items
#   # ###################################################################################################
#   # should be +- optimal because low amount of reads
#   await
#     for store_task in refresh_list
#       cb = defer()
#       do (store_task, cb)->
#         await store_task.load defer(err)
#         perr err if err
#         cb()
#   
#   # NOTE need optimisation, bulk read. Especially on init
#   await
#     for v in db_id_list
#       if !store_id_hash[v._id]
#         cb = defer()
#         do (v, cb)=>
#           loc_store_task = new entity
#           loc_store_task._id = v._id
#           await loc_store_task.load defer(err)
#           
#           loc_wrap_store_task = wrap loc_store_task
#           if err
#             perr err 
#           else
#             list.push loc_wrap_store_task
#           cb()
#   
#   if list[0]?.title
#     list.sort (a,b)->a.title.localeCompare b.title
#   else
#     list.sort (a,b)->a._id.localeCompare b._id
#   on_end()

# ###################################################################################################
_where_match = (obj, _where) ->
  for k,v of _where
    obj_match = obj[k]
    if !v? # null == undefined
      return false if obj_match?
    else
      if typeof v == "object"
        return false if typeof obj_match != "object"
        return false if !_where_match obj_match, v
      else
        return false if obj_match != v
  true

class window.DBTask
  id          : null
  title       : ""
  description : ""
  order       : null
  in_todo_list: false
  done        : false
  tier_hash   : {}
  
  __real      : null
  
  event_mixin @
  constructor:()->
    event_mixin_constructor @
    @__real = new Task_tracker_todo_item
    @tier_hash = {}
  
  where_match : (_where)->
    _where_match @, _where
  
  custom_filter_hash_match : (custom_filter_hash)->
    for k,cb of custom_filter_hash
      if !cb @
        return false
    true
  
  save : ()->
    @__real.title       = @title
    @__real.description = @description
    @__real.order       = @order
    @__real.done        = @done
    @__real.in_todo_list    = @in_todo_list ? false
    @__real.importance_tier = @tier_hash.important
    @__real.refine_tier     = @tier_hash.refined
    @__real.wtf_tier        = @tier_hash.wtf
    
    # Костыли
    @__real.iteration_id  = "0"
    @__real.order         = 0
    
    @__real.last_tier_edit_ts         = Date.now().toString()
    
    await @__real.save [], defer(err); throw err if err
    @id                  = @__real.id             
    @dispatch "save", @
  
  load : ()->
    @id                   = @__real.id             
    @title                = @__real.title          
    @description          = @__real.description    
    @order                = @__real.order          
    @done                 = @__real.done           
    @in_todo_list         = @__real.in_todo_list   
    @tier_hash.important  = @__real.importance_tier
    @tier_hash.refined    = @__real.refine_tier    
    @tier_hash.wtf        = @__real.wtf_tier       
  

# А вообще всё это делается через pubsub и даже где-то был код для этого
class DBTask_pool
  list : []
  handler : null
  
  event_mixin @
  constructor : (hash)->
    event_mixin_constructor @
    
    for k,v of hash
      @[k] = v
    
    @list = []
    @handler = (node)=>
      @dispatch "node_save", node
  
  delete : ()->
    for v in @list
      v.off "save", @handler
    @handler = null
    return
  
  # literally extract all table (((
  load : (on_end)->
    await Task_tracker_todo_item.list {}, defer(err, db_list); return on_end err if err
    # ###################################################################################################
    #    clear all items that missing
    # ###################################################################################################
    wrap_id_hash = {}
    for wrap_task in @list
      wrap_id_hash[wrap_task.id] = wrap_task
      wrap_id_hash._dead = true
    
    for v in db_list
      v._used = false
    
    new_task_list = []
    for v in db_list
      if wrap_task = wrap_id_hash[v.id]
        v._used = true
        if wrap_task.__real.updatedAt != v.updatedAt
          wrap_task.__real = v
          wrap_task.load()
        wrap_task._dead = false
      else
        wrap_task = new DBTask
        wrap_task.__real = v
        wrap_task.load()
        wrap_task._dead = false
      new_task_list.push wrap_task
    
    # keep reference
    @list.clear()
    @list.append new_task_list
    # ###################################################################################################
    @list.sort (a,b)->
      (a.order - b.order) or
      (a.id - b.id)
    
    @dispatch "load"
    for v in @list
      v.ensure_on "save", @handler
    
    on_end()
  
  find : (_where)->
    res = []
    for v in @list
      # inline...
      res.push v if v.where_match _where
    res

window.db_task_pool = new DBTask_pool

# ws_protocol = if location.protocol == "http:" then "ws:" else "wss:"
# ws_db = new Websocket_wrap "#{ws_protocol}//#{location.hostname}:10031"
# wsrs_db= new Ws_request_service ws_db
# window.db  = new DB wsrs_db
# 
#   
# 
# class window.DBTask
#   _dbmap : {
#     tier_hash   : type : "clone"
#     project_list:
#       type : "ref_list"
#       factory: (id)=>DBProject.factory id
#   }
#   
#   _id         : null
#   title       : ""
#   description : ""
#   order       : null
#   estimate_tsi: null
#   done        : false
#   tier_hash   : {}
#   _time_point_list : []
#   
#   project_list: []
#   
#   db_mixin @
#   constructor:()->
#     db_mixin_constructor @
#     @tier_hash = {}
#     @_time_point_list = []
#     @project_list = []
#   
#   where_match : (_where)->
#     _where_match @, _where
#   
#   custom_filter_hash_match : (custom_filter_hash)->
#     for k,cb of custom_filter_hash
#       if !cb @
#         return false
#     true
#   
#   # ###################################################################################################
#   #    time start/stop
#   # ###################################################################################################
#   is_started : ()->
#     res = false
#     if time_point = @_time_point_list.last()
#       res = time_point.is_start
#     res
#   
#   # TODO rename dbnode
#   time_start : ()->
#     dbnode = @
#     time_point = new DBTime_point
#     time_point.is_start = true
#     time_point.task_oid = dbnode._id
#     db_time_point_pool.list.push time_point
#     dbnode._time_point_list.push time_point
#     time_point.save()
#   
#   time_stop : ()->
#     dbnode = @
#     time_point = new DBTime_point
#     time_point.is_start = false
#     time_point.task_oid = dbnode._id
#     db_time_point_pool.list.push time_point
#     dbnode._time_point_list.push time_point
#     time_point.save()
# 
# class window.DBProject
#   _dbmap : {}
#   title : ""
#   
#   db_mixin @
#   constructor: ()->
#     db_mixin_constructor @
#   
# 
# # Это разные layout'ы сюда можно запихнуть таски и они будут по-другому отображаться.
# # Это не проект, это под-приложение
# class window.DBTrack
#   _dbmap : {
#     left : type : "clone"
#     main : type : "clone"
#   }
#   
#   title : ""
#   left  : null
#   main  : null
#   
#   db_mixin @
#   constructor:()->
#     db_mixin_constructor @
# 
# class window.DBTime_point
#   _dbmap : {}
#   
#   _id       : null
#   is_start  : true
#   ts        : 0
#   task_oid  : null
#   
#   db_mixin @
#   constructor : ()->
#     db_mixin_constructor @
#     @ts = Date.now()
#   
# 
# class window.DBEntity_pool
#   list : []
#   handler : null
#   collection : ""
#   
#   event_mixin @
#   constructor : (hash)->
#     event_mixin_constructor @
#     
#     throw new Error "missing collection"          if !hash.collection
#     throw new Error "missing entity constructor"  if !hash.entity
#     for k,v of hash
#       @[k] = v
#     
#     @list = []
#     @handler = (node)=>
#       @dispatch "node_save", node
#   
#   delete : ()->
#     for v in @list
#       v.off "save", @handler
#     @handler = null
#     return
#   
#   # literally extract all table (((
#   load : (on_end)->
#     await db_list_sync {
#       list      : @list
#       collection: @collection
#       entity    : @entity
#     }, defer(err); return on_end err if err
#     @dispatch "load"
#     for v in @list
#       v.ensure_on "save", @handler
#     
#     on_end()
#   
#   find : (_where)->
#     res = []
#     for v in @list
#       # inline...
#       res.push v if v.where_match _where
#     res
# 
# window.db_track_pool = new DBEntity_pool
#   collection: "dbtrack"
#   entity    : DBTrack
# 
# # после введения фильтрации по принадлежности к треку добавить where
# window.db_task_pool = new DBEntity_pool
#   collection: "dbtask"
#   entity    : DBTask
# 
# window.db_project_pool = new DBEntity_pool
#   collection: "dbproject"
#   entity    : DBProject
# 
# # после введения фильтрации по принадлежности к треку добавить where по task'ам
# window.db_time_point_pool = new DBEntity_pool
#   collection: "dbtime_point"
#   entity    : DBTime_point
# 
# window.merge_time_point_to_task = ()->
#   task_hash = {}
#   for task in db_task_pool.list
#     task_hash[task._id] = task
#   for time_point in db_time_point_pool.list
#     if !task = task_hash[time_point.task_oid]
#       perr "dangling time point", task
#       continue
#     task._time_point_list.push time_point
#   return
# 
