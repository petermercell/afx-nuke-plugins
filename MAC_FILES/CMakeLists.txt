# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (C) 2012-2016, Ryan P. Wilson
# macOS build for AFX Nuke Plugins
#
# Authority FX, Inc.
# www.authorityfx.com

cmake_minimum_required(VERSION 3.11)

project(afx-nuke-plugins LANGUAGES CXX)

# ============================================================================
# macOS-specific Configuration
# ============================================================================
if(NOT APPLE)
  message(FATAL_ERROR "This CMakeLists.txt is for macOS only")
endif()

# Set default build type if not specified
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

# ============================================================================
# RPATH Configuration - Make plugins portable
# ============================================================================
# Don't set RPATH - rely on Nuke's environment (DYLD_LIBRARY_PATH on macOS)
set(CMAKE_SKIP_BUILD_RPATH TRUE)
set(CMAKE_SKIP_INSTALL_RPATH TRUE)
set(CMAKE_MACOSX_RPATH FALSE)

# ============================================================================
# Architecture Configuration
# ============================================================================
# Detect and set architecture (Apple Silicon vs Intel)
if(NOT DEFINED CMAKE_OSX_ARCHITECTURES)
  execute_process(
    COMMAND uname -m
    OUTPUT_VARIABLE NATIVE_ARCH
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  if(NATIVE_ARCH STREQUAL "arm64")
    set(CMAKE_OSX_ARCHITECTURES "arm64")
    message(STATUS "Building for Apple Silicon (arm64)")
  else()
    set(CMAKE_OSX_ARCHITECTURES "x86_64")
    message(STATUS "Building for Intel (x86_64)")
  endif()
endif()

# Enable C++17 standard (required for Nuke 16.0v6)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Set the prefix for shared libraries (empty for .dylib without lib prefix)
set(CMAKE_SHARED_LIBRARY_PREFIX "")

# ============================================================================
# Nuke Configuration
# ============================================================================
if(NOT DEFINED NUKE_VERSION)
  set(NUKE_VERSION "16.0v6")
endif()

set(NUKE_BASE_DIR "/Applications/Nuke${NUKE_VERSION}")
set(NUKE_INSTALL_DIR "${NUKE_BASE_DIR}/Nuke${NUKE_VERSION}.app/Contents/MacOS")

message(STATUS "Nuke Version: ${NUKE_VERSION}")
message(STATUS "Nuke Directory: ${NUKE_INSTALL_DIR}")

# Verify Nuke directory exists
if(NOT EXISTS ${NUKE_INSTALL_DIR})
  message(FATAL_ERROR "Nuke directory not found: ${NUKE_INSTALL_DIR}")
endif()
if(NOT EXISTS ${NUKE_INSTALL_DIR}/libDDImage.dylib)
  message(FATAL_ERROR "libDDImage.dylib not found in: ${NUKE_INSTALL_DIR}")
endif()

# Add the Nuke include directory
include_directories(${NUKE_INSTALL_DIR}/include)

# ============================================================================
# Project directories
# ============================================================================
include_directories(${CMAKE_SOURCE_DIR})
include_directories(${CMAKE_SOURCE_DIR}/include)

# ============================================================================
# macOS Compiler Flags
# ============================================================================
add_compile_options(
  -fPIC
  -Wall
  -Wextra
  -Wno-unused-parameter
  -O3
)

# macOS-specific defines
add_definitions(
  -D_USE_MATH_DEFINES           # Enable M_PI and other math constants
  -DBOOST_BIND_GLOBAL_PLACEHOLDERS  # Suppress Boost.Bind deprecation warning
)

# ============================================================================
# Boost Configuration - HEADER-ONLY
# ============================================================================
# We use ONLY header-only Boost (Asio, Bind, Ptr_Container)
# threading.cpp uses std::thread, NOT boost::thread

# Try to find Boost via Homebrew first
find_package(Boost QUIET)

if(NOT Boost_FOUND)
  # Try common Homebrew location
  if(CMAKE_OSX_ARCHITECTURES STREQUAL "arm64")
    set(HOMEBREW_PREFIX "/opt/homebrew")
  else()
    set(HOMEBREW_PREFIX "/usr/local")
  endif()
  
  if(EXISTS "${HOMEBREW_PREFIX}/include/boost")
    set(BOOST_ROOT "${HOMEBREW_PREFIX}")
    include_directories(${HOMEBREW_PREFIX}/include)
    set(Boost_FOUND TRUE)
    message(STATUS "Boost: Found via Homebrew at ${HOMEBREW_PREFIX}")
  endif()
endif()

if(Boost_FOUND)
  if(DEFINED Boost_INCLUDE_DIRS)
    include_directories(${Boost_INCLUDE_DIRS})
    message(STATUS "Boost include dirs: ${Boost_INCLUDE_DIRS}")
  endif()
  message(STATUS "Boost libraries: Header-only (Asio, Bind, Ptr_Container) - NO LINKING")
else()
  message(FATAL_ERROR "Boost not found. Install via: brew install boost")
endif()

# ============================================================================
# Metal Configuration (Optional - macOS GPU acceleration)
# ============================================================================
# Metal is Apple's native GPU compute framework
# Available on all modern Macs (Intel and Apple Silicon)

set(METAL_AVAILABLE FALSE)
option(USE_METAL "Enable Metal GPU acceleration" ON)

if(USE_METAL AND APPLE)
  # Check if Metal is available (it should be on all modern macOS)
  find_library(METAL_FRAMEWORK Metal)
  find_library(FOUNDATION_FRAMEWORK Foundation)
  
  if(METAL_FRAMEWORK AND FOUNDATION_FRAMEWORK)
    set(METAL_AVAILABLE TRUE)
    message(STATUS "Metal: Available - GPU acceleration ENABLED")
    message(STATUS "Metal Framework: ${METAL_FRAMEWORK}")
    
    # Compile Metal shader
    set(METAL_SHADER "${CMAKE_SOURCE_DIR}/src/MedianFilter.metal")
    set(METAL_LIB "${CMAKE_BINARY_DIR}/MedianFilter.metallib")
    
    # Add custom command to compile Metal shader
    add_custom_command(
      OUTPUT ${METAL_LIB}
      COMMAND xcrun -sdk macosx metal -c ${METAL_SHADER} -o ${CMAKE_BINARY_DIR}/MedianFilter.air
      COMMAND xcrun -sdk macosx metallib ${CMAKE_BINARY_DIR}/MedianFilter.air -o ${METAL_LIB}
      DEPENDS ${METAL_SHADER}
      COMMENT "Compiling Metal shader"
    )
    
    # Add custom target for Metal shader
    add_custom_target(metal_shaders ALL DEPENDS ${METAL_LIB})
    
  else()
    message(STATUS "Metal: Not available")
  endif()
else()
  message(STATUS "Metal: Disabled by user")
endif()

# ============================================================================
# CUDA Configuration (Optional - for afx_median GPU acceleration)
# ============================================================================
# Note: CUDA support on macOS was discontinued after CUDA 10.2
# On Apple Silicon, CUDA is not available at all
# afx_median will fall back to Metal or CPU-only processing without CUDA

set(CUDA_AVAILABLE FALSE)

# Only try to find CUDA on Intel Macs (and only if Metal is not already available)
if(CMAKE_OSX_ARCHITECTURES STREQUAL "x86_64" AND NOT METAL_AVAILABLE)
  find_package(CUDAToolkit QUIET)
  if(CUDAToolkit_FOUND)
    set(CUDA_AVAILABLE TRUE)
    message(STATUS "CUDA Toolkit: ${CUDAToolkit_VERSION}")
    message(STATUS "CUDA Include: ${CUDAToolkit_INCLUDE_DIRS}")
    message(STATUS "GPU Acceleration: ENABLED (CUDA) for afx_median")
    include_directories(${CUDAToolkit_INCLUDE_DIRS})
  else()
    message(STATUS "CUDA not found - afx_median will use CPU-only processing")
  endif()
else()
  if(METAL_AVAILABLE)
    message(STATUS "Metal available - CUDA not needed")
  else()
    message(STATUS "Apple Silicon detected - CUDA not available")
  endif()
  message(STATUS "afx_median will use ${METAL_AVAILABLE} Metal" or "CPU processing")
endif()

# Only try to find CUDA on Intel Macs
if(CMAKE_OSX_ARCHITECTURES STREQUAL "x86_64")
  find_package(CUDAToolkit QUIET)
  if(CUDAToolkit_FOUND)
    set(CUDA_AVAILABLE TRUE)
    message(STATUS "CUDA Toolkit: ${CUDAToolkit_VERSION}")
    message(STATUS "CUDA Include: ${CUDAToolkit_INCLUDE_DIRS}")
    message(STATUS "GPU Acceleration: ENABLED for afx_median")
    include_directories(${CUDAToolkit_INCLUDE_DIRS})
  else()
    message(STATUS "CUDA not found - afx_median will use CPU-only processing")
  endif()
else()
  message(STATUS "Apple Silicon detected - CUDA not available")
  message(STATUS "afx_median will use CPU-only processing")
endif()

# ============================================================================
# Build libcore as STATIC library
# ============================================================================
# Core library contains common functionality used by multiple plugins

add_library(core STATIC
  src/threading.cpp
  # Add other core source files here as needed
)

set_target_properties(core PROPERTIES 
  ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib
  POSITION_INDEPENDENT_CODE ON
)

# Link core dependencies
target_link_libraries(core PRIVATE
  "-framework OpenGL"
)

# ============================================================================
# Build afx_median plugin
# ============================================================================
# Priority: Metal (macOS) > CUDA (if available) > CPU fallback

set(AFX_MEDIAN_SOURCES src/afx_median.cpp)
set(AFX_MEDIAN_LIBS core ${NUKE_INSTALL_DIR}/libDDImage.dylib "-framework OpenGL")
set(AFX_MEDIAN_DEFS "")

if(METAL_AVAILABLE)
  # Build with Metal support
  message(STATUS "afx_median: Building with Metal GPU acceleration")
  
  # Add Metal helper (Objective-C++)
  list(APPEND AFX_MEDIAN_SOURCES src/metal_helper.mm)
  
  # Add Metal frameworks
  list(APPEND AFX_MEDIAN_LIBS ${METAL_FRAMEWORK} ${FOUNDATION_FRAMEWORK})
  
  # Define USE_METAL
  list(APPEND AFX_MEDIAN_DEFS USE_METAL)
  
  # Set language to Objective-C++ for .mm files
  set_source_files_properties(src/metal_helper.mm PROPERTIES 
    COMPILE_FLAGS "-x objective-c++ -fobjc-arc"
  )
  
elseif(CUDA_AVAILABLE)
  # Build with CUDA support (Intel Mac only)
  message(STATUS "afx_median: Building with CUDA GPU acceleration")
  
  enable_language(CUDA)
  set(CMAKE_CUDA_STANDARD 17)
  set(CMAKE_CUDA_STANDARD_REQUIRED ON)
  
  list(APPEND AFX_MEDIAN_SOURCES src/afx_median.cu)
  list(APPEND AFX_MEDIAN_LIBS CUDA::cudart CUDA::cuda_driver)
  list(APPEND AFX_MEDIAN_DEFS USE_CUDA)
  
else()
  # CPU-only build
  message(STATUS "afx_median: Building CPU-only version (no GPU acceleration)")
endif()

# Create the plugin
add_library(afx_median SHARED ${AFX_MEDIAN_SOURCES})

# Set compile definitions
if(AFX_MEDIAN_DEFS)
  target_compile_definitions(afx_median PRIVATE ${AFX_MEDIAN_DEFS})
endif()

# Set CUDA properties if using CUDA
if(CUDA_AVAILABLE AND "USE_CUDA" IN_LIST AFX_MEDIAN_DEFS)
  set_target_properties(afx_median PROPERTIES
    CUDA_SEPARABLE_COMPILATION OFF
  )
  
  target_compile_options(afx_median PRIVATE
    $<$<COMPILE_LANGUAGE:CUDA>:--expt-relaxed-constexpr>
  )
endif()

# Link libraries
target_link_libraries(afx_median PRIVATE ${AFX_MEDIAN_LIBS})

# Set plugin properties
set_target_properties(afx_median PROPERTIES 
  OUTPUT_NAME "afx_median"
  SUFFIX ".dylib"
  INSTALL_NAME_DIR "@rpath"
  BUILD_WITH_INSTALL_NAME_DIR TRUE
)

# Add dependency on Metal shaders if Metal is used
if(METAL_AVAILABLE)
  add_dependencies(afx_median metal_shaders)
  
  # Install Metal library alongside plugin
  install(FILES ${METAL_LIB} DESTINATION .)
endif()

add_dependencies(afx_median core)
list(APPEND afx_PLUGINS afx_median)

# ============================================================================
# Build AFXSoftClip - Simple plugin, no CUDA, no IPP
# ============================================================================
add_library(afx_soft_clip SHARED src/afx_soft_clip.cpp)

set_target_properties(afx_soft_clip PROPERTIES 
  OUTPUT_NAME "afx_soft_clip"
  SUFFIX ".dylib"
  INSTALL_NAME_DIR "@rpath"
  BUILD_WITH_INSTALL_NAME_DIR TRUE
)

target_link_libraries(afx_soft_clip PRIVATE
  ${NUKE_INSTALL_DIR}/libDDImage.dylib
  "-framework OpenGL"
)

list(APPEND afx_PLUGINS afx_soft_clip)

# ============================================================================
# Build AFXToneMap - Simple plugin, no CUDA, no IPP
# ============================================================================
add_library(afx_tone_map SHARED src/afx_tone_map.cpp)

set_target_properties(afx_tone_map PROPERTIES 
  OUTPUT_NAME "afx_tone_map"
  SUFFIX ".dylib"
  INSTALL_NAME_DIR "@rpath"
  BUILD_WITH_INSTALL_NAME_DIR TRUE
)

target_link_libraries(afx_tone_map PRIVATE
  ${NUKE_INSTALL_DIR}/libDDImage.dylib
  "-framework OpenGL"
)

list(APPEND afx_PLUGINS afx_tone_map)

# ============================================================================
# Build AFXDeSpill - Needs core library
# ============================================================================
add_library(afx_despill SHARED src/afx_despill.cpp)

set_target_properties(afx_despill PROPERTIES 
  OUTPUT_NAME "afx_despill"
  SUFFIX ".dylib"
  INSTALL_NAME_DIR "@rpath"
  BUILD_WITH_INSTALL_NAME_DIR TRUE
)

target_link_libraries(afx_despill PRIVATE
  core
  ${NUKE_INSTALL_DIR}/libDDImage.dylib
  "-framework OpenGL"
)

add_dependencies(afx_despill core)
list(APPEND afx_PLUGINS afx_despill)

# ============================================================================
# Install Configuration
# ============================================================================
# Default install to user's .nuke directory
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "$ENV{HOME}/.nuke/afx-nuke-plugins" 
      CACHE PATH "Install path" FORCE)
