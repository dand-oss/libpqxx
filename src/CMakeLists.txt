if(NOT PostgreSQL_FOUND)
    if(POLICY CMP0074)
        cmake_policy(PUSH)
        # CMP0074 is `OLD` by `cmake_minimum_required(VERSION 3.7)`,
        # sets `NEW` to enable support CMake variable `PostgreSQL_ROOT`.
        cmake_policy(SET CMP0074 NEW)
    endif()
    find_package(PostgreSQL REQUIRED)
    if(POLICY CMP0074)
        cmake_policy(POP)
    endif()
endif()

# ASI: on Windows, link EDB's static libpq (libpq.a + libpgcommon/libpgport)
# into pqxx.dll, on the ports OpenSSL (ssl-jp -asv DLLs), instead of importing
# EDB's libpq.dll and its stock-named libssl-3-x64.dll/libcrypto-3-x64.dll.
# pqxx is then the only WinGLUE module with libpq in it.
if(WIN32)
    find_package(OpenSSL 3.5.8 EXACT CONFIG REQUIRED
        PATHS ${ASV_PLAT_PORTS}/ssl-jp NO_DEFAULT_PATH)
    set(ASV_PQXX_STATIC_LIBPQ "")
    set(ASV_PQXX_STATIC_LIBPQ_DEBUG ON)
    # Names: EDB's MinGW archives (libX.a), then MSVC-built libs from the
    # ASV libpq build (X.lib, or libX.lib without the leading "lib" for the
    # pgcommon/pgport shlibs). Debug variants carry a _d suffix before the
    # extension; when all are found, Debug links them and Release links the
    # release libs. Otherwise the release lib is used for both (EDB case).
    foreach(_asv_pg_lib IN ITEMS libpq libpgcommon_shlib libpgport_shlib)
        set(_asv_pg_names ${_asv_pg_lib}.a ${_asv_pg_lib}.lib)
        set(_asv_pg_dbg_names ${_asv_pg_lib}_d.a ${_asv_pg_lib}_d.lib)
        if(_asv_pg_lib MATCHES "^libpg")
            string(REGEX REPLACE "^lib" "" _asv_pg_nolib ${_asv_pg_lib})
            list(APPEND _asv_pg_names ${_asv_pg_nolib}.lib)
            list(APPEND _asv_pg_dbg_names ${_asv_pg_nolib}_d.lib)
        endif()
        find_library(ASV_PQXX_${_asv_pg_lib} NAMES ${_asv_pg_names}
            PATHS ${PostgreSQL_LIBRARY_DIRS} NO_DEFAULT_PATH REQUIRED)
        find_library(ASV_PQXX_${_asv_pg_lib}_DEBUG NAMES ${_asv_pg_dbg_names}
            PATHS ${PostgreSQL_LIBRARY_DIRS} NO_DEFAULT_PATH)
        if(ASV_PQXX_${_asv_pg_lib}_DEBUG)
            list(APPEND ASV_PQXX_STATIC_LIBPQ
                "$<$<CONFIG:Debug>:${ASV_PQXX_${_asv_pg_lib}_DEBUG}>"
                "$<$<NOT:$<CONFIG:Debug>>:${ASV_PQXX_${_asv_pg_lib}}>")
        else()
            set(ASV_PQXX_STATIC_LIBPQ_DEBUG OFF)
            list(APPEND ASV_PQXX_STATIC_LIBPQ ${ASV_PQXX_${_asv_pg_lib}})
        endif()
    endforeach()
    message(STATUS "libpqxx: static libpq ${ASV_PQXX_STATIC_LIBPQ}")
endif()

