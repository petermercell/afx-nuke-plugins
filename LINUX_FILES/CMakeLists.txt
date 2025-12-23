# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2017, Ryan P. Wilson
# Single-file static build - libcore compiled into afx_median.so
#
# Authority FX, Inc.
# www.authorityfx.com

cmake_minimum_required(VERSION 3.12)

# Set policies for better CUDA handling
if(POLICY CMP0146)
  cmake_policy(SET CMP0146 OLD)  # Keep using FindCUDA
endif()

project(afx-nuke-plugins)

# ============================================================================
# RPATH Configuration - Make plugins portable
# ============================================================================
# Don't set RPATH - rely on Nuke's LD_LIBRARY_PATH environment
# This makes plugins work regardless of where Nuke is installed
set(CMAKE_SKIP_BUILD_RPATH TRUE)
set(CMAKE_SKIP_INSTALL_RPATH TRUE)

# Compiler requirements
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "4.8.1")
    message(FATAL_ERROR "GCC version must be at least 4.8.1")
  else()
    message(STATUS "Using GCC version ${CMAKE_CXX_COMPILER_VERSION}")
  endif()
else()
  message(WARNING "Untested compiler: ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
endif()

# Set default build type if not specified
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
  set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG -Wall")
endif()

# Enable C++17 standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Append project Modules directory
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake/Modules/")

# Include project directories
include_directories(${CMAKE_SOURCE_DIR})

# Set Nuke version and directory
if(NOT DEFINED NUKE_VERSION)
  set(NUKE_VERSION "16.0v6")
endif()
set(NDKDIR /opt/Nuke${NUKE_VERSION})
message(STATUS "Using Nuke version: ${NUKE_VERSION}")
message(STATUS "Nuke directory: ${NDKDIR}")

# Verify Nuke directory exists
if(NOT EXISTS ${NDKDIR})
  message(FATAL_ERROR "Nuke directory not found: ${NDKDIR}")
endif()
if(NOT EXISTS ${NDKDIR}/libDDImage.so)
  message(FATAL_ERROR "libDDImage.so not found in: ${NDKDIR}")
endif()

# Add the Nuke include directory
include_directories(${NDKDIR}/include)

# Position Independent Code for shared libraries
add_compile_options(-fPIC)

# Find required packages
find_package(Nuke REQUIRED)
find_package(Ipp REQUIRED COMPONENTS ippcore ippi)
find_package(CUDA REQUIRED)

# Handle IPP - Force static linking ONLY
if(NOT Ipp_FOUND)
  message(FATAL_ERROR "IPP library not found. Please specify Ipp_INCLUDE_DIR, Ipp_LIBRARIES, and Ipp_LIBRARY_DIR.")
endif()

# Filter IPP libraries to ONLY use .a files (remove any .so files)
set(IPP_STATIC_LIBS "")
foreach(_lib ${Ipp_LIBRARIES})
  if(_lib MATCHES "\\.a$")
    list(APPEND IPP_STATIC_LIBS ${_lib})
  endif()
endforeach()

if(NOT IPP_STATIC_LIBS)
  message(FATAL_ERROR "No static IPP libraries (.a) found in ${Ipp_LIBRARIES}")
endif()

set(Ipp_LIBRARIES ${IPP_STATIC_LIBS})
message(STATUS "IPP static libraries: ${Ipp_LIBRARIES}")

# Find Boost - STATIC LINKING
set(Boost_USE_STATIC_LIBS ON)        # Link statically
set(Boost_USE_MULTITHREADED ON)
set(Boost_USE_STATIC_RUNTIME OFF)    # Don't link static runtime (causes issues)

find_package(Boost COMPONENTS system thread)

if(NOT Boost_FOUND)
  find_package(Boost REQUIRED)
  message(STATUS "Found Boost ${Boost_VERSION}, but specific components may not be available")
endif()

if(Boost_FOUND)
  include_directories(${Boost_INCLUDE_DIRS})
  message(STATUS "Boost version: ${Boost_VERSION}")
  message(STATUS "Boost include dirs: ${Boost_INCLUDE_DIRS}")
  
  # For static linking, find .a files
  if(NOT Boost_THREAD_FOUND)
    message(WARNING "Boost thread component not found via find_package. Will attempt manual linking.")
    find_library(Boost_THREAD_LIBRARY NAMES libboost_thread.a boost_thread PATHS ${Boost_LIBRARY_DIRS})
    find_library(Boost_SYSTEM_LIBRARY NAMES libboost_system.a boost_system PATHS ${Boost_LIBRARY_DIRS})
    find_library(Boost_CHRONO_LIBRARY NAMES libboost_chrono.a boost_chrono PATHS ${Boost_LIBRARY_DIRS})
    find_library(Boost_ATOMIC_LIBRARY NAMES libboost_atomic.a boost_atomic PATHS ${Boost_LIBRARY_DIRS})
    
    if(Boost_THREAD_LIBRARY AND Boost_SYSTEM_LIBRARY)
      set(Boost_LIBRARIES ${Boost_SYSTEM_LIBRARY} ${Boost_THREAD_LIBRARY})
      if(Boost_CHRONO_LIBRARY)
        list(APPEND Boost_LIBRARIES ${Boost_CHRONO_LIBRARY})
      endif()
      if(Boost_ATOMIC_LIBRARY)
        list(APPEND Boost_LIBRARIES ${Boost_ATOMIC_LIBRARY})
      endif()
      message(STATUS "Manually found static Boost libraries: ${Boost_LIBRARIES}")
    endif()
  endif()
  message(STATUS "Boost libraries for linking: ${Boost_LIBRARIES}")
endif()

# Handle CUDA - Use STATIC runtime
set(CUDA_PROPAGATE_HOST_FLAGS OFF)

# Support multiple GPU architectures for broader compatibility
# sm_52 = Maxwell (GTX 9xx, Quadro M series) - 2014
# sm_61 = Pascal (GTX 10xx, Titan X, Quadro P series) - 2016
# sm_70 = Volta (Titan V, V100) - 2017
# sm_75 = Turing (RTX 20xx, Quadro RTX, GTX 16xx) - 2018
# sm_80 = Ampere (A100) - 2020
# sm_86 = Ampere (RTX 30xx, RTX A series) - 2020
# sm_89 = Ada Lovelace (RTX 40xx, L series) - 2022
# sm_90 = Hopper (H100) - 2022

# Generate code for multiple architectures (increases compile time but works on more GPUs)
list(APPEND CUDA_NVCC_FLAGS 
  "-std=c++17"
  "-O3"
  "-gencode=arch=compute_52,code=sm_52"   # Maxwell
  "-gencode=arch=compute_61,code=sm_61"   # Pascal
  "-gencode=arch=compute_70,code=sm_70"   # Volta
  "-gencode=arch=compute_75,code=sm_75"   # Turing
  "-gencode=arch=compute_80,code=sm_80"   # Ampere (A100)
  "-gencode=arch=compute_86,code=sm_86"   # Ampere (RTX 30xx/A series)
  "-gencode=arch=compute_89,code=sm_89"   # Ada Lovelace
  "-gencode=arch=compute_90,code=sm_90"   # Hopper
  "-gencode=arch=compute_90,code=compute_90"  # PTX for future compatibility
)

# Find static CUDA runtime
set(CUDA_USE_STATIC_CUDA_RUNTIME ON)
find_library(CUDA_cudart_static_LIBRARY 
  NAMES libcudart_static.a cudart_static
  PATHS ${CUDA_TOOLKIT_ROOT_DIR}
  PATH_SUFFIXES lib lib64 lib/x64
)

if(CUDA_cudart_static_LIBRARY)
  message(STATUS "Found static CUDA runtime: ${CUDA_cudart_static_LIBRARY}")
  set(CUDA_LIBRARIES_STATIC ${CUDA_cudart_static_LIBRARY})
else()
  message(WARNING "Static CUDA runtime not found, using dynamic")
  set(CUDA_LIBRARIES_STATIC ${CUDA_LIBRARIES})
endif()

message(STATUS "CUDA NVCC Flags: ${CUDA_NVCC_FLAGS}")
message(STATUS "CUDA Toolkit: ${CUDA_TOOLKIT_ROOT_DIR}")
message(STATUS "CUDA Version: ${CUDA_VERSION}")

# ABI compatibility with Nuke
#set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D_GLIBCXX_USE_CXX11_ABI=0")

# ============================================================================
# IMPORTANT: Build libcore as STATIC library (not SHARED)
# This will be linked directly into afx_median.so
# ============================================================================
add_library(core STATIC src/threading.cpp)

# Add CUDA include directories to core
target_include_directories(core PUBLIC ${CUDA_INCLUDE_DIRS})

# Link dependencies to the core library - ALL STATIC
target_link_libraries(core
    PUBLIC
    ${Ipp_LIBRARIES}              # Already static .a files
    ${Boost_LIBRARIES}            # Static .a files
    ${CUDA_LIBRARIES_STATIC}      # Static cudart
    ${CMAKE_DL_LIBS}
    pthread
    rt
)

# Set target properties for STATIC library
set_target_properties(core PROPERTIES 
  ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib
  POSITION_INDEPENDENT_CODE ON  # Important for static lib that goes into .so
)

# Build afx_median using cuda_add_library
cuda_add_library(afx_median src/afx_median.cpp src/afx_median.cu SHARED)

set_target_properties(afx_median PROPERTIES 
  PREFIX ""
  OUTPUT_NAME "AFXMedian"  # Output will be AFXMedian.so
  LINK_FLAGS "-Wl,--exclude-libs,ALL"  # Hide symbols from static libs
)

# Link everything into afx_median - core is now STATIC so it gets compiled in
target_link_libraries(afx_median 
  core                           # STATIC library - gets compiled into afx_median.so
  ${CUDA_LIBRARIES_STATIC}
  ${NDKDIR}/libDDImage.so        # Must be dynamic (Nuke's library)
  OpenGL
  ${CMAKE_DL_LIBS}
  pthread
  rt
)

add_dependencies(afx_median core)
list(APPEND afx_PLUGINS afx_median)

# ============================================================================
# Build AFXSoftClip - Simple plugin, no core library needed
# ============================================================================
add_library(afx_soft_clip SHARED src/afx_soft_clip.cpp)
set_target_properties(afx_soft_clip PROPERTIES 
  PREFIX ""
  OUTPUT_NAME "AFXSoftClip"
  LINK_FLAGS "-Wl,--exclude-libs,ALL"
)
target_link_libraries(afx_soft_clip 
  ${Ipp_LIBRARIES}              # Static IPP
  ${NDKDIR}/libDDImage.so
  OpenGL
  pthread
  rt
)
list(APPEND afx_PLUGINS afx_soft_clip)

# ============================================================================
# Build AFXToneMap - Simple plugin, no core library needed
# ============================================================================
add_library(afx_tone_map SHARED src/afx_tone_map.cpp)
set_target_properties(afx_tone_map PROPERTIES 
  PREFIX ""
  OUTPUT_NAME "AFXToneMap"
  LINK_FLAGS "-Wl,--exclude-libs,ALL"
)
target_link_libraries(afx_tone_map 
  ${Ipp_LIBRARIES}              # Static IPP
  ${NDKDIR}/libDDImage.so
  OpenGL
  pthread
  rt
)
list(APPEND afx_PLUGINS afx_tone_map)

# ============================================================================
# Build AFXDeSpill - Needs core library for color operations
# ============================================================================
add_library(afx_despill SHARED src/afx_despill.cpp)
set_target_properties(afx_despill PROPERTIES 
  PREFIX ""
  OUTPUT_NAME "AFXDeSpill"
  LINK_FLAGS "-Wl,--exclude-libs,ALL"
)
target_link_libraries(afx_despill 
  core                          # Static core library
  ${NDKDIR}/libDDImage.so
  OpenGL
  ${CMAKE_DL_LIBS}
  pthread
  rt
)
add_dependencies(afx_despill core)
list(APPEND afx_PLUGINS afx_despill)

# ============================================================================
# Install - Only the .so files, nothing else
# ============================================================================
install(
  TARGETS ${afx_PLUGINS}
  LIBRARY DESTINATION .
)

# Print summary
message(STATUS "")
message(STATUS "===========================================================================")
message(STATUS "Configuration Summary:")
message(STATUS "  Build Type:        ${CMAKE_BUILD_TYPE}")
message(STATUS "  C++ Compiler:      ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
message(STATUS "  CUDA Toolkit:      ${CUDA_VERSION}")
message(STATUS "  CUDA NVCC Flags:   ${CUDA_NVCC_FLAGS}")
message(STATUS "  Nuke Version:      ${NUKE_VERSION}")
message(STATUS "  Nuke Directory:    ${NDKDIR}")
message(STATUS "  Nuke libDDImage:   ${NDKDIR}/libDDImage.so")
message(STATUS "  RPATH:             Not set (portable - uses Nuke's environment)")
message(STATUS "  ")
message(STATUS "Static Linking (compiled into plugins):")
message(STATUS "  libcore:           STATIC (compiled into AFXMedian and AFXDeSpill)")
message(STATUS "  Boost:             ${Boost_LIBRARIES}")
message(STATUS "  IPP:               ${Ipp_LIBRARIES}")
message(STATUS "  CUDA:              ${CUDA_LIBRARIES_STATIC}")
message(STATUS "  ")
message(STATUS "Dynamic Linking:")
message(STATUS "  Nuke DDImage:      ${NDKDIR}/libDDImage.so (required)")
message(STATUS "  System libs:       pthread, rt, dl, libstdc++, libc (required)")
message(STATUS "  ")
message(STATUS "Plugins Built:")
message(STATUS "  AFXMedian.so       GPU-accelerated smart median filter")
message(STATUS "  AFXSoftClip.so     Soft clipping with adjustable knee")
message(STATUS "  AFXToneMap.so      Tone mapping with exposure and darks control")
message(STATUS "  AFXDeSpill.so      Smart green/blue screen spill removal")
message(STATUS "  ")
message(STATUS "Installation:")
message(STATUS "  Install prefix:    ${CMAKE_INSTALL_PREFIX}")
message(STATUS "  Output:            Four standalone .so files (no menu.py, no icons)")
message(STATUS "  ")
message(STATUS "Usage in Nuke:")
message(STATUS "  Load individually:")
message(STATUS "    nuke.load('AFXMedian.so')")
message(STATUS "    nuke.createNode('AFXMedian')")
message(STATUS "  ")
message(STATUS "  Or use pluginAddPath:")
message(STATUS "    nuke.pluginAddPath('/path/to/plugins')")
message(STATUS "    # All plugins auto-load")
message(STATUS "===========================================================================")
message(STATUS "")
