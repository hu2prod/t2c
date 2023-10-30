#pragma once
#include<atomic>
#include<vector>
#include "type.hpp"

// about atomic_thread_fence
// https://stackoverflow.com/questions/13632344/understanding-c11-memory-fences
// https://preshing.com/20130922/acquire-and-release-fences/
// https://www.youtube.com/watch?v=ZQFzMfHIxng
// https://doc.rust-lang.org/std/sync/atomic/fn.fence.html
// https://www.codeproject.com/Articles/43510/Lock-Free-Single-Producer-Single-Consumer-Circular
//   https://github.com/KjellKod/lock-free-wait-free-circularfifo/blob/master/src/circularfifo_memory_relaxed_aquire_release_padded.hpp
// tl;dr Edge case. What if task in recv was already in L1 cache? volatile doesn't help, you will still read outdated from cache
//   updating counter in cache can be faster than updating task in cache. There is no guarantee at all that operations will transfer in correct order
// Pls note. x86 barriers will produce NO extra code on x86. Those operations are only preventing from compilator operation reorder
// https://stackoverflow.com/questions/29922747/does-the-mov-x86-instruction-implement-a-c11-memory-order-release-atomic-store

template<typename TASK>
class Message_ring {
  public:
  // https://stackoverflow.com/questions/25332258/c-volatile-arrays-in-c
  // _ring doesn't change
  // _ring[idx] changes (as pointer)
  // _ring[idx] contents by pointer changes
  TASK *volatile*volatile _ring;
  size_t _size;
  
  // perf stuff. I need no true low-latency in send->recv direction (recv->send _recv_offset is neither needed)
  // So I didn't make memory_order_relaxed after update counter, so recv will have lag or can have lag
  // That's cost for not call mem fence on recv on each _send_offset access (so more throughput on recv)
  // e.g. recv can do some other stuff until _send_offset will be updated
  
  // BUT if send will go sleep, it will flush all remaining counters with atomic_thread_fence(std::memory_order_release);
  // recv after wake up will do once atomic_thread_fence(std::memory_order_acquire);
  // So lag between send and recv can be no longer than 1 sleep or 1 task processing
  //  any other task processing will cause 1 message_ring pull (memory_order_acquire) and message_ring push(memory_order_release)
  //  so counters will be updated
  //  sleep only triggered on edges (very start and very end)
  volatile size_t _send_offset = 0;
  volatile size_t _recv_offset = 0;
  
  std::vector<TASK*> _overflow_list;
  size_t _overflow_idx = 0;
  i32 ref_count = 0;
  
  Message_ring(size_t size);
  ~Message_ring();
  void task_clear();
  
  // send side
  size_t  _get_free_push_size();
  size_t  get_free_nonbackpressure_push_size();
  size_t  push_and_get_free_nonbackpressure_push_size();
  bool    push(TASK* task);
  void    _push(TASK* task);
  
  
  // recv side
  size_t  get_available_pull_size();
  bool    can_pull();
  TASK*   pull();
  TASK*   dry_pull();
};

template<typename TASK>
class Message_ring_fan_in {
  public:
  Message_ring<TASK>** _list;
  size_t _size;
  
  Message_ring_fan_in(Message_ring<TASK>** list, size_t size);
  ~Message_ring_fan_in();
  
  // recv side
  size_t  get_available_pull_size();
  bool    can_pull();
  TASK*   pull();
  TASK*   dry_pull();
};

////////////////////////////////////////////////////////////////////////////////////////////////////
//    
//    template implementation
//    
////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////
//    Message_ring
////////////////////////////////////////////////////////////////////////////////////////////////////
template<typename TASK>
Message_ring<TASK>::Message_ring(size_t size) {
  _size = size;
  _ring = new TASK*[size];
}

template<typename TASK>
Message_ring<TASK>::~Message_ring() {
  delete[] _ring;
}

template<typename TASK>
void Message_ring<TASK>::task_clear() {
  for(u32 idx = _overflow_idx, len = _overflow_list.size();idx < len;idx++) {
    auto& task = _overflow_list[idx];
    if (task) {
      delete task;
    }
  }
}

