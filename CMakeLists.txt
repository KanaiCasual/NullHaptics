cmake_minimum_required(VERSION 3.16)
project(nullhaptics C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(MINHOOK_DIR ${CMAKE_SOURCE_DIR}/third_party/minhook)

# ---- the SteamVR driver (embedded into the installer) ---------------------
add_library(driver_nullhaptics SHARED
    src/driver.cpp
    ${MINHOOK_DIR}/src/buffer.c
    ${MINHOOK_DIR}/src/hook.c
    ${MINHOOK_DIR}/src/trampoline.c
    ${MINHOOK_DIR}/src/hde/hde32.c
    ${MINHOOK_DIR}/src/hde/hde64.c
)
target_include_directories(driver_nullhaptics PRIVATE
    ${CMAKE_SOURCE_DIR}/third_party
    ${MINHOOK_DIR}/include
)
set_target_properties(driver_nullhaptics PROPERTIES PREFIX "" OUTPUT_NAME "driver_NullHaptics")

# Stage the files the installer embeds, next to the generated .rc.
set(EMBED_DIR ${CMAKE_BINARY_DIR}/embed)
add_custom_command(TARGET driver_nullhaptics POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory ${EMBED_DIR}
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:driver_nullhaptics> ${EMBED_DIR}/driver_NullHaptics.dll
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/package/driver.vrdrivermanifest ${EMBED_DIR}/driver.vrdrivermanifest
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/package/resources/settings/default.vrsettings ${EMBED_DIR}/default.vrsettings
)

file(COPY ${CMAKE_SOURCE_DIR}/assets/app.ico DESTINATION ${EMBED_DIR})
file(COPY ${CMAKE_SOURCE_DIR}/assets/logo-256.png DESTINATION ${EMBED_DIR})
file(COPY ${CMAKE_SOURCE_DIR}/package/app.manifest DESTINATION ${EMBED_DIR})

# Resource IDs must match src/setup.cpp.
file(WRITE ${EMBED_DIR}/setup.rc
"1 24 \"app.manifest\"\n"
"1 ICON \"app.ico\"\n"
"101 RCDATA \"driver_NullHaptics.dll\"\n"
"102 RCDATA \"driver.vrdrivermanifest\"\n"
"103 RCDATA \"default.vrsettings\"\n"
"104 RCDATA \"logo-256.png\"\n"
)

# ---- the installer (self-contained GUI, single exe) -----------------------
add_executable(nullhaptics_setup WIN32 src/setup.cpp ${EMBED_DIR}/setup.rc)
set_target_properties(nullhaptics_setup PROPERTIES
    OUTPUT_NAME "NullHaptics-setup"
    LINK_FLAGS "/MANIFEST:NO"          # our app.manifest is the only one
)
target_compile_definitions(nullhaptics_setup PRIVATE UNICODE _UNICODE)
target_link_libraries(nullhaptics_setup PRIVATE gdiplus ole32 uxtheme dwmapi)
add_dependencies(nullhaptics_setup driver_nullhaptics)

add_custom_command(TARGET nullhaptics_setup POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_SOURCE_DIR}/dist
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:nullhaptics_setup> ${CMAKE_SOURCE_DIR}/dist/
)
