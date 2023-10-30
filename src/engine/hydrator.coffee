module = @

class Hydrator
  policy_filter_fn: null
  node_filter_fn  : null
  apply_fn  : null

@hydrator_list = []

@hydrator_def = (policy_filter_fn, node_filter_fn, apply_fn)->
  h = new Hydrator
  h.policy_filter_fn= policy_filter_fn
  h.node_filter_fn  = node_filter_fn
  h.apply_fn        = apply_fn
  module.hydrator_list.push h
  return

@hydrator_list_filter = (policy_filter_obj)->
  ret_list = []
  for h in module.hydrator_list
    continue if !h.policy_filter_fn policy_filter_obj
    ret_list.push h
  
  ret_list

@hydrator_apply = (h_list, node)->
  for h in h_list
    continue if !h.node_filter_fn node
    h.apply_fn node
  return
