window.codemirror_magic_value_sx = 7.1474609375
if navigator.platform.includes "Linux"
  window.codemirror_magic_value_sx = 7.8
no_prevent_default_hash =
  cut   : true
  paste : true
xtree_action_to_description_hash =
  # non-mutable
  # cursor
  "cursor_left"               : "move cursor left (overflow -> prev line)"
  "cursor_right"              : "move cursor right (overflow -> next line)"
  "cursor_up"                 : "move cursor up"
  "cursor_down"               : "move cursor down"
  "cursor_home"               : "move to the begin of line"
  "cursor_end"                : "move to the end of line"
  "word_left"                 : "move cursor one word left"
  "word_right"                : "move cursor one word right"
  # selection
  "selection_left"            : "selection mode. move cursor left"
  "selection_right"           : "selection mode. move cursor right"
  "selection_home"            : "selection mode. move cursor to the begin of line"
  "selection_end"             : "selection mode. move cursor to the end of line"
  "selection_word_left"       : "selection mode. move cursor one word left"
  "selection_word_right"      : "selection mode. move cursor one word right"
  
  # mutable
  # text
  "backspace"                 : "just delete char backwards"
  "char_delete"               : "delete next char"
  "word_delete_left"          : "delete word left"
  "word_delete_right"         : "delete word right"
  "capitalize"                : "capitalize"
  "lower_case"                : "lower case"
  "upper_case"                : "upper case"
  "lang_switch"               : "switch language ru <-> en (QIP ICQ messanger inspired)"
  
  "cut"                       : "cut"
  "paste"                     : "paste"
  # meta
  "done_toggle"               : "toggle done"
  "todo_toggle"               : "toggle todo"
  "task_start_stop"           : "task start/stop"
  
  # order
  "node_swap_up"              : "task order swap up"
  "node_swap_down"            : "task order swap down"
  
  # task creation
  "enter_task_create"         : "create task after current"
  
  # action_manager
  "undo"                      : "undo"
  "redo"                      : "redo"
  
  # fast rank change
  "important_inc"             : "important tier +1"
  "important_dec"             : "important tier -1"
  "refined_inc"               : "refined tier +1"
  "refined_dec"               : "refined tier -1"

word_cut = (str)->
  list = str.split /(\s+)/g
  ret = []
  for v in list
    continue if v == ""
    ret.push v
  ret

class window.TODO_keyboard_controller
  scheme    : {} # aka _key_sceme
  action_fn : (gui_action)->
  allow_create : true
  
  constructor:()->
    @scheme = {}
  
  # ###################################################################################################
  #    schemes
  # ###################################################################################################
  key : (hotkey, cb, opt={})->
    {
      # description
      no_prevent_default
    } = opt
    hotkey = hotkey.toLowerCase()
    parts = hotkey.split "+"
    key_name = parts.pop()
    throw new Error("wtf is key_name '#{key_name}'") if !Keymap[key_name]?
    
    normalized_key = Keymap.normalize key_name
    
    parts.push normalized_key
    hotkey = parts.join "+"
    
    if no_prevent_default
      @scheme[hotkey] = cb
    else
      @scheme[hotkey] = (e)->
        e.preventDefault()
        cb e
        return
    return
  
  scheme_change : (scheme_name)->
    if !@["set_scheme_#{scheme_name}"]?
      throw new Error("scheme #{scheme_name} not exists")
    @["set_scheme_#{scheme_name}"]()
    return
  # ###################################################################################################
  #    handler
  # ###################################################################################################
  key_down : (e)->
    string = ""
    string += "ctrl+"   if e.ctrlKey
    string += "alt+"    if e.altKey
    string += "shift+"  if e.shiftKey
    string += Keymap.rev_map[e.keyCode]
    
    if (cb = @scheme[string])?
      cb e
    return false
  # ###################################################################################################
  #    xtree specific
  # ###################################################################################################
  _export_hash : (hash)->
    for k,v of hash
      do (k,v)=>
        if no_prevent_default_hash[v]
          @key k, (()=>@action_fn v), no_prevent_default:true
        else
          @key k, ()=>@action_fn v
    return
  
  scheme_template_init : (scheme_name)->
    p "scheme_init '#{scheme_name}'"
    # @key "ctrl+q",        ((e)=>@set_key_scheme_select()                 ),
    hash =
      # "ctrl+h"        : "help_toggle"
      # "escape"        : "help_hide"
      # non-mutable
      "left"          : "cursor_left"
      "right"         : "cursor_right"
      "ctrl+left"     : "word_left"
      "ctrl+right"    : "word_right"
      "up"            : "cursor_up"
      "down"          : "cursor_down"
      "home"          : "cursor_home"
      "end"           : "cursor_end"
    
    @_export_hash hash
    return

  set_scheme_default : ()->
    @scheme_template_init "default"
    hash =
      "ctrl+s"          : "no_op"
      # non-mutable
      # selection
      "shift+left"      : "selection_left"
      "shift+right"     : "selection_right"
      "shift+home"      : "selection_home"
      "ctrl+shift+home" : "selection_home"
      "shift+end"       : "selection_end"
      "ctrl+shift+end"  : "selection_end"
      "ctrl+shift+left" : "selection_word_left"
      "ctrl+shift+right": "selection_word_right"
      
      # mutable
      # order edit
      "ctrl+up"         : "node_swap_up"
      "ctrl+down"       : "node_swap_down"
      # text edit
      "backspace"       : "backspace"
      "shift+backspace" : "backspace"
      "delete"          : "char_delete"
      "ctrl+backspace"  : "word_delete_left"
      "ctrl+delete"     : "word_delete_right"
      "alt+c"           : "capitalize"
      "ctrl+l"          : "lower_case"
      "ctrl+u"          : "upper_case"
      "ctrl+r"          : "lang_switch"
      "alt+r"           : "lang_switch"
      
      # clipboard
      "ctrl+x"          : "cut"
      "shift+delete"    : "cut"
      "ctrl+v"          : "paste"
      "shift+insert"    : "paste"
      
      # meta
      "ctrl+space"      : "done_toggle"
      "ctrl+enter"      : "todo_toggle"
      "alt+enter"       : "task_start_stop" # временный hotkey
      
      # task create
      "enter"           : "enter_task_create"
      
      # action_manager
      "ctrl+z"          : "undo"
      "ctrl+y"          : "redo"
      
      # fast rank change
      # alt+wasd
      "alt+d"           : "important_inc"
      "alt+a"           : "important_dec"
      "alt+s"           : "refined_inc"
      "alt+w"           : "refined_dec"
    @_export_hash hash
    return
