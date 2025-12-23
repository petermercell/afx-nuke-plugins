# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2017, Ryan P. Wilson
# Windows build for Visual Studio 2022 with CUDA 12.9
#
# Authority FX, Inc.
# www.authorityfx.com

cmake_minimum_required(VERSION 3.25)

# CRITICAL: Set MSVC runtime library policy BEFORE project()
cmake_policy(SET CMP0091 NEW)

# Enable CUDA language support (modern approach)
project(afx-nuke-plugins LANGUAGES CXX CUDA)

# ============================================================================
# Windows-specific Configuration
# ============================================================================
if(NOT WIN32)
  message(FATAL_ERROR "This CMakeLists.txt is for Windows only")
endif()

# Compiler requirements - Visual Studio 2022
if(MSVC)
  if(MSVC_VERSION LESS 1930)
    message(FATAL_ERROR "Visual Studio 2022 or later required (MSVC 19.30+)")
  else()
    message(STATUS "Using MSVC version ${MSVC_VERSION}")
  endif()
else()
  message(FATAL_ERROR "This build requires MSVC (Visual Studio)")
endif()

# Set default build type if not specified
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

# ============================================================================
# CRITICAL: Force static runtime library globally
# ============================================================================
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

# Enable C++17 standard (required for Nuke 16.0v6 which uses std::optional)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD 17)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)

# Append project Modules directory
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake/Modules/")

# Include project directories
include_directories(${CMAKE_SOURCE_DIR})
include_directories(${CMAKE_SOURCE_DIR}/include)

# ============================================================================
# Nuke Configuration
# ============================================================================
if(NOT DEFINED NUKE_VERSION)
  set(NUKE_VERSION "16.0v6")
endif()

# Set Nuke directory - adjust this path for your installation
if(NOT DEFINED NDKDIR)
  set(NDKDIR "C:/Program Files/Nuke${NUKE_VERSION}")
endif()

message(STATUS "Using Nuke version: ${NUKE_VERSION}")
message(STATUS "Nuke directory: ${NDKDIR}")

# Verify Nuke directory exists
if(NOT EXISTS "${NDKDIR}")
  message(FATAL_ERROR "Nuke directory not found: ${NDKDIR}")
endif()
if(NOT EXISTS "${NDKDIR}/DDImage.lib")
  message(FATAL_ERROR "DDImage.lib not found in: ${NDKDIR}")
endif()

# Add the Nuke include directory
include_directories("${NDKDIR}/include")

# ============================================================================
# Windows Compiler Flags
# ============================================================================
# Standard Windows defines
add_definitions(
  -DWIN32
  -D_WINDOWS
  -DNDEBUG
  -DNOMINMAX                    # Prevent min/max macro conflicts
  -D_CRT_SECURE_NO_WARNINGS     # Disable CRT security warnings
  -D_SCL_SECURE_NO_WARNINGS     # Disable SCL security warnings
  -D_USE_MATH_DEFINES           # Enable M_PI and other math constants
  -DWIN32_LEAN_AND_MEAN         # Exclude rarely-used stuff from Windows headers
  -D_WIN32_WINNT=0x0601         # Target Windows 7 and later (required for Boost.Asio)
  -DBOOST_BIND_GLOBAL_PLACEHOLDERS  # Suppress Boost.Bind deprecation warning
  -DBOOST_ALL_NO_LIB            # CRITICAL: Disable Boost auto-linking!
)

# MSVC-specific compiler flags - ONLY for C++ files, not CUDA
if(MSVC)
  # Warning level and optimization
  add_compile_options(
    $<$<COMPILE_LANGUAGE:CXX>:/W3>          # Warning level 3 (reasonable warnings)
    $<$<COMPILE_LANGUAGE:CXX>:/O2>          # Maximize speed
    $<$<COMPILE_LANGUAGE:CXX>:/Ob2>         # Inline expansion
    $<$<COMPILE_LANGUAGE:CXX>:/EHsc>        # Exception handling
    $<$<COMPILE_LANGUAGE:CXX>:/FS>          # Force synchronous PDB writes
    $<$<COMPILE_LANGUAGE:CXX>:/nologo>      # Suppress startup banner
  )
  
  # Suppress specific warnings that are too noisy
  add_compile_options(
    $<$<COMPILE_LANGUAGE:CXX>:/wd4514>      # Unreferenced inline function removed
    $<$<COMPILE_LANGUAGE:CXX>:/wd4710>      # Function not inlined
    $<$<COMPILE_LANGUAGE:CXX>:/wd4711>      # Function selected for inline expansion
    $<$<COMPILE_LANGUAGE:CXX>:/wd4668>      # Undefined preprocessor macro
  )
