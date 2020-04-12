# Simple file to find MKL (if available)
# This needs a lot of work to make it robust
INCLUDE( CheckCXXSourceCompiles )

MESSAGE(STATUS "Looking for Intel MKL libraries")

IF(DEFINED MKL_ROOT)
  # Finding and setting the MKL_INCLUDE_DIRECTORIES based on explicit MKL_ROOT
  SET(SUFFIXES include)
  FIND_PATH(MKL_INCLUDE_DIRECTORIES "mkl.h" HINTS ${MKL_ROOT}
    PATH_SUFFIXES ${SUFFIXES} NO_CMAKE_SYSTEM_PATH)
  IF(NOT MKL_INCLUDE_DIRECTORIES)
    message(FATAL_ERROR "MKL_INCLUDE_DIRECTORIES not set. \"mkl.h\" not found in MKL_ROOT/(${SUFFIXES})")
  ENDIF ()
ELSE(DEFINED MKL_ROOT)
  # Finding and setting the MKL_INCLUDE_DIRECTORIES based on MKLROOT, MKL_HOME, $ENV{MKLROOT}, $ENV{MKL_ROOT}, $ENV{MKL_HOME}
  # Extremely Basic Support of common mkl module environment variables
  # or -DMKLROOT/-DMKL_HOME instead of preferred -DMKL_ROOT
  FIND_PATH(MKL_INCLUDE_DIRECTORIES "mkl.h"
    HINTS ${MKLROOT} ${MKL_HOME} $ENV{MKLROOT} $ENV{MKL_ROOT} $ENV{MKL_HOME}
    PATH_SUFFIXES include NO_CMAKE_SYSTEM_PATH)
  IF(MKL_INCLUDE_DIRECTORIES)
    STRING(REPLACE "/include" "" MKL_ROOT ${MKL_INCLUDE_DIRECTORIES})
  ELSE(MKL_INCLUDE_DIRECTORIES)
    # Finding MKL headers in the system
    FIND_PATH(MKL_INCLUDE_DIRECTORIES "mkl.h" PATH_SUFFIXES mkl)
  ENDIF(MKL_INCLUDE_DIRECTORIES)
ENDIF(DEFINED MKL_ROOT)

IF(MKL_INCLUDE_DIRECTORIES)
  MESSAGE("MKL_INCLUDE_DIRECTORIES: ${MKL_INCLUDE_DIRECTORIES}")
ELSE(MKL_INCLUDE_DIRECTORIES)
  IF(CMAKE_CXX_COMPILER_ID MATCHES "Intel")
    MESSAGE(FATAL_ERROR "Intel's standard compilervar.sh sets the env variable MKLROOT.\n"
            "If you are invoking icc without the customary environment\n"
            "you must set the the environment variable or pass cmake MKL_ROOT.")
  ELSE(CMAKE_CXX_COMPILER_ID MATCHES "Intel")
    MESSAGE(FATAL_ERROR "ENABLE_MKL is TRUE and mkl directory not found. Set MKL_ROOT." )
  ENDIF(CMAKE_CXX_COMPILER_ID MATCHES "Intel")
ENDIF(MKL_INCLUDE_DIRECTORIES)

IF( NOT CMAKE_CXX_COMPILER_ID MATCHES "Intel" )
  # Finding and setting the MKL_LINK_DIRECTORIES
  # the directory organization varies with platform and targets
  # these suffixes are not exhaustive
  SET(MKL_FIND_LIB "libmkl_intel_lp64${CMAKE_SHARED_LIBRARY_SUFFIX}")
  SET(SUFFIXES lib lib/intel64)
  FIND_PATH(MKL_LINK_DIRECTORIES "${MKL_FIND_LIB}" HINTS ${MKL_ROOT}
    PATH_SUFFIXES ${SUFFIXES} NO_CMAKE_SYSTEM_PATH)
  IF(MKL_LINK_DIRECTORIES)
    MESSAGE("MKL_LINK_DIRECTORIES: ${MKL_LINK_DIRECTORIES}")
    set(MKL_LINKER_FLAGS "-L${MKL_LINK_DIRECTORIES} -Wl,-rpath,${MKL_LINK_DIRECTORIES}")
  ELSE(MKL_LINK_DIRECTORIES)
    FIND_LIBRARY(MKL_SYSTEM_LIBRARIES "${MKL_FIND_LIB}")
    IF(MKL_SYSTEM_LIBRARIES)
      MESSAGE("MKL provided by the system. Leave MKL_LINK_DIRECTORIES unset.")
    ENDIF()
  ENDIF(MKL_LINK_DIRECTORIES)
  IF (NOT MKL_LINK_DIRECTORIES AND NOT MKL_SYSTEM_LIBRARIES)
    MESSAGE(FATAL_ERROR "${MKL_FIND_LIB} found neither in MKL_ROOT/(${SUFFIXES}) nor on system library paths.")
  ENDIF ()
  SET(MKL_LIBRARIES "-lmkl_intel_lp64 -lmkl_sequential -lmkl_core -lpthread -lm -ldl")