# ###################################################################################################
#    controller
# ###################################################################################################
class window.TODO_gui_controller
  $textarea   : null
  refresh_fn  : ()->
  
  doc         : null
  # project     : null # for new nodes
  _handler_gui: null
  _handler_load: null
  _handler_refresh: null
  _handler_node_move_out: null
  _handler_node_move_in : null
  
  action_manager      : null
  keyboard_controller : null
  
  # state
  _cursor_timer : null
  cursor_visible: false
  x : 0
  y : 0
  true_x : 0
  selection_node_list : []
  
  # settings
  sx:codemirror_magic_value_sx
  sy:16
  
  
  _is_mouse_down : false
  _mouse_up_handler : null
  
  constructor:()->
    @action_manager         = new Xtree_action_manager()
    @keyboard_controller    = new TODO_keyboard_controller()
    @selection_node_list    = []
  
  delete : ()->
    @action_manager     = null
    @keyboard_controller= null
    @refresh_fn = ()->
    if @_mouse_up_handler
      global_mouse_up.off @_mouse_up_handler
      @_mouse_up_handler = null
    @set_doc null
    return
  
  init : ()->
    @keyboard_controller.set_scheme_default()
    @keyboard_controller.action_fn = @action_fn_get()
    @cursor_blink_off()
    return
    
  
  set_doc : (doc)->
    return if doc == @doc
    if @doc
      @doc.off "gui", @_handler_gui
      @doc.off "load", @_handler_load
      @doc.off "refresh", @_handler_refresh
      @doc.off "node_move_out", @_handler_node_move_out
      @doc.off "node_move_in",  @_handler_node_move_in
    @doc = doc
    return if !@doc
    
    if @doc.node_list.length
      @cursor_move 0, 0
    
    @cursor_blink_off()
    @doc.on "gui", @_handler_gui = (e)=>
      {node, event} = e
      if !@[e.switch]?
        perr "unknown e.switch=#{e.switch}"
        return
      @[e.switch] node, event
      return
    @doc.on "load", @_handler_load = ()=>
      # ТУПОЙ способ
      for node,idx in @doc.node_list
        if !node.dbnode.order?
          node.dbnode.order = idx
          node.dbnode.save()
      
      max_len = @doc.node_list.length
      order_get = (a)->a.dbnode.order ? max_len
      @doc.node_list.sort (a,b)->order_get(a) - order_get(b)
      @cursor_move 0, 0
      return
    @doc.on "refresh", @_handler_load = ()=>
      @refresh_fn()
    @doc.on "node_move_out", @_handler_node_move_out = (node)=>
      @selection_drop(false)
      @refresh_fn()
    @doc.on "node_move_in", @_handler_node_move_in = (node)=>
      @cursor_move @x, @doc.node_to_coord(node), select_textarea: false
    return
  
  node_save_refresh : (node)->
    node.dbnode.save()
    @refresh_fn()
    @doc.dispatch "node_refresh", node
    return
  
  # ###################################################################################################
  #    cursor
  # ###################################################################################################
  cursor_visible_set : (val)->
    @cursor_visible = val
    for node in @selection_node_list
      node.cursor_active_set val
    return
  
  cursor_blink_on : ()->
    if !@_cursor_timer
      @_cursor_timer = setInterval ()=>
        @cursor_visible_set !@cursor_visible
      , 500
    @cursor_visible_set true
    return
  
  cursor_blink_off : ()->
    if @_cursor_timer
      clearInterval @_cursor_timer
      @_cursor_timer = null
    @cursor_visible_set false
    return
  
  cursor_d_move : (x, y = 0, opt={})->
    @cursor_move @x+x, @y+y, opt
  
  _max_y : ()->
    max_y = -1
    for node in @doc.node_list
      max_y += node.line_count()
    max_y
  
  cursor_move   : (x, y = @y, opt={})->
    return if !@doc
    max_y = @_max_y()
    @x = x
    @y = y
    @y = max_y if @y > max_y
    @y = 0 if @y < 0
    @x = 0 if @x < 0 # TEMP
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    min_x = indent_x
    max_x = indent_x + node.dbnode.title.length
    @x = min_x if @x < min_x
    @x = max_x if @x > max_x
    
    @cursor_blink_on()
    
    @selection_drop(opt.select_textarea)
    @selection_node_list.push node
    
    for loc_node in @selection_node_list
      loc_node.cursor_active_set true
      loc_node.selection_active = true
      loc_node.is_current = true
      loc_node.selection_start = @x-indent_x
      loc_node.selection_end   = @x-indent_x
    
    @doc.dispatch "node_select", @selection_node_list[0]
    
    @refresh_fn()
    @true_x = @x
    return
  
  # ###################################################################################################
  #    low level
  # ###################################################################################################
  # ###################################################################################################
  #    focus
  # ###################################################################################################
  focus : ()->
    @cursor_blink_on()
    @refresh_fn()
    return
  
  focus_out : ()->
    @cursor_blink_off()
    @refresh_fn()
    return
  
  # ###################################################################################################
  #    text + mouse
  # ###################################################################################################
  _mouse_event_and_node_to_xy : (node, event)->
    mouse_pos = rel_mouse_coords event.nativeEvent
    
    loc_node = node
    node_list = []
    loop
      node_list.push loc_node
      break if !loc_node.parent_node
      loc_node = loc_node.parent_node
    
    {
      x : 2*node_list.length + Math.floor mouse_pos.x/@sx
      y : @doc.node_to_coord node
    }
  
  _is_mouse_down : false
  _mouse_up_handler : null
  node_mouse_down : (node, event)->
    @focus()
    {x,y} = @_mouse_event_and_node_to_xy node, event
    @cursor_move x,y
    @_is_mouse_down = true
    # note once is not off'able
    global_mouse_up.on "mouse_up", @_mouse_up_handler = ()=>
      @_is_mouse_down = false
      global_mouse_up.off "mouse_up", @_mouse_up_handler
      @_mouse_up_handler = null
    
    return
  
  node_mouse_up : ()->
    # @_is_mouse_down = false
    return
  
  node_mouse_move : (node, event)->
    return if !@_is_mouse_down
    
    {x,y} = @_mouse_event_and_node_to_xy node, event
    {
      node: selection_node
      indent_x
    } = @doc.coord_to_node_and_indent_x @y
    
    inner_x = x - indent_x
    inner_x = Math.max inner_x, 0
    inner_x = Math.min inner_x, node.dbnode.title.length
    console.log "inner_x=#{inner_x}"
    new_selection_end = inner_x
    if selection_node.selection_end != new_selection_end
      selection_node.selection_end = new_selection_end
      @refresh_fn()
    
    return
  
  mouse_out : ()->
    # @_is_mouse_down = false
  # ###################################################################################################
  #    keyboard
  # ###################################################################################################
  action_fn_get : ()->
    (gui_action, extra)=>
      if !xtree_action_to_description_hash[gui_action]?
        throw new Error "unknown action #{gui_action}"
      if !@[gui_action]
        throw new Error "action #{gui_action} not implemented"
      @[gui_action](extra)
  
  key_down : (node, event)->
    @keyboard_controller.key_down event
  
  key_up : (node, event)->
    
  key_press : (node, event)->
    @type node, String.fromCharCode(event.charCode)
  
  # ###################################################################################################
  #    mid level
  # ###################################################################################################
  
  # expanded_toggle : (node, event)->
  
  
  # ###################################################################################################
  #    cursor
  # ###################################################################################################
  cursor_left : ()->
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    min_x = indent_x
    if @x > min_x
      @cursor_d_move -1
    else if @y != 0
      @cursor_move Infinity, @y-1
    return
  
  cursor_right : ()->
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    max_x = indent_x + node.dbnode.title.length
    if @x < max_x
      @cursor_d_move 1
    else
      max_y = @_max_y()
      if @y != max_y
        @cursor_move 0, @y+1
    return
  
  cursor_up : ()->
    true_x = @true_x
    @cursor_move true_x, @y-1
    @true_x = true_x
    return
  
  cursor_down : ()->
    true_x = @true_x
    @cursor_move true_x, @y+1
    @true_x = true_x
    return
  
  cursor_home : ()->
    @cursor_move 0
    return
  
  cursor_end : ()->
    @cursor_move Infinity
    return
  
  
  _node_word_left2offset : (node, indent_x)->
    inner_x = @x - indent_x
    word_list = word_cut node.dbnode.title
    
    scan_pos = 0
    for word,idx in word_list
      break if scan_pos <= inner_x < scan_pos + word.length
      scan_pos += word.length
    
    if inner_x == scan_pos
      if idx == 0
        return 0
      prev_word = word_list[idx-1]
      offset = -prev_word.length
      if /^\s+$/.test prev_word
        offset -= word_list[idx-2].length if word_list[idx-2]
    else
      offset = scan_pos-inner_x
    offset
  
  _node_word_right2offset : (node, indent_x)->
    inner_x = @x - indent_x
    if inner_x == node.dbnode.title.length
      return 0
    inner_x = @x - indent_x
    word_list = word_cut node.dbnode.title
    
    scan_pos = 0
    for word,idx in word_list
      break if scan_pos <= inner_x < scan_pos + word.length
      scan_pos += word.length
    
    offset = scan_pos-inner_x+word.length
    if /^\s+$/.test word
      offset += word_list[idx+1].length if word_list[idx+1]
    
    offset
  
  word_left : ()->
    # NOTE multicursor not implemented
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    inner_x = @x - indent_x
    if inner_x == 0
      @cursor_left()
      return
    
    @cursor_d_move @_node_word_left2offset node, indent_x
  
  word_right : ()->
    # NOTE multicursor not implemented
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    inner_x = @x - indent_x
    if inner_x == node.dbnode.title.length
      @cursor_right()
      return
    
    @cursor_d_move @_node_word_right2offset node, indent_x
  # ###################################################################################################
  #    selection
  # ###################################################################################################
  selection_drop : (select_textarea = true)->
    for node in @selection_node_list
      node.cursor_active_set false
      node.selection_active = false
      node.is_current       = false
      node.selection_start = node.selection_end
    @selection_node_list.clear()
    @selection_to_textarea(select_textarea)
    return
  
  selection_to_textarea : (select_textarea = true)->
    @refresh_fn()
    call_later ()=>
      return if !@$textarea
      extract_jl = []
      for node in @selection_node_list
        {sel_min, sel_max, length} = node.sel_range()
        extract_jl.push node.dbnode.title.substr(sel_min, length)
      
      @$textarea.value = extract_jl.join "\n"
      if select_textarea
        @$textarea.select()
    return
  
  selection_left : ()->
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    return if indent_x >= @x # prevent overflow
    @x--
    for node in @selection_node_list
      node.selection_end = Math.max 0, node.selection_end-1
    @selection_to_textarea()
    return
  
  selection_right : ()->
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    return if node.dbnode.title.length+indent_x <= @x # prevent overflow
    @x++
    
    for node in @selection_node_list
      node.selection_end = Math.min node.dbnode.title.length, node.selection_end+1
    @selection_to_textarea()
    return
  
  selection_home : ()->
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    @x = indent_x
    for node in @selection_node_list
      node.selection_end = 0
    @selection_to_textarea()
    return
  
  selection_end : ()->
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    @x = indent_x+node.dbnode.title.length
    for node in @selection_node_list
      node.selection_end = node.indent_get()+node.dbnode.title.length
    @selection_to_textarea()
    return
  
  selection_word_left : ()->
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    return if indent_x >= @x # prevent overflow
    
    offset =  @_node_word_left2offset node, indent_x
    @x += offset
    for node in @selection_node_list
      node.selection_end = Math.max 0, node.selection_end+offset
    @selection_to_textarea()
    return
  
  selection_word_right : ()->
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    return if node.dbnode.title.length+indent_x <= @x # prevent overflow
    
    offset =  @_node_word_right2offset node, indent_x
    @x += offset
    for node in @selection_node_list
      node.selection_end = Math.min node.dbnode.title.length, node.selection_end+offset
    @selection_to_textarea()
    return
  
  # ###################################################################################################
  #    travel
  # ###################################################################################################
  
  # only for hierarhy
  
  # ###################################################################################################
  #    type
  # ###################################################################################################
  
  type : (node, insert_text)->
    return if !@doc
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    inner_x = @x - indent_x
    extra_offset = 0
    
    if node.selection_start != node.selection_end
      if node.selection_start < node.selection_end
        extra_offset = node.selection_end - node.selection_start
      {sel_min, sel_max} = node.sel_range()
      new_text = node.dbnode.title.substr(0, sel_min)+insert_text+node.dbnode.title.substr(sel_max)
    else
      if @doc._insert_mode
        new_text = node.dbnode.title.substr(0, inner_x)+insert_text+node.dbnode.title.substr(inner_x)
      else
        new_text = node.dbnode.title.substr(0, inner_x)+insert_text+node.dbnode.title.substr(inner_x+1)
    @node_change_text node, new_text, insert_text.length - extra_offset
  
  _selection_delete : (node)->
    return if !@doc
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    {sel_min, sel_max, length} = node.sel_range()
    new_text = node.dbnode.title.substr(0, sel_min)+node.dbnode.title.substr(sel_max)
    diff = 0
    if node.selection_end == sel_max
      diff = -length
    
    @node_change_text node, new_text, diff
  
  backspace : ()->
    return if !@doc
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    inner_x = @x - indent_x
    
    if node.selection_start != node.selection_end
      @_selection_delete()
      return
    
    if node.selection_start == 0
      @node_join_prev node
      return
    
    new_text = node.dbnode.title.substr(0, inner_x-1)+node.dbnode.title.substr(inner_x)
    @node_change_text node, new_text
  
  char_delete : ()->
    return if !@doc
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    inner_x = @x - indent_x
    
    if node.selection_start != node.selection_end
      @_selection_delete()
      return
    
    if node.selection_end == node.dbnode.title.length
      # will NOT work here
      # @node_join_next node
      return
    
    new_text = node.dbnode.title.substr(0, inner_x)+node.dbnode.title.substr(inner_x+1)
    @node_change_text node, new_text, 0
  
  cut : ()->
    return if !@$textarea
    return if !@doc
    
    {node} = @doc.coord_to_node_and_indent_x @y
    {length} = node.sel_range()
    if length
      @char_delete()
    return
  
  paste : ()->
    return if !@$textarea
    return if !@doc
    
    call_later ()=>
      # NOTE only 1 line impl
      text = @$textarea.value
      return if -1 != text.indexOf "\n"
      
      {node, indent_x} = @doc.coord_to_node_and_indent_x @y
      
      {sel_min, sel_max, length} = node.sel_range()
      new_text = node.dbnode.title.substr(0, sel_min)+text+node.dbnode.title.substr(sel_max)
      
      @node_change_text node, new_text, text.length - length
  
  capitalize : ()->
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    new_text = node.dbnode.title.substr(0, 1).toUpperCase()+node.dbnode.title.substr(1)
    @node_change_text node, new_text
  
  # ###################################################################################################
  #    word-based
  # ###################################################################################################
  word_delete_left : ()->
    return if !@doc
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    if node.selection_start != node.selection_end
      @_selection_delete()
      return
    inner_x = @x - indent_x
    return if inner_x == 0
    offset = @_node_word_left2offset node, indent_x
    
    if reg_ret = /\s+$/.exec node.dbnode.title.substr(0, inner_x)
      offset = -reg_ret[0].length
    new_text = node.dbnode.title.substr(0, inner_x+offset)+node.dbnode.title.substr(inner_x)
    @node_change_text node, new_text
  
  word_delete_right : ()->
    return if !@doc
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    if node.selection_start != node.selection_end
      @_selection_delete()
      return
    inner_x = @x - indent_x
    return if inner_x == node.dbnode.title.length
    offset = @_node_word_right2offset node, indent_x
    
    if reg_ret = /^\s+/.exec node.dbnode.title.substr(inner_x)
      offset = reg_ret[0].length
    new_text = node.dbnode.title.substr(0, inner_x)+node.dbnode.title.substr(inner_x+offset)
    @node_change_text node, new_text, 0
  
  # ###################################################################################################
  #    char based
  # ###################################################################################################
  _selection_apply : (fn)->
    return if !@doc
    @action_manager.group_start()
    for node in @selection_node_list
      if node.selection_start == node.selection_end
        text = fn node.dbnode.title
      else
        {sel_min, sel_max, length} = node.sel_range()
        pre = node.dbnode.title.substr 0, sel_min
        post= node.dbnode.title.substr sel_max
        mid = node.dbnode.title.substr sel_min, length
        text = pre+fn(mid)+post
      
      @node_change_text node, text, 0, false
    @action_manager.group_end()
  
  upper_case : ()->
    @_selection_apply (t)->t.toUpperCase()
  lower_case : ()->
    @_selection_apply (t)->t.toLowerCase()
  lang_switch : ()->
    @_selection_apply (t)->lang_switch t
  
  # ###################################################################################################
  #    undo-able
  # ###################################################################################################
  node_change_text : (node, new_text, x_offset = new_text.length - node.dbnode.title.length, cursor_move = true)->
    old_text = node.dbnode.title
    old_cursor_position = @x
    new_cursor_position = @x+x_offset
    
    action = new Xtree_action
    action.redo_fn_list.push ()=>
      node.dbnode.title = new_text
      return if !@doc
      if cursor_move
        if -1 != y = @doc.node_to_coord node
          @cursor_move new_cursor_position, y
      @node_save_refresh node
      return
    
    action.undo_fn_list.push ()=>
      node.dbnode.title = old_text
      if cursor_move
        if -1 != y = @doc.node_to_coord node
          @cursor_move old_cursor_position, y
      @node_save_refresh node
      return
      
    
    action.redo()
    @action_manager.action_add action
    return
  
  _node_swap : (node, node_swap, seek_list)->
    node_idx      = seek_list.idx node
    node_swap_idx = seek_list.idx node_swap
    
    node_order      = node.dbnode.order
    node_swap_order = node_swap.dbnode.order
    action = new Xtree_action
    action.redo_fn_list.push ()=>
      node.dbnode.order = node_swap_order
      node_swap.dbnode.order = node_order
      seek_list[node_idx] = node_swap
      seek_list[node_swap_idx] = node
      node.dbnode.save()
      node_swap.dbnode.save()
      @cursor_move @x, @doc.node_to_coord node
      return
    
    action.undo_fn_list.push ()=>
      node.dbnode.order       = node_order
      node_swap.dbnode.order  = node_swap_order
      seek_list[node_swap_idx]= node_swap
      seek_list[node_idx]     = node
      node.dbnode.save()
      node_swap.dbnode.save()
      @cursor_move @x, @doc.node_to_coord node
      return
    
    action.redo()
    @action_manager.action_add action
    return
  
  _seek_list_get : (node)->
    if node.parent_node
      throw new Error "unimplemented"
    else
      seek_list = @doc.node_list
    seek_list
  
  node_swap_up : ()->
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    seek_list = @_seek_list_get node
    
    idx = seek_list.idx node
    return if !node_swap = seek_list[idx-1]
    
    @_node_swap node, node_swap, seek_list
    return
  
  node_swap_down : ()->
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    seek_list = @_seek_list_get node
    
    idx = seek_list.idx node
    return if !node_swap = seek_list[idx+1]
    
    @_node_swap node, node_swap, seek_list
    return
  
  done_toggle : ()->
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    done = node.dbnode.done
    action = new Xtree_action
    action.redo_fn_list.push ()=>
      node.dbnode.done = !done
      @node_save_refresh node
      return
    
    action.undo_fn_list.push ()=>
      node.dbnode.done = done
      @node_save_refresh node
      return
    
    action.redo()
    @action_manager.action_add action
    return
  
  todo_toggle : ()->
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    in_todo_list = node.dbnode.in_todo_list
    action = new Xtree_action
    action.redo_fn_list.push ()=>
      node.dbnode.in_todo_list = !in_todo_list
      @node_save_refresh node
      return
    
    action.undo_fn_list.push ()=>
      node.dbnode.in_todo_list = in_todo_list
      @node_save_refresh node
      return
    
    action.redo()
    @action_manager.action_add action
    return
  
  # tier change
  important_inc : ()->
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    value = node.dbnode.tier_hash.important
    action = new Xtree_action
    action.redo_fn_list.push ()=>
      node.dbnode.tier_hash.important = value+1
      @node_save_refresh node
      return
    
    action.undo_fn_list.push ()=>
      node.dbnode.tier_hash.important = value
      @node_save_refresh node
      return
    
    action.redo()
    @action_manager.action_add action
    return
  
  important_dec : ()->
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    value = node.dbnode.tier_hash.important
    action = new Xtree_action
    action.redo_fn_list.push ()=>
      node.dbnode.tier_hash.important = value-1
      @node_save_refresh node
      return
    
    action.undo_fn_list.push ()=>
      node.dbnode.tier_hash.important = value
      @node_save_refresh node
      return
    
    action.redo()
    @action_manager.action_add action
    return
  
  refined_inc : ()->
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    value = node.dbnode.tier_hash.refined
    action = new Xtree_action
    action.redo_fn_list.push ()=>
      node.dbnode.tier_hash.refined = value+1
      @node_save_refresh node
      return
    
    action.undo_fn_list.push ()=>
      node.dbnode.tier_hash.refined = value
      @node_save_refresh node
      return
    
    action.redo()
    @action_manager.action_add action
    return
  
  refined_dec : ()->
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    value = node.dbnode.tier_hash.refined
    action = new Xtree_action
    action.redo_fn_list.push ()=>
      node.dbnode.tier_hash.refined = value-1
      @node_save_refresh node
      return
    
    action.undo_fn_list.push ()=>
      node.dbnode.tier_hash.refined = value
      @node_save_refresh node
      return
    
    action.redo()
    @action_manager.action_add action
    return
  
  # action manager
  undo : ()->
    @action_manager.undo()
  
  redo : ()->
    @action_manager.redo()
  # ###################################################################################################
  #    can't undo
  # ###################################################################################################
  node_create : ()->
    return if !@allow_create
    new_node = new TODO_node
    new_node.parent_doc = @doc
    new_node.dbnode = new DBTask
    # if @project
    #   new_node.project_list.push @project
    window.db_task_pool.list.push new_node.dbnode
    @doc.node_list.push new_node
    @cursor_move @x, @doc.node_to_coord new_node
    return
  
  enter_task_create : ()->
    return if !@allow_create
    {node, indent_x} = @doc.coord_to_node_and_indent_x @y
    seek_list = @_seek_list_get node
    
    idx = seek_list.idx node
    new_node = new TODO_node
    new_node.parent_doc = @doc
    new_node.dbnode = new DBTask
    # if @project
    #   new_node.dbnode.project_list.push @project
    window.db_task_pool.list.push new_node.dbnode # Костыль
    seek_list.insert_after idx, new_node
    
    for v,idx in seek_list
      if v.dbnode.order != idx
        v.dbnode.order = idx
        v.dbnode.save()
    
    @cursor_move @x, @doc.node_to_coord new_node
    return
  
  # task_start_stop : ()->
  #   {node, indent_x} = @doc.coord_to_node_and_indent_x @y
  #   {dbnode} = node
  #   if dbnode.is_started()
  #     dbnode.time_stop()
  #   else
  #     dbnode.time_start()
  #   @doc.dispatch "refresh"
  
