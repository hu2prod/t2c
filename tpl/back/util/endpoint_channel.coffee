module.exports = (mod, opt)->
  {
    name
    fn
    req
  } = opt
  opt.req ?= {}
  
  mod[name] = fn
  broadcast_connection_list = []
  last_msg_json = null
  broadcast_fn = null
  
  unsub = (req, connection)->
    # Возможный BUG. req.sub_id иногда может не существовать
    # и не понятно баг здесь что мы не проверяем этот случай или где-то забыли проставить
    # закостыливать не хочется
    
    connection["__#{name}_sub_id_hash"] ?= {}
    delete connection["__#{name}_sub_id_hash"][req.sub_id]
    if 0 == h_count connection["__#{name}_sub_id_hash"]
      broadcast_connection_list.remove connection
    return
  
  mod["#{name}_get"] = (req, cb, http_req, http_res, ws_send, connection)->
    if last_msg_json?
      res = JSON.parse last_msg_json
      res.switch = "#{name}_get"
    else
      await fn req, defer(err, msg); return cb err if err
      last_msg_json = JSON.stringify
        switch : "#{name}_stream"
        res    : msg
      
      res = JSON.stringify
        switch : "#{name}_get"
        res    : msg
    
    cb null, res
  
  mod["#{name}_sub"] = (req, cb, http_req, http_res, ws_send, connection)->
    if !connection?
      return cb new Error "#{name}_sub can be only applied to websocket request"
    
    connection["__#{name}_sub_id_hash"] ?= {}
    connection["__#{name}_sub_id_hash"][req.sub_id] = true
    
    broadcast_connection_list.upush connection
    
    connection.on "close", ()->
      # kill all subs
      broadcast_connection_list.remove connection
    
    if last_msg_json?
      connection.send last_msg_json
    else
      do ()->
        await setTimeout defer(), 0
        fn req, (err, data)=>
          return perr err if err
          broadcast_fn data
    
    cb null
  
  mod["#{name}_unsub"] = (req, cb, http_req, http_res, ws_send, connection)->
    if !connection?
      return cb new Error "#{name}_unsub can be only applied to websocket request"
    
    connection["__#{name}_sub_id_hash"] ?= {}
    delete connection["__#{name}_sub_id_hash"][req.sub_id]
    if 0 == h_count connection["__#{name}_sub_id_hash"]
      broadcast_connection_list.remove connection
    
    cb null
  
  broadcast_fn = (msg)->
    if !msg?
      await fn {}, defer(err, msg)
      if err
        perr "BROADCAST ERROR", err
        return
    
    last_msg_json = JSON.stringify
      switch : "#{name}_stream"
      res    : msg
    
    for loc_con in broadcast_connection_list
      try
        loc_con.send last_msg_json
      catch err
        perr err
    return
  
  if opt.interval
    do ()->
      loop
        await fn opt.req, defer(err, res)
        if err
          perr err
        else
          msg_json = JSON.stringify {
            switch : "#{name}_stream"
            res
          }
          
          if last_msg_json != msg_json
            last_msg_json = msg_json
            
            for loc_con in broadcast_connection_list
              try
                loc_con.send last_msg_json
              catch err
                perr err
          
        await setTimeout defer(), opt.interval
  
  return {broadcast_fn,broadcast_connection_list}