# When setting up the include paths, mention the binary tree's include
# directory *before* the source tree's include directory.  If the source tree
# happens to contain autoconf-generated config headers, we should still prefer
# the ones in the binary tree.
# cmake-lint: disable=C0301
macro(LIBRARY_TARGET_SETUP tgt)
    target_include_directories(${tgt}
        PUBLIC
            $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include>
            $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
            $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
        PRIVATE
            ${PostgreSQL_INCLUDE_DIRS}
    )
    if(WIN32)
        # ASI: static EDB libpq + ports OpenSSL; libintl stubs replace EDB's
        # libintl-9.dll/libiconv-2.dll (libpq messages stay untranslated)
        target_sources(${tgt} PRIVATE
            ${PROJECT_SOURCE_DIR}/src/win32/asv_libintl_stubs.cxx)
        target_link_libraries(${tgt} PRIVATE
            ${ASV_PQXX_STATIC_LIBPQ}
            OpenSSL::SSL OpenSSL::Crypto
            secur32 advapi32 shell32 wldap32
        )
        # libpq.a is built /MD (Release CRT); the Debug build uses /MDd
        # Only needed when Debug falls back to the release libs.
        if(NOT ASV_PQXX_STATIC_LIBPQ_DEBUG)
            target_link_options(${tgt} PRIVATE
                $<$<CONFIG:Debug>:/NODEFAULTLIB:MSVCRT>)
        endif()
        target_link_libraries(${tgt} PUBLIC wsock32 ws2_32)
    else()
        target_link_libraries(${tgt} PRIVATE PostgreSQL::PostgreSQL)
    endif()
    install(TARGETS ${tgt} EXPORT libpqxx-targets
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    )
    get_target_property(name ${tgt} NAME)
    get_target_property(output_name ${tgt} OUTPUT_NAME)
    # Unix-target symlink only; not for Windows targets, including the winx cross build
    if(NOT WIN32)
        # Create library symlink
        get_target_property(target_type ${tgt} TYPE)
        if(target_type STREQUAL "SHARED_LIBRARY")
            set(library_prefix ${CMAKE_SHARED_LIBRARY_PREFIX})
            set(library_suffix ${CMAKE_SHARED_LIBRARY_SUFFIX})
        elseif(target_type STREQUAL "STATIC_LIBRARY")
            set(library_prefix ${CMAKE_STATIC_LIBRARY_PREFIX})
            set(library_suffix ${CMAKE_STATIC_LIBRARY_SUFFIX})
        endif()
        list(APPEND noop_command "${CMAKE_COMMAND}" "-E" "true")
        list(
            APPEND create_symlink_command "${CMAKE_COMMAND}" "-E" "create_symlink" "${library_prefix}${output_name}${library_suffix}" "${library_prefix}${name}${library_suffix}")
        # `add_custom_command()` does nothing if the `OUTPUT_NAME` and `NAME`
        # properties are equal, otherwise it creates library symlink.
        add_custom_command(TARGET ${tgt} POST_BUILD
            COMMAND "$<IF:$<STREQUAL:${name},${output_name}>,${noop_command},${create_symlink_command}>"
            VERBATIM
            COMMAND_EXPAND_LISTS
            COMMENT "Ensure library symlink"
        )
        install(
            FILES ${CMAKE_CURRENT_BINARY_DIR}/${library_prefix}${name}${library_suffix}
            DESTINATION ${CMAKE_INSTALL_LIBDIR}
        )
    endif()
endmacro()
file(GLOB CXX_SOURCES *.cxx)
add_library(pqxx ${CXX_SOURCES})
add_library(libpqxx::pqxx ALIAS pqxx)
get_target_property(pqxx_target_type pqxx TYPE)
if(pqxx_target_type STREQUAL "SHARED_LIBRARY")
    target_compile_definitions(pqxx PUBLIC PQXX_SHARED)
endif()
# cmake-lint: disable=C0301
set_target_properties(
    pqxx PROPERTIES
    OUTPUT_NAME $<IF:$<PLATFORM_ID:Windows>,pqxx,pqxx-${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}>
)
LIBRARY_TARGET_SETUP(pqxx)

# Install pkg-config file.
# cmake-lint: disable=C0103
set(prefix ${CMAKE_INSTALL_PREFIX})
# cmake-lint: disable=C0103
set(exec_prefix \${prefix})
# cmake-lint: disable=C0103
set(libdir "\${prefix}/${CMAKE_INSTALL_LIBDIR}")
# cmake-lint: disable=C0103
set(includedir "\${prefix}/${CMAKE_INSTALL_INCLUDEDIR}")
set(VERSION ${PROJECT_VERSION})
configure_file(
    ${PROJECT_SOURCE_DIR}/libpqxx.pc.in ${PROJECT_BINARY_DIR}/libpqxx.pc)
install(FILES ${PROJECT_BINARY_DIR}/libpqxx.pc
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig
)
