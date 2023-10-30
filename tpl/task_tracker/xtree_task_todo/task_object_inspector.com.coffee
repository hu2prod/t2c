pad_zero_2 = (t)-> t.rjust 2, "0"
tp_date_format = (time_point)->
  return "??.??.??" if !time_point
  date  = new Date time_point.ts
  day   = pad_zero_2 date.getDate()
  month = pad_zero_2 date.getMonth()+1
  year  = pad_zero_2 date.getFullYear()
  "#{day}.#{month}.#{year}"

tp_ts_format = (time_point)->
  return "??:??:??" if !time_point
  date  = new Date time_point.ts
  hour  = pad_zero_2 date.getHours()
  min   = pad_zero_2 date.getMinutes()
  sec   = pad_zero_2 date.getSeconds()
  "#{hour}:#{min}:#{sec}"
  
duration_format = (total)->
  jl = []
  sec = total//1000
  jl.push pad_zero_2 sec%60
  min = sec//60
  jl.push pad_zero_2 min%60
  hour = min//60
  jl.push pad_zero_2 hour if hour
  jl.reverse()
  jl.join ":"

module.exports =
  state:
    new_project_name : ""
  input_size_x : 300
  
  # old_is_started : null
  # mount : ()->
  #   # Костыль, но работает
  #   @timer = setInterval ()=>
  #     return if !@props.node
  #     val = @props.node.dbnode.is_started()
  #     if val or @old_is_started != val
  #       @old_is_started = val
  #       @force_update()
  #     return
  #   , 1000
  
  unmount : ()->
    clearInterval @timer
  
  render : ()->
    # is_started = @props.node?.dbnode.is_started() or false
    table {
      style:
        fontFamily : "monospace"
    }
      tbody
        if @props.node
          {parent_doc, dbnode} = @props.node
          save = ()=>
            dbnode.save()
            @force_update()
            parent_doc.dispatch "refresh"
            return
          tr
            td {
              style:
                width : 80
            }, "id"
            td
              dbnode.id
          tr
            td {
              style:
                width : 80
            }, "Done"
            td
              Checkbox {
                value : dbnode.done
                on_change : (value)->
                  dbnode.done = value
                  save()
              }
          tr
            td {
              style:
                width : 80
            }, "TODO"
            td
              Checkbox {
                value : dbnode.in_todo_list
                on_change : (value)->
                  dbnode.in_todo_list = value
                  save()
              }
          tr
            td "Title"
            td
              Text_input {
                value : dbnode.title
                on_change : (value)->
                  dbnode.title = value
                  save()
                style:
                  fontFamily : "monospace"
                  width  : @input_size_x
              }
          tr
            td "Description"
            td
              Textarea {
                value : @props.node.dbnode.description
                on_change : (value)->
                  dbnode.description = value
                  save()
                style:
                  width  : @input_size_x+8 # hacky fix
                  height : 600
                  resize : "vertical"
              }
          # tr
          #   td "Estimate"
          #   td
          #     # TODO component for storing in tsi format
          #     Text_input {
          #       value : @props.node.dbnode.estimate_tss
          #       on_change : (value)->
          #         dbnode.estimate_tss = value
          #         save()
          #       style:
          #         fontFamily : "monospace"
          #         width  : @input_size_x
          #     }
          # TODO make for for all tiers for current track
          # also extra for other tiers, not for current track
          tr
            td "Important"
            td
              Number_input {
                value : @props.node.dbnode.tier_hash.important ? ""
                on_change : (value)->
                  dbnode.tier_hash.important = value
                  save()
                style:
                  width  : @input_size_x
              }
          tr
            td "Refined"
            td
              Number_input {
                value : @props.node.dbnode.tier_hash.refined ? ""
                on_change : (value)->
                  dbnode.tier_hash.refined = value
                  save()
                style:
                  width  : @input_size_x
              }
          tr
            td "Not a pain"
            td
              Number_input {
                value : @props.node.dbnode.tier_hash.wtf ? ""
                on_change : (value)->
                  dbnode.tier_hash.wtf = value
                  save()
                style:
                  width  : @input_size_x
              }
          # tr
          #   td "Project list"
          #   td
          #     table {
          #       style:
          #         width: "100%"
          #     }
          #       tbody
          #         tr
          #           td "name"
          #         for project in @props.node.dbnode.project_list
          #           do (project)=>
          #             tr
          #               td project.title
          #               td Button {
          #                 label: "x"
          #                 on_click: ()=>@project_remove project
          #               }
          #         tr
          #           td Text_input bind2(@, "new_project_name"), {
          #               style:
          #                 width: "100%"
          #               on_enter: ()=>@new_project_add @state.new_project_name
          #             }
          #           td Button {
          #             label   : "Add"
          #             on_click: ()=>@new_project_add @state.new_project_name
          #           }
          #         
          #         sort_list = []
          #         cmp = @state.new_project_name
          #         for dbproject in db_project_pool.list
          #           dist = levenshtein dbproject.title, cmp
          #           # continue if dist > 5
          #           sort_list.push {
          #             # dbproject : dbproject
          #             title : dbproject.title
          #             dist  : dist
          #           }
          #         sort_list.sort (a,b)->a.dist-b.dist
          #         sort_list = sort_list.slice 0, 5
          #         for v in sort_list
          #           do (v)=>
          #             tr {
          #               style:
          #                 background: if v.dist == 0 then "#afa" else ""
          #               on_click: ()=>
          #                 # new_project_add v.dbproject.title
          #                 @new_project_add v.title
          #             }
          #               td v.title
          #               td v.dist
          # tr
          #   td "Time track"
          #   td
          #     # TODO separate component and move OI to separate folder
          #     if is_started
          #       Button {
          #         label     : "stop"
          #         on_click  : @time_stop
          #       }
          #     else
          #       Button {
          #         label     : "start"
          #         on_click  : @time_start
          #       }
          #     table {
          #       style :
          #         width : "100%"
          #     }
          #       tbody
          #         start_time_point = null
          #         date_str = ""
          #         total = 0
          #         for time_point in @props.node.dbnode._time_point_list
          #           format = tp_ts_format time_point
          #           
          #           if time_point.is_start
          #             start_time_point = time_point
          #           else
          #             new_date_str1 = tp_date_format start_time_point
          #             new_date_str2 = tp_date_format time_point
          #             duration = (time_point?.ts or 0) - (start_time_point?.ts or 0)
          #             if new_date_str1 != new_date_str2
          #               CKR.item tr
          #                 td "#{new_date_str1} #{tp_ts_format start_time_point} - #{new_date_str2} #{tp_ts_format time_point}"
          #                 td duration_format duration
          #             else
          #               if date_str != new_date_str2
          #                 date_str = new_date_str2
          #                 CKR.item tr
          #                   td {colSpan:2}
          #                     b new_date_str2
          #               CKR.item tr
          #                 td "#{tp_ts_format start_time_point} - #{tp_ts_format time_point}"
          #                 td duration_format duration
          #             
          #             total += duration
          #             start_time_point = null
          #         if start_time_point
          #           CKR.item tr
          #             td "#{tp_ts_format start_time_point} - ..:..:.."
          #             # BUG autoupdate работать не будет
          #             duration = Date.now() - (start_time_point?.ts or 0)
          #             total += duration
          #             td duration_format duration
          #         CKR.item tr
          #           td b "Total : "
          #           td duration_format total
          #         return null
                
  
  # time_start: ()->
  #   {dbnode} = @props.node
  #   dbnode.time_start()
  #   @props.node.parent_doc.dispatch "refresh"
  #   @force_update()
  # 
  # time_stop: ()->
  #   {dbnode} = @props.node
  #   dbnode.time_stop()
  #   @props.node.parent_doc.dispatch "refresh"
  #   @force_update()
  
  # NOTE project_list not defined yet
  # new_project_add: (title)->
  #   # search project with this name
  #   found = null
  #   for dbproject in db_project_pool.list
  #     if dbproject.title == title
  #       found = dbproject
  #       break
  #   
  #   if !found
  #     dbproject = new DBProject
  #     dbproject.title = @state.new_project_name
  #     window.db_project_pool.list.push dbproject # Костыль
  #     dbproject.save()
  #   else
  #     dbproject = found
  #   
  #   # не добавлять дубликаты
  #   # Прим. На самом деле достаточно было бы upush
  #   # Но у нас BUG т.к. они создаются почему-то по второму кругу
  #   found = null
  #   for project in @props.node.dbnode.project_list
  #     if project._id == dbproject._id
  #       found = true
  #       break
  #   
  #   if !found
  #     @props.node.dbnode.project_list.push dbproject
  #   @props.node.dbnode.save()
  #   @force_update()
  #   return
  # 
  # project_remove: (dbproject)->
  #   @props.node.dbnode.project_list.remove dbproject
  #   @props.node.dbnode.save()
  #   @force_update()
  
  