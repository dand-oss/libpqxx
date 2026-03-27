include(CheckFunctionExists)
include(CMakeFindDependencyMacro)
if(NOT PostgreSQL_FOUND)
    # Help FindPostgreSQL locate libpq.
    # Priority: PGDIR env var > Windows I:/t/postgres/<ver> > ASV_PLAT_PORTS
    if(DEFINED ENV{PGDIR})
        set(PostgreSQL_ROOT "$ENV{PGDIR}")
    elseif(WIN32)
        # EDB zip extracts to pgsql/ subdir under the version directory
        file(GLOB _pg_dirs "I:/t/postgres/*/pgsql")
        if(NOT _pg_dirs)
            file(GLOB _pg_dirs "I:/t/postgres/*")
        endif()
        if(_pg_dirs)
            list(SORT _pg_dirs ORDER DESCENDING)
            list(GET _pg_dirs 0 PostgreSQL_ROOT)
        endif()
    endif()
    if(NOT PostgreSQL_ROOT AND ASV_PLAT_PORTS)
        set(PostgreSQL_ROOT "${ASV_PLAT_PORTS}")
    endif()

    if(POLICY CMP0074)
        cmake_policy(PUSH)
        cmake_policy(SET CMP0074 NEW)
    endif()
    find_package(PostgreSQL)
    if(POLICY CMP0074)
        cmake_policy(POP)
    endif()
endif()
if(NOT PostgreSQL_FOUND)
    find_package(PkgConfig QUIET)
    if(PkgConfig_FOUND)
        pkg_check_modules(PostgreSQL QUIET libpq)
    endif()
endif()
if(NOT PostgreSQL_FOUND)
    message(FATAL_ERROR
        "Could not find PostgreSQL/libpq.\n"
        "Set PGDIR env var or PostgreSQL_ROOT cmake var to a PostgreSQL installation.\n"
        "On Linux: install libpq-dev. On Windows: install to I:/t/postgres/<ver>/.\n"
        "Searched PostgreSQL_ROOT=${PostgreSQL_ROOT}"
    )
endif()
check_function_exists("poll" PQXX_HAVE_POLL)

# Incorporate feature checks based on C++ feature test macros.
include(pqxx_cxx_feature_checks)

# Check for std::stacktrace support.  We can't just generate this like other
# tests because some compilers require an extra library to support
# std::stacktrace.
try_compile(
    PQXX_HAVE_STACKTRACE ${PROJECT_BINARY_DIR}
    SOURCES ${PROJECT_SOURCE_DIR}/config-tests/stacktrace_support.cxx
)

set(AC_CONFIG_H_IN "${PROJECT_SOURCE_DIR}/include/pqxx/internal/config.h.in")
set(CM_CONFIG_H_IN
    "${PROJECT_BINARY_DIR}/include/pqxx/internal/config_cmake.h.in"
)
set(CONFIG_H "${PROJECT_BINARY_DIR}/include/pqxx/internal/config.h")
message(STATUS "Generating configuration headers")

# First we write config_cmake.h.in based on autoconf's config.h.in.
file(WRITE "${CM_CONFIG_H_IN}" "")
file(STRINGS "${AC_CONFIG_H_IN}" lines)
foreach(line ${lines})
    string(REGEX REPLACE "^#undef" "#cmakedefine" l "${line}")
    file(APPEND "${CM_CONFIG_H_IN}" "${l}\n")
endforeach()

# Now have CMake write config.h based on that config_cmake.h.in.  This makes the
# process look as much like the autoconf one as we can.
configure_file("${CM_CONFIG_H_IN}" "${CONFIG_H}" @ONLY)

message(STATUS "Generating configuration headers - done")
