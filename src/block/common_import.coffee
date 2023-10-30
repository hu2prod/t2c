iced_compiler = require "iced-coffee-script"
LRU = require "lru"
{
  Node
} = require "../engine/ast"
{
  def
} = require "../engine/block"
{
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
} = require "../engine/block_decl_helper"
{
  hydrator_def
  hydrator_list_filter
  hydrator_apply
} = require "../engine/hydrator"
mod_runner = require "../engine/runner"
mod_config = require "../config"

iced_lru = new LRU 1000
module.exports = {
  Node
  
  bdh_module_name_root
  bdh_node_module_name_assign_on_call
  
  def
  
  hydrator_def
  hydrator_list_filter
  hydrator_apply
  
  mod_runner
  mod_config
  iced_compile : (code, opt={})->
    return ret if ret = iced_lru.get code
    opt.runtime ?= "none"
    ret = iced_compiler.compile code, opt
    iced_lru.set code, ret
    ret
}