# ###################################################################################################
#    doc
# ###################################################################################################
class window.TODO_doc
  node_list : []
  # filters
  _where    : {}
  custom_filter_hash : {}
  
  _insert_mode : true
  
  event_mixin @
  constructor:()->
    event_mixin_constructor @
    @node_list = []
    @_where = {}
    @custom_filter_hash = {}
    db_task_pool.on "node_save", (dbnode)=>
      # maybe faster hash???
      for v,idx in @node_list
        if v.dbnode == dbnode
          match = dbnode.where_match(@_where) and dbnode.custom_filter_hash_match(@custom_filter_hash)
          if !match
            @node_list.remove_idx idx
            @dispatch "node_move_out", v
          return
      match = dbnode.where_match(@_where) and dbnode.custom_filter_hash_match(@custom_filter_hash)
      if match
        @node_list.push node = @_wrap_dbnode dbnode
        @dispatch "node_move_in", node
      return
  
  delete : ()->
    
  _wrap_dbnode : (dbnode)->
    ext = new TODO_node
    ext.parent_doc = @
    ext.dbnode = dbnode
    ext
  
  # NOTE now it's sync
  load : (on_end)->
    @node_list.clear()
    for dbnode in db_task_pool.find @_where
      continue if !dbnode.custom_filter_hash_match(@custom_filter_hash)
      @node_list.push @_wrap_dbnode dbnode
    
    @dispatch "load"
    on_end()
  
  where_update : ()->
    @node_list.clear()
    for dbnode in db_task_pool.find @_where
      continue if !dbnode.custom_filter_hash_match(@custom_filter_hash)
      @node_list.push @_wrap_dbnode dbnode
    @dispatch "refresh"
    return
  
  # ###################################################################################################
  #    coord <-> node 
  # ###################################################################################################
  _coord_to_node_lookup_counter : 0
  _coord_to_node_ret_level      : 0
  coord_to_node_and_indent_x : (y)->
    @_coord_to_node_lookup_counter = y
    for root in @node_list
      ret = @_coord_to_node root, 0
      break if ret
    if ret == null
      throw new Error "coord_to_node_and_indent_x error: y out of bounds"
    {
      node    : ret
      indent_x: 2*(@_coord_to_node_ret_level+1)
    }
  
  _coord_to_node : (tree, level)->
    if @_coord_to_node_lookup_counter == 0
      @_coord_to_node_ret_level = level
      return tree
    @_coord_to_node_lookup_counter--
    return null if !tree.expanded
    level++
    for child in tree.child_list
      return ret if ret = @_coord_to_node child, level
    return null
  
  _node_to_coord_y : 0
  node_to_coord : (node)->
    @_node_to_coord_y = 0
    for root in @node_list
      return @_node_to_coord_y if @_node_to_coord node, root
    -1
  
  _node_to_coord : (node, tree)->
    return true if tree == node
    @_node_to_coord_y++
    if tree.expanded
      for subtree in tree.child_list
        return true if @_node_to_coord node, subtree
    return false
  
  # ###################################################################################################
  #    gui
  # ###################################################################################################
  gui_focus         : ()->      @dispatch "gui", {switch: "focus",           }
  gui_focus_out     : ()->      @dispatch "gui", {switch: "focus_out",       }
  gui_key_down      : (event)-> @dispatch "gui", {switch: "key_down",  event }
  gui_key_up        : (event)-> @dispatch "gui", {switch: "key_up",    event }
  gui_key_press     : (event)-> @dispatch "gui", {switch: "key_press", event }
  gui_mouse_out     : (event)-> @dispatch "gui", {switch: "mouse_out", event }

