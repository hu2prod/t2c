require "fy"
argv = require("minimist")(process.argv.slice(2))
config = require("dotenv-flow").config().parsed or {}
for k,v of argv
  config[k.toUpperCase()] = v
# ###################################################################################################

@watch            = !!+(config.WATCH or "0")
@proxy_port       = config.PROXY_PORT or "80"
@domain           = config.DOMAIN
@http_bypass      = config.HTTP_BYPASS or "http://localhost:10000" # http_port
@ws_bypass        = config.WS_BYPASS   or "" # ws_port
@comress_threshold= +(config.COMRESS_THRESHOLD or "1024")
@http_bypass_cache_time = +(config.HTTP_BYPASS_CACHE_TIME or "30000") # 30 sec
@dev              = config.DEV
