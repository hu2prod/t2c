#pragma once
#include <thread>
#include <signal.h>


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
  
  bool thread_affinity_single_core_set(std::string& err, THREAD_TYPE& thread, int core_id) {
    SetThreadAffinityMask(thread.native_handle(), 1ULL << core_id);
    Sleep(1);
    return true;
  }
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
  
  bool thread_affinity_single_core_set(std::string& err, THREAD_TYPE& thread, int core_id) {
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(core_id, &cpuset);
    int ret_code = pthread_setaffinity_np(thread, sizeof(cpu_set_t), &cpuset);
    if (ret_code != 0) {
      std::string err = "!pthread_setaffinity_np ret_code=";
      err += std::to_string(ret_code);
      
      return false;
    }
    return true;
  }
#endif