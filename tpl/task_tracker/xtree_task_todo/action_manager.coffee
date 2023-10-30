class window.Xtree_action
  redo_fn_list : []
  undo_fn_list : []
  # type    : ''
  constructor:()->
    @redo_fn_list = []
    @undo_fn_list = []
  
  redo : ()->
    for fn in @redo_fn_list
      fn.call @
    return
  undo : ()->
    for fn in @undo_fn_list
      fn.call @
    return
  
  # TODO merge

class window.Xtree_action_manager
  undo_list_cap : 100000
  undo_list : []
  redo_list : []
  _group_started : false
  group_list: []
  
  constructor:()->
    @undo_list = []
    @redo_list = []
    @group_list = []
  
  action_add : (action)->
    if @_group_started
      @group_list.push action
      return
    
    @undo_list.push action
    @redo_list.clear()
    return
  
  undo : ()->
    return if !@undo_list.length
    action = @undo_list.pop()
    action.undo()
    @redo_list.push action
    return
  
  redo : ()->
    return if !@redo_list.length
    action = @redo_list.pop()
    action.redo()
    @undo_list.push action
    return
  
  group_start : ()->
    @_group_started = true
  
  group_end : ()->
    @_group_started = false
    return if @group_list.length == 0
    merged_action = new Xtree_action
    # redo first -> last
    for action in @group_list
      merged_action.redo_fn_list.append action.redo_fn_list
    # undo last -> first
    for idx in [@group_list.length - 1 .. 0]
      action = @group_list[idx]
      merged_action.undo_fn_list.append action.undo_fn_list
    @action_add merged_action
    @group_list.clear()
    return
  