endif()

# ============================================================================
# Boost Configuration - HEADER-ONLY ONLY
# ============================================================================
# Critical: We use ONLY header-only Boost (Asio, Bind, Ptr_Container)
# threading.cpp uses std::thread, NOT boost::thread
# Must prevent CMake from finding or linking any Boost libraries

# Set Boost root but DON'T search for any libraries
if(NOT DEFINED BOOST_ROOT)
  set(BOOST_ROOT "C:/local/boost_1_88_0")
endif()

# Just add include directory directly - don't use find_package at all for libraries
if(EXISTS "${BOOST_ROOT}/boost")
  include_directories(${BOOST_ROOT})
  message(STATUS "Boost version: 1.88.0")
  message(STATUS "Boost include dirs: ${BOOST_ROOT}")
  message(STATUS "Boost libraries: Header-only (Asio, Bind) - NO LINKING")
  set(Boost_FOUND TRUE)
else()
  message(FATAL_ERROR "Boost not found at ${BOOST_ROOT}")
endif()

# ============================================================================
# Intel IPP Configuration - STATIC LINKING
# ============================================================================
if(NOT DEFINED IPP_ROOT)
  set(IPP_ROOT "C:/Program Files (x86)/Intel/oneAPI/ipp/2022.1")
endif()

set(Ipp_INCLUDE_DIR "${IPP_ROOT}/include/ipp")
set(Ipp_LIBRARY_DIR "${IPP_ROOT}/lib")

# Find IPP static libraries (.lib files)
find_library(IPP_CORE_LIB NAMES ippcore PATHS "${Ipp_LIBRARY_DIR}" NO_DEFAULT_PATH)
find_library(IPP_I_LIB NAMES ippi PATHS "${Ipp_LIBRARY_DIR}" NO_DEFAULT_PATH)

if(IPP_CORE_LIB AND IPP_I_LIB)
  set(Ipp_LIBRARIES ${IPP_CORE_LIB} ${IPP_I_LIB})
  message(STATUS "IPP include dir: ${Ipp_INCLUDE_DIR}")
  message(STATUS "IPP libraries: ${Ipp_LIBRARIES}")
  include_directories(${Ipp_INCLUDE_DIR})
else()
  message(FATAL_ERROR "IPP libraries not found in ${Ipp_LIBRARY_DIR}")
endif()

# ============================================================================
# CUDA Configuration
# ============================================================================
enable_language(CUDA)
find_package(CUDAToolkit REQUIRED)

message(STATUS "CUDA Toolkit: ${CUDAToolkit_VERSION}")
message(STATUS "CUDA Include: ${CUDAToolkit_INCLUDE_DIRS}")

# CUDA include directories
include_directories(${CUDAToolkit_INCLUDE_DIRS})

# Support multiple GPU architectures
# Note: Architectures < sm_75 are deprecated in CUDA 12.9 but still supported
# C++17 is required for compatibility with Nuke 16.0v6 headers
set(CMAKE_CUDA_ARCHITECTURES 
  52      # Maxwell (for compatibility)
  61      # Pascal
  70      # Volta
  75      # Turing
  80      # Ampere A100
  86      # Ampere RTX 30xx/A series
  89      # Ada Lovelace
  90      # Hopper
)

message(STATUS "CUDA Architectures: ${CMAKE_CUDA_ARCHITECTURES}")
message(STATUS "CUDA Compiler: ${CMAKE_CUDA_COMPILER}")

# Clear any auto-generated CUDA flags
set(CMAKE_CUDA_FLAGS "" CACHE STRING "CUDA compiler flags" FORCE)
set(CMAKE_CUDA_FLAGS_RELEASE "" CACHE STRING "CUDA compiler flags for Release" FORCE)

message(STATUS "CUDA Flags: ${CMAKE_CUDA_FLAGS}")

# Use static CUDA runtime
set(CMAKE_CUDA_RUNTIME_LIBRARY Static)

# ============================================================================
# Build libcore as STATIC library
# ============================================================================
add_library(core STATIC src/threading.cpp)

