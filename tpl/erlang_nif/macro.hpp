#pragma once
// why malloc, and not new
// https://stackoverflow.com/questions/23591196/are-calloc-malloc-faster-than-operator-new-in-c
// patched for erlang_nif
// some node.js-related stuff is still here

#include <vector>
#include <string>

#define PPCAT_NX(A, B) A ## B
#define PPCAT_NX3(A, B, C) A ## B ## C
#define PPCAT_NX4(A, B, C, D) A ## B ## C ## D
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)

#if _MSC_VER
#define UNUSED
#else
#define UNUSED __attribute__((unused))
#endif


////////////////////////////////////////////////////////////////////////////////////////////////////
//    
//    Function
//    
////////////////////////////////////////////////////////////////////////////////////////////////////

// TODO LATER rework or DROP
#define FN_EXPORT(NAME)                                                                     \
status = napi_create_function(env, nullptr, 0, NAME, nullptr, &__fn);                       \
if (status != napi_ok) {                                                                    \
  napi_throw_error(env, nullptr, "FN_EXPORT !napi_create_function NAME=" TOSTRING(NAME));   \
  return nullptr;                                                                           \
}                                                                                           \
                                                                                            \
status = napi_set_named_property(env, exports, TOSTRING(NAME), __fn);                       \
if (status != napi_ok) {                                                                    \
  napi_throw_error(env, nullptr, "FN_EXPORT !napi_set_named_property NAME=" TOSTRING(NAME));\
  return nullptr;                                                                           \
}


////////////////////////////////////////////////////////////////////////////////////////////////////
//    arg
////////////////////////////////////////////////////////////////////////////////////////////////////
#define FN_ARG_HEAD_EMPTY
/*
if (argc != 0) {
  return enif_make_badarg(envPtr);
}
*/

#define FN_ARG_HEAD(COUNT)                                                                  \
int arg_idx = 0;                                                                            \
if (argc != COUNT) {                                                                        \
  return enif_make_badarg(envPtr);                                                          \
}

// TODO LATER?
#define FN_ARG_BOOL(NAME)                                                                   \
bool NAME;                                                                                  \
status = napi_get_value_bool(env, argv[arg_idx], &NAME);                                    \
if (status != napi_ok) {                                                                    \
  std::string err_msg = "FN_ARG_BOOL !napi_get_value_bool. Bad bool arg " TOSTRING(NAME) " FN_NAME="; \
  err_msg += __func__;                                                                      \
  napi_throw_error(env, nullptr, err_msg.c_str());                                          \
  return ret_dummy;                                                                         \
}                                                                                           \
arg_idx++;

#define FN_ARG_I32(NAME)                                                                    \
i32 NAME;                                                                                   \
if (!enif_get_int(envPtr, argv[arg_idx], &NAME)) {                                          \
  return enif_make_badarg(envPtr);                                                          \
}                                                                                           \
arg_idx++;

// TODO LATER
#define FN_ARG_I64(NAME)                                                                    \
i64 NAME;                                                                                   \
if (!enif_get_int64(envPtr, argv[arg_idx], &NAME)) {                                        \
  return enif_make_badarg(envPtr);                                                          \
}                                                                                           \
arg_idx++;

#define FN_ARG_U32(NAME)                                                                    \
i32 NAME;                                                                                   \
if (!enif_get_int(envPtr, argv[arg_idx], &NAME)) {                                          \
  return enif_make_badarg(envPtr);                                                          \
}                                                                                           \
arg_idx++;

// TODO LATER
#define FN_ARG_U64(NAME)                                                                    \
u64 NAME;                                                                                   \
bool PPCAT_NX(NAME,_lossless);                                                              \
status = napi_get_value_bigint_uint64(env, argv[arg_idx], &NAME, &PPCAT_NX(NAME,_lossless));\
                                                                                            \
if (status != napi_ok) {                                                                    \
  std::string err_msg = "FN_ARG_U64 !napi_get_value_bigint_uint64. Bad u64 arg " TOSTRING(NAME) " FN_NAME="; \
  err_msg += __func__;                                                                      \
  napi_throw_error(env, nullptr, err_msg.c_str());                                          \
  return ret_dummy;                                                                         \
}                                                                                           \
arg_idx++;

