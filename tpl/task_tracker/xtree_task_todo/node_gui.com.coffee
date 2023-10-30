time_slot = 10*60*1000 # 10m
# time_slot = 8*60*60*1000 # 8h
# time_slot = 12*60*60*1000 # 12h
# time_slot = 24*60*60*1000 # 24h
module.exports =
  render : ()->
    {node} = @props
    return div {} if !node
    {dbnode} = node
    # {expanded,child_list} = node
    child_list = []
    expanded = false
    puts "redraw"
    
    div {class : "tree_node"}
      if child_list.length
        b {
          class:"tree_fix_expander #{if !child_list.length then 'tree_expander_hide' else ''}"
          on_click:@expanded_toggle
        }, if expanded then '-' else '+'
      else
        icon = ""
        color = ""
        if dbnode.last_edit_ts and !dbnode.done
          diff_ts = Date.now() - dbnode.last_edit_ts
          diff_ts_slot = diff_ts / time_slot
          diff_ts_slot_log = Math.floor Math.max 0, Math.log2(diff_ts_slot)
          icon = diff_ts_slot_log if diff_ts_slot_log
          color = "#FFFF00" if diff_ts_slot_log >= 1
          color = "#FFEE00" if diff_ts_slot_log >= 2
          color = "#FFCC00" if diff_ts_slot_log >= 3
          color = "#FFAA00" if diff_ts_slot_log >= 4
          color = "#FF7700" if diff_ts_slot_log >= 5
          color = "#FF0000" if diff_ts_slot_log >= 6
        else
          diff_ts = 0
        
        # if dbnode.is_started()
        #   # icon = "▶️"
        #   icon = "▶"
        #   color = ""
        # else if dbnode._time_point_list.length and !dbnode.done
        #   # TODO сделать более няшную иконку
        #   icon = "||"
        #   color = ""
        
        b {
          class:"tree_fix_expander_time"
          style : {color}
        }, icon
      
      sel_min = Math.min node.selection_start, node.selection_end
      sel_max = Math.max node.selection_start, node.selection_end
      pre {
        # TODO dbnode.meta.done
        class : "tree_text #{if node.is_current then 'tree_current_line' else ''} #{if dbnode.done then 'tree_done' else ''}"
        onMouseDown : @text_mouse_down
        onMouseUp   : @text_mouse_up
        onMouseMove : @text_mouse_move
      }, ()->
        span {
          ref   : 'cursor'
          class : if node.parent_doc._insert_mode then "tree_cursor" else "tree_cursor_replace"
          style :
            position : "absolute"
            display  : if node.cursor_active then 'inline' else 'none'
            left     : window.codemirror_magic_value_sx*node.selection_end
        }
        span {
          class:"tree_selection"
          style:
            position  : 'absolute'
            display  : if node.selection_active then 'inline' else 'none'
            left      : window.codemirror_magic_value_sx*sel_min
            width     : window.codemirror_magic_value_sx*(sel_max - sel_min)
        }
        dbnode.title+'\u00A0'
  
  
  expanded_toggle : ()->
    @props.node.gui_expanded_toggle()
    @force_update()
  
  # TODO shorten
  text_mouse_down : (event)->
    @props.node.gui_mouse_down(event)
    @force_update()
  
  text_mouse_up : (event)->
    @props.node.gui_mouse_up(event)
    @force_update()
  
  text_mouse_move : (event)->
    @props.node.gui_mouse_move(event)
    # @force_update()