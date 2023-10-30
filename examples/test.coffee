project "template", ()->
  # cat ../*/gen/zz_main.coffee | grep service_port_offset | grep -v cat | sort -V
  policy_set "service_port_offset", 0 # replace with other number <1000 for non-conflicting services
  policy_set "package_manager", "snpm"
  npm_i "fy"
  
  # TODO make 1 cmd
  npm_i "iced-coffee-script"
  npm_i "iced-runtime"
  npm_i "iced-coffee-coverage"
  npm_i "istanbul"
  npm_i "mocha"
  # --timeout 5000
  # npm_script "test", "mocha --recursive --compilers coffee:iced-coffee-script/register --require iced-coffee-coverage/register-istanbul test && istanbul report"
  # npm_script "test-specific", "mocha --recursive --compilers coffee:iced-coffee-script/register test -g"
  npm_script "test", "mocha --recursive --compilers coffee:iced-coffee-script/register --require ./register-istanbul test && istanbul report"
  npm_script "test-specific", "mocha --recursive --compilers coffee:iced-coffee-script/register --require ./register-istanbul test -g"
  gitignore "coverage"
  
  ###
  assert = require "assert"
  describe "chunk_split section", ()-> 
    it "no split needed", ()->
  ##
