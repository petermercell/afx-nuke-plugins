#ifndef AFX_THREADING_H_
#define AFX_THREADING_H_

#include <boost/asio.hpp>
#include <boost/thread.hpp>
#include <boost/function.hpp>
#include <boost/bind.hpp>
#include <vector>
#include "include/bounds.h"

#ifdef _WIN32
  #ifdef _MSC_VER
    #pragma warning(disable: 4251)
  #endif
  #define WINLIB_EXPORT __declspec(dllexport)
#else
  #define WINLIB_EXPORT
#endif

namespace afx {

class WINLIB_EXPORT Threader {
 private:
  boost::asio::io_context io_context_;  // Renamed from io_service_ to io_context_
  boost::asio::executor_work_guard<boost::asio::io_context::executor_type> work_guard_;
  std::vector<std::thread> thread_pool_;
  unsigned int num_threads_;

  std::mutex mutex_;
  std::condition_variable io_service_ready_;
  std::condition_variable exited_run_;  // Declared here
  bool running_;

  // This function is passed to each thread in the thread pool and blocks for work.
  void Worker_();

 public:
  Threader();
  explicit Threader(unsigned int req_num_threads);
  ~Threader();

  void AddThreads(unsigned int num_threads);
  void InitializeThreads(unsigned int requested_threads = 0);
  void Wait();
  void StopAndJoin();
  void AddWork(boost::function<void()> function);
  bool IsRunning() const;
  unsigned int Threads() const;
};

class WINLIB_EXPORT ImageThreader : public Threader {
 public:
  // Split bounds into rows.
  void ThreadRows(const Bounds& region, boost::function<void(Bounds)> function);

  // Split bounds into columns.
  void ThreadColumns(const Bounds& region, boost::function<void(Bounds)> function);

  // Split bounds into num_threads chunks in the y-axis.
  void ThreadRowChunks(const Bounds& region, boost::function<void(Bounds)> function);

  // Split bounds into num_threads chunks in the x-axis.
  void ThreadColumnChunks(const Bounds& region, boost::function<void(Bounds)> function);
};

}  // namespace afx

#endif  // AFX_THREADING_H_

