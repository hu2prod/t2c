module = @
mod_runner = require "./runner"

@block_hash = {}
@def = (name_selector, cb)->
  # TODO multiple block name_selector
  [sequence..., name] = name_selector.split(/\s+/g)
  if module.block_hash[name]
    throw new Error "unimplemented redefine of '#{name}'"
  
  rev_sequence = sequence.slice().reverse()
  
  # Прим. Пока не поддерживается вариант когда одно имя доступно по нескольким путям
  # Доп. проверки пока только на hydrator'е
  cb_wrap = (arg...)->
    root = mod_runner.current_runner.curr_root
    for v in rev_sequence
      pass = false
      while !pass
        if !root
          throw new Error "block '#{name}' should be nested in blocks: #{rev_sequence.join ', '}"
        
        pass = root.type == v
        root = root.parent
    
    cb arg...
  
  module.block_hash[name] = cb_wrap
  global[name] = cb_wrap
  return
