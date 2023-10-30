module = @
@_size_free_buf_list_hash = {}
@alloc = (size)->
  module._size_free_buf_list_hash[size] ?= []
  if ret = module._size_free_buf_list_hash[size].pop()
    ret.fill 0
    return ret
  Buffer.alloc size

@free = (buf)->
  module._size_free_buf_list_hash[buf.length].push buf
