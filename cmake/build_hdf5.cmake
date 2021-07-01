# builds HDF5 library from scratch
# note: the use of "lib" vs. CMAKE_STATIC_LIBRARY_PREFIX is deliberate based on the particulars of these libraries
# across Intel Fortran on Windows vs. Gfortran on Windows vs. Linux.

set(hdf5_external true CACHE BOOL "autobuild HDF5")

set(HDF5_VERSION 1.10.7)
# for user information, not used by ExternalProject itself

include(ExternalProject)

# need to be sure _ROOT isn't empty, defined is not enough
if(NOT HDF5_ROOT)
  if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(HDF5_ROOT ${PROJECT_BINARY_DIR} CACHE PATH "HDF5_ROOT")
  else()
    set(HDF5_ROOT ${CMAKE_INSTALL_PREFIX})
  endif()
endif()

set(HDF5_LIBRARIES)
foreach(_name hdf5_hl_fortran hdf5_hl_f90cstub hdf5_fortran hdf5_f90cstub hdf5_hl hdf5)
  list(APPEND HDF5_LIBRARIES ${HDF5_ROOT}/lib/lib${_name}${CMAKE_STATIC_LIBRARY_SUFFIX})
endforeach()

set(HDF5_INCLUDE_DIRS ${HDF5_ROOT}/include)

# --- Zlib
set(zlib_root
-DHDF5_ENABLE_Z_LIB_SUPPORT:BOOL=ON
-DZLIB_USE_EXTERNAL:BOOL=OFF)

if(TARGET ZLIB::ZLIB)
  add_custom_target(ZLIB)
else()
  include(${CMAKE_CURRENT_LIST_DIR}/build_zlib.cmake)
endif()
# --- HDF5
# https://forum.hdfgroup.org/t/issues-when-using-hdf5-as-a-git-submodule-and-using-cmake-with-add-subdirectory/7189/2

set(hdf5_cmake_args
${zlib_root}
-DCMAKE_INSTALL_PREFIX:PATH=${HDF5_ROOT}
-DCMAKE_MODULE_PATH:PATH=${CMAKE_MODULE_PATH}
-DHDF5_GENERATE_HEADERS:BOOL=false
-DHDF5_DISABLE_COMPILER_WARNINGS:BOOL=true
-DBUILD_SHARED_LIBS:BOOL=false
-DCMAKE_BUILD_TYPE=Release
-DHDF5_BUILD_FORTRAN:BOOL=true
-DHDF5_BUILD_CPP_LIB:BOOL=false
-DBUILD_TESTING:BOOL=false
-DHDF5_BUILD_EXAMPLES:BOOL=false)

if(hdf5_parallel)
  find_package(MPI REQUIRED COMPONENTS C)
  list(APPEND hdf5_cmake_args
    -DHDF5_ENABLE_PARALLEL:BOOL=true
    -DHDF5_BUILD_TOOLS:BOOL=false)
    # https://github.com/HDFGroup/hdf5/issues/818  for broken ph5diff
else()
  list(APPEND hdf5_cmake_args
    -DHDF5_ENABLE_PARALLEL:BOOL=false
    -DHDF5_BUILD_TOOLS:BOOL=true)
endif()

if(CMAKE_VERSION VERSION_LESS 3.20)
  ExternalProject_Add(HDF5
  URL ${hdf5_url}
  URL_HASH SHA256=${hdf5_sha256}
  CMAKE_ARGS ${hdf5_cmake_args}
  BUILD_BYPRODUCTS ${HDF5_LIBRARIES}
  DEPENDS ZLIB)
else()
  ExternalProject_Add(HDF5
  URL ${hdf5_url}
  URL_HASH SHA256=${hdf5_sha256}
  CMAKE_ARGS ${hdf5_cmake_args}
  BUILD_BYPRODUCTS ${HDF5_LIBRARIES}
  DEPENDS ZLIB
  CONFIGURE_HANDLED_BY_BUILD ON
  INACTIVITY_TIMEOUT 15)
endif()

# --- imported target

file(MAKE_DIRECTORY ${HDF5_INCLUDE_DIRS})
# avoid race condition

# this GLOBAL is required to be visible via other project's FetchContent of h5fortran
add_library(HDF5::HDF5 INTERFACE IMPORTED GLOBAL)
target_include_directories(HDF5::HDF5 INTERFACE "${HDF5_INCLUDE_DIRS}")
target_link_libraries(HDF5::HDF5 INTERFACE "${HDF5_LIBRARIES}")

add_dependencies(HDF5::HDF5 HDF5)

# --- external deps

target_link_libraries(HDF5::HDF5 INTERFACE ZLIB::ZLIB)

set(THREADS_PREFER_PTHREAD_FLAG true)
find_package(Threads)
if(Threads_FOUND)
  target_link_libraries(HDF5::HDF5 INTERFACE Threads::Threads)
endif(Threads_FOUND)

# libdl and libm are needed on some systems--don't remove
target_link_libraries(HDF5::HDF5 INTERFACE ${CMAKE_DL_LIBS})

if(UNIX)
  target_link_libraries(HDF5::HDF5 INTERFACE m)
endif(UNIX)
