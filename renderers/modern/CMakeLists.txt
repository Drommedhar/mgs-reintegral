add_library(psyz_renderer STATIC sdl3_gpu.c
    "${PSYZ_SOURCE_ROOT}/src/platform/sdl3_software.c")
target_include_directories(psyz_renderer PRIVATE
    "${PSYZ_SOURCE_ROOT}/include" "${PSYZ_SOURCE_ROOT}/src"
    "${PSYZ_SOURCE_ROOT}/src/platform"
    "${PSYZ_SOURCE_ROOT}/../external/SDL/src/video/khronos")
target_compile_definitions(psyz_renderer PRIVATE __psyz _CRT_SECURE_NO_WARNINGS)
target_link_libraries(psyz_renderer PUBLIC SDL3::SDL3)
set_property(TARGET psyz_renderer PROPERTY MGS_MODERN_RENDERER TRUE)
