project "template", ()->
  policy_set "package_manager", "snpm"
  npm_i "fy"
  npm_i "striptags", "3.2.0"
  
  node = node_worker "striptags", ()->
  node.data_hash.require_codebub = """
    fs = require "fs"
    striptags = require "striptags"
    """#"
  
  node.data_hash.code_codebub = """
    cont = fs.readFileSync req.file, "utf-8"
    cb null, {cont:striptags cont}
    """#"
  
  ###
  usage
  striptags = require "./worker/striptags"
  await striptags.job {file}, defer(err)
  # OR
  await striptags.job_auto_bucket {file}, defer(err)
  
  ###

