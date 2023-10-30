module = @
class @DB
  final_model_hash: {}
  migration_list  : []
  migration_idx   : 0
  constructor:()->
    @final_model_hash = {}
    @migration_list   = []
  
  delete : ()->
    for k,v of @final_model_hash
      v.delete()
    @final_model_hash = {}
    
    for v in @migration_list
      v.delete()
    @migration_list.clear()
    return
  
  migration_get : ()->
    ret = @migration_list[@migration_idx++]
    if !ret
      @migration_list.push ret = new module.Migration
      ret.parent_db = @
      ret.idx = @migration_idx-1
    ret

class @Migration
  parent_db : null
  idx       : -1
  name      : ""
  model_hash: {}
  index_hash: {}
  
  constructor:()->
    @model_hash = {}
    @index_hash = {}
  
  delete : ()->
    for k,v of @model_hash
      v.delete()
    @model_hash = {}
    
    for k,v of @index_hash
      v.delete()
    @index_hash = {}
    return
  
  model_get : (name)->
    ret = @model_hash[name]
    final_model = @parent_db.final_model_hash[name]
    if !final_model
      @parent_db.final_model_hash[name] = final_model = new module.Model
      final_model.name = name
    
    if !ret
      @model_hash[name] = ret = new module.Model
      ret.name = name
      ret.final_model = final_model
    
    ret
  
  index_get : (key)->
    ret = @index_hash[key]
    if !ret
      @index_hash[key] = ret = new module.Index
    
    ret

class @Model
  final_model : null
  name        : ""
  field_hash  : {}
  constructor:()->
    @field_hash = {}
  
  delete : ()->
    for k,v of @field_hash
      v.delete()
    @field_hash = {}
    return
  
  field_get : (name)->
    return ret if ret = @final_model?.field_hash[name]
    
    ret = @field_hash[name]
    if !ret
      @field_hash[name] = ret = new module.Field
      ret.name = name
      
      @final_model.field_hash[name] = ret
    
    ret
  
class @Index
  table_name : ""
  field_list : []
  is_unique  : false
  # TODO delete
  
  constructor:()->
    @field_list = []
  
  delete : ()->
    @field_list.clear()

class @Field
  name : ""
  type : null
  default_value   : undefined
  allow_null      : false
  custom_validator: undefined
  migration_idx   : undefined
  
  delete : ()->
    @custom_validator = null

