module.exports =
  state :
    new_task_title : ""
  
  controller : null
  mount_done : ()->
    @controller = new TODO_gui_controller
    # @controller.project = @props.project
    @controller.$textarea = @refs.textarea
    @controller.refresh_fn = ()=>
      @force_update()
    @controller.init()
    # LATER update on props change
    @controller.set_doc @props.doc
    @controller.allow_create = @props.allow_create
    call_later ()=>
      # is_current is setted after set_doc
      @force_update()
  
  componentWillUpdate : (new_props)->
    if new_props.doc != @props.doc
      @controller.set_doc new_props.doc
    # if new_props.project != @props.project
      # @controller.project = new_props.project
    @controller.allow_create = new_props.allow_create
  
  render : ()->
    div {
      on_click  : @focus
    }
      textarea {
        ref       : 'textarea'
        onKeyDown : @key_down
        onKeyUp   : @key_up
        onKeyPress: @key_press
        onBlur    : @focus_out
        style :
          position: 'absolute'
          # top     : 100
          top     : -1000
          left    : -1000
      }
      div {style: position : 'relative'}
        if @props.doc.node_list.length
          for task in @props.doc.node_list
            Xtree_task_todo_node_gui {node: task}
        else
          if @props.allow_create
            Button {
              label    : "+"
              on_click : @node_create
              style:
                width: "100%"
            }
          else
            div {
              style:
                width       : '100%'
                textAlign   : 'center'
                fontFamily  : 'monospace'
                color       : '#ccc'
            }, 'empty'
  
  node_create : ()->
    @controller.node_create()
  # ###################################################################################################
  #    handlers
  # ###################################################################################################
  focus : ()->
    @refs.textarea.focus()
    @props.doc.gui_focus()
    @force_update()
  
  focus_out : ()->
    @props.doc.gui_focus_out()
    @force_update()
  
  key_down : (event)->
    @props.doc.gui_key_down(event)
  
  key_up : (event)->
    @props.doc.gui_key_up(event)
  
  key_press : (event)->
    @props.doc.gui_key_press(event)
  
  mouse_out : (event)->
    @props.doc.gui_mouse_out(event)
  