// TODO LATER
#define FN_ARG_F32(NAME)                                                                    \
f64 PPCAT_NX(_,NAME);                                                                       \
f32 NAME;                                                                                   \
status = napi_get_value_double(env, argv[arg_idx], &PPCAT_NX(_,NAME));                      \
                                                                                            \
if (status != napi_ok) {                                                                    \
  std::string err_msg = "FN_ARG_F32 !napi_get_value_double. Bad f32 arg " TOSTRING(NAME) " FN_NAME="; \
  err_msg += __func__;                                                                      \
  napi_throw_error(env, nullptr, err_msg.c_str());                                          \
  return ret_dummy;                                                                         \
}                                                                                           \
NAME = PPCAT_NX(_,NAME)                                                                     \
arg_idx++;

#define FN_ARG_F64(NAME)                                                                    \
f64 NAME;                                                                                   \
status = napi_get_value_double(env, argv[arg_idx], &NAME);                                  \
                                                                                            \
if (status != napi_ok) {                                                                    \
  std::string err_msg = "!napi_get_value_double. Bad f64 arg " TOSTRING(NAME) " FN_NAME=";  \
  err_msg += __func__;                                                                      \
  napi_throw_error(env, nullptr, err_msg.c_str());                                          \
  return ret_dummy;                                                                         \
}                                                                                           \
arg_idx++;


// This implementation contains memory leak
// free(str) should be called manually
// TODO LATER
#define FN_ARG_STR(NAME)                                                                      \
ErlNifBinary PPCAT_NX(NAME,_erl);                                                             \
if (!enif_inspect_binary(envPtr, argv[arg_idx], &PPCAT_NX(NAME,_erl))) {                      \
  return enif_make_badarg(envPtr);                                                            \
}                                                                                             \
char *NAME;                                                                                   \
size_t PPCAT_NX(NAME,_len);                                                                   \
PPCAT_NX(NAME,_len) = PPCAT_NX(NAME,_erl).size;                                               \
NAME = (char*)malloc(PPCAT_NX(NAME,_len)+1);                                                  \
memcpy(NAME, PPCAT_NX(NAME,_erl).data, PPCAT_NX(NAME,_len));                                  \
NAME[PPCAT_NX(NAME,_len)] = 0;                                                                \
arg_idx++;

#define FN_ARG_BUF(NAME)                                                                      \
ErlNifBinary PPCAT_NX(NAME,_erl);                                                             \
if (!enif_inspect_binary(envPtr, argv[arg_idx], &PPCAT_NX(NAME,_erl))) {                      \
  return enif_make_badarg(envPtr);                                                            \
}                                                                                             \
u8 *NAME;                                                                                     \
size_t PPCAT_NX(NAME,_len);                                                                   \
NAME = PPCAT_NX(NAME,_erl).data;                                                              \
PPCAT_NX(NAME,_len) = PPCAT_NX(NAME,_erl).size;                                               \
arg_idx++;

// TODO LATER
#define FN_ARG_BUF_VAL(NAME)                                                                  \
u8 *NAME;                                                                                     \
size_t PPCAT_NX(NAME,_len);                                                                   \
status = napi_get_buffer_info(env, argv[arg_idx], (void**)&NAME, &PPCAT_NX(NAME,_len));       \
if (status != napi_ok) {                                                                      \
  std::string err_msg = "FN_ARG_BUF_VAL !napi_get_buffer_info. Bad buf arg " TOSTRING(NAME) " FN_NAME="; \
  err_msg += __func__;                                                                        \
  napi_throw_error(env, nullptr, err_msg.c_str());                                            \
  return ret_dummy;                                                                           \
}                                                                                             \
napi_value PPCAT_NX(NAME,_val) = argv[arg_idx];                                               \
arg_idx++;

