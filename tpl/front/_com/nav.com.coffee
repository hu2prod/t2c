module.exports =
  render : ()->
    Page_tab_bar_router {
      value : @props.path
      list  : window.route_list
      on_change : (t)=>
        route_go t.path
        return
      btn_style :
        fontSize  : 10
    }
