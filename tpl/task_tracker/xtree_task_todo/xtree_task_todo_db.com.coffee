null_project = {
  value : null
  title : ""
}
# default_filter_project_id = null_project
# try
#   default_filter_project_id = JSON.parse localStorage.filter_project_id
# catch err
# 
# 
module.exports =
  state :
    loaded          : false
    # filter_project  : default_filter_project_id
    filter_find     : ""
    filter_show_done: true
    neg_tier_count  : 0
    mode_unsorted   : true
  selected_node       : null
  selected_track      : null
  
  doc_hash            : {} # for fast rebuild on neg_tier_count change
  doc_list_list       : []
  doc_todo            : []
  tier_refined_list   : []
  tier_important_list : []
  mount : ()->
    load_ls @, "filter_show_done"
    load_ls @, "neg_tier_count"
    await
      db_task_pool      .load defer(err1)
      # TODO load dyn_enum_task_tracker_todo_item_group
      # TODO load task_tracker_iteration
    return perr err1 if err1
    
    # await
    #   db_track_pool     .load defer(err1)
    #   db_task_pool      .load defer(err2)
    #   db_project_pool   .load defer(err3)
    #   db_time_point_pool.load defer(err4)
    # merge_time_point_to_task()
    # return perr err1 if err1
    # return perr err2 if err2
    # return perr err3 if err3
    # return perr err4 if err4
    
    @doc_todo = doc = new TODO_doc
    _where =
      in_todo_list:true
    if !@state.filter_show_done
      _where.done = false
    doc._where = _where
    puts "doc._where", doc._where
    # TODO переместить в отдельный компонент ? как .on "load" ?
    # copypaste
    doc.load ()->
    @doc_handler_apply doc
    
    @refresh_tier_docs()
    @set_state loaded : true
  
  refresh_tier_docs : ()->
    tier_list = []
    for i in [-@state.neg_tier_count ... 0] by 1
      tier_list.push i
    tier_list.push null
    for i in [0 .. 5]
      tier_list.push i
      
    @tier_refined_list = tier_list
    @tier_important_list = tier_list
    
    @doc_list_list = []
    # selected_track = db_track_pool.list[0]
    # @selected_track = db_track_pool.list[0]
    for tier_refined in @tier_refined_list
      @doc_list_list.push doc_equal_refine_list = []
      for tier_important in @tier_important_list
        _where = {
          tier_hash :
            important : tier_important
            refined   : tier_refined
        }
        if !@state.filter_show_done
          _where.done = false
        
        key = JSON.stringify _where
        if doc = @doc_hash[key]
          doc_equal_refine_list.push doc
        else
          doc = new TODO_doc
          doc_equal_refine_list.push doc
          doc.tier_important= tier_important
          doc.tier_refined  = tier_refined
          doc._where = _where
          # TODO переместить в отдельный компонент ? как .on "load" ?
          doc.load ()=>
          @doc_handler_apply doc
    
    @doc_hash_rebuild()
    @force_update()
    return
  
  doc_hash_rebuild : ()->
    @doc_hash = {}
    for doc_list in @doc_list_list
      for doc in doc_list
        key = JSON.stringify doc._where
        @doc_hash[key] = doc
    return
  
  doc_handler_apply : (doc)->
    doc.on "node_select", (node)=>
      if @selected_node != node
        @selected_node = node
        @force_update()
      return
    doc.on "node_refresh", (node)=>
      if @selected_node == node
        # NOTE need only for Task_object_inspector, but...
        @force_update()
      return
    return
  
  render : ()->
    if !@state.loaded
      return div "loading..."
    
    tier_null_idx = @state.neg_tier_count
    
    table {class: "grid_layout"}
      tbody
        tr
          # TODO + negative tiers
          td { class : "cell_center", rowSpan : @tier_refined_list.length+1 }
            b "Filter"
            table {
              style:
                fontFamily : "monospace"
            }
              tbody
                # tr
                #   td {
                #     style:
                #       width : 80
                #   }, "Project"
                #   list = [null_project]
                #   # for dbproject in db_project_pool.list
                #   for dbproject in []
                #     list.push {
                #       value: dbproject._id
                #       title: dbproject.title
                #     }
                #   td Select bind2(@, "filter_project", on_change:()=>call_later ()=>@update_filter_project()), {
                #     list : list
                #     style:
                #       width : "100%"
                #   }
                tr
                  td {
                    style:
                      width : 80
                  }, "Find"
                  td Text_input bind2(@, "filter_find", on_change:()=>call_later ()=>@update_filter_find()), {
                    style:
                      width : 300
                  }
                tr
                  td {
                    style:
                      width : 80
                  }, "Show done"
                  td Checkbox bind2ls(@, "filter_show_done", on_change:()=>call_later ()=>@update_filter_done())
                tr
                  td "Neg tier"
                  td Number_input bind2ls(@, "neg_tier_count", on_change:()=>call_later ()=>@refresh_tier_docs()), {
                    style:
                      width : 300
                  }
            b "Object inspector"
            Xtree_task_todo_task_object_inspector {node: @selected_node}
          td { class : "cell_center"}
            Tab_bar {
              hash : {
                "unsorted": "Unsorted backblog"
                "checklist": "TODO checklist"
              }
              center : true
              value: if @state.mode_unsorted then "unsorted" else "checklist"
              on_change : (value)=>
                @set_state mode_unsorted : value == "unsorted"
            }
          td {
            style:
              minWidth : 110
          }
          for doc in @doc_list_list[0]
            td { class : "cell_center" }
              {tier_important} = doc
              b if tier_important? then "Tier #{tier_important}" else "No importance tier"
        for doc_list,idx1 in @doc_list_list # refined
          tr {}
            {tier_refined} = doc_list[0]
            if idx1 == 0
              td {
                style:
                  minWidth: 300
                  height  : 150
                rowSpan : @tier_refined_list.length+1
              }
                if @state.mode_unsorted
                  if doc = @doc_list_list[tier_null_idx]?[tier_null_idx]
                    Xtree_task_todo {
                      doc
                      allow_create: true
                    }
                else
                  Xtree_task_todo {
                    doc : @doc_todo
                  }
            if idx1 == tier_null_idx
              td b "No refine tier"
            else
              td b "Tier #{tier_refined}"
            for doc,idx2 in doc_list # important
              td {
                style:
                  minWidth: 300
                  height  : 150
              }
                if idx1 != tier_null_idx or idx2 != tier_null_idx
                  Xtree_task_todo {doc}
                else
                  div {
                    style:
                      fontFamily      : "monospace"
                      textAlign       : "center"
                      backgroundColor : "#eee"
                      lineHeight      : "150px"
                      height          : "100%"
                  }, "moved"
  
  update_filter_done : ()->
    update_doc = (doc)=>
      if @state.filter_show_done
        delete doc._where.done
      else
        doc._where.done = false
      doc.where_update()
      return
    
    for list in @doc_list_list
      for doc in list
        update_doc doc
    
    update_doc @doc_todo
    @doc_hash_rebuild()
    return
  
  # get_project_by_id : (_id)->
  #   # for dbproject in db_project_pool.list
  #   for dbproject in []
  #     return dbproject if dbproject._id == _id
  #   null
  
  # update_filter_project : ()->
  #   _id = @state.filter_project
  #   localStorage.filter_project_id = JSON.stringify _id
  #   # На самом деле _id это только строка. null'ом оно быть не может из-за внутренней структуры Select
  #   if _id
  #     update_doc = (doc)=>
  #       doc.custom_filter_hash.project = (dbnode)->
  #         for dbproject in dbnode.project_list
  #           return true if dbproject._id == _id
  #         false
  #       doc.where_update()
  #       return
  #   else
  #     update_doc = (doc)=>
  #       delete doc.custom_filter_hash.project
  #       doc.where_update()
  #   
  #   for list in @doc_list_list
  #     for doc in list
  #       update_doc doc
  #   
  #   update_doc @doc_todo
  #   @doc_hash_rebuild()
  #   return
  
  update_filter_find : ()->
    if @state.filter_find
      chunk_list = @state.filter_find.split(" ").filter (t)->t
      update_doc = (doc)=>
        doc.custom_filter_hash.find = (dbnode)->
          for chunk in chunk_list
            continue if -1 != dbnode.title.indexOf chunk
            continue if -1 != dbnode.description.indexOf chunk
            return false
          true
        doc.where_update()
        return
    else
      update_doc = (doc)=>
        delete doc.custom_filter_hash.find
        doc.where_update()
    
    for list in @doc_list_list
      for doc in list
        update_doc doc
    
    update_doc @doc_todo
    @doc_hash_rebuild()
    return
    
  