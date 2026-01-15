cmake_minimum_required(VERSION 3.10)
project(multipart-parser-c VERSION 1.0.0 LANGUAGES C)

# Build options
option(BUILD_SHARED_LIBS "Build shared library" ON)
option(BUILD_STATIC_LIBS "Build static library" ON)
option(BUILD_TESTING "Build tests" ON)
option(BUILD_BENCHMARKS "Build performance benchmarks" ON)
option(ENABLE_ASAN "Enable AddressSanitizer" OFF)
option(ENABLE_UBSAN "Enable UndefinedBehaviorSanitizer" OFF)
option(ENABLE_COVERAGE "Enable code coverage" OFF)

# Compiler flags
set(CMAKE_C_STANDARD 90)
set(CMAKE_C_STANDARD_REQUIRED OFF)
set(CMAKE_C_EXTENSIONS OFF)

# Base compiler flags
set(BASE_C_FLAGS "-Wall -pedantic")

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Set compiler flags based on build type
if(CMAKE_BUILD_TYPE MATCHES Debug)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${BASE_C_FLAGS} -g -O0")
elseif(CMAKE_BUILD_TYPE MATCHES Release)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${BASE_C_FLAGS} -O3")
endif()

# AddressSanitizer
if(ENABLE_ASAN)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fsanitize=address -fno-omit-frame-pointer")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fsanitize=address")
endif()

# UndefinedBehaviorSanitizer
if(ENABLE_UBSAN)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fsanitize=undefined -fno-omit-frame-pointer")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fsanitize=undefined")
endif()

# Code coverage
if(ENABLE_COVERAGE)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} --coverage -fprofile-arcs -ftest-coverage")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} --coverage")
endif()

# Source files
set(MULTIPART_PARSER_SOURCES
    multipart_parser.c
)

set(MULTIPART_PARSER_HEADERS
    multipart_parser.h
)

# Shared library
if(BUILD_SHARED_LIBS)
    add_library(multipart_parser_shared SHARED ${MULTIPART_PARSER_SOURCES})
    set_target_properties(multipart_parser_shared PROPERTIES
        OUTPUT_NAME multipart_parser
        VERSION ${PROJECT_VERSION}
        SOVERSION 1
        PUBLIC_HEADER multipart_parser.h
    )
    target_include_directories(multipart_parser_shared PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
        $<INSTALL_INTERFACE:include>
    )
endif()

# Static library
if(BUILD_STATIC_LIBS)
    add_library(multipart_parser_static STATIC ${MULTIPART_PARSER_SOURCES})
    set_target_properties(multipart_parser_static PROPERTIES
        OUTPUT_NAME multipart_parser
        PUBLIC_HEADER multipart_parser.h
    )
    target_include_directories(multipart_parser_static PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
        $<INSTALL_INTERFACE:include>
    )
endif()

# Alias for easier usage
if(BUILD_SHARED_LIBS)
    add_library(multipart_parser::multipart_parser ALIAS multipart_parser_shared)
elseif(BUILD_STATIC_LIBS)
    add_library(multipart_parser::multipart_parser ALIAS multipart_parser_static)
endif()

# Tests
if(BUILD_TESTING)
    enable_testing()
    
    add_executable(multipart_test test.c)
    if(BUILD_SHARED_LIBS)
        target_link_libraries(multipart_test multipart_parser_shared)
    else()
        target_link_libraries(multipart_test multipart_parser_static)
    endif()
    
    add_test(NAME multipart_test COMMAND multipart_test)
    
    # Set ASAN options for tests if enabled
    if(ENABLE_ASAN)
        set_tests_properties(multipart_test PROPERTIES
            ENVIRONMENT "ASAN_OPTIONS=detect_leaks=1:check_initialization_order=1:strict_init_order=1"
        )
    endif()
endif()

# Benchmarks
if(BUILD_BENCHMARKS)
    add_executable(multipart_benchmark benchmark.c)
    if(BUILD_SHARED_LIBS)
        target_link_libraries(multipart_benchmark multipart_parser_shared)
    else()
        target_link_libraries(multipart_benchmark multipart_parser_static)
    endif()
endif()

# Installation
include(GNUInstallDirs)

if(BUILD_SHARED_LIBS)
    install(TARGETS multipart_parser_shared
        EXPORT multipart_parser-targets
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    )
endif()

if(BUILD_STATIC_LIBS)
    install(TARGETS multipart_parser_static
        EXPORT multipart_parser-targets
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    )
endif()

# Export targets
install(EXPORT multipart_parser-targets
    FILE multipart_parser-targets.cmake
    NAMESPACE multipart_parser::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/multipart_parser
)

# Create config file
include(CMakePackageConfigHelpers)
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/multipart_parser-config-version.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

configure_file(cmake/multipart_parser-config.cmake.in
    "${CMAKE_CURRENT_BINARY_DIR}/multipart_parser-config.cmake"
    @ONLY
)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/multipart_parser-config.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/multipart_parser-config-version.cmake"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/multipart_parser
)

# pkg-config file
configure_file(cmake/multipart_parser.pc.in
    "${CMAKE_CURRENT_BINARY_DIR}/multipart_parser.pc"
    @ONLY
)

install(FILES "${CMAKE_CURRENT_BINARY_DIR}/multipart_parser.pc"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig
)

# Print configuration summary
message(STATUS "")
message(STATUS "Configuration Summary:")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  Shared library: ${BUILD_SHARED_LIBS}")
message(STATUS "  Static library: ${BUILD_STATIC_LIBS}")
message(STATUS "  Build tests: ${BUILD_TESTING}")
message(STATUS "  Build benchmarks: ${BUILD_BENCHMARKS}")
message(STATUS "  AddressSanitizer: ${ENABLE_ASAN}")
message(STATUS "  UBSan: ${ENABLE_UBSAN}")
message(STATUS "  Coverage: ${ENABLE_COVERAGE}")
message(STATUS "")
