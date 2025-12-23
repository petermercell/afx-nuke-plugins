#include "include/threading.h"

#include <boost/asio.hpp>
#include <boost/thread.hpp>
#include <boost/thread/locks.hpp>
#include <boost/function.hpp>
#include <boost/bind/bind.hpp>
using namespace boost::placeholders;

#include <algorithm>
#include <cmath>
#include <memory>
#include <vector>

namespace afx {

Threader::Threader()
    : work_guard_(boost::asio::make_work_guard(io_context_)),
      running_(false) {
  InitializeThreads(0);  // Default to system concurrency
}

Threader::Threader(unsigned int req_num_threads)
    : work_guard_(boost::asio::make_work_guard(io_context_)),
      running_(false) {
  InitializeThreads(req_num_threads);
}

Threader::~Threader() {
  StopAndJoin();
}

void Threader::InitializeThreads(unsigned int req_num_threads) {
  if (running_) {
    StopAndJoin();
  }

  if (io_context_.stopped()) {
    io_context_.restart();
  }

  running_ = true;
  unsigned int avail_threads = std::thread::hardware_concurrency();
  num_threads_ = req_num_threads > 0 ? std::min(req_num_threads, avail_threads) : avail_threads;

  for (unsigned int t = 0; t < num_threads_; ++t) {
    thread_pool_.emplace_back(&Threader::Worker_, this);
  }
}

void Threader::Worker_() {
  while (running_) {
    io_context_.run();
    {
      std::unique_lock<std::mutex> lock(mutex_);
      exited_run_.notify_one();  // Notify threads are exiting
      while (running_ && io_context_.stopped()) {
        io_service_ready_.wait(lock);
      }
    }
  }
}

void Threader::Wait() {
  // Use boost::asio::executor_work_guard instead of deprecated work object
  boost::asio::executor_work_guard<boost::asio::io_context::executor_type> work_guard(io_context_.get_executor());

  std::unique_lock<std::mutex> lock(mutex_);
  while (!io_context_.stopped()) {
    exited_run_.wait(lock);  // Wait for all threads to exit `run()`
  }

  if (running_) {
    io_context_.restart();  // Restart the io_context for further use
  }

  io_service_ready_.notify_all();  // Notify threads to proceed
}

void Threader::StopAndJoin() {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    running_ = false;
  }

  Wait();
  for (auto& thread : thread_pool_) {
    if (thread.joinable()) {
      thread.join();
    }
  }
  thread_pool_.clear();
}

void Threader::AddWork(boost::function<void()> function) {
  boost::asio::post(io_context_, function);
}

bool Threader::IsRunning() const {
  return running_;
}

unsigned int Threader::Threads() const {
  return num_threads_;
}

void Threader::AddThreads(unsigned int num_threads) {
  for (unsigned int t = 0; t < num_threads; ++t) {
    thread_pool_.emplace_back(&Threader::Worker_, this);
  }
}

void ImageThreader::ThreadRows(const Bounds& region, boost::function<void(Bounds)> function) {
  Bounds thread_region = region;
  for (int row = region.y1(); row <= region.y2(); ++row) {
    thread_region.SetY(row, row);
    AddWork([function, thread_region]() { function(thread_region); });
  }
}

void ImageThreader::ThreadColumns(const Bounds& region, boost::function<void(Bounds)> function) {
  Bounds thread_region = region;
  for (int column = region.x1(); column <= region.x2(); ++column) {
    thread_region.SetX(column, column);
    AddWork([function, thread_region]() { function(thread_region); });
  }
}

void ImageThreader::ThreadRowChunks(const Bounds& region, boost::function<void(Bounds)> function) {
  unsigned int num_chunks = Threads();
  num_chunks = std::min(num_chunks, region.GetHeight());
  Bounds thread_region = region;

  for (unsigned int i = 0; i < num_chunks; ++i) {
    thread_region.SetY1(static_cast<int>(std::ceil(static_cast<float>(region.GetHeight()) * i / num_chunks) + region.y1()));
    thread_region.SetY2(static_cast<int>(std::ceil(static_cast<float>(region.GetHeight()) * (i + 1) / num_chunks) - 1 + region.y1()));
    AddWork([function, thread_region]() { function(thread_region); });
  }
}

void ImageThreader::ThreadColumnChunks(const Bounds& region, boost::function<void(Bounds)> function) {
  unsigned int num_chunks = Threads();
  num_chunks = std::min(num_chunks, region.GetWidth());
  Bounds thread_region = region;

  for (unsigned int i = 0; i < num_chunks; ++i) {
    thread_region.SetX1(static_cast<int>(std::ceil(static_cast<float>(region.GetWidth()) * i / num_chunks) + region.x1()));
    thread_region.SetX2(static_cast<int>(std::ceil(static_cast<float>(region.GetWidth()) * (i + 1) / num_chunks) - 1 + region.x1()));
    AddWork([function, thread_region]() { function(thread_region); });
  }
}

}  // namespace afx

