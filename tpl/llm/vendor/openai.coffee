axios = require "axios"
{LLM_key_queue, LLM_vendor} = require "../def"
proxy = require "../proxy"
config = require "../../config"
db = require "../../db"

# TODO move
Buffer.prototype.split = (separator)->
  res_list = []
  start = 0
  end = 0
  
  loop
    end = @indexOf separator, start
    break if end == -1
    res_list.push @slice start, end
    start = end + separator.length
  
  if start == 0
    res_list.push start
  else
    res_list.push @slice start
  res_list

module.exports = vendor = new LLM_vendor
vendor.name = "openai"
vendor.queue_load_fn = ()->
  for _api_key, key_id in config.openai_api_key_list
    vendor.queue_list.push queue = new LLM_key_queue vendor, key_id, config.openai_max_parallel_req_per_key
    queue.do_loop()
  return

vendor.build_request_fn = (opt)->
  # TODO model specific
  system = opt.system ? ""
  req = {
    "model": opt.model ? config.openai_llm_model
    "messages": [
      {"role": "system", "content": system}
    ]
    stream : true
  }
  if opt.msg_inject_list
    req.messages.append opt.msg_inject_list
  req.messages.push {"role": "user", "content": opt.prompt}
  
  # KEEP
  # puts JSON.stringify loc_opt, null, 2
  # process.exit()
  
  if opt.temperature?
    req.temperature = opt.temperature
  return req

split_buf = Buffer.from "\n\n"
vendor.make_request_fn  = (opt, cb)->
  {
    req
    key_id
  } = opt
  
  loc_opt = {
    method: "POST"
    url   : "https://api.openai.com/v1/chat/completions"
    data  : JSON.stringify req
    headers : {
      "Content-Type": "application/json"
      Authorization : "Bearer #{config.openai_api_key_list[key_id]}"
    }
    transformResponse : []
    responseType: "stream"
  }
  # NOTE unimplemented
  proxy loc_opt, vendor.name, key_id
  await axios(loc_opt).cb defer(err, axios_res); return cb err if err
  
  stream_list = []
  last_cut = Buffer.alloc 0
  compose_result = ""
  success = false
  axios_res.data.on "data", (res)->
    last_cut = Buffer.concat [last_cut, res]
    
    msg_buf_list = last_cut.split split_buf
    last_cut = msg_buf_list.pop()
    for msg_buf in msg_buf_list
      msg_buf = msg_buf.slice "data: ".length
      msg = msg_buf.toString()
      if msg == "[DONE]"
        success = true
        continue
      
      try
        last_result = JSON.parse msg
      catch err
        perr err.message
        return
      
      # for replay?
      last_result.ts = Date.now()
      stream_list.push last_result
      {content} = last_result.choices[0].delta
      compose_result += content if content?
      
      vendor.dispatch "llm_gen", {
        req_id  : opt.id
        res     : last_result
        compose_result
      }
  
  await axios_res.data.on "end", defer()
  
  # last resort костыль
  success = true if last_cut.toString() == "data: [DONE]"
  
  cb null, {
    stream_list
    compose_result
    index         : stream_list.last()?.choices[0].index
    finish_reason : stream_list.last()?.choices[0].finish_reason
    success
  }

vendor.progress_fn = (opt, cb)->
  {
    task
    queue
  } = opt
  was_paused = task.status == "PAUSED"
  # ###################################################################################################
  # DB update
  where = {
    id : task.id
  }
  update_hash = {
    status : "IN_PROGRESS"
  }
  if !task.key_id?
    update_hash.key_id = task.key_id = queue.key_id
  
  await db.llm_state.update(update_hash, {where}).cb defer(err, _res); return cb err if err
  
  # ###################################################################################################
  if module.debug_log
    if was_paused
      puts "DEBUG CALL RESTART #{task.id}"
    else
      puts "DEBUG CALL START #{task.id}"
  
  for retry_count in [0 ... vendor.retry_count]
    loc_opt = {
      id    : task.id
      key_id: task.key_id
      req   : JSON.parse task.text_i_json
    }
    await vendor.make_request_fn loc_opt, defer(err, res);
    
    # Прим. Всё-таки это больше openai-specific костыли
    if err?.message == "Request failed with status code 429"
      queue.rate_limit_on task
      if queue.in_progress_queue_list[0] != task
        queue.scheduled_queue_list.push task
        queue.in_progress_queue_list.remove task
        update_hash = {
          status : "PAUSED"
        }
        await db.llm_state.update(update_hash, {where}).cb defer(err, _res); return cb err if err
        if module.debug_log
          puts "DEBUG PAUSED #{task.id}"
        return cb()

      interval_ms = Math.min 60000, 5000*(1+2**retry_count)
      if module.debug_log
        puts "DEBUG WAIT #{task.id} #{interval_ms}"
      await setTimeout defer(), interval_ms
      continue

    break if err # ERROR_UNKNOWN
    if !res.success
      puts "ERROR_STREAM #{task.id}"
      # Сбойные данные могут быть тоже полезными. Запомним их
      if task.text_err_o_json
        text_err_o_json = JSON.parse task.text_err_o_json
      else
        text_err_o_json = list:[]

      text_err_o_json.list.push res
      update_hash = {
        text_err_o_json : JSON.stringify text_err_o_json
      }
      task.text_err_o_json = update_hash.text_err_o_json
      await db.llm_state.update(update_hash, {where}).cb defer(err, _res); return cb err if err
      continue

    break
  
  # ###################################################################################################
  # handle result
  if module.debug_log
    puts "DEBUG CALL DONE #{task.id}"
  queue.rate_limit_off task
  queue.in_progress_queue_list.remove task
  
  status = "DONE"
  if err
    puts "ERR:", err.message
    # если за 20 попыток мы не смогли преодолеть rate limit, то определённо что-то сломалось и надо остановиться
    # аналогично если за 20 попыток мы не смогли получить целый ответ
    if err.message == "Request failed with status code 429"
      status = "ERROR_RATE_LIMIT"
    else if err.message == "Request failed with status code 502"
      # КОСТЫЛЬ, бо заебало. Bad gateway
      status = "ERROR_RATE_LIMIT"
    else
      status = "ERROR_UNKNOWN"
  else
    status = "ERROR_STREAM" if !res.success
  
  # ###################################################################################################
  # DB update
  where = {
    id : task.id
  }
  update_hash = {
    status
    done_at : Date.now()
  }
  update_hash.error = err.message if err
  update_hash.text_o_json = JSON.stringify res if res

  await db.llm_state.update(update_hash, {where}).cb defer(err); return cb err if err
  obj_set task, update_hash
  
  # ###################################################################################################
  # return/broadcast
  vendor.dispatch "llm_gen_complete", task

  switch task.status
    when "ERROR_STREAM", "ERROR_UNKNOWN", "ERROR_RATE_LIMIT"
      return cb new Error(task.status), task
    else
      return cb null, task