#define FN_ARG_CLASS(CLASS_NAME, NAME)                                                        \
struct PPCAT_NX(CLASS_NAME,_c_wrapper) *PPCAT_NX(NAME,_wrapper);                              \
CLASS_NAME *NAME;                                                                             \
if (!enif_get_resource(envPtr, argv[arg_idx], PPCAT_NX3(CLASS_DECL_, CLASS_NAME, _c_wrapper), (void**) &PPCAT_NX(NAME,_wrapper))) {\
  return error(envPtr, "failed to read " TOSTRING(CLASS_NAME));                               \
}                                                                                             \
NAME = PPCAT_NX(NAME,_wrapper)->obj;                                                          \
if (NAME->_class_tag != PPCAT_NX(CLASS_NAME,_tag)) {                                          \
  std::string err_msg = "FN_ARG_CLASS Wrong class tag for arg " TOSTRING(NAME) ". expected " TOSTRING(CLASS_NAME) " FN_NAME="; \
  err_msg += __func__;                                                                        \
  return error(envPtr, err_msg.c_str());                                                      \
}                                                                                             \
if (NAME->_deleted) {                                                                         \
  std::string err_msg = "FN_ARG_CLASS You are calling already freed object " TOSTRING(NAME) " of class " TOSTRING(CLASS_NAME) " FN_NAME="; \
  err_msg += __func__;                                                                        \
  return error(envPtr, err_msg.c_str());                                                      \
}                                                                                             \
arg_idx++;

// TODO LATER
#define FN_ARG_CLASS_VAL(CLASS_NAME, NAME)                                                    \
CLASS_NAME *NAME;                                                                             \
status = napi_unwrap(env, argv[arg_idx], reinterpret_cast<void**>(&NAME));                    \
if (status != napi_ok) {                                                                      \
  std::string err_msg = "FN_ARG_CLASS_VAL !napi_get_buffer_info. Bad " TOSTRING(CLASS_NAME) " arg " TOSTRING(NAME) " FN_NAME="; \
  err_msg += __func__;                                                                        \
  napi_throw_error(env, nullptr, err_msg.c_str());                                            \
  return ret_dummy;                                                                           \
}                                                                                             \
if (NAME->_class_tag != PPCAT_NX(CLASS_NAME,_tag)) {                                          \
  std::string err_msg = "FN_ARG_CLASS_VAL Wrong class tag for arg " TOSTRING(NAME) ". expected " TOSTRING(CLASS_NAME) " FN_NAME="; \
  err_msg += __func__;                                                                        \
  napi_throw_error(env, nullptr, err_msg.c_str());                                            \
  return ret_dummy;                                                                           \
}                                                                                             \
if (NAME->_deleted) {                                                                         \
  std::string err_msg = "FN_ARG_CLASS_VAL You are calling already freed object " TOSTRING(NAME) " of class " TOSTRING(CLASS_NAME) " FN_NAME="; \
  err_msg += __func__;                                                                        \
  napi_throw_error(env, nullptr, err_msg.c_str());                                            \
  return ret_dummy;                                                                           \
}                                                                                             \
napi_value PPCAT_NX(NAME,_val) = argv[arg_idx];                                               \
arg_idx++;

////////////////////////////////////////////////////////////////////////////////////////////////////
//    ret
////////////////////////////////////////////////////////////////////////////////////////////////////
#define FN_RET return enif_make_atom(envPtr, "ok");

#define FN_THROW(ARG)             \
return error(envPtr, ARG);

#define FN_RET_BOOL_CREATE(NAME)                                                        \
ERL_NIF_TERM PPCAT_NX(_ret_,NAME);                                                      \
PPCAT_NX(_ret_,NAME) = enif_make_atom(envPtr, NAME ? "true" : "false");

#define FN_RET_I32_CREATE(NAME)                                                         \
ERL_NIF_TERM PPCAT_NX(_ret_,NAME);                                                      \
PPCAT_NX(_ret_,NAME) = enif_make_int(envPtr, NAME);

