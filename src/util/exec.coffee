{execSync} = require "child_process"
module.exports = (cmd)->
  p cmd
  execSync cmd
