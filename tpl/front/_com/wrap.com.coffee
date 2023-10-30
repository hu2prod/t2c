module.exports =
  render : ()->
    div {
      style:
        height      : "100%"
        width       : "100%"
    }
      div {
        style:
          marginBottom : -50
      }
        Page_nav {path : @props.path}
      div {
        style:
          display     : "table"
          height      : "100%"
          width       : "100%"
      }
        div {
          style:
            paddingTop    : 50+10
            paddingLeft   : 10
            paddingRight  : 10
            display       : "table-cell"
            # verticalAlign : "middle"
            # textAlign     : "center"
        }
          @props.children