# ###################################################################################################
#    node
# ###################################################################################################
class window.TODO_node
  parent_doc  : null
  parent_node : null
  dbnode      : null
  
  # partially stored (browser localstorage)
  expanded        : false
  is_current      : false
  # not stored
  cursor_active   : false
  selection_active: false
  selection_start : 0
  selection_end   : 0
  
  $cursor         : null
  
  
  
  gui_expanded_toggle : ()->      @parent_doc.dispatch "gui", {switch: "expanded_toggle",   node:@        }
  gui_click           : (event)-> @parent_doc.dispatch "gui", {switch: "node_click",        node:@, event }
  gui_double_click    : (event)-> @parent_doc.dispatch "gui", {switch: "node_double_click", node:@, event }
  gui_mouse_down      : (event)-> @parent_doc.dispatch "gui", {switch: "node_mouse_down",   node:@, event }
  gui_mouse_up        : (event)-> @parent_doc.dispatch "gui", {switch: "node_mouse_up",     node:@, event }
  gui_mouse_move      : (event)-> @parent_doc.dispatch "gui", {switch: "node_mouse_move",   node:@, event }
  
  cursor_active_set: (val)->
    @cursor_active = val
    if @$cursor
      @$cursor.style.display = if val then "inline" else "none"
    return
  
  # ###################################################################################################
  #    Tools
  # ###################################################################################################
  line_count : ()->
    return 1 if !@expanded
    ret = 1
    for v in @child_list
      ret += v.line_count()
    ret
  
  indent_get : ()->
    return 0 if !@parent_node
    return 2+@parent_node.indent_get()
  
  sel_range : ()->
    sel_min = Math.min @selection_start, @selection_end
    sel_max = Math.max @selection_start, @selection_end
    {
      sel_min
      sel_max
      length : sel_max - sel_min
    }