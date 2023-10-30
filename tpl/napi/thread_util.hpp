#pragma once
// TODO remove thread
#include <thread>
#include <signal.h>
#include <string>

#if defined(_MSC_VER)
  #include <windows.h>
  #include <thread>
  
  #define THREAD_TYPE std::thread
  #define THREAD_CREATE(RES, ERR, FN, ARG) \
    RES = std::thread(FN, (void*)ARG);
  #define THREAD_JOIN(RES) \
    RES.join();
  
  // there is no equivalent
  #define THREAD_TERM(THREAD) \
    ::TerminateThread(THREAD.native_handle(), 1)
  
  #define THREAD_KILL(THREAD) \
    ::TerminateThread(THREAD.native_handle(), 1)
#else
  #include <pthread.h>
  
  #define THREAD_TYPE pthread_t
  #define THREAD_CREATE(RES, ERR, FN, ARG) \
    i32 err_code = pthread_create(&RES, 0, FN, (void*)ARG); \
    if (err_code) { \
      ERR = new std::string("!pthread_create code="); \
      *ERR += std::to_string(err_code); \
      return; \
    }
  #define THREAD_JOIN(RES) \
    pthread_join(RES, NULL);
  
  #define THREAD_TERM(THREAD) \
    pthread_kill(_this->thread, SIGTERM)
  
  #define THREAD_KILL(THREAD) \
    pthread_kill(_this->thread, SIGKILL)
  
#endif

bool thread_affinity_single_core_set(std::string& err, THREAD_TYPE& thread, int core_id);
