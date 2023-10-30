fs = require "fs"

class Fs_write_buf
  fh        : null
  buf_queue : []
  limit     : 64
  buf_pool  : false
  constructor : ()->
    @buf_queue = []
  
  push : (buf, cb)->
    @buf_queue.push buf
    if @buf_queue.length > @limit
      await @flush defer(err); return cb err if err
    cb null
    
  flush : (cb)->
    # TODO buffer pool
    # DEBUG
    expd_len = 0
    for v in @buf_queue
      expd_len += v.length
    
    buf = Buffer.concat @buf_queue
    
    # DEBUG
    real_len = buf.length
    if expd_len != real_len
      perr "expd_len != real_len #{expd_len} != #{real_len}"
      process.exit()
    
    await fs.write @fh, buf, defer(err); return cb err if err
    
    if @buf_pool
      for buf in @buf_queue
        @buf_pool.free buf
    
    @buf_queue.clear()
    
    cb null
  
  push_sync : (buf)->
    @buf_queue.push buf
    if @buf_queue.length > @limit
      @flush_sync()
    return
  
  push_str_len8 : (str)->
    size = Buffer.byteLength str
    if size > 255
      throw new Error "size > 255"
    buf = (@buf_pool ? Buffer).alloc 1
    buf[0] = size
    @push_sync buf
    
    buf = (@buf_pool ? Buffer).alloc size
    buf.write str
    @push_sync buf
    return
  
  push_str_len32 : (str)->
    size = Buffer.byteLength str
    buf = (@buf_pool ? Buffer).alloc 4
    buf.writeUInt32LE size
    @push_sync buf
    
    buf = (@buf_pool ? Buffer).alloc size
    buf.write str
    @push_sync buf
    return
  
  flush_sync : ()->
    # TODO buffer pool
    # DEBUG
    expd_len = 0
    for v in @buf_queue
      expd_len += v.length
    
    buf = Buffer.concat @buf_queue
    
    # DEBUG
    real_len = buf.length
    if expd_len != real_len
      perr "expd_len != real_len #{expd_len} != #{real_len}"
      process.exit()
    
    fs.writeSync @fh, buf
    
    if @buf_pool
      for buf in @buf_queue
        @buf_pool.free buf
    
    @buf_queue.clear()
    return

module.exports = Fs_write_buf
