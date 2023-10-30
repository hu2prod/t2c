module = @
###
NOTE. __metadata занимает до 10 MB
Это нормально
Оно же записывает последовательно все записи в log а только потом compaction
Но это печально
###

@get_encode_decode = (prefix, field_list, endian)->
  # применимо и для key и для value
  # здесь везде используется key
  length_estimate_jl = []
  concat_jl = []
  decode_jl = []
  expd_length_flat = 0
  
  arg_list = []
  for field in field_list
    arg_list.push field.name
  
  for field in field_list
    switch field.type
      when "bool"
        expd_length_flat++
        concat_jl.push """
          res[offset++] = +#{field.name}
          """
        decode_jl.push """
          #{field.name} = !!buf[offset++]
          """
      
      when "i32"
        expd_length_flat+=4
        concat_jl.push """
          res.writeInt32#{endian} +#{field.name}, offset; offset += 4
          """
        decode_jl.push """
          #{field.name} = buf.readInt32#{endian} offset; offset += 4
          """
      
      when "u32"
        expd_length_flat+=4
        concat_jl.push """
          res.writeUInt32#{endian} +#{field.name}, offset; offset += 4
          """
        decode_jl.push """
          #{field.name} = buf.readUInt32#{endian} offset; offset += 4
          """
      
      when "i64"
        expd_length_flat+=8
        concat_jl.push """
          res.writeBigInt64#{endian} BigInt(#{field.name}), offset; offset += 8
          """
        aux_compat = ""
        if field.as_string
          aux_compat = """
            # sequelize compat
            #{field.name} = +#{field.name}.toString()
            """
        
        decode_jl.push """
          #{field.name} = buf.readBigInt64#{endian} offset; offset += 8
          #{aux_compat}
          """
      
      when "u64"
        expd_length_flat+=8
        concat_jl.push """
          res.writeBigUInt64#{endian} BigInt(#{field.name}), offset; offset += 8
          """
        aux_compat = ""
        if field.as_string
          aux_compat = """
            # sequelize compat
            #{field.name} = +#{field.name}.toString()
            """
        
        decode_jl.push """
          #{field.name} = buf.readBigUInt64#{endian} offset; offset += 8
          #{aux_compat}
          """
      
      when "f32"
        expd_length_flat+=4
        concat_jl.push """
          res.writeFloat#{endian} #{field.name}, offset; offset += 4
          """
        decode_jl.push """
          #{field.name} = buf.readFloat#{endian} offset; offset += 4
          """
      
      when "f64"
        expd_length_flat+=8
        concat_jl.push """
          res.writeDouble#{endian} #{field.name}, offset; offset += 8
          """
        decode_jl.push """
          #{field.name} = buf.readDouble64#{endian} offset; offset += 8
          """
      
      when "str", "string", "text"
        expd_length_flat+=4
        length_estimate_jl.push """
          expd_length += _#{field.name}_len = Buffer.byteLength #{field.name}
          """
        concat_jl.push """
          res.writeInt32#{endian} _#{field.name}_len, offset; offset += 4
          res.write #{field.name}, offset; offset += _#{field.name}_len
          """
        decode_jl.push """
          _#{field.name}_len = buf.readInt32#{endian} offset; offset += 4
          _#{field.name}_buf = buf.slice(offset, offset+_#{field.name}_len)
          #{field.name} = _#{field.name}_buf.toString(); offset += _#{field.name}_len
          """
      
      when "json"
        expd_length_flat+=4
        # TODO policy
        length_estimate_jl.push """
          expd_length += _#{field.name}_len = BSON.calculateObjectSize #{field.name}
          """
        # TODO round-up buf_pool.alloc _#{field.name}_len
        concat_jl.push """
          res.writeInt32#{endian} _#{field.name}_len, offset; offset += 4
          tmp_buf = buf_pool.alloc _#{field.name}_len
          BSON.setInternalBufferSize _#{field.name}_len
          BSON.serializeWithBufferAndIndex #{field.name}, tmp_buf
          tmp_buf.copy res, offset; offset += _#{field.name}_len
          buf_pool.free tmp_buf
          """
        decode_jl.push """
          _#{field.name}_len = buf.readInt32#{endian} offset; offset += 4
          _#{field.name}_buf = buf.slice(offset, offset+_#{field.name}_len)
          #{field.name} = BSON.deserialize(_#{field.name}_buf, promoteBuffers: true); offset += _#{field.name}_len
          """
      
      when "buf"
        expd_length_flat+=4
        length_estimate_jl.push """
          expd_length += _#{field.name}_len = #{field.name}.length
          """
        
        concat_jl.push """
          res.writeInt32#{endian} _#{field.name}_len, offset; offset += 4
          #{field.name}.copy res, offset; offset += _#{field.name}_len
          """
        decode_jl.push """
          _#{field.name}_len = buf.readInt32#{endian} offset; offset += 4
          #{field.name} = buf.slice(offset, offset+_#{field.name}_len); offset += _#{field.name}_len
          """
      
      else
        throw new Error "unimplemented field for #{field.type}"
    
  
  """
    @#{prefix}_encode = (#{arg_list.join ', '})->
      expd_length = #{expd_length_flat}
      #{join_list length_estimate_jl, "  "}
      
      res = buf_pool.alloc expd_length
      offset = 0
      #{join_list concat_jl, "  "}
      
      res
    
    @#{prefix}_decode = (buf)->
      offset = 0
      #{join_list decode_jl, "  "}
      
      {#{arg_list.join ', '}}
    
    """

