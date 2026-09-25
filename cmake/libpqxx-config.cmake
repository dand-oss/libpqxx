include(CMakeFindDependencyMacro)

# Help FindPostgreSQL locate libpq on Windows
if(NOT PostgreSQL_FOUND)
    if(DEFINED ENV{PGDIR})
        set(PostgreSQL_ROOT "$ENV{PGDIR}")
    elseif(WIN32)
        file(GLOB _pg_dirs "I:/t/postgres/*/pgsql")
        if(NOT _pg_dirs)
            file(GLOB _pg_dirs "I:/t/postgres/*")
        endif()
        if(_pg_dirs)
            list(SORT _pg_dirs ORDER DESCENDING)
            list(GET _pg_dirs 0 PostgreSQL_ROOT)
        endif()
    endif()
endif()

# ASI: on Windows pqxx.dll has EDB's static libpq inside it (linked PRIVATE),
# so consumers need no libpq at all
if(NOT WIN32)
    find_dependency(PostgreSQL)
endif()
include("${CMAKE_CURRENT_LIST_DIR}/libpqxx-targets.cmake")
