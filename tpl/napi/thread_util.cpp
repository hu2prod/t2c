#include "thread_util.hpp"

#if defined(_MSC_VER)
  bool thread_affinity_single_core_set(std::string& err, THREAD_TYPE& thread, int core_id) {
    SetThreadAffinityMask(thread.native_handle(), 1ULL << core_id);
    Sleep(1);
    return true;
  }
#else
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
