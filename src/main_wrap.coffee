#!/usr/bin/env iced
### !pragma coverage-skip-block ###
argv = require("minimist")(process.argv.slice(2))
await require("./main_impl").go argv, defer(err)
### !pragma coverage-skip-block ###
if err
  unless err?.message in ["no cmd", "bad cmd", "unknown cmd"]
    throw err

process.exit()