endif()

install(
  TARGETS ${afx_PLUGINS}
  LIBRARY DESTINATION .
)

# ============================================================================
# Print Configuration Summary
# ============================================================================
message(STATUS "")
message(STATUS "===========================================================================")
message(STATUS "macOS Build Configuration Summary:")
message(STATUS "  Build Type:        ${CMAKE_BUILD_TYPE}")
message(STATUS "  Compiler:          ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
message(STATUS "  C++ Standard:      C++${CMAKE_CXX_STANDARD}")
message(STATUS "  Architecture:      ${CMAKE_OSX_ARCHITECTURES}")
message(STATUS "  ")
message(STATUS "GPU Acceleration:")
if(METAL_AVAILABLE)
  message(STATUS "  Metal:             ENABLED (Apple GPU)")
  message(STATUS "  GPU Framework:     Metal (native macOS)")
elseif(CUDA_AVAILABLE)
  message(STATUS "  CUDA Toolkit:      ${CUDAToolkit_VERSION}")
  message(STATUS "  GPU Acceleration:  ENABLED (CUDA)")
else()
  message(STATUS "  GPU Acceleration:  DISABLED (CPU-only)")
  if(CMAKE_OSX_ARCHITECTURES STREQUAL "arm64")
    message(STATUS "  Note:              Install is automatic - Metal available but not enabled")
    message(STATUS "                     Set USE_METAL=ON to enable (default)")
  else()
    message(STATUS "  Note:              Install CUDA 10.2 for GPU support on Intel Mac")
    message(STATUS "                     Or enable Metal (USE_METAL=ON)")
  endif()
endif()
message(STATUS "  ")
message(STATUS "Nuke Configuration:")
message(STATUS "  Nuke Version:      ${NUKE_VERSION}")
message(STATUS "  Nuke Directory:    ${NUKE_INSTALL_DIR}")
message(STATUS "  DDImage Library:   ${NUKE_INSTALL_DIR}/libDDImage.dylib")
message(STATUS "  ")
message(STATUS "Dependencies:")
message(STATUS "  Boost:             Header-only (Asio, Bind, Ptr_Container)")
if(DEFINED Boost_INCLUDE_DIRS)
  message(STATUS "  Boost Location:    ${Boost_INCLUDE_DIRS}")
else()
  message(STATUS "  Boost Location:    ${BOOST_ROOT}")
endif()
message(STATUS "  IPP:               REMOVED (no longer needed)")
message(STATUS "  ")
message(STATUS "Plugins Built:")
if(METAL_AVAILABLE)
  message(STATUS "  afx_median.dylib   Smart median filter (Metal GPU)")
elseif(CUDA_AVAILABLE)
  message(STATUS "  afx_median.dylib   Smart median filter (CUDA GPU)")
else()
  message(STATUS "  afx_median.dylib   Smart median filter (CPU)")
endif()
message(STATUS "  afx_soft_clip.dylib  Soft clipping with adjustable knee")
message(STATUS "  afx_tone_map.dylib   Tone mapping with exposure control")
message(STATUS "  afx_despill.dylib    Smart green/blue screen spill removal")
message(STATUS "  ")
message(STATUS "Installation:")
message(STATUS "  Install prefix:    ${CMAKE_INSTALL_PREFIX}")
message(STATUS "  RPATH:             Not set (portable - uses Nuke's environment)")
message(STATUS "  ")
message(STATUS "Build Commands:")
message(STATUS "  Configure:         cmake -B build")
message(STATUS "  Build:             cmake --build build --config Release")
message(STATUS "  Install:           cmake --install build")
message(STATUS "  ")
message(STATUS "Prerequisites:")
message(STATUS "  - Xcode Command Line Tools: xcode-select --install")
message(STATUS "  - Boost (header-only):      brew install boost")
message(STATUS "  - Nuke ${NUKE_VERSION}:          Installed at ${NUKE_BASE_DIR}")
if(NOT CUDA_AVAILABLE AND CMAKE_OSX_ARCHITECTURES STREQUAL "x86_64")
  message(STATUS "  - CUDA 10.2 (optional):     For GPU acceleration on Intel Mac")
endif()
message(STATUS "  ")
message(STATUS "Usage in Nuke (macOS):")
message(STATUS "  Add to init.py or menu.py:")
message(STATUS "    nuke.pluginAddPath('${CMAKE_INSTALL_PREFIX}')")
message(STATUS "  Or load individually:")
message(STATUS "    nuke.load('afx_median.dylib')")
message(STATUS "    nuke.createNode('AFXMedian')")
message(STATUS "===========================================================================")
message(STATUS "")