// TODO LATER
#define FN_RET_I64_CREATE(NAME)                                                         \
napi_value PPCAT_NX(_ret_,NAME);                                                        \
status = napi_create_bigint_int64(env, NAME, &PPCAT_NX(_ret_,NAME));                    \
if (status != napi_ok) {                                                                \
  std::string err_msg = "FN_RET_I64_CREATE !napi_create_bigint_int64 " TOSTRING(NAME) " FN_NAME="; \
  err_msg += __func__;                                                                  \
  napi_throw_error(env, nullptr, err_msg.c_str());                                      \
  return ret_dummy;                                                                     \
}

#define FN_RET_U32_CREATE(NAME)                                                         \
ERL_NIF_TERM PPCAT_NX(_ret_,NAME);                                                      \
PPCAT_NX(_ret_,NAME) = enif_make_int(envPtr, NAME);

// TODO LATER
#define FN_RET_U64_CREATE(NAME)                                                         \
napi_value PPCAT_NX(_ret_,NAME);                                                        \
status = napi_create_bigint_uint64(env, NAME, &PPCAT_NX(_ret_,NAME));                   \
if (status != napi_ok) {                                                                \
  std::string err_msg = "FN_RET_U64_CREATE !napi_create_bigint_uint64 " TOSTRING(NAME) " FN_NAME="; \
  err_msg += __func__;                                                                  \
  napi_throw_error(env, nullptr, err_msg.c_str());                                      \
  return ret_dummy;                                                                     \
}

// TODO LATER
#define FN_RET_F32_CREATE(NAME)                                                         \
napi_value PPCAT_NX(_ret_,NAME);                                                        \
status = napi_create_double(env, NAME, &PPCAT_NX(_ret_,NAME));                          \
if (status != napi_ok) {                                                                \
  std::string err_msg = "FN_RET_F32_CREATE !napi_create_double " TOSTRING(NAME) " FN_NAME="; \
  err_msg += __func__;                                                                  \
  napi_throw_error(env, nullptr, err_msg.c_str());                                      \
  return ret_dummy;                                                                     \
}

// TODO LATER
#define FN_RET_F64_CREATE(NAME)                                                         \
napi_value PPCAT_NX(_ret_,NAME);                                                        \
status = napi_create_double(env, NAME, &PPCAT_NX(_ret_,NAME));                          \
if (status != napi_ok) {                                                                \
  std::string err_msg = "FN_RET_F64_CREATE !napi_create_double " TOSTRING(NAME) " FN_NAME="; \
  err_msg += __func__;                                                                  \
  napi_throw_error(env, nullptr, err_msg.c_str());                                      \
  return ret_dummy;                                                                     \
}

// TODO LATER
#define FN_RET_STR_CREATE(NAME)                                                         \
napi_value PPCAT_NX(_ret_,NAME);                                                        \
status = napi_create_string_utf8(env, NAME, PPCAT_NX(NAME,_len), &PPCAT_NX(_ret_,NAME));\
if (status != napi_ok) {                                                                \
  std::string err_msg = "FN_RET_STR_CREATE !napi_create_string_utf8 " TOSTRING(NAME) " FN_NAME="; \
  err_msg += __func__;                                                                  \
  napi_throw_error(env, nullptr, err_msg.c_str());                                      \
  return ret_dummy;                                                                     \
}

// TODO LATER
#define FN_RET_STR_FREE_CREATE(NAME)                                                    \
napi_value PPCAT_NX(_ret_,NAME);                                                        \
status = napi_create_string_utf8(env, NAME, PPCAT_NX(NAME,_len), &PPCAT_NX(_ret_,NAME));\
free(NAME);                                                                             \
                                                                                        \
if (status != napi_ok) {                                                                \
  std::string err_msg = "FN_RET_STR_FREE_CREATE !napi_create_string_utf8 " TOSTRING(NAME) " FN_NAME="; \
  err_msg += __func__;                                                                  \
  napi_throw_error(env, nullptr, err_msg.c_str());                                      \
  return ret_dummy;                                                                     \
}

