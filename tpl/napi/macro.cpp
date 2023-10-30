#pragma once
#include "macro.hpp"

////////////////////////////////////////////////////////////////////////////////////////////////////
//    helpers
////////////////////////////////////////////////////////////////////////////////////////////////////
void napi_helper_error_cb(napi_env env, const char* error_str, napi_value callback) {
  napi_status status;
  napi_value global;
  status = napi_get_global(env, &global);
  if (status != napi_ok) {
    std::string err_msg = "!napi_get_global. status = ";
    err_msg += std::to_string(status);
    err_msg += " FN_NAME=";
    err_msg += __func__;
    napi_throw_error(env, nullptr, err_msg.c_str());
    return;
  }
  
  napi_value call_argv[1];
  
  napi_value error;
  status = napi_create_string_utf8(env, error_str, strlen(error_str), &error);
  if (status != napi_ok) {
    std::string err_msg = "!napi_create_string_utf8. status = ";
    err_msg += std::to_string(status);
    err_msg += " FN_NAME=";
    err_msg += __func__;
    napi_throw_error(env, nullptr, err_msg.c_str());
    return;
  }
  
  status = napi_create_error(env, nullptr, error, &call_argv[0]);
  if (status != napi_ok) {
    std::string err_msg = "!napi_create_error. status = ";
    err_msg += std::to_string(status);
    err_msg += ". error = ";
    err_msg += error_str;
    err_msg += " FN_NAME=";
    err_msg += __func__;
    napi_throw_error(env, nullptr, err_msg.c_str());
    return;
  }
  
  napi_value result;
  status = napi_call_function(env, global, callback, 1, call_argv, &result);
  if (status != napi_ok) {
    // это нормальная ошибка если основной поток падает
    napi_throw_error(env, nullptr, "!napi_call_function");
    return;
  }
  return;
}
