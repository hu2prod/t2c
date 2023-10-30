module.exports =
  render : ()->
    div {
      class : "tab"
      style : @props.style
    }
      style     = if @props.center then {margin:"0 auto"} else {};
      btn_style = if @props.center then {} else {float:"left"};
      obj_set btn_style, @props.btn_style if @props.btn_style
      div {style}
        for v in @props.list
          do (v)=>
            a {
              class : if @props.value == v.path then "active" else ""
              href  : "#/#{v.path}"
              on_click: (e)=>
                e.preventDefault()
                @props.on_change v
              style : btn_style
            }, v.title
