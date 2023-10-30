@deep_obj_set = deep_obj_set = (dst, src)->
  for k,v of src
    if v instanceof Array
      dst[k] ?= v
      list = dst[k]
      
      # list_item can be other instance, so !=, but JSON.eq
      for list_item in v
        found = false
        for cmp_v in list
          if JSON.eq list_item, cmp_v
            found = true
            break
        if !found
          list.push list_item
    else if typeof v == "object"
      dst[k] ?= {}
      if typeof dst[k] != "object"
        puts "src", v
        puts "dst", dst[k]
        throw new Error "bad deep_obj_set key=#{k}"
      deep_obj_set dst[k], v
    else
      dst[k] = v
  return

@deep_obj_set_weak = deep_obj_set_weak = (dst, src)->
  for k,v of src
    if v instanceof Array
      dst[k] ?= v
      list = dst[k]
      
      # list_item can be other instance, so !=, but JSON.eq
      for list_item in v
        found = false
        for cmp_v in list
          if JSON.eq list_item, cmp_v
            found = true
            break
        if !found
          list.push list_item
    else if typeof v == "object"
      dst[k] ?= {}
      if typeof dst[k] != "object"
        puts "src", v
        puts "dst", dst[k]
        throw new Error "bad deep_obj_set_weak key=#{k}"
      deep_obj_set_weak dst[k], v
    else
      dst[k] ?= v
  return

@deep_obj_set_strict = deep_obj_set_strict = (dst, src)->
  for k,v of src
    if v instanceof Array
      dst[k] ?= v
      list = dst[k]
      
      # list_item can be other instance, so !=, but JSON.eq
      for list_item in v
        found = false
        for cmp_v in list
          if JSON.eq list_item, cmp_v
            found = true
            break
        if !found
          list.push list_item
    else if typeof v == "object"
      dst[k] ?= {}
      if typeof dst[k] != "object"
        puts "src", v
        puts "dst", dst[k]
        throw new Error "bad deep_obj_set_strict key=#{k}"
      deep_obj_set_strict dst[k], v
    else
      if !dst[k]?
        dst[k] = v
      else if dst[k] != v
        puts "src", v
        puts "dst", dst[k]
        throw new Error " deep_obj_set_strict key=#{k}"
  return
