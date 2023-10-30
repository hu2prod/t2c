module.exports = (mod, opt)->
  {
    name
    fn
    req
    req2key
  } = opt
  opt.req ?= {}
  if !req2key
    throw new Error "missing req2key for #{name}"
  
  key_connection_list_hash  = {}
  key_to_req_hash           = {}
  key_last_json_msg_ts_hash = {}
  broadcast_connection_list = []
  
  unsub = (req, connection)->
    connection["__#{name}_global_sub_id_hash"] ?= {}
    delete connection["__#{name}_global_sub_id_hash"][req.sub_id]
    if 0 == h_count connection["__#{name}_global_sub_id_hash"]
      broadcast_connection_list.remove connection
    return
  
  if opt.global # global_ep
    mod["#{name}_global_sub"] = (req, cb, http_req, http_res, ws_send, connection)->
      if !connection?
        return cb new Error "#{name}_global_sub can be only applied to websocket request"
      
      connection["__#{name}_global_sub_id_hash"] ?= {}
      connection["__#{name}_global_sub_id_hash"][req.sub_id] = true
      
      broadcast_connection_list.upush connection
      
      connection.on "close", ()->
        # kill all subs
        broadcast_connection_list.remove connection
      
      cb null
    
    mod["#{name}_global_unsub"] = (req, cb, http_req, http_res, ws_send, connection)->
      if !connection?
        return cb new Error "#{name}_global_unsub can be only applied to websocket request"
      
      connection["__#{name}_global_sub_id_hash"] ?= {}
      delete connection["__#{name}_global_sub_id_hash"][req.sub_id]
      if 0 == h_count connection["__#{name}_global_sub_id_hash"]
        broadcast_connection_list.remove connection
      
      cb null
  
  mod["#{name}_sub"] = (req, cb, http_req, http_res, ws_send, connection)->
    if !connection?
      return cb new Error "#{name}_sub can be only applied to websocket request"
    
    await opt.req2key req, defer(err, key); return cb err if err
    
    connection["__#{name}_sub_id_hash"] ?= {}
    connection["__#{name}_sub_id_hash"][key] ?= {}
    connection["__#{name}_sub_id_hash"][key][req.sub_id] = true
      
    key_connection_list_hash[key] ?= []
    key_connection_list_hash[key].upush connection
    key_to_req_hash[key] = req
    
    connection.on "close", ()->
      # kill all subs
      key_connection_list_hash[key]?.remove connection
    
    
    msg_ts = key_last_json_msg_ts_hash[key]
    if msg_ts?
      can_send = false
      if !opt.timeout?
        can_send = true
      else
        can_send = true if msg_ts.ts + opt.timeout < Date.now()
      
      if can_send
        connection.send msg_ts.msg
        return cb null
    
    if fn?
      await fn key, req, defer(err, res); return cb err if err
      if res?
        key_last_json_msg_ts_hash[key] = {
          msg : last_msg_json = JSON.stringify
            switch : "#{name}_stream"
            res    : res
          ts : Date.now()
        }
        broadcast_key_fn key, res
    
    cb null
  
  mod["#{name}_unsub"] = (req, cb, http_req, http_res, ws_send, connection)->
    if !connection?
      return cb new Error "#{name}_unsub can be only applied to websocket request"
    
    await opt.req2key req, defer(err, key); return cb err if err
    
    connection["__#{name}_sub_id_hash"] ?= {}
    if connection["__#{name}_sub_id_hash"][key]
      delete connection["__#{name}_sub_id_hash"][key][req.sub_id]
      if 0 == h_count connection["__#{name}_sub_id_hash"][key]
        key_connection_list_hash[key]?.remove connection
    
    cb null
  
  
  broadcast_key_fn = (key, msg)->
    connection_list = key_connection_list_hash[key] ? []
    return if connection_list.length == 0 and broadcast_connection_list.length == 0
    if !msg
      await fn key, null, defer(err, msg);
      if err
        perr "BROADCAST ERROR", err
        return
      
    key_last_json_msg_ts_hash[key] = {
      msg : last_msg_json = JSON.stringify
        switch : "#{name}_stream"
        res    : msg
      ts : Date.now()
    }
    
    # TODO do not send 1 message 2 times at same connection (direct sub + broadcast sub)
    
    for loc_con in connection_list
      try
        loc_con.send last_msg_json
      catch err
        perr err
    
    for loc_con in broadcast_connection_list
      try
        loc_con.send last_msg_json
      catch err
        perr err
    
    return
  
  if opt.interval?
    do ()=>
      time_offset = opt.timeout ? opt.interval
      loop
        if fn?
          for key,connection_list of key_connection_list_hash
            continue if connection_list.length == 0
            continue if !req = key_to_req_hash[key]
            msg_ts = key_last_json_msg_ts_hash[key]
            continue if msg_ts and msg_ts.ts + time_offset > Date.now()
            
            await fn key, req, defer(err, res); return cb err if err
            if res?
              broadcast_key_fn key, res
        
        await setTimeout defer(), opt.interval
      
      return
  
  return {broadcast_key_fn}
