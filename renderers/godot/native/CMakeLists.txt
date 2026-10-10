add_library(psyz_renderer STATIC
    "${PSYZ_SOURCE_ROOT}/src/platform/sdl3_gpu.c"
    "${PSYZ_SOURCE_ROOT}/src/platform/sdl3_software.c"
    "${CMAKE_CURRENT_LIST_DIR}/transport.c")
target_include_directories(psyz_renderer PRIVATE
    "${CMAKE_CURRENT_LIST_DIR}"
    "${PSYZ_SOURCE_ROOT}/include"
    "${PSYZ_SOURCE_ROOT}/../external/SDL/src/video/khronos")
target_compile_definitions(psyz_renderer PRIVATE
    __psyz _CRT_SECURE_NO_WARNINGS PSYZ_GODOT_REMOTE)
target_link_libraries(psyz_renderer PUBLIC SDL3::SDL3)
set_property(TARGET psyz_renderer PROPERTY MGS_GODOT_SCENE TRUE)
if(WIN32)
    target_link_libraries(psyz_renderer PRIVATE ws2_32)
endif()
