#!/usr/bin/env iced
require "fy"
fs = require "fs"
express = require "express"
compression = require "compression"
http_proxy  = require "http-proxy"
spdy    = require "spdy"
axios   = require "axios"
config  = require "./config"

app = express()

# app.use require("helmet")()
app.use express.static "./static", dotfiles: "allow"

# ###################################################################################################
#    http_bypass
# ###################################################################################################
bypass_cache = {}
do ()=>
  loop
    remove_key_list = []
    for key, proxy_res of bypass_cache
      if Date.now() - proxy_res.ts > config.http_bypass_cache_time
        remove_key_list.push key
    
    for key in remove_key_list
      delete bypass_cache[key]
    
    await setTimeout defer(), 10000
  return

comp = compression(threshold: config.comress_threshold)

app.use (req, res)->
  # TODO own cached compress
  comp req, res, ->
  # UNhelmet for dev env
  if config.dev
    res.removeHeader "content-security-policy"
  
  # ###################################################################################################
  #    cache
  # ###################################################################################################
  cache_key = req.url
  url = config.http_bypass+req.url
  if proxy_res = bypass_cache[cache_key]
    proxy_res
    if Date.now() - proxy_res.ts < config.http_bypass_cache_time
      for k,v of proxy_res.headers
        res.setHeader k, v
      res.end proxy_res.data
      return
  
  opt = {
    url
    responseType  : "arraybuffer"
  }
  await axios.request(opt).cb defer(err, proxy_res)
  if err
    perr err
    res.end()
    return
  
  delete proxy_res.headers.connection
  for k,v of proxy_res.headers
    res.setHeader k, v
  
  bypass_cache[cache_key] = proxy_res
  proxy_res.ts = Date.now()
  
  res.end proxy_res.data

app.use (err, req, res, next)->
  console.error err
  res.status(500).send("")

# ###################################################################################################
app.listen config.proxy_port
p "listen :#{config.proxy_port}"

cert_path = "/etc/letsencrypt/live/#{config.domain}/fullchain.pem"
key_path  = "/etc/letsencrypt/live/#{config.domain}/privkey.pem"

if fs.existsSync(cert_path) and fs.existsSync(key_path)
  https_opt =
    cert: fs.readFileSync cert_path
    key : fs.readFileSync key_path
  https_server = spdy.createServer https_opt, app
  https_server.listen 443
  p "listen :443"
  
  # ###################################################################################################
  #    ws_bypass (https only)
  # ###################################################################################################
  if config.ws_bypass
    puts "ws_bypass", config.ws_bypass
    proxy = http_proxy.createProxyServer target: config.ws_bypass, ws: true, xfwd : true
    https_server.on "upgrade", (req, socket, head)->
      proxy.ws req, socket, head
