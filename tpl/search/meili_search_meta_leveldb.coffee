os = require "os"
{MeiliSearch} = require "meilisearch"
sequelize = require "sequelize"
argv      = require("minimist")(process.argv.slice(2))
require "lock_mixin"
config  = require "../config"
BigMap  = require "../util/bigmap"
meilisearch_worker= require "../worker/meilisearch"
# db_worker         = require "../worker/db"

base64_url_encode = (t)->
  res = t.toString "base64"
  
  # https://github.com/brianloveswords/base64url/blob/master/src/base64url.ts
  res = res.replace(`/=/g`, "")
  res = res.replace(/\+/g, "-")
  res = res.replace(/\//g, "_")
  res

base64_url_decode = (t)->
  Buffer.from t, "base64"

client = new MeiliSearch
  host  : config.meilisearch_connection_string

module.exports = (index_config)->
  {
    db
    table_name
    prefix
    field_list
    primary_key
    doc_transform
    index_name
  } = index_config
  
  db_attributes = field_list
  db ?= require "../db"
  
  doc_transform2_cmp = (db_doc)->
    db_doc.id_buf = Buffer.from db_doc[primary_key]
    db_doc.id = base64_url_encode db_doc.id_buf
  
  doc_transform2_final = (db_doc)->
    db_doc.id_buf = Buffer.from db_doc[primary_key]
    db_doc.id = base64_url_encode db_doc.id_buf
    
    doc = {}
    doc.id = db_doc.id
    for k in field_list
      doc[k] = db_doc[k]
    doc
  
  mod = {}
  
  cached_index = null
  mod.get_index = (cb)->
    return cb null, cached_index if cached_index
    
    await client.getIndexes().cb defer(err, list); return cb err if err
    found = false
    for v in list
      if v.uid == index_name
        found = true
        break
    if !found
      puts "create index #{index_name}"
      await client.createIndex(index_name, primaryKey:"id") .cb defer(err, res);    return cb err if err
      await client.waitForTask(res.uid)                     .cb defer(err);         return cb err if err
      await client.getIndex(index_name)                     .cb defer(err, index);  return cb err if err
      await index.updateSearchableAttributes(field_list)    .cb defer(err);         return cb err if err
    
    await client.getIndex(index_name)                       .cb defer(err, index);  return cb err if err
    if !global.is_fork
      index.getDocumentsWorker = (req)->
        new Promise (resolve, reject)->
          loc_opt = {
            req
            index_name
            method_name : "getDocuments"
          }
          await meilisearch_worker.job loc_opt, defer(err, res)
          if err
            reject err
          else
            resolve res
    cached_index = index
    cb null, index
  
  mod.doc_insert = (doc, cb)->
    await mod.get_index defer(err, index); return cb err if err
    doc_transform? doc
    doc = doc_transform2_final doc
    
    await index.addDocuments([doc]).cb defer(err); return cb err if err
    cb()
  
  # DO NOT apply for mass update
  mod.doc_update = (doc, cb)->
    await mod.get_index defer(err, index); return cb err if err
    doc_transform? doc
    doc = doc_transform2_final doc
    
    await index.addDocuments([doc])       .cb defer(err); return cb err if err
    cb()
  
  # DO NOT apply for mass update
  mod.doc_update_by_id = (doc_id, cb)->
    await mod.get_index defer(err, index); return cb err if err
    where = {}
    where[primary_key] = doc_id
    await db[table_name].findOne({where,attributes:db_attributes,raw:true}).cb defer(err, doc); return cb err if err
    if !doc
      perr "WARNING. doc_update_by_id for non-existant id=#{doc_id}"
      return cb()
    doc_transform? doc
    doc = doc_transform2_final doc
    
    await index.addDocuments([doc])       .cb defer(err); return cb err if err
    cb()
  
  mod.doc_delete = (doc, cb)->
    await mod.get_index defer(err, index); return cb err if err
    
    await index.deleteDocuments([doc.id]).cb defer(err); return cb err if err
    cb()
  
  mod.doc_delete_by_id = (doc_id, cb)->
    await mod.get_index defer(err, index); return cb err if err
    
    await index.deleteDocuments([doc_id]).cb defer(err); return cb err if err
    cb()
  
  mod.doc_list_delete = (list, cb)->
    await mod.get_index defer(err, index); return cb err if err
    await index.deleteDocuments(list).cb defer(err); return cb err if err
    cb()
  
  mod.doc_search = (opt, cb)->
    {
      search
    } = opt
    # NOTE 1000 too much (2+GB)
    limit = opt.limit ? 50
    await mod.get_index defer(err, index); return cb err if err
    
    await index.search(search, {attributesToHighlight: ["*"], limit}).cb defer(err, res_meili); return cb err if err
    
    cb null, res_meili
  
  # SAFE
  mod.doc_sync = (_opt, cb)->
    await mod.get_index defer(err, index); return cb err if err
    # ###################################################################################################
    #    config
    # ###################################################################################################
    # prevent payload too large and perform fast import
    db_read_batch_size    = index_config.db_read_batch_size     ? 100000
    meili_read_batch_size = index_config.meili_read_batch_size  ? 100000
    batch_size            = index_config.batch_size             ? 100000
    display_batch_size    = index_config.display_batch_size     ? 100000
    max_payload_size      = index_config.max_payload_size       ? 10e6 # 10 MB
    # 100e6 100 MB is default limit. Do NOT exceed that
    # display_batch_size = 1000 # DEBUG
    
    # ###################################################################################################
    # this will build whole plan for update
    # this can consume a lot of memory, but still less than full list of all documents
    doc_id_delete_list = []
    # add or update
    doc_add_list = []
    meili_doc_dict = new BigMap
    
    # NOTE stats could be wrong if more than 2**42 elements
    new_item_count    = 0
    update_item_count = 0
    # ###################################################################################################
    #    read all stuff from meilisearch, detect items that don't need any changes
    # ###################################################################################################
    offset = 0
    
    puts "#{index_name} meili scan"
    loop
      puts "#{index_name} meili scan #{offset}" if offset and offset % display_batch_size == 0
      await index.getDocuments({attributesToRetrieve:"*", limit:meili_read_batch_size, offset})  .cb defer(err, meili_doc_list); return cb err if err
      offset += meili_read_batch_size
      if meili_doc_list.length
        id_list = []
        for meili_doc in meili_doc_list
          id_list.push meili_doc.id
          meili_doc_dict.set meili_doc.id, meili_doc
        
        # where = {
        #   id : id_list
        # }
        # await db[table_name].findAll({where,attributes:db_attributes,raw:true}).cb defer(err, db_doc_list); return cb err if err
        # NOTE where id : [] not supported for leveldb yet
        db_doc_list = []
        for id in id_list
          where = {}
          where[primary_key] = id
          await db[table_name].findOne({where,attributes:db_attributes,raw:true}).cb defer(err, db_doc); return cb err if err
          doc_transform? db_doc
          doc_transform2_cmp db_doc
          db_doc_list.push db_doc
        
        db_id_dict = new Map
        for db_doc in db_doc_list
          db_id_dict.set db_doc.id
          if meili_doc = meili_doc_dict.get db_doc.id
            # compare without field order
            # NOTE. meili returns id last
            found = false
            for k,v of meili_doc
              if db_doc[k] != v
                found = true
                break
            if found
              doc_add_list.push db_doc
          else
            doc_add_list.push db_doc
        
        for id in id_list
          if !db_id_dict.has id
            doc_id_delete_list.push id
      
      break if meili_doc_list.length < meili_read_batch_size
    
    # ###################################################################################################
    #    read all ids from prostgres, detect new items
    # ###################################################################################################
    puts "#{index_name} db scan"
    # TODO change to walk by keys
    # await db[table_name].findAll({where:{},attributes:["id"],raw:true}).cb defer(err, db_doc_list); return cb err if err
    
    {key_decode} = db[table_name]
    db_doc_list = []
    walk = (key_buf, cb)->
      try
        db_doc_list.push key_decode key_buf
      catch err
        return cb err
      
      cb null, true
    
    await db[table_name]._suffix_walk_key walk, defer(err); return cb err if err
    
    for db_doc in db_doc_list
      doc_transform? db_doc
      doc_transform2_cmp db_doc
      continue if meili_doc_dict.has db_doc.id
      doc_add_list.push db_doc
      new_item_count++
    
    puts "#{index_name} add/update id sort"
    doc_add_list.sort (a,b)->a.id_buf.compare b.id_buf
    
    if !new_item_count and !update_item_count and !doc_id_delete_list.length
      puts "#{index_name} SKIP"
      return cb null
    else
      puts "#{index_name} update plan"
      puts "new     items #{new_item_count}"
      puts "update  items #{update_item_count}"
      puts "delete  items #{doc_id_delete_list.length}"
    
    if argv.dry
      return cb()
    
    # ###################################################################################################
    #    Apply plan delete
    # ###################################################################################################
    await index.deleteDocuments(doc_id_delete_list).cb defer(err); return cb err if err
    
    # ###################################################################################################
    #    Apply plan add/update
    # ###################################################################################################
    
    total_added = 0
    payload_size = 0
    meili_sub_doc_list = []
    meili_sub_doc_list_push = (cb)->
      return cb() if !meili_sub_doc_list.length
      
      puts "add/update #{total_added}/#{doc_add_list.length} #{payload_size} bytes"
      total_added += meili_sub_doc_list.length
      loc_meili_sub_doc_list = meili_sub_doc_list
      meili_sub_doc_list = []
      payload_size = 0
      await index.updateDocuments(loc_meili_sub_doc_list).cb defer(err); return cb err if err
      
      cb()
    
    db_sub_doc_list = []
    db_sub_doc_get_push = (cb)->
      return cb() if !db_sub_doc_list.length
      
      loc_db_sub_doc_list = db_sub_doc_list
      db_sub_doc_list = []
      
      # id_first = loc_db_sub_doc_list[0]
      # id_last  = loc_db_sub_doc_list.last()
      
      # if +id_last - +id_first <= 2*db_read_batch_size
      #   # strategy extract more, but less expensive primary key lookup
      #   where = {id:{}}
      #   where.id[sequelize.Op.between] = [id_first, id_last]
      #   await db[table_name].findAll({where,attributes:db_attributes,raw:true}).cb defer(err, unfiltered_db_doc_list); return cb err if err
      #   id_dict = new Map
      #   for id in loc_db_sub_doc_list
      #     id_dict.set id, true
      #   db_doc_list = []
      #   for db_doc in unfiltered_db_doc_list
      #     if id_dict.has db_doc.id
      #       db_doc_list.push db_doc
      # else
      #   # strategy read exact id's because range strategy will consume too much space to read and to transfer
      #   where = {id:loc_db_sub_doc_list}
      #   await db[table_name].findAll({where,attributes:db_attributes,raw:true}).cb defer(err, db_doc_list); return cb err if err
      # NOTE where id : [] not supported for leveldb yet
      for db_doc in loc_db_sub_doc_list
        doc = doc_transform2_final db_doc
        
        size = JSON.stringify(doc).length
        if payload_size + size < max_payload_size
          meili_sub_doc_list.push doc
          payload_size += size
        else
          await meili_sub_doc_list_push defer(err); return cb err if err
          meili_sub_doc_list.push doc
        
        if meili_sub_doc_list.length >= batch_size
          await meili_sub_doc_list_push defer(err); return cb err if err
      cb()
    
    # DEBUG
    # doc_add_list = doc_add_list.slice(0, 100)
    
    for v in doc_add_list
      db_sub_doc_list.push v
      if db_sub_doc_list.length >= db_read_batch_size
        await db_sub_doc_get_push defer(err); return cb err if err
    
    await db_sub_doc_get_push     defer(err); return cb err if err
    await meili_sub_doc_list_push defer(err); return cb err if err
    
    # Прим. getTasks не самая лучшая идея, лучше мониторить отдельные id'шники
    loop
      await index.getTasks().cb defer(err, res); throw err if err
      res = res.results.filter (t)->!(t.status in ["succeeded", "failed"])
      break if res.length == 0
      puts "wait for meilisearch #{res.length} tasks left"
      await setTimeout defer(), 1000
    
    cb()
  
  # can out of memory, but x10 fast on 10+M datasets (<2M will be not affected)
  # also consumes x4+ more CPU (multithreaded, nodejs only, also meilisearch and postgres loaded 1-4 cores each)
  mod.doc_sync_fast = (_opt, cb)->
    await mod.get_index defer(err, index); return cb err if err
    # ###################################################################################################
    #    config
    # ###################################################################################################
    # prevent payload too large and perform fast import
    db_read_batch_size    = index_config.db_read_batch_size     ? 100000
    meili_read_batch_size = index_config.meili_read_batch_size  ? 100000
    batch_size            = index_config.batch_size             ? 100000
    display_batch_size    = index_config.display_batch_size     ? 100000
    max_payload_size      = index_config.max_payload_size       ? 10e6 # 10 MB
    # 100e6 100 MB is default limit. Do NOT exceed that
    # display_batch_size = 1000 # DEBUG
    
    # ###################################################################################################
    # this will build whole plan for update
    # this can consume a lot of memory, but still less than full list of all documents
    doc_id_delete_list = []
    # add or update
    doc_add_list = []
    meili_doc_dict = new BigMap
    
    # NOTE stats could be wrong if more than 2**42 elements
    new_item_count    = 0
    update_item_count = 0
    
    # ###################################################################################################
    #    read all stuff from meilisearch, detect items that don't need any changes
    # ###################################################################################################
    puts "#{index_name} meili scan"
    # block 1 loop
    block_1_live = true
    block_1_res_list = []
    lock_meili = new Lock_mixin
    lock_meili.$limit = os.cpus().length
    
    meili_backpressure_limit = 2*lock_meili.$limit
    
    lock_db = new Lock_mixin
    lock_db.$limit = os.cpus().length
    
    do ()->
      offset = 0
      block_1_need_shutdown = false
      while !block_1_need_shutdown
        while !lock_meili.can_lock()
          await setTimeout defer(), 100
        do (offset)->
          loc_cb = (err)->
            if err
              perr "meili worker fail", err.message
              return cb err
          await lock_meili.wrap loc_cb, defer(loc_cb)
          
          puts "#{index_name} meili scan #{offset} queue=#{block_1_res_list.length} lock_meili=#{lock_meili.$count} lock_db=#{lock_db.$count}" if offset and offset % display_batch_size == 0
          await index.getDocumentsWorker({attributesToRetrieve:"*", limit:meili_read_batch_size, offset})  .cb defer(err, meili_doc_list); return loc_cb err if err
          block_1_res_list.push meili_doc_list
          
          if meili_doc_list.length < meili_read_batch_size
            block_1_need_shutdown = true
          
          # backpressure
          while block_1_res_list.length > meili_backpressure_limit
            await setTimeout defer(), 100
          
          loc_cb()
        offset += meili_read_batch_size
      await lock_meili.drain defer()
      block_1_live = false
    
    # block 2 loop
    loop
      if block_1_res_list.length == 0
        break if !block_1_live
        await setTimeout defer(), 100
        continue
      meili_doc_list = block_1_res_list.shift()
      continue if !meili_doc_list.length
      
      await lock_db.lock defer()
      do (meili_doc_list)->
        loc_cb = (err)->
          if err
            p "db worker fail", err.message
            return cb err
          lock_db.unlock()
        
        id_list = []
        
        for meili_doc in meili_doc_list
          id_list.push meili_doc.id
          meili_doc_dict.set meili_doc.id, meili_doc
        
        # loc_opt = {
        #   table_name
        #   method_name: "findAll"
        #   req : {where,attributes:db_attributes,raw:true}
        # }
        # await db_worker.job loc_opt, defer(err, db_doc_list); return loc_cb err if err
        db_doc_list = []
        for id in id_list
          where = {}
          where[primary_key] = id
          await db[table_name].findOne({where,attributes:db_attributes,raw:true}).cb defer(err, db_doc); return cb err if err
          doc_transform? db_doc
          doc_transform2 db_doc
          db_doc_list.push db_doc
        
        db_id_dict = new Map
        for db_doc in db_doc_list
          db_id_dict.set db_doc.id
          if meili_doc = meili_doc_dict.get db_doc.id
            # compare without field order
            # NOTE. meili returns id last
            found = false
            for k,v of meili_doc
              if db_doc[k] != v
                found = true
                break
            if found
              doc_add_list.push db_doc
          else
            doc_add_list.push db_doc
        
        for id in id_list
          if !db_id_dict.has id
            doc_id_delete_list.push id
        
        loc_cb()
    
    await lock_db.drain defer()
    
    # ###################################################################################################
    #    read all ids from prostgres, detect new items
    # ###################################################################################################
    puts "#{index_name} db scan"
    # NOTE this can't be optimized to worker, because out of memory
    # ну точнее я так и не смог ничего сделать с out of memory
    # boost не больше 20%. По сравнению с базовым x10 выглядит всё еще хорошо, но мелочи
    
    # await db[table_name].findAll({where:{},attributes:["id"],raw:true}).cb defer(err, db_doc_list); return cb err if err
    
    {key_decode} = db[table_name]
    db_doc_list = []
    walk = (key_buf, cb)->
      try
        db_doc_list.push key_decode key_buf
      catch err
        return cb err
      
      cb null, true
    
    await db[table_name]._suffix_walk_key walk, defer(err); return cb err if err
    
    for db_doc in db_doc_list
      doc_transform2 db_doc
      continue if meili_doc_dict.has db_doc.id
      doc_add_list.push db_doc
      new_item_count++
    
    puts "#{index_name} add/update id sort"
    doc_add_list.sort (a,b)->a.id_buf.compare b.id_buf
    
    if !new_item_count and !update_item_count and !doc_id_delete_list.length
      puts "#{index_name} SKIP"
      return cb null
    else
      puts "#{index_name} update plan"
      puts "new     items #{new_item_count}"
      puts "update  items #{update_item_count}"
      puts "delete  items #{doc_id_delete_list.length}"
    
    if argv.dry
      return cb()
    
    # ###################################################################################################
    #    Apply plan delete
    # ###################################################################################################
    await index.deleteDocuments(doc_id_delete_list).cb defer(err); return cb err if err
    
    # ###################################################################################################
    #    Apply plan add/update
    # ###################################################################################################
    
    total_added = 0
    payload_size = 0
    meili_sub_doc_list = []
    meili_sub_doc_list_push = (cb)->
      return cb() if !meili_sub_doc_list.length
      
      puts "add/update #{total_added}/#{doc_add_list.length} #{payload_size} bytes"
      total_added += meili_sub_doc_list.length
      loc_meili_sub_doc_list = meili_sub_doc_list
      meili_sub_doc_list = []
      payload_size = 0
      await index.updateDocuments(loc_meili_sub_doc_list).cb defer(err); return cb err if err
      
      cb()
    
    db_sub_doc_list = []
    db_sub_doc_get_push = (cb)->
      return cb() if !db_sub_doc_list.length
      
      loc_db_sub_doc_list = db_sub_doc_list
      db_sub_doc_list = []
      
      # id_first = loc_db_sub_doc_list[0]
      # id_last  = loc_db_sub_doc_list.last()
      
      # if +id_last - +id_first <= 2*db_read_batch_size
      #   # strategy extract more, but less expensive primary key lookup
      #   where = {id:{}}
      #   where.id[sequelize.Op.between] = [id_first, id_last]
      #   await db[table_name].findAll({where,attributes:db_attributes,raw:true}).cb defer(err, unfiltered_db_doc_list); return cb err if err
      #   id_dict = new Map
      #   for id in loc_db_sub_doc_list
      #     id_dict.set id, true
      #   db_doc_list = []
      #   for db_doc in unfiltered_db_doc_list
      #     if id_dict.has db_doc.id
      #       db_doc_list.push db_doc
      # else
      #   # strategy read exact id's because range strategy will consume too much space to read and to transfer
      #   where = {id:loc_db_sub_doc_list}
      #   await db[table_name].findAll({where,attributes:db_attributes,raw:true}).cb defer(err, db_doc_list); return cb err if err
      # NOTE where id : [] not supported for leveldb yet
      for db_doc in loc_db_sub_doc_list
        doc = doc_transform2_final db_doc
        
        size = JSON.stringify(doc).length
        if payload_size + size < max_payload_size
          meili_sub_doc_list.push doc
          payload_size += size
        else
          await meili_sub_doc_list_push defer(err); return cb err if err
          meili_sub_doc_list.push doc
        
        if meili_sub_doc_list.length >= batch_size
          await meili_sub_doc_list_push defer(err); return cb err if err
      cb()
    
    # DEBUG
    # doc_add_list = doc_add_list.slice(0, 100)
    
    for v in doc_add_list
      db_sub_doc_list.push v
      if db_sub_doc_list.length >= db_read_batch_size
        await db_sub_doc_get_push defer(err); return cb err if err
    
    await db_sub_doc_get_push     defer(err); return cb err if err
    await meili_sub_doc_list_push defer(err); return cb err if err
    
    # Прим. getTasks не самая лучшая идея, лучше мониторить отдельные id'шники
    loop
      await index.getTasks().cb defer(err, res); throw err if err
      res = res.results.filter (t)->!(t.status in ["succeeded", "failed"])
      break if res.length == 0
      puts "wait for meilisearch #{res.length} tasks left"
      await setTimeout defer(), 1000
    
    cb()
  
  mod
