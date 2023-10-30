module = @
class @Policy
  key : ""
  val : null
  this_node_only : false
  is_weak : false
  used: false

class @Node
  parent: null
  name  : ""
  type  : ""
  src_nodegen : ""
  
  # phase handlers
  nodegen     : null
  validator   : null
  # code bubble
  emit_codebub: null
  emit_codegen: null
  emit_min_deps: null
  
  policy_hash : {}
  child_list  : []
  
  # replacement for list hash group
  typed_ref_hash : {}
  
  data_hash : {}
  
  constructor:()->
    @policy_hash= {}
    @child_list = []
    @typed_ref_hash = {}
    @data_hash  = {}
  
  delete : ()->
    @parent = null
    for v in @child_list
      v.delete()
    
    @child_list.clear()
    
    @policy_hash    = {}
    @typed_ref_hash = {}
    
    for k,v of @data_hash
      v?.delete?()
    @data_hash      = {}
    return
  
  # ###################################################################################################
  #    policy
  # ###################################################################################################
  policy_get : (key, this_node = true)->
    if ret = @policy_hash[key]
      return ret if this_node
      return ret if !ret.this_node_only
    
    return @parent?.policy_get key, false
  
  policy_get_val_use : (key)->
    ret = @policy_get key
    if !ret?
      throw new Error "policy '#{key}' not found"
    
    ret.used = true
    ret.val
  
  policy_get_val_use_default : (key, default_value)->
    ret = @policy_get key
    if !ret?
      return default_value
    
    ret.used = true
    ret.val
  
  policy_get_val_no_use : (key)->
    ret = @policy_get key
    if !ret?
      throw new Error "policy '#{key}' not found"
    
    ret.val
  
  policy_get_here_is_weak : (key)->
    ret = @policy_get key
    if !ret?
      throw new Error "policy '#{key}' not found"
    
    ret.is_weak
  
  policy_set_here_weak : (key, val)->
    return if policy = @policy_hash[key]
    
    @policy_hash[key] = policy = new module.Policy
    policy.key = key
    policy.val = val
    policy.is_weak = true
    return
  
  policy_set_here : (key, val)->
    if policy = @policy_hash[key]
      if policy.is_weak
        policy.is_weak = false
        policy.val = val
        return
      
      # !is_weak
      if policy.val != val
        p "old val", policy.val
        p "new val", val
        throw new Error "policy key=#{key} mismatch. node name=#{@name} type=#{@type}"
      return
    
    @policy_hash[key] = policy = new module.Policy
    policy.key = key
    policy.val = val
    return
  
  # ###################################################################################################
  #    type ref
  # ###################################################################################################
  tr_get_try : (type, name)->
    @typed_ref_hash[type] ?= {}
    return ret if ret = @typed_ref_hash[type][name]
    null
  
  tr_get : (type, name, src_nodegen)->
    @typed_ref_hash[type] ?= {}
    return ret if ret = @typed_ref_hash[type][name]
    
    @typed_ref_hash[type][name] = node = new Node
    @child_list.push node
    node.parent = @
    node.name = name
    node.type = type
    node.src_nodegen= src_nodegen
    node
  
  tr_get_deep : (type, name)->
    return ret if ret = @typed_ref_hash[type]?[name]
    if !@parent
      throw new Error "can't find tr_get_deep type=#{type} name=#{name}"
    @parent.tr_get_deep type, name
  
  # Потенциально вредная функция
  # желательно убрать
  tr_get_type_only_here : (type)->
    return null if !hash = @typed_ref_hash[type]
    list = Object.values hash
    return null if list.length == 0
    if list.length > 1
      throw new Error "multiple type=#{type}"
    list[0]
  
  # ###################################################################################################
  #    misc
  # ###################################################################################################
  mk_child : (type, name, src_nodegen)->
    node = new Node
    @child_list.push node
    node.parent = @
    node.name = name
    node.type = type
    node.src_nodegen= src_nodegen
    node
  
  # unused
  _type_filter_search_str : (type_filter)->
    return @ if @type == type_filter
    @parent?._type_filter_search_str type_filter
  
  _type_filter_search_list : (type_filter)->
    return @ if type_filter.has @type
    @parent?._type_filter_search_str type_filter
  
  _type_filter_search_regexp : (type_filter)->
    return @ if type_filter.test @type
    @parent?._type_filter_search_str type_filter
  
  type_filter_search : (type_filter)->
    if typeof type_filter == "string"
      return @_type_filter_search_str type_filter
    else if type_filter instanceof Array
      return @_type_filter_search_list type_filter
    else if type_filter instanceof RegExp
      return @_type_filter_search_regexp type_filter
    else
      p type_filter
      throw new Error "bad type_filter '#{type_filter}'"
    
  