# CRITICAL: Set static runtime for core library
set_property(TARGET core PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

# Add CUDA include directories to core
target_include_directories(core PUBLIC 
  ${CUDAToolkit_INCLUDE_DIRS}
  ${CMAKE_SOURCE_DIR}/include
)

# Link dependencies to the core library
target_link_libraries(core PUBLIC
  ${Ipp_LIBRARIES}
  CUDA::cudart_static
)

set_target_properties(core PROPERTIES 
  ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib
  POSITION_INDEPENDENT_CODE ON
)

# ============================================================================
# Build afx_median plugin with CUDA support
# ============================================================================
add_library(afx_median SHARED 
  src/afx_median.cpp
  src/afx_median.cu
)

# CRITICAL: Set static runtime for afx_median
set_property(TARGET afx_median PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

# Set CUDA properties for afx_median
set_target_properties(afx_median PROPERTIES
  CUDA_SEPARABLE_COMPILATION OFF
  CUDA_RUNTIME_LIBRARY Static
)

# Set CUDA-specific compile options
# CRITICAL: Pass /MT to host compiler via nvcc
target_compile_options(afx_median PRIVATE
  # CUDA-only flags
  $<$<COMPILE_LANGUAGE:CUDA>:--expt-relaxed-constexpr>
  # Host compiler flags - pass to MSVC via nvcc
  # Using comma-separated list in SINGLE -Xcompiler
  $<$<COMPILE_LANGUAGE:CUDA>:-Xcompiler=/EHsc,/W3,/nologo,/O2,/Ob2,/FS,/MT,/wd4514,/wd4710,/wd4711,/wd4668>
)

# Add compile definitions specifically for CUDA files
target_compile_definitions(afx_median PRIVATE
  $<$<COMPILE_LANGUAGE:CUDA>:WIN32_LEAN_AND_MEAN>
  $<$<COMPILE_LANGUAGE:CUDA>:_WIN32_WINNT=0x0601>
)

# Output naming
set_target_properties(afx_median PROPERTIES 
  OUTPUT_NAME "afx_median"
  SUFFIX ".dll"
  RUNTIME_OUTPUT_DIRECTORY_RELEASE ${PROJECT_BINARY_DIR}/Release
  LIBRARY_OUTPUT_DIRECTORY_RELEASE ${PROJECT_BINARY_DIR}/Release
)

# Link everything into afx_median
target_link_libraries(afx_median PRIVATE
  core
  "${NDKDIR}/DDImage.lib"
  CUDA::cudart_static
  CUDA::cuda_driver
  opengl32
)

add_dependencies(afx_median core)
list(APPEND afx_PLUGINS afx_median)

# ============================================================================
# Build AFXSoftClip - Simple plugin, no CUDA
# ============================================================================
add_library(afx_soft_clip SHARED src/afx_soft_clip.cpp)

# CRITICAL: Set static runtime
set_property(TARGET afx_soft_clip PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

set_target_properties(afx_soft_clip PROPERTIES 
  OUTPUT_NAME "afx_soft_clip"
  SUFFIX ".dll"
  RUNTIME_OUTPUT_DIRECTORY_RELEASE ${PROJECT_BINARY_DIR}/Release
  LIBRARY_OUTPUT_DIRECTORY_RELEASE ${PROJECT_BINARY_DIR}/Release
)

target_link_libraries(afx_soft_clip PRIVATE
  ${Ipp_LIBRARIES}
  "${NDKDIR}/DDImage.lib"
  opengl32
)

list(APPEND afx_PLUGINS afx_soft_clip)

# ============================================================================
# Build AFXToneMap - Simple plugin, no CUDA
# ============================================================================
add_library(afx_tone_map SHARED src/afx_tone_map.cpp)

# CRITICAL: Set static runtime
set_property(TARGET afx_tone_map PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

set_target_properties(afx_tone_map PROPERTIES 
  OUTPUT_NAME "afx_tone_map"
  SUFFIX ".dll"
  RUNTIME_OUTPUT_DIRECTORY_RELEASE ${PROJECT_BINARY_DIR}/Release
  LIBRARY_OUTPUT_DIRECTORY_RELEASE ${PROJECT_BINARY_DIR}/Release
)

target_link_libraries(afx_tone_map PRIVATE
  ${Ipp_LIBRARIES}
  "${NDKDIR}/DDImage.lib"
  opengl32
)

list(APPEND afx_PLUGINS afx_tone_map)

# ============================================================================
# Build AFXDeSpill - Needs core library
# ============================================================================
add_library(afx_despill SHARED src/afx_despill.cpp)

# CRITICAL: Set static runtime
set_property(TARGET afx_despill PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

set_target_properties(afx_despill PROPERTIES 
  OUTPUT_NAME "afx_despill"
  SUFFIX ".dll"
  RUNTIME_OUTPUT_DIRECTORY_RELEASE ${PROJECT_BINARY_DIR}/Release
  LIBRARY_OUTPUT_DIRECTORY_RELEASE ${PROJECT_BINARY_DIR}/Release
)

target_link_libraries(afx_despill PRIVATE
  core
  "${NDKDIR}/DDImage.lib"
  opengl32
)

add_dependencies(afx_despill core)
list(APPEND afx_PLUGINS afx_despill)

# ============================================================================
# Install Configuration
# ============================================================================
# Default install to user's .nuke directory
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "$ENV{USERPROFILE}/.nuke/afx-nuke-plugins" 
      CACHE PATH "Install path" FORCE)
endif()

install(
  TARGETS ${afx_PLUGINS}
  RUNTIME DESTINATION .
  LIBRARY DESTINATION .
)

# ============================================================================
# Print Configuration Summary
# ============================================================================
message(STATUS "")
message(STATUS "===========================================================================")
message(STATUS "Windows Build Configuration Summary:")
message(STATUS "  Build Type:        ${CMAKE_BUILD_TYPE}")
message(STATUS "  Compiler:          MSVC ${MSVC_VERSION}")
message(STATUS "  C++ Standard:      C++${CMAKE_CXX_STANDARD}")
message(STATUS "  CUDA Standard:     C++${CMAKE_CUDA_STANDARD}")
message(STATUS "  Runtime Linking:   STATIC (/MT) - No VC++ Redistributable required!")
message(STATUS "  ")
message(STATUS "CUDA Configuration:")
message(STATUS "  CUDA Toolkit:      ${CUDAToolkit_VERSION}")
message(STATUS "  CUDA Compiler:     ${CMAKE_CUDA_COMPILER}")
message(STATUS "  CUDA Architectures: ${CMAKE_CUDA_ARCHITECTURES}")
message(STATUS "  CUDA Runtime:      Static")
message(STATUS "  ")
message(STATUS "Nuke Configuration:")
message(STATUS "  Nuke Version:      ${NUKE_VERSION}")
message(STATUS "  Nuke Directory:    ${NDKDIR}")
message(STATUS "  DDImage Library:   ${NDKDIR}/DDImage.lib")
message(STATUS "  ")
message(STATUS "Dependencies:")
message(STATUS "  Boost:             ${BOOST_ROOT}")
message(STATUS "  IPP:               ${IPP_ROOT}")
message(STATUS "  IPP Libraries:     ${Ipp_LIBRARIES}")
message(STATUS "  ")
message(STATUS "Static Linking (compiled into plugins):")
message(STATUS "  libcore:           STATIC (compiled into afx_median and afx_despill)")
message(STATUS "  Boost:             Header-only (Asio, Bind only - using std::thread)")
message(STATUS "  IPP:               ${Ipp_LIBRARIES}")
message(STATUS "  CUDA:              Static runtime")
message(STATUS "  VC++ Runtime:      STATIC (/MT) - eliminates MSVCP140.dll/VCRUNTIME140.dll")
message(STATUS "  ")
message(STATUS "Plugins Built:")
message(STATUS "  afx_median.dll     GPU-accelerated smart median filter")
message(STATUS "  afx_soft_clip.dll  Soft clipping with adjustable knee")
message(STATUS "  afx_tone_map.dll   Tone mapping with exposure control")
message(STATUS "  afx_despill.dll    Smart green/blue screen spill removal")
message(STATUS "  ")
message(STATUS "Installation:")
message(STATUS "  Install prefix:    ${CMAKE_INSTALL_PREFIX}")
message(STATUS "  ")
message(STATUS "Build Commands:")
message(STATUS "  Configure:         cmake -B build -G \"Visual Studio 17 2022\" -A x64")
message(STATUS "  Build:             cmake --build build --config Release")
message(STATUS "  Install:           cmake --install build --config Release")
message(STATUS "  ")
message(STATUS "Portability:")
message(STATUS "  DLL Dependencies:  DDImage.dll, KERNEL32.dll, WS2_32.dll, opengl32.dll")
message(STATUS "                     + Universal CRT (built into Windows 10/11)")
message(STATUS "  Required:          - Nuke installation (provides DDImage.dll)")
message(STATUS "                     - Windows 10/11 (for Universal CRT)")
message(STATUS "  NOT Required:      - Visual C++ Redistributable (statically linked!)")
message(STATUS "  ")
message(STATUS "Usage in Nuke (Windows):")
message(STATUS "  Add to init.py or menu.py:")
message(STATUS "    nuke.pluginAddPath('C:/Users/YourName/.nuke/afx-nuke-plugins')")
message(STATUS "  Or load individually:")
message(STATUS "    nuke.load('afx_median.dll')")
message(STATUS "    nuke.createNode('AFXMedian')")
message(STATUS "===========================================================================")
message(STATUS "")