ELSE ( NOT CMAKE_CXX_COMPILER_ID MATCHES "Intel" )
  # this takes away link control for intel but is convenient
  # perhaps we should consider dropping it since it will more or less
  # unify the MKL setup.
  # Note -mkl implicitly includes that icc's mkl/include
  SET(MKL_COMPILE_DEFINITIONS "-mkl")
ENDIF (NOT CMAKE_CXX_COMPILER_ID MATCHES "Intel" )

# Check for mkl.h
FILE( WRITE "${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/CMakeTmp/src_mkl.cxx"
  "#include <iostream>\n #include <mkl.h>\n int main() { return 0; }\n" )
TRY_COMPILE(HAVE_MKL ${CMAKE_BINARY_DIR}
  ${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/CMakeTmp/src_mkl.cxx
  CMAKE_FLAGS
  "-DINCLUDE_DIRECTORIES=${MKL_INCLUDE_DIRECTORIES} "
  "-DLINK_DIRECTORIES=${MKL_LINK_DIRECTORIES}"
  LINK_LIBRARIES "${MKL_LIBRARIES}"
  COMPILE_DEFINITIONS "${MKL_COMPILE_DEFINITIONS}"
  OUTPUT_VARIABLE MKL_OUT)
IF( NOT HAVE_MKL )
  MESSAGE( "${MKL_OUT}" )
ENDIF( NOT HAVE_MKL )

# Check for mkl_vml_functions.h
FILE( WRITE "${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/CMakeTmp/src_mkl_vml.cxx"
  "#include <iostream>\n #include <mkl_vml_functions.h>\n int main() { return 0; }\n" )
TRY_COMPILE(HAVE_MKL_VML ${CMAKE_BINARY_DIR}
  ${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/CMakeTmp/src_mkl_vml.cxx
  CMAKE_FLAGS
  "-DINCLUDE_DIRECTORIES=${MKL_INCLUDE_DIRECTORIES} "
  "-DLINK_DIRECTORIES=${MKL_LINK_DIRECTORIES}"
  COMPILE_DEFINITIONS "${MKL_COMPILE_DEFINITIONS}"
  OUTPUT_VARIABLE MKL_OUT)

# Check for fftw3
FIND_PATH(MKL_FFTW3 "fftw3.h"
  HINTS ${MKL_INCLUDE_DIRECTORIES}
  PATH_SUFFIXES fftw)
IF(MKL_FFTW3)
  FILE( WRITE "${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/CMakeTmp/src_mkl_fftw3.cxx"
    "#include <iostream>\n #include <fftw3.h>\n int main() { return 0; }\n" )
  TRY_COMPILE(HAVE_MKL_FFTW3 ${CMAKE_BINARY_DIR}
    ${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/CMakeTmp/src_mkl_fftw3.cxx
    CMAKE_FLAGS
    "-DINCLUDE_DIRECTORIES=${MKL_FFTW3} "
    "-DLINK_DIRECTORIES=${MKL_LINK_DIRECTORIES}"
    LINK_LIBRARIES "${MKL_LIBRARIES}"
    COMPILE_DEFINITIONS "${MKL_COMPILE_DEFINITIONS}"
    OUTPUT_VARIABLE MKL_OUT)
ELSE(MKL_FFTW3)
  UNSET(HAVE_MKL_FFTW3)
ENDIF(MKL_FFTW3)

IF ( HAVE_MKL )
  SET( MKL_FOUND TRUE )
  MESSAGE(STATUS "MKL found: HAVE_MKL=${HAVE_MKL}, HAVE_MKL_VML=${HAVE_MKL_VML}, HAVE_MKL_FFTW3=${HAVE_MKL_FFTW3}")

  #create BLAS_LAPACK target
  ADD_LIBRARY(Math::BLAS_LAPACK INTERFACE IMPORTED)
  SET_TARGET_PROPERTIES(Math::BLAS_LAPACK PROPERTIES INTERFACE_COMPILE_DEFINITIONS "HAVE_MKL")
  IF (NOT CMAKE_CXX_COMPILER_ID MATCHES "Intel" )
    SET_TARGET_PROPERTIES(Math::BLAS_LAPACK PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${MKL_INCLUDE_DIRECTORIES}"
                                                       INTERFACE_LINK_LIBRARIES "${MKL_LINKER_FLAGS};${MKL_LIBRARIES}")
  ELSE (NOT CMAKE_CXX_COMPILER_ID MATCHES "Intel" )
    SET_TARGET_PROPERTIES(Math::BLAS_LAPACK PROPERTIES INTERFACE_COMPILE_OPTIONS "-mkl"
                                                       INTERFACE_LINK_LIBRARIES "-mkl")
  ENDIF (NOT CMAKE_CXX_COMPILER_ID MATCHES "Intel" )

  IF( HAVE_MKL_VML )
    #create scalar_vector_functions target
    ADD_LIBRARY(Math::scalar_vector_functions INTERFACE IMPORTED)
    SET_TARGET_PROPERTIES(Math::scalar_vector_functions PROPERTIES INTERFACE_COMPILE_DEFINITIONS "HAVE_MKL;HAVE_MKL_VML")
    IF (NOT CMAKE_CXX_COMPILER_ID MATCHES "Intel" )
      SET_TARGET_PROPERTIES(Math::scalar_vector_functions PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${MKL_INCLUDE_DIRECTORIES}"
                                                                     INTERFACE_LINK_LIBRARIES "${MKL_LINKER_FLAGS};${MKL_LIBRARIES}")
    ELSE (NOT CMAKE_CXX_COMPILER_ID MATCHES "Intel" )
      SET_TARGET_PROPERTIES(Math::scalar_vector_functions PROPERTIES INTERFACE_COMPILE_OPTIONS "-mkl"
                                                                     INTERFACE_LINK_LIBRARIES "-mkl")
    ENDIF (NOT CMAKE_CXX_COMPILER_ID MATCHES "Intel" )
  ENDIF( HAVE_MKL_VML )

  IF( HAVE_MKL_FFTW3 )
    #create FFTW3 target
    ADD_LIBRARY(Math::FFTW3 INTERFACE IMPORTED)
    SET_TARGET_PROPERTIES(Math::FFTW3 PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${MKL_FFTW3}"
                                                 INTERFACE_COMPILE_DEFINITIONS "HAVE_MKL;HAVE_LIBFFTW")
    IF (NOT CMAKE_CXX_COMPILER_ID MATCHES "Intel" )
      SET_TARGET_PROPERTIES(Math::FFTW3 PROPERTIES INTERFACE_LINK_LIBRARIES "${MKL_LINKER_FLAGS};${MKL_LIBRARIES}")
    ELSE (NOT CMAKE_CXX_COMPILER_ID MATCHES "Intel" )
      SET_TARGET_PROPERTIES(Math::FFTW3 PROPERTIES INTERFACE_COMPILE_OPTIONS "-mkl"
                                                   INTERFACE_LINK_LIBRARIES "-mkl")
    ENDIF (NOT CMAKE_CXX_COMPILER_ID MATCHES "Intel" )
  ENDIF( HAVE_MKL_FFTW3 )
ELSE( HAVE_MKL )
  SET( MKL_FOUND FALSE )
  MESSAGE(STATUS "MKL not found")
ENDIF( HAVE_MKL )
