module.exports = (list, allow_non_strict_order = true)->
  # Requirements
  # list[].name
  # list[]._i_link_list
  # list[]._o_link_list
  
  for v,idx in list
    v._i = idx
  
  # ###################################################################################################
  #    check cycles
  # ###################################################################################################
  # https://www.geeksforgeeks.org/detect-cycle-in-a-graph/
  ###
    mods
      Uint8Array instead of array of bools
      return cycle if found
  ###
  len = list.length
  visited_list      = new Uint8Array len
  in_recursion_list = new Uint8Array len
  
  is_cyclic_util = (i, node)->
    return [node] if in_recursion_list[i]
    return null if visited_list[i]
    visited_list[i]     = 1
    in_recursion_list[i]= 1
    
    # NOTE we don't need walk _i_link_list
    # for loc_v in node._o_link_list
    for loc_v in node._i_link_list
      if cycle_list = is_cyclic_util loc_v._i, loc_v
        cycle_list.push loc_v
        return cycle_list
    
    in_recursion_list[i] = 0
    return null
  
  
  for v,i in list
    if cycle_list = is_cyclic_util i, v
      perr "Cycle detected"
      for v2 in cycle_list
        perr "  ", v2.name
      throw new Error "Cycle detected"
  
  # ###################################################################################################
  #    topo sort
  # ###################################################################################################
  # https://www.geeksforgeeks.org/topological-sorting/
  ###
    mods
      stack layers of mutually independent (all dependencies only to left layer)
  ###
  
  visited_list.fill 0
  stack_list_list = []
  topological_sort_util = (phase)->
    visited_list[phase._i] = 1
    req_depth = 0
    for loc_v in phase._i_link_list
      if !visited_list[loc_v._i]
        topological_sort_util loc_v
      
      req_depth = Math.max req_depth, loc_v._topo_depth+1
    
    phase._topo_depth = req_depth
    stack_list_list[req_depth] ?= []
    stack_list_list[req_depth].push phase
    return
  
  for v,i in list
    if !visited_list[v._i]
      topological_sort_util v, 0
  
  if !allow_non_strict_order
    orphan_list = []
    for v in stack_list_list[0]
      if v._o_link_list.length == 0
        orphan_list.push v
    
    if orphan_list.length and list.length > 1
      perr "phase orphan_list"
      for v in orphan_list
        perr "  ", v.name
      throw new Error "Orphaned node detected"
    
    for loc_stack_list in stack_list_list
      if loc_stack_list.length > 1
        perr "unordered node group"
        for v in loc_stack_list
          perr "  ", v.name
        throw new Error "Unordered node group detected"
  
  # ###################################################################################################
  list.sort (a,b)->a._topo_depth-b._topo_depth
  return
