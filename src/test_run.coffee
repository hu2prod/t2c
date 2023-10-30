#!/usr/bin/env iced
fs = require "fs"
require "fy"
runner = require "./engine/runner"
require "./block_import"

cb = (err)->
  if err
    throw err
  puts "done"
  process.exit()

# ###################################################################################################
dir = "/data/nodejs/experiments/t2c_playground"
process.chdir dir
runner.reset()
require "#{dir}/gen/zz_main.coffee"
runner.current_runner.go {}

cb()
