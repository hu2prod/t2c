fs      = require "fs"
chokidar= require "chokidar"
require "event_mixin"

module.exports = (dir_list, run)->
  need_refresh = true
  ev = new Event_mixin
  
  for dir in dir_list
    do (dir)=>
      loop
        if !need_refresh
          await setTimeout defer(), 1000
        
        continue if !fs.existsSync dir
        watcher = chokidar.watch dir
        await watcher.on "ready", defer()
        timeout = null
        handler = (path)->
          clearTimeout timeout if timeout
          timeout = setTimeout ()->
            puts "file changed", "#{dir}/#{path}"
            need_refresh = true
            ev.dispatch "need_refresh"
          , 100
        
        watcher.on "add",    handler
        watcher.on "change", handler
        watcher.on "unlink", handler
        break
      return
  
  do ()=>
    cb = null
    on_end_wait = ()->
      if cb
        old_cb = cb
        cb = null
        old_cb()
    
    ev.on "need_refresh", on_end_wait
    loop
      if !need_refresh
        await
          cb = defer()
          setTimeout on_end_wait, 1000
        continue
      
      need_refresh = false
      await run defer()
      puts "wait for changes..."
    return
  
  return
