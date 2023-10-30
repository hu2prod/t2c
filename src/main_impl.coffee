require "fy"
require "fy/codegen"
fs = require "fs"

@go = (argv, cb)->
  cmd = argv._[0]
  if !cmd
    puts "usage"
    # puts "  t1c <command>"
    puts "  t2c <command>"
    puts ""
    puts "command list"
    
    cmd_list = [
      {
        title       : "init"
        description : ""
      }
      {
        title       : "build1"
        description : "generate code + min deps"
      }
      {
        title       : "build2"
        description : "build1 + long builds build (e.g. NAPI)"
      }
      {
        title       : "build1_watch"
        description : "build1 + watch on any files changed in gen/ code_bubble/ override/"
      }
      {
        title       : "build2_watch"
        description : "build2 + watch on any files changed in gen/ code_bubble/ override/"
      }
      {
        title       : "build1_watch_x100"
        description : "build1_watch for debug"
      }
    ]
    max_title_width = 0
    for v in cmd_list
      max_title_width = Math.max max_title_width, v.title.length
    
    for v in cmd_list
      {title, description} = v
      # подобрано на глаз
      puts "----------------------------------------------------------------------------------------------------------------------------------"
      puts "  #{title.rjust max_title_width}  #{make_tab description, ' '.repeat 4+max_title_width}"
    return cb new Error "no cmd"
  
  cmd = cmd.split("-").join("_") # all commands with - are correct and converted to _
  if !/^[_a-z0-9]+$/.test cmd
    perr "bad command #{cmd}"
    return cb new Error "bad cmd"
  
  switch cmd
    when "init"
      cmd = require("./cmd/init")
    
    when "build1"
      cmd = require("./cmd/build1")
    
    when "build2"
      cmd = require("./cmd/build2")
    
    when "build1_watch"
      cmd = require("./cmd/build1_watch")
    
    when "build1_watch_x100"
      cmd = require("./cmd/build1_watch_x100")
    
    when "build2_watch"
      cmd = require("./cmd/build2_watch")
    
    else
      perr "unknown cmd '#{cmd}'"
      return cb new Error "unknown cmd"
  
  # await + switch = bad combination for code coverage
  await cmd {}, defer(err); return cb err if err
  
  return cb()