// TODO LATER
#define FN_RET_STR_SIMPLE_CRAFT_CREATE(NAME)                                            \
napi_value PPCAT_NX(_ret_,NAME);                                                        \
status = napi_create_string_utf8(env, NAME->c_str(), NAME->size(), &PPCAT_NX(_ret_,NAME)); \
delete NAME;                                                                            \
if (status != napi_ok) {                                                                \
  std::string err_msg = "FN_RET_STR_SIMPLE_CRAFT_CREATE !napi_create_string_utf8 " TOSTRING(NAME) " FN_NAME="; \
  err_msg += __func__;                                                                  \
  napi_throw_error(env, nullptr, err_msg.c_str());                                      \
  return ret_dummy;                                                                     \
}

// highly NOT recommended
// NOTE. enif_make_resource_binary requires custom resource type
// TODO make that later, it will make -1 memcpy
// BUT. Any way pipeline will allocate and memcpy but in other places, except you will make own buffer for freed resources
#define FN_RET_BUF_CREATE(NAME)                                                         \
ERL_NIF_TERM PPCAT_NX(_ret_,NAME);                                                      \
{                                                                                       \
  u8* buf = enif_make_new_binary(envPtr, PPCAT_NX(NAME,_len), &PPCAT_NX(_ret_,NAME));   \
  memcpy(buf, NAME, PPCAT_NX(NAME,_len));                                               \
}


// TODO LATER
#define FN_DECL_RET_BUF_VAL(NAME)                                                       \
napi_value PPCAT_NX(_ret_,NAME);                                                        \

// TODO LATER
#define FN_RET_BUF_FREE_CREATE(NAME)                                                    \
napi_value PPCAT_NX(_ret_,NAME);                                                        \
{                                                                                       \
  void* _ret_tmp;                                                                       \
  status = napi_create_buffer_copy(env, PPCAT_NX(NAME,_len), NAME, &_ret_tmp, &PPCAT_NX(_ret_,NAME)); \
}                                                                                       \
free(NAME);                                                                             \
                                                                                        \
if (status != napi_ok) {                                                                \
  std::string err_msg = "FN_RET_BUF_FREE_CREATE !napi_create_buffer_copy " TOSTRING(NAME) " FN_NAME="; \
  err_msg += __func__;                                                                  \
  napi_throw_error(env, nullptr, err_msg.c_str());                                      \
  return ret_dummy;                                                                     \
}

#define FN_RET_REF_CREATE(NAME)                                                         \
ERL_NIF_TERM PPCAT_NX(_ret_,NAME);                                                      \
if (!NAME) {                                                                            \
  PPCAT_NX(_ret_,NAME) = enif_make_atom(envPtr, "undefined");                           \
} else {                                                                                \
  PPCAT_NX(_ret_,NAME) = NAME->_wrapper;                                                \
}

#define FN_RET_BOOL(NAME)   \
FN_RET_BOOL_CREATE(NAME)    \
return ok_tuple(envPtr, PPCAT_NX(_ret_,NAME));

#define FN_RET_I32(NAME)   \
FN_RET_I32_CREATE(NAME)    \
return ok_tuple(envPtr, PPCAT_NX(_ret_,NAME));

#define FN_RET_I64(NAME)   \
FN_RET_I64_CREATE(NAME)    \
return ok_tuple(envPtr, PPCAT_NX(_ret_,NAME));

#define FN_RET_U32(NAME)   \
FN_RET_U32_CREATE(NAME)    \
return ok_tuple(envPtr, PPCAT_NX(_ret_,NAME));

#define FN_RET_U64(NAME)   \
FN_RET_U64_CREATE(NAME)    \
return ok_tuple(envPtr, PPCAT_NX(_ret_,NAME));

#define FN_RET_F32(NAME)   \
FN_RET_F32_CREATE(NAME)    \
return ok_tuple(envPtr, PPCAT_NX(_ret_,NAME));

#define FN_RET_F64(NAME)   \
FN_RET_F64_CREATE(NAME)    \
return ok_tuple(envPtr, PPCAT_NX(_ret_,NAME));

#define FN_RET_STR(NAME)   \
FN_RET_STR_CREATE(NAME)    \
return ok_tuple(envPtr, PPCAT_NX(_ret_,NAME));

