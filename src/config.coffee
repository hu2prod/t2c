fs = require "fs"
# TODO fixme?
@curr_arch = "node16-linux-x64"

@local_config_path = "#{process.env.HOME}/.t2c/local_config.json"
@local_config = {}
if fs.existsSync @local_config_path
  @local_config = JSON.parse fs.readFileSync @local_config_path

