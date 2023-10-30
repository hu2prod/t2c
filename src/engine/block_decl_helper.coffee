# bdh = block decl helper
# for better autosuggest
@bdh_module_name_root = (a_module, name, opt)->
  a_module["#{name}_nodegen"]      = opt.nodegen       ? (node, phase_ctx)->false
  a_module["#{name}_validator"]    = opt.validator     ? (node, phase_ctx)->false
  a_module["#{name}_emit_codebub"] = opt.emit_codebub  ? (node, phase_ctx)->false
  a_module["#{name}_emit_codegen"] = opt.emit_codegen  ? (node, phase_ctx)->false
  a_module["#{name}_emit_min_deps"]= opt.emit_min_deps ? (node, phase_ctx, cb)->cb null, false
  return

@bdh_node_module_name_assign_on_call = (node, a_module, name)->
  node.nodegen        ?= a_module["#{name}_nodegen"]
  node.validator      ?= a_module["#{name}_validator"]
  node.emit_codebub   ?= a_module["#{name}_emit_codebub"]
  node.emit_codegen   ?= a_module["#{name}_emit_codegen"]
  node.emit_min_deps  ?= a_module["#{name}_emit_min_deps"]
  return
