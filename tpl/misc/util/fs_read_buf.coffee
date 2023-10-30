fs = require "fs"

class Fs_read_buf
  fh        : null
  curr_buf  : null
  curr_buf_real_length: 0
  curr_buf_offset     : 0
  buf_pool  : false
  buf_size  : 10e6
  constructor : ()->
    @buf_queue = []
  
  open : (path)->
    @fh = fs.openSync path, "r"
    @curr_buf = (@buf_pool ? Buffer).alloc @buf_size
    @curr_buf_real_length = fs.readSync @fh, @curr_buf
    return
  
  close : ()->
    fs.closeSync @fh
    @fh = null
    
    if @buf_pool
      @buf_pool.free @curr_buf
    return
  
  ensure : (byte_count)->
    left = @curr_buf_real_length - @curr_buf_offset
    return if left >= byte_count
    
    @curr_buf.copy @curr_buf, 0, @curr_buf_offset
    @curr_buf_offset = 0
    
    bytes_read = fs.readSync @fh, @curr_buf, left, @buf_size-left
    
    @curr_buf_real_length = bytes_read + left
    if @curr_buf_real_length < byte_count
      throw new Error "can't ensure byte_count #{byte_count}. End of file"
    
    return
  
  readBigUInt64LE : ()->
    byte_count = 8
    @ensure byte_count
    ret = @curr_buf.readBigUInt64LE @curr_buf_offset
    @curr_buf_offset += byte_count
    ret
  
  readUInt32LE : ()->
    byte_count = 4
    @ensure byte_count
    ret = @curr_buf.readUInt32LE @curr_buf_offset
    @curr_buf_offset += byte_count
    ret
  
  read_u8 : ()->
    byte_count = 1
    @ensure byte_count
    ret = @curr_buf[@curr_buf_offset]
    @curr_buf_offset += byte_count
    ret
  
  read_str : (byte_count)->
    @ensure byte_count
    ret_buf = @curr_buf.slice @curr_buf_offset, @curr_buf_offset+byte_count
    ret = ret_buf.toString()
    @curr_buf_offset += byte_count
    ret
  
  read_str_len8 : ()->
    len = @read_u8()
    @read_str len
  
  read_str_len32 : ()->
    len = @readUInt32LE()
    @read_str len
  
  skip : (byte_count)->
    max = @buf_size//4
    while byte_count > 0
      loc_byte_count = Math.min max, byte_count
      byte_count -= loc_byte_count
      @ensure loc_byte_count
      @curr_buf_offset += loc_byte_count
    return
  

module.exports = Fs_read_buf