template<typename TASK>
size_t Message_ring<TASK>::_get_free_push_size() {
  return _size - 1 - get_available_pull_size();
}

template<typename TASK>
size_t Message_ring<TASK>::get_free_nonbackpressure_push_size() {
  if (_overflow_list.size()) return 0;
  
  return _get_free_push_size();
}

// NOTE _overflow_list will shrink after queue will disappear, no memory movement in progress
//   backpressure should fix that
template<typename TASK>
size_t Message_ring<TASK>::push_and_get_free_nonbackpressure_push_size() {
  size_t free_push_count = _get_free_push_size();
  if (!free_push_count) return 0;
  size_t ol_size = _overflow_list.size();
  if (!ol_size) return free_push_count;
  
  while(free_push_count) {
    free_push_count--;
    _push(_overflow_list[_overflow_idx++]);
    
    if (_overflow_idx == ol_size) {
      _overflow_idx = 0;
      _overflow_list.resize(0);
      _overflow_list.shrink_to_fit();
      break;
    }
  }
  
  return free_push_count;
}

template<typename TASK>
bool Message_ring<TASK>::push(TASK* task) {
  if (push_and_get_free_nonbackpressure_push_size() > 0) {
    _push(task);
    return true;
  }
  _overflow_list.push_back(task);
  return false;
}

template<typename TASK>
void Message_ring<TASK>::_push(TASK* task) {
  _ring[_send_offset] = task;
  atomic_thread_fence(std::memory_order_release);
  _send_offset = (_send_offset+1) % _size;
}

template<typename TASK>
size_t Message_ring<TASK>::get_available_pull_size() {
  if (_send_offset >= _recv_offset) {
    return _send_offset - _recv_offset;
  }
  return _size + _send_offset - _recv_offset;
}

template<typename TASK>
bool Message_ring<TASK>::can_pull() {
  return (_send_offset != _recv_offset);
}

template<typename TASK>
TASK* Message_ring<TASK>::pull() {
  if (can_pull()) {
    atomic_thread_fence(std::memory_order_acquire);
    TASK* ret = (TASK*)_ring[_recv_offset];
    _recv_offset = (_recv_offset+1) % _size;
    return ret;
  }
  return nullptr;
}

template<typename TASK>
TASK* Message_ring<TASK>::dry_pull() {
  if (can_pull()) {
    atomic_thread_fence(std::memory_order_acquire);
    return (TASK*)_ring[_recv_offset];
  }
  return nullptr;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
//    Message_ring_fan_in
////////////////////////////////////////////////////////////////////////////////////////////////////
template<typename TASK>
Message_ring_fan_in<TASK>::Message_ring_fan_in(Message_ring<TASK>** list, size_t size) {
  _list = list;
  _size = size;
}

template<typename TASK>
Message_ring_fan_in<TASK>::~Message_ring_fan_in() {
  delete[] _list;
}

template<typename TASK>
size_t Message_ring_fan_in<TASK>::get_available_pull_size() {
  size_t ret = 0;
  for(size_t i=0;i < _size;i++) {
    ret += _list[i]->get_available_pull_size();
  }
  return ret;
}

template<typename TASK>
bool Message_ring_fan_in<TASK>::can_pull() {
  for(size_t i=0;i < _size;i++) {
    if (_list[i]->can_pull()) return true;
  }
  return false;
}

template<typename TASK>
TASK* Message_ring_fan_in<TASK>::pull() {
  for(size_t i = 0;i < _size;i++) {
    TASK* ret = _list[i]->pull();
    if (ret) {
      return ret;
    }
  }
  return nullptr;
}

template<typename TASK>
TASK* Message_ring_fan_in<TASK>::dry_pull() {
  for(size_t i = 0;i < _size;i++) {
    TASK* ret = _list[i]->dry_pull();
    if (ret) {
      return ret;
    }
  }
  return nullptr;
}