#define FN_RET_STR_FREE(NAME)   \
FN_RET_STR_FREE_CREATE(NAME)    \
return ok_tuple(envPtr, PPCAT_NX(_ret_,NAME));

#define FN_RET_STR_SIMPLE_CRAFT(NAME)   \
FN_RET_STR_SIMPLE_CRAFT_CREATE(NAME)    \
return ok_tuple(envPtr, PPCAT_NX(_ret_,NAME));

#define FN_RET_BUF(NAME)   \
FN_RET_BUF_CREATE(NAME)    \
return ok_tuple(envPtr, PPCAT_NX(_ret_,NAME));

#define FN_RET_BUF_FREE(NAME)   \
FN_RET_BUF_FREE_CREATE(NAME)    \
return ok_tuple(envPtr, PPCAT_NX(_ret_,NAME));

#define FN_RET_REF(NAME)   \
FN_RET_REF_CREATE(NAME)    \
return ok_tuple(envPtr, PPCAT_NX(_ret_,NAME));

////////////////////////////////////////////////////////////////////////////////////////////////////
//    
//    Class
//    
////////////////////////////////////////////////////////////////////////////////////////////////////
#define FN_ARG_THIS(CLASS_NAME)                                             \
FN_ARG_CLASS(CLASS_NAME, _this)

#define CLASS_DEF(NAME)                                                     \
PPCAT_NX3(CLASS_DECL_,NAME,_c_wrapper) = enif_open_resource_type(envPtr, NULL, TOSTRING(NAME), PPCAT_NX(NAME,_destructor), ERL_NIF_RT_CREATE, NULL); \
if (PPCAT_NX3(CLASS_DECL_,NAME,_c_wrapper) == NULL) {                       \
  return false;                                                             \
}

// TODO LATER
#define CLASS_METHOD_SYNC(CLASS_NAME, METHOD_NAME)                          \
PPCAT_NX(CLASS_NAME,_prop_list).push_back({ TOSTRING(METHOD_NAME) "_sync", nullptr, PPCAT_NX4(CLASS_NAME, _, METHOD_NAME, _sync), nullptr, nullptr, nullptr, napi_enumerable, nullptr });

// DROP
#define CLASS_METHOD_ASYNC(CLASS_NAME, METHOD_NAME)                         \
PPCAT_NX(CLASS_NAME,_prop_list).push_back({ TOSTRING(METHOD_NAME)        , nullptr, PPCAT_NX3(CLASS_NAME, _, METHOD_NAME       ), nullptr, nullptr, nullptr, napi_enumerable, nullptr });

// TODO LATER
#define CLASS_METHOD(CLASS_NAME, METHOD_NAME)                               \
CLASS_METHOD_SYNC(CLASS_NAME, METHOD_NAME)                                  \
CLASS_METHOD_ASYNC(CLASS_NAME, METHOD_NAME)

// TODO LATER rework or DROP
#define CLASS_EXPORT(NAME)                                                  \
napi_value NAME;                                                            \
status = napi_define_class(env, TOSTRING(NAME), NAPI_AUTO_LENGTH, PPCAT_NX(NAME,_constructor), nullptr, PPCAT_NX(NAME,_prop_list).size(), PPCAT_NX(NAME,_prop_list).data(), &NAME); \
if (status != napi_ok) {                                                    \
  std::string err_msg = "CLASS_EXPORT !napi_define_class " TOSTRING(NAME) " FN_NAME="; \
  err_msg += __func__;                                                      \
  napi_throw_error(env, nullptr, err_msg.c_str());                          \
  return nullptr;                                                           \
}                                                                           \
                                                                            \
status = napi_set_named_property(env, exports, TOSTRING(NAME), NAME);       \
if (status != napi_ok) {                                                    \
  std::string err_msg = "CLASS_EXPORT !napi_set_named_property " TOSTRING(NAME) " FN_NAME="; \
  err_msg += __func__;                                                      \
  napi_throw_error(env, nullptr, err_msg.c_str());                          \
  return nullptr;                                                           \
}
