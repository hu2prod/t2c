#!/usr/bin/env iced
fs = require "fs"
crypto = require "crypto"
{execSync} = require "child_process"
require "fy"
require "lock_mixin"
argv = require("minimist")(process.argv.slice(2))

arch_list = fs.readFileSync("arch_linux_list", "utf-8").split("\n").filter (t)->t

puts "arch_list"
for v in arch_list
  puts "  #{v}"
puts ""

# ###################################################################################################
#    util
# ###################################################################################################
file_ignore_regex = /^\/build.*?\//
file_test_regex = /\.(h|c|hpp|cpp|asm|inc|gyp)$/

collect_file_list = (dir, root_dir = dir)->
  ret_list = []
  file_list = fs.readdirSync dir
  file_list.natsort()
  for file in file_list
    full_file = "#{dir}/#{file}"
    stat = fs.lstatSync full_file
    if stat.isDirectory()
      ret_list.append collect_file_list full_file, root_dir
    else
      part_file = full_file.replace root_dir, ""
      continue if file_ignore_regex.test part_file
      continue if !file_test_regex.test  part_file
      ret_list.push full_file
  
  return ret_list

file_list_to_checksum = (file_list)->
  ret_hash = {}
  
  for file in file_list
    hash = crypto.createHash "sha256"
    hash.update fs.readFileSync file
    ret_hash[file] = hash.digest "hex"
  
  ret_hash

rm_rf = (path)->
  if fs.existsSync path
    if fs.rmSync?
      fs.rmSync path, recursive : true
    else
      fs.rmdirSync path, recursive : true

# ###################################################################################################
# ??? TODO build custom binaries for src_c_napi

# ###################################################################################################
if fs.existsSync "src_c_lib"
  puts """
    ####################################################################################################
    #   src_c_lib
    ####################################################################################################
    """
  for mod_name in fs.readdirSync "src_c_lib"
    puts mod_name
    
    opt =
      cwd   : "src_c_lib/#{mod_name}"
      stdio : "inherit"
    
    for arch in arch_list
      if !fs.existsSync "src_c_lib/#{mod_name}/build_#{arch}.sh"
        puts "#{arch} SKIP no src_c_lib/#{mod_name}/build_#{arch}.sh"
        continue
      
      file_list = collect_file_list "./src_c_lib/#{mod_name}"
      file_hash = file_list_to_checksum file_list
      
      file_hash_path = "./src_c_lib/#{mod_name}/file_hash.json"
      build_path = "src_c_lib/#{mod_name}/build_#{arch}"
      if fs.existsSync build_path
        if fs.existsSync file_hash_path
          old_file_hash = JSON.parse fs.readFileSync file_hash_path
          if JSON.eq old_file_hash, file_hash
            puts "SKIP #{arch}"
            continue
      
      puts arch
      
      rm_rf build_path
      
      cmd = "./build_#{arch}.sh"
      execSync cmd, opt
      
      fs.writeFileSync file_hash_path, JSON.stringify file_hash, null, 2

if fs.existsSync "src_c_napi"
  puts """
    ####################################################################################################
    #   src_c_napi
    ####################################################################################################
    """
  for mod_name in fs.readdirSync "src_c_napi"
    puts mod_name
    for arch in arch_list
      if !fs.existsSync "src_c_napi/#{mod_name}/#{arch}"
        puts "#{arch} SKIP no src_c_napi/#{mod_name}/#{arch}"
        continue
      
      need_rebuild = true
      
      file_hash_path = "./src_c_napi/#{mod_name}/#{arch}/file_hash.json"
      build_path = "src_c_napi/#{mod_name}/#{arch}/build"
      
      file_hash_collect = ()->
        file_list = collect_file_list "./src_c_napi/#{mod_name}/src"
        file_list.append collect_file_list "./src_c_napi/#{mod_name}/#{arch}"
        # TODO all deps
        file_hash = file_list_to_checksum file_list
      
      loop
        if !fs.existsSync build_path
          need_rebuild = true
          break
        
        if !fs.existsSync file_hash_path
          need_rebuild = true
          break
        
        file_hash = file_hash_collect()
        old_file_hash = JSON.parse fs.readFileSync file_hash_path
        if !JSON.eq old_file_hash, file_hash
          need_rebuild = true
          break
        
        need_rebuild = false
        break
      
      if !need_rebuild
        puts "#{arch} SKIP"
        continue
      
      puts arch
      
      opt =
        cwd   : "src_c_napi/#{mod_name}/#{arch}"
        stdio : "inherit"
      
      # rm_rf build_path
      # более аккуратный способ
      rm_rf "#{build_path}/Release/obj.target/module"
      
      cmd = "npm run install"
      # cmd = "npm run install-verbose"
      execSync cmd, opt
      
      # re-read
      file_hash = file_hash_collect()
      fs.writeFileSync file_hash_path, JSON.stringify file_hash, null, 2

puts "done"