cmp_gen = (val, ret)->
  """
  if v instanceof Buffer
    #{ret} if !v.equals #{val}[k]
  else if typeof v == "object"
    #{ret} if !JSON.eq v, #{val}[k]
  else
    #{ret} if #{val}[k] != v
  """#"

custom_cmp_gen = (val, ret_jl...)->
  """
  if v instanceof Buffer
    if !v.equals #{val}[k]
      #{join_list ret_jl, "    "}
  else if typeof v == "object"
    if !JSON.eq v, #{val}[k]
      #{join_list ret_jl, "    "}
  else
    if #{val}[k] != v
      #{join_list ret_jl, "    "}
  """#"

@model_code_gen = (model, opt={})->
  {
    config_prefix
    extension
    metadata # update counter, use autoincrement
    bson_ext
  } = opt
  extension ?= true
  
  field_list = Object.values model.field_hash
  
  key_field_list = []
  key_plus_field_list = []
  val_field_list = []
  suffix_field_list = []
  
  for field in field_list
    if field.is_key
      key_field_list.push field
      key_plus_field_list.push field
    else if field.suffix
      suffix_field_list.push field
      key_plus_field_list.push field
    else
      val_field_list.push field
  
  if key_field_list.length == 0
    key_plus_field_list = []
    first_added = false
    for field in field_list
      # edge case when first is suffix
      if !first_added and !field.suffix
        key_plus_field_list.push field
        first_added = true
        continue
      
      if field.is_key
        key_plus_field_list.push field
        first_added = true
      else if field.suffix
        key_plus_field_list.push field
    
    key_field_list.push field_list[0]
    val_field_list.shift()
  
  # name
  field_name_list = []
  for field in field_list
    field_name_list.push field.name
  
  key_field_name_list = []
  for field in key_field_list
    key_field_name_list.push field.name
  key_c_arg = key_field_name_list.join ", "
  
  suffix_field_name_list = []
  for field in suffix_field_list
    suffix_field_name_list.push field.name
  suffix_c_arg = suffix_field_name_list.join ", "
  suffix_c_arg_comma = ""
  if suffix_field_name_list.length
    suffix_c_arg_comma = "#{suffix_c_arg}, "
  
  key_plus_field_name_list = []
  for field in key_plus_field_list
    key_plus_field_name_list.push field.name
  key_plus_c_arg = key_plus_field_name_list.join ", "
  
  val_field_name_list = []
  for field in val_field_list
    val_field_name_list.push field.name
  val_c_arg = val_field_name_list.join ", "
  
  # пока не поддерживается даже в теории mixed endian для 1 модели (разве что key, val)
  # BE чтобы нормально сортировались ключи
  endian = "BE"
  
  suffix_split = "__"
  key_code = module.get_encode_decode "key", key_field_list, endian
  suffix_code = module.get_encode_decode "suffix", suffix_field_list, endian
  val_code = module.get_encode_decode "val", val_field_list, endian
  
  if suffix_field_list.length
    suffix_type_fix_jl = []
    for field in suffix_field_list
      switch field.type
        when "bool"
          suffix_type_fix_jl.push "#{field.name} = !!#{field.name}"
        
        when "i32", "f32", "f64"
          suffix_type_fix_jl.push "#{field.name} = +#{field.name}"
        
        when "i64"
          suffix_type_fix_jl.push "#{field.name} = BigInt #{field.name}"
    
    get_suffix_list_code = """
      @get_suffix_list = ()->
        path = config.#{config_prefix}path+"/#{model.name}"
        return [] if !fs.existsSync path
        model_list = fs.readdirSync path
        model_list.natsort()
        ret_list = []
        for model in model_list
          # DANGER
          [#{suffix_c_arg}] = model.split #{JSON.stringify suffix_split}
          #{join_list suffix_type_fix_jl, "      "}
          ret_list.push {#{suffix_c_arg}}
        
        ret_list
      """#"
  else
    get_suffix_list_code = """
      @get_suffix_list = ()->[{}]
      """
  
  where_suffix_check_jl = []
  if suffix_field_name_list.length
    where_suffix_check_jl.push """
      {#{suffix_c_arg}} = suffix
      """
  for suffix in suffix_field_name_list
    where_suffix_check_jl.push """
      continue if where.#{suffix}? and where.#{suffix} != #{suffix}
      """
  
  autoincrement = false
  if key_field_list.length == 1
    [autoincrement_field] = key_field_list
    if autoincrement_field.type in ["i32", "i64"]
      autoincrement = true
  
  autoincrement = false if !metadata
  
  # можно выключать, а вот включить если такого поля нет нельзя
  if autoincrement and model.autoincrement?
    autoincrement = model.autoincrement
  
  suffix_unpack_gen = ()->""
  if suffix_field_list.length
    suffix_unpack_gen = (from)->
      """
      {#{suffix_c_arg}} = #{from}
      """
  
  create_impl = """
    await module.put_checked doc, defer(err, res); return cb err if err
    cb null, doc, res
    """
  if autoincrement
    [autoincrement_field] = key_field_list
    if autoincrement_field.as_string
      # двойная конвертация на val_encode
      # но иначе больше кода (надо будет после сохранения перед возвратом сделать post-processing)
      autoincrement_get_code = "+metadata.autoincrement.toString()"
    else
      autoincrement_get_code = "metadata.autoincrement"
    
    create_impl = """
      #{suffix_unpack_gen 'doc'}
      suffix_buf = module.suffix_encode(#{suffix_c_arg})
      
      await module._metadata_get_sb suffix_buf, defer(err, metadata); return cb err if err
      
      if !doc.#{autoincrement_field.name}?
        doc.#{autoincrement_field.name} = #{autoincrement_get_code}
        metadata.autoincrement++
      else
        perr "WARNING. Ignoring autoincrement for model=#{model.name}"
      
      {#{key_plus_c_arg}} = doc
      await module.has #{key_plus_c_arg}, defer(err, found); return cb err if err
      if !found
        metadata.count++
      
      await module._metadata_set_sb suffix_buf, metadata, defer(err); return cb err if err
      await module.put doc, defer(err, res); return cb err if err
      cb null, doc, !found
      """#"
  else if metadata
    # no autoincrement, but count update
    create_impl = """
      #{suffix_unpack_gen 'doc'}
      suffix_buf = module.suffix_encode(#{suffix_c_arg})
      
      await module._metadata_get_sb suffix_buf, defer(err, metadata); return cb err if err
      
      {#{key_plus_c_arg}} = doc
      await module.has #{key_plus_c_arg}, defer(err, found); return cb err if err
      if !found
        metadata.count++
      
      await module._metadata_set_sb suffix_buf, metadata, defer(err); return cb err if err
      await module.put doc, defer(err, res); return cb err if err
      cb null, doc, !found
      """#"
  
  aux_extension = ""
  if extension
    aux_metadata = ""
    aux_metadata_on_destroy = ""
    if metadata
      aux_metadata = """
        # ###################################################################################################
        #    count, autoincrement add-on
        # ###################################################################################################
        __metadata = require "./__metadata"
        @_metadata_get = (#{suffix_c_arg_comma}cb)->
          suffix_buf = module.suffix_encode(#{suffix_c_arg})
          await __metadata.get #{JSON.stringify model.name}, suffix_buf, defer(err, val); return cb err if err
          
          # iced-2 BUG
          # val ?= {}
          if !val
            val = {}
          val.count ?= `0n`
          val.autoincrement ?= `1n`
          
          cb null, val
        
        @_metadata_set = (#{suffix_c_arg_comma}val, cb)->
          suffix_buf = module.suffix_encode(#{suffix_c_arg})
          await __metadata.put_by_key #{JSON.stringify model.name}, suffix_buf, val, defer(err); return cb err if err
          cb()
        
        @_metadata_get_sb = (suffix_buf, cb)->
          await __metadata.get #{JSON.stringify model.name}, suffix_buf, defer(err, val); return cb err if err
          
          # iced-2 BUG
          # val ?= {}
          if !val
            val = {}
          val.count ?= `0n`
          val.autoincrement ?= `1n`
          
          cb null, val
        
        @_metadata_set_sb = (suffix_buf, val, cb)->
          await __metadata.put_by_key #{JSON.stringify model.name}, suffix_buf, val, defer(err); return cb err if err
          cb null
        
        @_metadata_count = (opt, cb)->
          {where} = opt
          # TODO support when where has only suffix inside
          # TODO support full scan
          suffix_list = module.get_suffix_list()
          ret = `0n`
          for suffix in suffix_list
            #{suffix_unpack_gen 'suffix'}
            await module._metadata_get #{suffix_c_arg_comma}defer(err, metadata); return cb err if err
            ret += metadata.count
          cb null, ret
        
        @count = (opt, cb)->
          # _metadata_count is 100% correct, count is easy for use
          # NOTE no await, because will break return Promise
          if cb
            module._metadata_count opt, (err, res)->
              return cb err if err
              return cb null, +res.toString()
          else
            new Promise (resolve, reject)->
              cb = (err, res)->
                if err
                  reject err
                else
                  resolve +res.toString()
              module._metadata_count opt, cb
        
        """#"
      
      aux_metadata_on_destroy = """
        # need update count
        for _suffix_key, v of suffix_hash
          {suffix_buf, suffix, delete_count_sup} = v
          continue if delete_count_sup == `0n`
          
          await module._metadata_get_sb suffix_buf, defer(extra_err, metadata);
          if extra_err
            puts "WARNING count will be corrupted. suffix=\#{JSON.stringify suffix}. Can't read", extra_err
            break
          
          metadata.count -= delete_count_sup
          
          await module._metadata_set_sb suffix_buf, metadata, defer(extra_err);
          if extra_err
            puts "WARNING count will be corrupted. suffix=\#{JSON.stringify suffix}. Can't write", extra_err
            break
        """#"
    
    aux_extension = """
      #{aux_metadata}
      
      # ###################################################################################################
      #    
      #    sequelize-like
      #    
      # ###################################################################################################
      # ###################################################################################################
      #    findOne
      # ###################################################################################################
      @_findOne_cb = (opt, cb)->
        {
          where
          attributes
        } = opt
        # good case, full key_plus_field_name_list
        fast_request = true
        for key in #{JSON.stringify key_plus_field_name_list}
          if !where.hasOwnProperty key
            fast_request = false
            break
        
        need_read_val = false
        for v in #{JSON.stringify val_field_name_list}
          if where.hasOwnProperty v
            need_read_val = true
            break
        
        need_read_val = true if !attributes
        
        if fast_request
          {#{key_plus_c_arg}} = where
          
          if !need_read_val
            await module.has #{key_plus_c_arg}, defer(err, res); return cb err if err
            return cb() if !res
            val = {#{key_plus_c_arg}}
          else
            # extra filer. Suboptimal
            await module.get #{key_plus_c_arg}, defer(err, val); return cb err if err
            return cb() if !val
            for k,v of where
              continue if k in #{JSON.stringify key_plus_field_name_list}
              #{make_tab cmp_gen('val', 'return cb()'), "        "}
            # TODO set all key and suffix fields to val
          
          # typical use case optimize
          # если полный ключ в where, то в val не возвращается key
          return cb null, val
        
        suffix_list = module.get_suffix_list()
        found = null
        for suffix in suffix_list
          #{join_list where_suffix_check_jl, "    "}
          
          walk = (key_buf, cb, db)->
            key = module.key_decode key_buf
            
            for k,v of where
              continue unless k in #{JSON.stringify key_field_name_list}
              #{make_tab cmp_gen('key', 'return cb null, true'), "        "}
            
            await module._db_get db, key_buf, defer(err, val_buf); return cb err if err
            if !val_buf or !val_buf.length
              return cb null, true
            
            val = module.val_decode val_buf
            if need_read_val
              for k,v of where
                continue unless k in #{JSON.stringify val_field_name_list}
                #{make_tab cmp_gen('val', 'return cb null, true'), "          "}
            
            found = val
            # untypical use case optimize
            # если не полный ключ в where, то в val не возвращается вообще всё отключа
            obj_set found, key
            cb null, false
          
          await module._suffix_walk_key #{suffix_c_arg_comma}walk, defer(err); return cb err if err
          
          break if found
        
        return cb null, found
      
      @findOne = (opt, cb)->
        if cb
          module._findOne_cb opt, cb
        else
          new Promise (resolve, reject)->
            cb = (err, res)->
              if err
                reject err
              else
                resolve res
            module._findOne_cb opt, cb
      
      # ###################################################################################################
      #    findAll
      # ###################################################################################################
      @_findAll_cb = (opt, cb)->
        {where,attributes} = opt
        # good case, full key_plus_field_name_list
        fast_request = true
        for key in #{JSON.stringify key_plus_field_name_list}
          if !where.hasOwnProperty key
            fast_request = false
            break
        
        need_read_val = false
        for v in #{JSON.stringify val_field_name_list}
          if where.hasOwnProperty v
            need_read_val = true
            break
        
        # This case doesn't work with id : [], so it's not needed at all
        ###
        if fast_request
          {#{key_plus_c_arg}} = where
          await module.get #{key_plus_c_arg}, defer(err, val); return cb err if err
          return cb null, [] if !val
          
          # extra filer. Suboptimal
          if need_read_val
            for k,v of where
              continue unless k in #{JSON.stringify val_field_name_list}
              #{make_tab cmp_gen('val', 'return cb null, []'), "        "}
          
          # typical use case optimize
          # если полный ключ в where, то в val не возвращается key
          return cb null, [val]
        ###
        
        suffix_list = module.get_suffix_list()
        found_list = []
        for suffix in suffix_list
          #{join_list where_suffix_check_jl, "    "}
          
          walk = (key_buf, cb, db)->
            key = module.key_decode key_buf
            
            for k,v of where
              continue unless k in #{JSON.stringify key_field_name_list}
              #{make_tab cmp_gen('key', 'return cb null, true'), "        "}
            
            await module._db_get db, key_buf, defer(err, val_buf); return cb err if err
            if !val_buf or !val_buf.length
              return cb null, true
            
            val = module.val_decode val_buf
            if need_read_val
              for k,v of where
                continue unless k in #{JSON.stringify val_field_name_list}
                #{make_tab cmp_gen('val', 'return cb null, true'), "          "}
            
            found = val
            # untypical use case optimize
            # если не полный ключ в where, то в val не возвращается вообще всё отключа
            obj_set found, key
            if !attributes
              found_list.push found
            else
              filter_found = {}
              for v in attributes
                filter_found[v] = found[v]
              found_list.push filter_found
            cb null, true
          
          await module._suffix_walk_key #{suffix_c_arg_comma}walk, defer(err); return cb err if err
        
        return cb null, found_list
      
      @findAll = (opt, cb)->
        if cb
          module._findAll_cb opt, cb
        else
          new Promise (resolve, reject)->
            cb = (err, res)->
              if err
                reject err
              else
                resolve res
            module._findAll_cb opt, cb
      
      # ###################################################################################################
      #    update
      # ###################################################################################################
      @_update_cb = (update_hash, opt, cb)->
        {where,attributes} = opt
        # good case, full key_plus_field_name_list
        fast_request = true
        for key in #{JSON.stringify key_plus_field_name_list}
          if !where.hasOwnProperty key
            fast_request = false
            break
        
        need_read_val = false
        for v in #{JSON.stringify val_field_name_list}
          if where.hasOwnProperty v
            need_read_val = true
            break
        
        if fast_request
          {#{key_plus_c_arg}} = where
          await module.ensure_open #{suffix_c_arg_comma}defer(err, db); return cb err if err
          key_buf = module.key_encode #{key_c_arg}
          
          await module._db_get db, key_buf, defer(err, val_buf);
          if err
            buf_pool.free key_buf
            return cb err
          
          if !val_buf or !val_buf.length
            buf_pool.free key_buf
            return cb null, 0
          
          val = module.val_decode val_buf
          
          # extra filer. Suboptimal
          if need_read_val
            for k,v of where
              continue unless k in #{JSON.stringify val_field_name_list}
              #{make_tab custom_cmp_gen('val', 'buf_pool.free key_buf', 'return cb null, 0'), "        "}
          
          obj_set val, update_hash
          {#{val_c_arg}} = val
          val_buf = module.val_encode #{val_c_arg}
          await db.put key_buf, val_buf, {}, defer(err);
          buf_pool.free key_buf
          buf_pool.free val_buf
          return cb err if err
          # typical use case optimize
          # если полный ключ в where, то в val не возвращается key
          return cb null, 1
        
        suffix_list = module.get_suffix_list()
        update_count = 0
        for suffix in suffix_list
          #{join_list where_suffix_check_jl, "    "}
          
          walk = (key_buf, cb, db)->
            key = module.key_decode key_buf
            
            for k,v of where
              continue unless k in #{JSON.stringify key_field_name_list}
              #{make_tab cmp_gen('key', 'return cb null, true'), "        "}
            
            await module._db_get db, key_buf, defer(err, val_buf); return cb err if err
            if !val_buf or !val_buf.length
              return cb null, true
            
            val = module.val_decode val_buf
            if need_read_val
              for k,v of where
                continue unless k in #{JSON.stringify val_field_name_list}
                #{make_tab cmp_gen('val', 'return cb null, true'), "          "}
            
            obj_set val, update_hash
            {#{val_c_arg}} = val
            val_buf = module.val_encode #{val_c_arg}
            await db.put key_buf, val_buf, {}, defer(err);
            buf_pool.free val_buf
            return cb err if err
            
            update_count++
            cb null, false
          
          await module._suffix_walk_key #{suffix_c_arg_comma}walk, defer(err); return cb err if err
        
        return cb null, update_count
      
      @update = (update_hash, opt, cb)->
        if cb
          module._update_cb update_hash, opt, cb
        else
          new Promise (resolve, reject)->
            cb = (err, res)->
              if err
                reject err
              else
                resolve res
            module._update_cb update_hash, opt, cb
      
      # ###################################################################################################
      #    destroy
      # ###################################################################################################
      @_find_db_suffix_group_key_buf_cb = (opt, cb)->
        {where,attributes} = opt
        # good case, full key_plus_field_name_list
        fast_request = true
        for key in #{JSON.stringify key_plus_field_name_list}
          if !where.hasOwnProperty key
            fast_request = false
            break
        
        need_read_val = false
        for v in #{JSON.stringify val_field_name_list}
          if where.hasOwnProperty v
            need_read_val = true
            break
        
        if fast_request
          {#{key_plus_c_arg}} = where
          await module.ensure_open #{suffix_c_arg_comma}defer(err, db); return cb err if err
          return cb null, {} if !db
          
          key_buf = module.key_encode #{key_c_arg}
          
          await module._db_get db, key_buf, defer(err, val_buf);
          if err
            buf_pool.free key_buf
            return cb err
          if !val_buf or !val_buf.length
            buf_pool.free key_buf
            return cb null, {}
          
          key_buf._need_free = true
          
          if need_read_val
            # extra filer. Suboptimal
            for k,v of where
              continue unless k in #{JSON.stringify val_field_name_list}
              #{make_tab custom_cmp_gen('val', 'buf_pool.free key_buf', 'return cb null, {}'), "          "}
          
          suffix_buf = module.suffix_encode(#{suffix_c_arg})
          suffix_key = suffix_buf.toString("base64")
          buf_pool.free suffix_buf
          ret = {}
          ret[suffix_key] = {
            suffix : {#{suffix_c_arg}}
            suffix_buf
            db
            key_buf_list: [key_buf]
            delete_count_sup : `0n`
          }
          return cb null, ret
        
        suffix_list = module.get_suffix_list()
        ret = {}
        for suffix in suffix_list
          #{join_list where_suffix_check_jl, "    "}
          suffix_buf = module.suffix_encode(#{suffix_c_arg})
          suffix_key = suffix_buf.toString("base64")
          buf_pool.free suffix_buf
          
          loc_db = null
          key_buf_list = []
          
          walk = (key_buf, cb, db)->
            key = module.key_decode key_buf
            
            for k,v of where
              continue unless k in #{JSON.stringify key_field_name_list}
              #{make_tab cmp_gen('key', 'return cb null, true'), "        "}
            
            if need_read_val
              await module._db_get db, key_buf, defer(err, val_buf); return cb err if err
              if !val_buf or !val_buf.length
                return cb null, true
              
              val = module.val_decode val_buf
              for k,v of where
                continue if k in #{JSON.stringify key_plus_field_name_list}
                #{make_tab cmp_gen('val', 'return cb null, true'), "          "}
            
            loc_db = db
            key_buf_list.push key_buf
            
            cb null, true
          
          await module._suffix_walk_key #{suffix_c_arg_comma}walk, defer(err);
          if err
            for k2,v2 of ret
              buf_pool.free v2.suffix_buf
            return cb err
          
          if key_buf_list.length
            ret[suffix_key] = {
              suffix
              suffix_buf
              db : loc_db
              key_buf_list
              delete_count_sup : `0n`
            }
          else
            buf_pool.free suffix_buf
        
        return cb null, ret
      
      @_destroy_cb = (opt, cb)->
        await module._find_db_suffix_group_key_buf_cb opt, defer(err, suffix_hash); return cb err if err
        
        # trade-off
        # --точность
        # ++user-friendly easy API
        delete_count = 0
        err_ret = null
        for _suffix_key, v of suffix_hash
          {db, suffix, suffix_buf, key_buf_list} = v
          for key_buf in key_buf_list
            await db.del key_buf, {}, defer(err)
            
            if err
              err_ret = err
              break
            v.delete_count_sup++
            # actually_deleted = true
            # либо db.del удалил его, либо он уже был удалён до этого
            #   но вопрос обновил ли тот кто-то metadata
            # в существующие key_buf_list же он как-то попал
            delete_count++
          
          break if err_ret
        
        for _suffix_key, v of suffix_hash
          {key_buf_list} = v
          for key_buf in key_buf_list
            if key_buf._need_free
              buf_pool.free key_buf
        
        #{make_tab aux_metadata_on_destroy, "  "}
        
        if err_ret
          return cb err, delete_count
        
        cb null, delete_count
      
      @destroy = (opt, cb)->
        if cb
          module._destroy_cb opt, cb
        else
          new Promise (resolve, reject)->
            cb = (err, res)->
              if err
                reject err
              else
                resolve res
            module._destroy_cb opt, cb
      
      # ###################################################################################################
      #    create
      # ###################################################################################################
      @_create = (doc, cb)->
        #{make_tab create_impl, "  "}
      
      @create = (doc, cb)->
        if cb
          module._create doc, cb
        else
          new Promise (resolve, reject)->
            cb = (err, res)->
              if err
                reject err
              else
                resolve res
            module._create doc, cb
      
      """#"
  
  bson_module = "bson"
  bson_module = "bson-ext" if bson_ext
  
  """
  module = @
  fs = require "fs"
  leveldown = require "leveldown"
  mkdirp = require "mkdirp"
  BSON = require "#{bson_module}"
  require "lock_mixin"
  buf_pool = require "../../util/buf_pool"
  config = require "../../config"
  @open_close_lock = new Lock_mixin
  @db_hash = {}
  
  # ###################################################################################################
  #    open/close
  # ###################################################################################################
  @check = (#{suffix_c_arg_comma}cb)->
    suffix = [#{suffix_c_arg}].join #{JSON.stringify suffix_split}
    suffix = "/"+suffix if suffix
    
    cb null, module.db_hash[suffix]
  
  @ensure_open = (#{suffix_c_arg_comma}cb)->
    suffix = [#{suffix_c_arg}].join #{JSON.stringify suffix_split}
    suffix = "/"+suffix if suffix
    if ret = module.db_hash[suffix]
      return cb null, ret
    await module.open_close_lock.wrap cb, defer(cb)
    
    if !ret = module.db_hash[suffix]
      path = config.#{config_prefix}path+"/#{model.name}"+suffix
      mkdirp.sync path
      ret = leveldown path
      await ret.open {}, defer(err); return cb err if err
      module.db_hash[suffix] = ret
    
    cb null, ret
  
  @close = (cb)->
    await module.open_close_lock.wrap cb, defer(cb)
    for _k,v of module.db_hash
      await v.close defer(err); perr err if err
    obj_clear module.db_hash
    cb()
  
  # ###################################################################################################
  #    encode /decode
  # ###################################################################################################
  #{key_code}
  #{suffix_code}
  #{val_code}
  
  # ###################################################################################################
  #    better get
  # ###################################################################################################
  @_db_get = (db, key_buf, cb)->
    await db.get key_buf, {asBuffer:true}, defer(err, ret_val_buf);
    if err
      if err.message.startsWith "NotFound"
        return cb null, null
      return cb err
    
    cb null, ret_val_buf
  
  # ###################################################################################################
  #    default API, better field usage
  # ###################################################################################################
  @put_by_key = (#{key_plus_c_arg}, doc, cb)->
    if typeof cb != "function"
      puts {doc, cb}
      throw new Error "bad arguments"
    
    for k in #{JSON.stringify val_field_name_list}
      if !doc.hasOwnProperty k
        return cb new Error "invalid doc. Missing "+k
    
    {#{val_c_arg}} = doc
    
    await module.ensure_open #{suffix_c_arg_comma}defer(err, db); return cb err if err
    key_buf = module.key_encode #{key_c_arg}
    val_buf = module.val_encode #{val_c_arg}
    await db.put key_buf, val_buf, {}, defer(err);
    buf_pool.free key_buf
    buf_pool.free val_buf
    return cb err if err
    
    cb null
  
  @put = @set = (doc, cb)->
    if typeof cb != "function"
      puts {doc, cb}
      throw new Error "bad arguments"
    
    for k in #{JSON.stringify field_name_list}
      if !doc.hasOwnProperty k
        return cb new Error "invalid doc. Missing "+k
    
    {#{field_name_list.join ', '}} = doc
    
    await module.ensure_open #{suffix_c_arg_comma}defer(err, db); return cb err if err
    key_buf = module.key_encode #{key_c_arg}
    val_buf = module.val_encode #{val_c_arg}
    await db.put key_buf, val_buf, {}, defer(err);
    buf_pool.free key_buf
    buf_pool.free val_buf
    return cb err if err
    
    cb null
  
  @put_checked = (doc, cb)->
    if typeof cb != "function"
      puts {doc, cb}
      throw new Error "bad arguments"
    
    for k in #{JSON.stringify field_name_list}
      if !doc.hasOwnProperty k
        return cb new Error "invalid doc. Missing "+k
    
    {#{field_name_list.join ', '}} = doc
    
    await module.ensure_open #{suffix_c_arg_comma}defer(err, db); return cb err if err
    key_buf = module.key_encode #{key_c_arg}
    val_buf = module.val_encode #{val_c_arg}
    
    await module._db_get db, key_buf, defer(err, ret_val_buf); return cb err if err
    exists_before = ret_val_buf? and ret_val_buf.length
    
    await db.put key_buf, val_buf, {}, defer(err);
    buf_pool.free key_buf
    buf_pool.free val_buf
    return cb err if err
    
    cb null, !exists_before
  
  @get = (#{key_plus_c_arg}, cb)->
    if typeof cb != "function"
      puts {#{key_plus_c_arg}, cb}
      throw new Error "bad arguments"
    
    await module.ensure_open #{suffix_c_arg_comma}defer(err, db); return cb err if err
    key_buf = module.key_encode #{key_c_arg}
    
    await module._db_get db, key_buf, defer(err, val_buf); return cb err if err
    if !val_buf
      return cb null, null
    
    cb null, module.val_decode val_buf
  
  # do not decode value
  @has = (#{key_plus_c_arg}, cb)->
    if typeof cb != "function"
      puts {#{key_plus_c_arg}, cb}
      throw new Error "bad arguments"
    
    await module.ensure_open #{suffix_c_arg_comma}defer(err, db); return cb err if err
    key_buf = module.key_encode #{key_c_arg}
    
    await module._db_get db, key_buf, defer(err, val_buf); return cb err if err
    
    exists = val_buf? and val_buf.length != 0
    cb null, exists
  
  @del = (#{key_plus_c_arg}, cb)->
    if typeof cb != "function"
      puts {#{key_plus_c_arg}, cb}
      throw new Error "bad arguments"
    
    await module.ensure_open #{suffix_c_arg_comma}defer(err, db); return cb err if err
    key_buf = module.key_encode #{key_c_arg}
    await db.del key_buf, {}, defer(err);
    buf_pool.free key_buf
    
    cb null
  
  @del_checked = (#{key_plus_c_arg}, cb)->
    if typeof cb != "function"
      puts {#{key_plus_c_arg}, cb}
      throw new Error "bad arguments"
    
    await module.ensure_open #{suffix_c_arg_comma}defer(err, db); return cb err if err
    key_buf = module.key_encode #{key_c_arg}
    await module._db_get db, key_buf, defer(err, res);
    if !res or !res.length
      buf_pool.free key_buf
      return cb null, false
    await db.del key_buf, {}, defer(err);
    buf_pool.free key_buf
    
    cb null, true
  
  #{get_suffix_list_code}
  
  # ###################################################################################################
  #    default API, optimized
  # ###################################################################################################
  @put_raw = @set_raw = (#{key_plus_c_arg}, val_buf, cb)->
    if typeof cb != "function"
      puts {#{key_plus_c_arg}, cb}
      throw new Error "bad arguments"
    
    await module.ensure_open #{suffix_c_arg_comma}defer(err, db); return cb err if err
    key_buf = module.key_encode #{key_c_arg}
    await db.put key_buf, val_buf, {}, defer(err);
    buf_pool.free key_buf
    return cb err if err
    
    cb()
  
  @put_checked_raw = (#{key_plus_c_arg}, val_buf, cb)->
    if typeof cb != "function"
      puts {#{key_plus_c_arg}, cb}
      throw new Error "bad arguments"
    
    await module.ensure_open #{suffix_c_arg_comma}defer(err, db); return cb err if err
    key_buf = module.key_encode #{key_c_arg}
    
    # shortcutted module.has
    await module._db_get db, key_buf, defer(err, ret_val_buf);
    if err
      buf_pool.free key_buf
      return cb err
    exists_before = ret_val_buf? and ret_val_buf.length
    
    await db.put key_buf, val_buf, {}, defer(err);
    buf_pool.free key_buf
    return cb err if err
    
    cb null, !exists_before
  
  @get_raw = (#{key_plus_c_arg}, cb)->
    if typeof cb != "function"
      puts {#{key_plus_c_arg}, cb}
      throw new Error "bad arguments"
    
    await module.ensure_open #{suffix_c_arg_comma}defer(err, db); return cb err if err
    key_buf = module.key_encode #{key_c_arg}
    await module._db_get db, key_buf, defer(err, val_buf);
    buf_pool.free key_buf
    return cb err if err
    
    cb null, val_buf
  
  # ###################################################################################################
  #    walk
  # ###################################################################################################
  @_suffix_walk_key = (#{suffix_c_arg_comma}walk, cb)->
    if typeof cb != "function" or typeof walk != "function"
      puts {#{suffix_c_arg_comma}walk, cb}
      throw new Error "bad arguments"
    
    await module.ensure_open #{suffix_c_arg_comma}defer(err, db); return cb err if err
    return cb() if !db
    it = db.iterator keys:true, values:false
    
    walk_continue = true
    while walk_continue
      await it.next defer(err, key_buf, _val_buf);
      if err
        await it.end defer(_err)
        if _err
          err.extra_err = _err
        return cb err
      
      break if !key_buf
      
      await walk key_buf, defer(err, walk_continue), db, it;
      if err
        await it.end defer(_err)
        if _err
          err.extra_err = _err
        return cb err
    
    await it.end defer(err); return cb err if err
    
    cb()
  
  @_suffix_walk = (#{suffix_c_arg_comma}walk, cb)->
    if typeof cb != "function" or typeof walk != "function"
      puts {#{suffix_c_arg_comma}cb}
      throw new Error "bad arguments"
    
    await module.ensure_open #{suffix_c_arg_comma}defer(err, db); return cb err if err
    return cb() if !db
    it = db.iterator()
    
    walk_continue = true
    while walk_continue
      await it.next defer(err, key_buf, val_buf);
      if err
        await it.end defer(_err)
        if _err
          err.extra_err = _err
        return cb err
      
      break if !key_buf
      
      await walk key_buf, val_buf, defer(err, walk_continue), db, it;
      if err
        await it.end defer(_err)
        if _err
          err.extra_err = _err
        return cb err
    
    await it.end defer(err); return cb err if err
    
    cb()
  
  #{aux_extension}
  
  """#"
  # TODO batch
  # TODO clear (как-то надо узнать все известные suffix'ы на диске)
  # TODO iterator + seek
  # TODO sequelize-like API
  # TODO human-friendly parital decode (field skip)
