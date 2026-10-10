cmake_minimum_required(VERSION 3.24)
project(MGSIntegralNative VERSION 0.1.0 LANGUAGES C CXX)
set(MGS_RELEASE_VERSION "0.1.0-alpha.1" CACHE STRING "Release version")
set(MGS_BUILD_COMMIT "local" CACHE STRING "Source commit")
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
configure_file(include/mgs_build.h.in mgs_build.h @ONLY)

if(NOT WIN32 OR NOT CMAKE_SIZEOF_VOID_P EQUAL 4)
    message(FATAL_ERROR "The initial native target requires Windows x86.")
endif()

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_EXTENSIONS ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
find_package(Python3 REQUIRED COMPONENTS Interpreter)
set(MGS_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/vendor/mgs")
set(MGS_NATIVE_ROOT "${CMAKE_CURRENT_BINARY_DIR}/native-source")
file(GLOB_RECURSE MGS_SOURCE_INPUTS CONFIGURE_DEPENDS
    "${MGS_ROOT}/source/*.c" "${MGS_ROOT}/source/*.h" "${MGS_ROOT}/source/*.cnf")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${MGS_SOURCE_INPUTS}
    "${CMAKE_CURRENT_SOURCE_DIR}/config/stages.json"
    "${CMAKE_CURRENT_SOURCE_DIR}/tools/generate_sources.py"
    "${CMAKE_CURRENT_SOURCE_DIR}/tools/native_encoding.py"
    "${CMAKE_CURRENT_SOURCE_DIR}/tools/native_overlay.py")

execute_process(
    COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tools/generate_sources.py"
            --source "${MGS_ROOT}" --output "${CMAKE_CURRENT_BINARY_DIR}/mgs_sources.cmake"
            --config "${CMAKE_CURRENT_SOURCE_DIR}/config/stages.json"
    RESULT_VARIABLE source_result
)
if(NOT source_result EQUAL 0)
    message(FATAL_ERROR "Could not resolve the recovered MGS source list.")
endif()
include("${CMAKE_CURRENT_BINARY_DIR}/mgs_sources.cmake")

set(MGS_RENDERER_MODULE "" CACHE PATH "Directory providing an external PsyZ renderer target")
if(MGS_RENDERER_MODULE)
    get_filename_component(PSYZ_RENDERER_MODULE "${MGS_RENDERER_MODULE}" ABSOLUTE
        BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
    set(PSYZ_RENDERER external CACHE STRING "PsyZ renderer" FORCE)
else()
    set(PSYZ_RENDERER sdl3_gpu CACHE STRING "PsyZ renderer" FORCE)
endif()

add_subdirectory(vendor/psyz/psyz)
target_compile_definitions(psyz PRIVATE PSYZ_POLL_IRQ_ONLY _CRT_SECURE_NO_WARNINGS)
target_sources(psyz PRIVATE vendor/psyz/psyz/src/psyz/vlc.c vendor/psyz/psyz/src/psyz/mdec_decode.c)
add_library(mgs_game STATIC ${MGS_SOURCES})
target_include_directories(mgs_game BEFORE PRIVATE include "${MGS_NATIVE_ROOT}" "${MGS_NATIVE_ROOT}/include")
target_link_libraries(mgs_game PUBLIC psyz)
target_compile_definitions(mgs_game PRIVATE INTEGRAL MGS_NATIVE _CRT_SECURE_NO_WARNINGS)
target_compile_options(mgs_game PRIVATE -fno-strict-aliasing -fwrapv -funsigned-char -Wno-deprecated-non-prototype -Werror=unknown-pragmas
    -include "${CMAKE_CURRENT_SOURCE_DIR}/include/mgs_native.h")
set_source_files_properties("${MGS_NATIVE_ROOT}/main/main.c" PROPERTIES COMPILE_DEFINITIONS "main=mgs_main")
set_source_files_properties("${MGS_NATIVE_ROOT}/libsio/dummy.c" PROPERTIES COMPILE_DEFINITIONS "getchar=mgs_sio_getchar")

add_executable(mgs-integral-native src/main.c src/mgs_disc.c src/mgs_memory.c src/mgs_stages.c src/mgs_overlay.c src/mgs_log.c
    src/mgs_threads.c src/mgs_gte.c src/mgs_math.c src/mgs_gpu.c src/mgs_mods.c src/mgs_sdk.c src/mgs_rotation.c src/mgs_sight.c src/mgs_capture.c src/mgs_probe.c src/mgs_dock_route.c src/mgs_cadence.c src/mgs_player.c src/mgs_pocket_device.c
    src/mgs_bonus_items.c src/mgs_invulnerability.c src/mgs_game_options.c src/mgs_input_movie.c src/mgs_input_log.c src/mgs_controller_ports.c src/mgs_mantis_memory.c src/mgs_checkpoint.c src/mgs_ending_probe.c
    src/mgs_completed_load_probe.c src/mgs_escape_route.c src/mgs_rex_probe.c src/mgs_liquid_probe.c
    src/mgs_garage_route.c src/mgs_video.c src/mgs_visibility.c src/mgs_frame_timing.c
    src/mgs_texture_correction.c)
target_include_directories(mgs-integral-native PRIVATE include "${MGS_NATIVE_ROOT}" "${MGS_NATIVE_ROOT}/include"
    "${CMAKE_CURRENT_BINARY_DIR}")
target_link_libraries(mgs-integral-native PRIVATE mgs_game)
if(TARGET psyz_renderer)
    get_target_property(mgs_godot_scene psyz_renderer MGS_GODOT_SCENE)
endif()
if(mgs_godot_scene)
    target_compile_definitions(mgs_game PRIVATE MGS_GODOT_SCENE)
    target_compile_definitions(mgs-integral-native PRIVATE MGS_GODOT_SCENE)
    target_sources(mgs-integral-native PRIVATE src/mgs_godot_scene.c)
    target_include_directories(mgs-integral-native PRIVATE renderers/godot/native)
endif()
target_link_options(mgs-integral-native PRIVATE -Xlinker /errorlimit:0)
psyz_title(mgs-integral-native "RE:INTEGRAL")
# Supply UAC in app.manifest; LLD's default UAC merge corrupts its namespaces.
target_link_options(mgs-integral-native PRIVATE
    "-Wl,/manifest:embed" "-Wl,/manifestuac:no"
    "-Wl,/manifestinput:${CMAKE_CURRENT_SOURCE_DIR}/launcher/app.manifest")
set_property(TARGET mgs-integral-native APPEND PROPERTY LINK_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/launcher/app.manifest")

include(CTest)
set(MGS_MODERN_RENDERER false)
if(TARGET psyz_renderer)
    get_target_property(mgs_modern_renderer psyz_renderer MGS_MODERN_RENDERER)
    if(mgs_modern_renderer)
        set(MGS_MODERN_RENDERER true)
    endif()
endif()
add_subdirectory(launcher)
if(BUILD_TESTING)
    add_executable(mgs_texture_correction_test tests/mgs_texture_correction_test.c src/mgs_texture_correction.c)
    target_include_directories(mgs_texture_correction_test PRIVATE include vendor/psyz/psyz/include)
    target_compile_definitions(mgs_texture_correction_test PRIVATE __psyz)
    target_compile_options(mgs_texture_correction_test PRIVATE -UNDEBUG)
    add_test(NAME mgs_texture_correction_test COMMAND mgs_texture_correction_test)
    if(mgs_modern_renderer)
        add_executable(mgs_modern_gpu_test tests/mgs_modern_gpu_test.c)
        target_link_libraries(mgs_modern_gpu_test PRIVATE psyz)
        target_compile_options(mgs_modern_gpu_test PRIVATE -UNDEBUG)
        foreach(scale IN ITEMS 1 4)
            add_test(NAME mgs_modern_gpu_${scale}x_test COMMAND mgs_modern_gpu_test ${scale})
            set_tests_properties(mgs_modern_gpu_${scale}x_test PROPERTIES ENVIRONMENT "SDL_VIDEODRIVER=offscreen" LABELS "gpu")
        endforeach()
    endif()
    add_executable(mgs_frame_timing_test tests/mgs_frame_timing_test.c src/mgs_frame_timing.c)
    target_include_directories(mgs_frame_timing_test PRIVATE include)
    target_compile_options(mgs_frame_timing_test PRIVATE -UNDEBUG)
    add_test(NAME mgs_frame_timing_test COMMAND mgs_frame_timing_test)
    add_test(NAME performance_analysis COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_performance.py")
    execute_process(COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_video_config_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/video_config_helpers.inc"
        RESULT_VARIABLE video_config_result)
    if(NOT video_config_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare video configuration regression")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        tests/prepare_video_config_test.py tests/prepare_mantis_test.py
        vendor/psyz/psyz/src/platform/sdl3_gpu.c vendor/psyz/psyz/src/platform/sdl3_common.h)
    add_executable(mgs_video_config_test tests/mgs_video_config_test.c)
    target_include_directories(mgs_video_config_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        vendor/psyz/external/SDL/include)
    target_compile_options(mgs_video_config_test PRIVATE -UNDEBUG)
    add_test(NAME mgs_video_config_test COMMAND mgs_video_config_test)
    execute_process(COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_video_effects_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/video_effects_helpers.inc"
        RESULT_VARIABLE video_effects_result)
    if(NOT video_effects_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare framebuffer effect regression")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        tests/prepare_video_effects_test.py tests/prepare_mantis_test.py
        vendor/mgs/source/takabe/wt_view.c vendor/mgs/source/okajima/blur.c
        vendor/mgs/source/okajima/blurpure.c vendor/mgs/source/takabe/focus.c)
    foreach(effect_index RANGE 0 3)
        add_executable(mgs_video_effect_${effect_index}_test tests/mgs_video_effects_test.c)
        target_include_directories(mgs_video_effect_${effect_index}_test PRIVATE
            "${CMAKE_CURRENT_BINARY_DIR}" include vendor/mgs/source
            vendor/mgs/source/include vendor/psyz/psyz/include)
        target_compile_definitions(mgs_video_effect_${effect_index}_test PRIVATE
            MGS_EFFECT=${effect_index} __psyz MGS_NATIVE INTEGRAL)
        target_compile_options(mgs_video_effect_${effect_index}_test PRIVATE -UNDEBUG)
        add_test(NAME mgs_video_effect_${effect_index}_test COMMAND mgs_video_effect_${effect_index}_test)
    endforeach()
    execute_process(COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_wide_environment_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/wide_environment_helpers.inc"
        RESULT_VARIABLE wide_environment_result)
    if(NOT wide_environment_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare widescreen environment regression")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        tests/prepare_wide_environment_test.py tests/prepare_mantis_test.py
        vendor/mgs/source/thing/sphere.c vendor/mgs/source/thing/sphere2.c
        vendor/mgs/source/takabe/gas_efct.c)
    foreach(environment_index RANGE 0 2)
        add_executable(mgs_wide_environment_${environment_index}_test
            tests/mgs_wide_environment_test.c src/mgs_math.c)
        target_include_directories(mgs_wide_environment_${environment_index}_test PRIVATE
            "${CMAKE_CURRENT_BINARY_DIR}" include vendor/mgs/source vendor/mgs/source/include)
        target_link_libraries(mgs_wide_environment_${environment_index}_test PRIVATE psyz)
        target_compile_definitions(mgs_wide_environment_${environment_index}_test PRIVATE
            MGS_ENVIRONMENT=${environment_index} MGS_NATIVE INTEGRAL)
        target_compile_options(mgs_wide_environment_${environment_index}_test PRIVATE -UNDEBUG)
        add_test(NAME mgs_wide_environment_${environment_index}_test
            COMMAND mgs_wide_environment_${environment_index}_test)
    endforeach()
    execute_process(COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_visibility_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/visibility_helpers.inc"
        RESULT_VARIABLE visibility_result)
    if(NOT visibility_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare gameplay visibility regression")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        tests/prepare_visibility_test.py vendor/mgs/source/libdg/bound.c
        vendor/mgs/source/libdg/chanl.c)
    add_executable(mgs_visibility_test tests/mgs_visibility_test.c src/mgs_visibility.c)
    target_include_directories(mgs_visibility_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        include vendor/mgs/source vendor/mgs/source/include vendor/psyz/psyz/include)
    target_compile_definitions(mgs_visibility_test PRIVATE __psyz MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_visibility_test PRIVATE -UNDEBUG)
    add_test(NAME mgs_visibility_test COMMAND mgs_visibility_test)
    execute_process(COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_fog_visibility_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/fog_visibility_helpers.inc"
        RESULT_VARIABLE fog_visibility_result)
    if(NOT fog_visibility_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare fog gameplay visibility regression")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        tests/prepare_fog_visibility_test.py tests/prepare_mantis_test.py
        vendor/mgs/source/takabe/libdg2.c)
    add_executable(mgs_fog_visibility_test tests/mgs_fog_visibility_test.c src/mgs_visibility.c)
    target_include_directories(mgs_fog_visibility_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        include vendor/mgs/source vendor/mgs/source/include vendor/psyz/psyz/include)
    target_compile_definitions(mgs_fog_visibility_test PRIVATE __psyz MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_fog_visibility_test PRIVATE -UNDEBUG)
    add_test(NAME mgs_fog_visibility_test COMMAND mgs_fog_visibility_test)
    find_program(MGS_PWSH pwsh REQUIRED)
    add_test(NAME video_cli COMMAND "${MGS_PWSH}" -NoProfile -File
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_video_cli.ps1"
        -Executable $<TARGET_FILE:mgs-integral-native>)
    execute_process(COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_widescreen_clip_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/widescreen_clip_helpers.inc"
        RESULT_VARIABLE widescreen_clip_result)
    if(NOT widescreen_clip_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare widescreen clipping regression")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        tests/prepare_widescreen_clip_test.py vendor/mgs/source/libdg/bound.c
        vendor/mgs/source/libdg/trans.c vendor/mgs/source/libdg/divide.c
        vendor/mgs/source/libdg/frame.c)
    add_executable(mgs_widescreen_clip_test tests/mgs_widescreen_clip_test.c)
    target_include_directories(mgs_widescreen_clip_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        include vendor/mgs/source vendor/mgs/source/include vendor/psyz/psyz/include)
    target_compile_definitions(mgs_widescreen_clip_test PRIVATE __psyz MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_widescreen_clip_test PRIVATE -UNDEBUG)
    add_test(NAME mgs_widescreen_clip_test COMMAND mgs_widescreen_clip_test)
    add_executable(mgs_video_test tests/mgs_video_test.c src/mgs_video.c)
    target_include_directories(mgs_video_test PRIVATE include vendor/psyz/psyz/include)
    target_compile_definitions(mgs_video_test PRIVATE __psyz)
    target_compile_options(mgs_video_test PRIVATE -UNDEBUG)
    foreach(video_case IN ITEMS parse default wide auto original oversize aspect)
        add_test(NAME mgs_video_${video_case}_test COMMAND mgs_video_test ${video_case})
    endforeach()
    add_test(NAME input_session COMMAND "${MGS_PWSH}" -NoProfile -File
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_input_session.ps1")
    add_test(NAME input_resume COMMAND "${Python3_EXECUTABLE}" -m unittest tests.test_input_resume)
    set_tests_properties(input_resume PROPERTIES WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
    add_test(NAME input_paths COMMAND "${MGS_PWSH}" -NoProfile -File
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_input_paths.ps1"
        -Executable $<TARGET_FILE:mgs-integral-native>)
    add_test(NAME bk2_inspection COMMAND "${Python3_EXECUTABLE}" -m unittest tests.test_bk2)
    set_tests_properties(bk2_inspection PROPERTIES WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
    add_executable(mgs_pad_poll_hook_test tests/test_pad_poll_hook.c
        vendor/psyz/psyz/src/psyz/libapi.c vendor/psyz/psyz/src/psyz/clock.c)
    target_include_directories(mgs_pad_poll_hook_test PRIVATE vendor/psyz/psyz/include)
    target_compile_definitions(mgs_pad_poll_hook_test PRIVATE __psyz PSYZ_POLL_IRQ_ONLY)
    target_compile_options(mgs_pad_poll_hook_test PRIVATE -UNDEBUG)
    add_test(NAME mgs_pad_poll_hook_test COMMAND mgs_pad_poll_hook_test)
    add_executable(mgs_input_log_test tests/mgs_input_log_test.c src/mgs_input_log.c)
    target_include_directories(mgs_input_log_test PRIVATE include)
    target_compile_options(mgs_input_log_test PRIVATE -UNDEBUG)
    add_test(NAME mgs_input_log_test COMMAND mgs_input_log_test)
    add_executable(mgs_input_movie_test tests/mgs_input_movie_test.c
        src/mgs_input_movie.c src/mgs_input_log.c)
    target_include_directories(mgs_input_movie_test PRIVATE include vendor/mgs/source
        vendor/mgs/source/include vendor/psyz/psyz/include)
    target_compile_definitions(mgs_input_movie_test PRIVATE __psyz MGS_NATIVE INTEGRAL)
    add_test(NAME mgs_input_movie_test COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_input_movie.py" $<TARGET_FILE:mgs_input_movie_test>)
    set_tests_properties(mgs_input_movie_test PROPERTIES TIMEOUT 30)
    add_executable(mgs_bonus_items_test tests/mgs_bonus_items_test.c src/mgs_bonus_items.c
        vendor/mgs/source/libgcl/variable.c vendor/mgs/source/libgv/strcode.c)
    target_include_directories(mgs_bonus_items_test PRIVATE include
        vendor/mgs/source vendor/mgs/source/include)
    target_compile_definitions(mgs_bonus_items_test PRIVATE __psyz MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_bonus_items_test PRIVATE -UNDEBUG -fno-strict-aliasing -fwrapv
        -include "${CMAKE_CURRENT_SOURCE_DIR}/include/mgs_native.h")
    target_link_libraries(mgs_bonus_items_test PRIVATE psyz)
    add_test(NAME mgs_bonus_items_test COMMAND mgs_bonus_items_test)
    add_executable(mgs_game_options_test tests/mgs_game_options_test.c
        src/mgs_game_options.c vendor/mgs/source/libgcl/expr.c)
    target_include_directories(mgs_game_options_test PRIVATE include
        vendor/mgs/source vendor/mgs/source/include vendor/psyz/psyz/include)
    target_compile_definitions(mgs_game_options_test PRIVATE __psyz MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_game_options_test PRIVATE -UNDEBUG -fwrapv
        -include "${CMAKE_CURRENT_SOURCE_DIR}/include/mgs_native.h")
    add_test(NAME mgs_game_options_test COMMAND mgs_game_options_test)
    foreach(check IN ITEMS invulnerability tank_gunner tank_camera)
        execute_process(COMMAND "${Python3_EXECUTABLE}"
            "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_${check}_test.py"
            --output "${CMAKE_CURRENT_BINARY_DIR}/${check}_helpers.inc"
            RESULT_VARIABLE player_check_result)
        if(NOT player_check_result EQUAL 0)
            message(FATAL_ERROR "Could not prepare ${check} regression")
        endif()
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
            "tests/prepare_${check}_test.py")
        add_executable(mgs_${check}_test tests/mgs_${check}_test.c)
        target_include_directories(mgs_${check}_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
            include vendor/mgs/source vendor/mgs/source/include)
        target_compile_definitions(mgs_${check}_test PRIVATE __psyz MGS_NATIVE INTEGRAL)
        target_compile_options(mgs_${check}_test PRIVATE -UNDEBUG -fwrapv -fno-strict-aliasing)
        target_link_libraries(mgs_${check}_test PRIVATE psyz)
        add_test(NAME mgs_${check}_test COMMAND mgs_${check}_test)
    endforeach()
    target_sources(mgs_invulnerability_test PRIVATE src/mgs_invulnerability.c)
    target_sources(mgs_tank_gunner_test PRIVATE src/mgs_math.c)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        vendor/mgs/source/chara/snake/sna_init.c vendor/mgs/source/overlays/s05a/kojo/m1e1sold.c
        vendor/mgs/source/overlays/s05a/kojo/m1e1came.c vendor/mgs/source/libgv/actor.c)
    add_executable(mgs_checkpoint_test tests/mgs_checkpoint_test.c src/mgs_checkpoint.c
        src/mgs_bonus_items.c vendor/mgs/source/libgcl/variable.c
        vendor/mgs/source/libgv/strcode.c vendor/mgs/source/game/area.c)
    target_include_directories(mgs_checkpoint_test PRIVATE include
        vendor/mgs/source vendor/mgs/source/include)
    target_compile_definitions(mgs_checkpoint_test PRIVATE __psyz MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_checkpoint_test PRIVATE -UNDEBUG -fno-strict-aliasing -fwrapv
        -include "${CMAKE_CURRENT_SOURCE_DIR}/include/mgs_native.h")
    target_link_libraries(mgs_checkpoint_test PRIVATE psyz)
    add_test(NAME mgs_checkpoint_test COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_checkpoint.py" $<TARGET_FILE:mgs_checkpoint_test>)
    set_tests_properties(mgs_checkpoint_test PROPERTIES TIMEOUT 30)
    execute_process(COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_item_callback_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/item_callback_helpers.inc"
        RESULT_VARIABLE item_callback_result)
    if(NOT item_callback_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare item callback regression")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        tests/prepare_item_callback_test.py vendor/mgs/source/game/item.c
        vendor/mgs/source/chara/torture/boxall.c)
    add_executable(mgs_item_callback_test tests/mgs_item_callback_test.c)
    target_include_directories(mgs_item_callback_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        include vendor/mgs/source vendor/mgs/source/include)
    target_compile_definitions(mgs_item_callback_test PRIVATE MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_item_callback_test PRIVATE -UNDEBUG)
    target_link_libraries(mgs_item_callback_test PRIVATE psyz)
    add_test(NAME mgs_item_callback_test COMMAND mgs_item_callback_test)
    add_executable(mgs_boxall_test tests/mgs_boxall_test.c)
    target_include_directories(mgs_boxall_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        include vendor/mgs/source vendor/mgs/source/include)
    target_compile_definitions(mgs_boxall_test PRIVATE MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_boxall_test PRIVATE -UNDEBUG)
    target_link_libraries(mgs_boxall_test PRIVATE psyz)
    add_test(NAME mgs_boxall_test COMMAND mgs_boxall_test)
    execute_process(COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_chaff_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/chaff_helpers.inc"
        RESULT_VARIABLE chaff_result)
    if(NOT chaff_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare chaff particle regression")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        tests/prepare_chaff_test.py vendor/mgs/source/okajima/chafgrnd.c
        vendor/mgs/source/libdg/prim.c)
    add_executable(mgs_chaff_test tests/mgs_chaff_test.c)
    target_include_directories(mgs_chaff_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        include vendor/mgs/source vendor/mgs/source/include vendor/psyz/psyz/include)
    target_compile_definitions(mgs_chaff_test PRIVATE __psyz MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_chaff_test PRIVATE -UNDEBUG -fno-strict-aliasing)
    add_test(NAME mgs_chaff_test COMMAND mgs_chaff_test)
    add_executable(mgs_stage_registry_test tests/mgs_stage_registry_test.c src/mgs_overlay.c)
    target_include_directories(mgs_stage_registry_test PRIVATE tests/stage_registry include
        "${MGS_ROOT}/source/include")
    target_compile_options(mgs_stage_registry_test PRIVATE -UNDEBUG)
    add_test(NAME stage_registry COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_stage_registry.py"
        $<TARGET_FILE:mgs_stage_registry_test>)
    add_executable(mgs_pocket_device_test tests/mgs_pocket_device_test.c src/mgs_pocket_device.c)
    target_include_directories(mgs_pocket_device_test PRIVATE include)
    target_compile_options(mgs_pocket_device_test PRIVATE -UNDEBUG)
    add_test(NAME pocket_device COMMAND mgs_pocket_device_test)
    add_executable(mgs_host_file_test tests/mgs_host_file_test.c)
    target_include_directories(mgs_host_file_test PRIVATE include)
    target_compile_options(mgs_host_file_test PRIVATE -UNDEBUG)
    target_link_libraries(mgs_host_file_test PRIVATE psyz)
    add_test(NAME host_files COMMAND mgs_host_file_test "${CMAKE_CURRENT_BINARY_DIR}/host-file-test.bin")
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_overlay_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/overlay-test" RESULT_VARIABLE overlay_test_result)
    if(NOT overlay_test_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare overlay data tests.")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        tests/prepare_overlay_test.py tests/overlay_actor_a.c tests/overlay_actor_b.c)
    add_executable(mgs_overlay_test tests/mgs_overlay_test.c src/mgs_overlay.c
        "${CMAKE_CURRENT_BINARY_DIR}/overlay-test/overlay_actor_a.c"
        "${CMAKE_CURRENT_BINARY_DIR}/overlay-test/overlay_actor_b.c")
    target_include_directories(mgs_overlay_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/overlay-test")
    add_executable(mgs_safety_probe tests/mgs_safety_probe.c src/mgs_safety.c)
    target_include_directories(mgs_safety_probe PRIVATE include)
    add_test(NAME safety COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_safety.py"
        $<TARGET_FILE:mgs_safety_probe>)
    set_tests_properties(safety PROPERTIES WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" TIMEOUT 30)
    add_executable(mgs_disc_test tests/mgs_disc_test.c src/mgs_disc.c src/mgs_safety.c)
    target_include_directories(mgs_disc_test PRIVATE include)
    target_compile_options(mgs_disc_test PRIVATE -UNDEBUG)
    target_link_libraries(mgs_disc_test PRIVATE psyz)
    add_test(NAME disc_change COMMAND "${Python3_EXECUTABLE}" -m tests.test_disc_change
        $<TARGET_FILE:mgs_disc_test>)
    set_tests_properties(disc_change PROPERTIES WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" TIMEOUT 30)
    add_executable(mgs_save_test tests/mgs_save_test.c)
    target_link_libraries(mgs_save_test PRIVATE mgs_game)
    target_compile_options(mgs_save_test PRIVATE -UNDEBUG)
    add_test(NAME native_saves COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_saves.py"
        $<TARGET_FILE:mgs_save_test>)
    set_tests_properties(native_saves PROPERTIES WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" TIMEOUT 30)
    add_executable(mgs_vlc_test tests/test_vlc.c)
    add_executable(mgs_mdec_test tests/test_mdec_decode.c)
    foreach(movie_test IN ITEMS mgs_vlc_test mgs_mdec_test)
        target_include_directories(${movie_test} PRIVATE vendor/psyz/psyz/src/psyz)
    endforeach()
    add_executable(mgs_threads_test tests/mgs_threads_test.c src/mgs_threads.c)
    add_executable(mgs_gte_test tests/mgs_gte_test.c src/mgs_gte.c src/mgs_rotation.c)
    add_executable(mgs_math_test tests/mgs_math_test.c src/mgs_math.c)
    add_executable(mgs_rotation_test tests/mgs_rotation_test.c src/mgs_rotation.c)
    add_executable(mgs_fog_test tests/mgs_fog_test.c)
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_environment_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/environment_helpers.inc" RESULT_VARIABLE environment_test_result)
    if(NOT environment_test_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare environment mapping tests.")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS tests/prepare_environment_test.py
        vendor/mgs/source/takabe/envmap3.c vendor/mgs/source/takabe/sub_efct.c)
    add_executable(mgs_environment_test tests/mgs_environment_test.c)
    target_include_directories(mgs_environment_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        vendor/mgs/source vendor/mgs/source/include)
    target_compile_definitions(mgs_environment_test PRIVATE MGS_NATIVE)
    target_compile_options(mgs_environment_test PRIVATE -fno-strict-aliasing)

    foreach(recovered IN ITEMS countdown rex liquid liquid_dispatch liquid_climb boss_terminal torture tank_completion asiato garage garage_aim jeep_road jeep_driver escape_snake escape_liquid rank_pocket rank_pocket_worker pocket_entry pocket_entry_render pocket_back brf_render camera_card camera_state water)
        execute_process(COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_${recovered}_test.py"
            --output "${CMAKE_CURRENT_BINARY_DIR}/${recovered}_helpers.inc" RESULT_VARIABLE recovered_test_result)
        if(NOT recovered_test_result EQUAL 0)
            message(FATAL_ERROR "Could not prepare ${recovered} reference tests")
        endif()
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "tests/prepare_${recovered}_test.py")
    endforeach()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        vendor/mgs/source/overlays/s19b/menu/countdwn.c
        vendor/mgs/source/kojo/mgrex.c vendor/mgs/source/overlays/s17a/rex_data.c
        vendor/mgs/source/overlays/s17a/rex_native.h vendor/mgs/source/kojo/rex_particles.c
        vendor/mgs/source/overlays/s17a/rex_particles.h vendor/mgs/source/kojo/mg_laser.c
        vendor/mgs/source/kojo/mg_hatch.c vendor/mgs/source/kojo/mgrexlzr.c vendor/mgs/source/libgv/util.c)
    add_executable(mgs_countdown_test tests/mgs_countdown_test.c)
    add_executable(mgs_rex_helpers_test tests/mgs_rex_helpers_test.c src/mgs_math.c src/mgs_gte.c)
    add_executable(mgs_liquid_leaf_test tests/mgs_liquid_leaf_test.c)
    add_executable(mgs_liquid_dispatch_test tests/mgs_liquid_dispatch_test.c)
    add_executable(mgs_liquid_climb_test tests/mgs_liquid_climb_test.c)
    # Windows installer detection matches "patch" inside "dispatch" on unmanifested x86 tools.
    set_target_properties(mgs_liquid_dispatch_test PROPERTIES OUTPUT_NAME mgs_liquid_action_test)
    add_executable(mgs_boss_terminal_test tests/mgs_boss_terminal_test.c)
    add_executable(mgs_torture_test tests/mgs_torture_test.c)
    add_executable(mgs_tank_completion_test tests/mgs_tank_completion_test.c)
    add_executable(mgs_garage_aim_test tests/mgs_garage_aim_test.c src/mgs_gte.c src/mgs_rotation.c)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        vendor/mgs/source/chara/torture/torture.c
        tests/prepare_mantis_test.py vendor/mgs/source/overlays/s05a/kojo/m1e1act.c)
    add_executable(mgs_asiato_test tests/mgs_asiato_test.c)
    target_include_directories(mgs_asiato_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        include vendor/mgs/source vendor/mgs/source/include vendor/psyz/psyz/include)
    target_compile_definitions(mgs_asiato_test PRIVATE __psyz MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_asiato_test PRIVATE -UNDEBUG -fno-strict-aliasing)
    add_test(NAME mgs_asiato_test COMMAND mgs_asiato_test)
    add_executable(mgs_rex_probe_test tests/mgs_rex_probe_test.c)
    add_executable(mgs_liquid_probe_test tests/mgs_liquid_probe_test.c)
    foreach(probe_target IN ITEMS mgs_rex_probe_test mgs_liquid_probe_test)
        target_include_directories(${probe_target} PRIVATE
            include vendor/mgs/source vendor/mgs/source/include vendor/psyz/psyz/include)
        target_compile_definitions(${probe_target} PRIVATE __psyz MGS_NATIVE INTEGRAL)
        target_compile_options(${probe_target} PRIVATE -UNDEBUG -fno-strict-aliasing)
        add_test(NAME ${probe_target} COMMAND ${probe_target})
        set_tests_properties(${probe_target} PROPERTIES TIMEOUT 15)
    endforeach()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        tests/prepare_mantis_test.py vendor/mgs/source/libgv/near.c
        vendor/mgs/source/enemy/asiato.c)
    add_executable(mgs_snake18_state_test tests/mgs_snake18_state_test.c)
    add_executable(mgs_snake18_target_test tests/mgs_snake18_target_test.c)
    add_executable(mgs_snake18_wall_test tests/mgs_snake18_wall_test.c)
    add_executable(mgs_s19_action_test tests/mgs_s19_action_test.c)
    add_executable(mgs_s19_commander_test tests/mgs_s19_commander_test.c)
    add_executable(mgs_s19_timer_test tests/mgs_s19_timer_test.c)
    add_executable(mgs_s19_footprint_test tests/mgs_s19_footprint_test.c)
    add_executable(mgs_garage_state_test tests/mgs_garage_state_test.c)
    add_executable(mgs_jeep_road_test tests/mgs_jeep_road_test.c)
    add_executable(mgs_jeep_driver_test tests/mgs_jeep_driver_test.c)
    add_executable(mgs_rank_stats_test tests/mgs_rank_stats_test.c)
    add_executable(mgs_rank_award_test tests/mgs_rank_award_test.c)
    add_executable(mgs_rank_pocket_test tests/mgs_rank_pocket_test.c)
    add_executable(mgs_rank_pocket_state_test tests/mgs_rank_pocket_state_test.c)
    add_executable(mgs_rank_pocket_worker_test tests/mgs_rank_pocket_worker_test.c)
    add_executable(mgs_brf_draw_test tests/mgs_brf_draw_test.c)
    add_executable(mgs_brf_state_test tests/mgs_brf_state_test.c)
    add_executable(mgs_brf_decode_test tests/mgs_brf_decode_test.c)
    add_executable(mgs_brf_init_test tests/mgs_brf_init_test.c)
    add_executable(mgs_brf_graph_final_test tests/mgs_brf_graph_final_test.c)
    add_executable(mgs_brf_graph_early_test tests/mgs_brf_graph_early_test.c)
    add_executable(mgs_brf_camera_test tests/mgs_brf_camera_test.c)
    add_executable(mgs_brf_late_test tests/mgs_brf_late_test.c)
    add_executable(mgs_brf_core_test tests/mgs_brf_core_test.c)
    add_executable(mgs_brf_render_test tests/mgs_brf_render_test.c)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        vendor/mgs/source/overlays/brf/onoda/brf/graph_assets.c
        vendor/mgs/source/overlays/brf/onoda/brf/graph_layout.c
        vendor/mgs/source/overlays/brf/onoda/brf/graph_noise.c
        vendor/mgs/source/overlays/brf/onoda/brf/graph_render.c
        vendor/mgs/source/overlays/brf/onoda/brf/graph_motion.c
        vendor/mgs/source/overlays/brf/onoda/brf/graph_fog.c
        vendor/mgs/source/overlays/brf/onoda/brf/graph_data.c
        vendor/mgs/source/overlays/brf/onoda/brf/graph_native.h
        vendor/mgs/source/overlays/brf/overlay3.c)
    add_executable(mgs_pocket_entry_test tests/mgs_pocket_entry_test.c)
    add_executable(mgs_pocket_entry_render_test tests/mgs_pocket_entry_render_test.c)
    add_executable(mgs_pocket_back_test tests/mgs_pocket_back_test.c)
    add_executable(mgs_camera_controls_test tests/mgs_camera_controls_test.c)
    add_executable(mgs_camera_animation_test tests/mgs_camera_animation_test.c)
    add_executable(mgs_camera_photo_test tests/mgs_camera_photo_test.c)
    add_executable(mgs_camera_files_test tests/mgs_camera_files_test.c)
    add_executable(mgs_camera_card_test tests/mgs_camera_card_test.c)
    add_executable(mgs_camera_state_test tests/mgs_camera_state_test.c)
    add_executable(mgs_water_test tests/mgs_water_test.c)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        vendor/mgs/source/takabe/wt_view.c)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        vendor/mgs/source/overlays/camera/unknown/camera_card.c
        vendor/mgs/source/overlays/camera/unknown/camera.c)
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_camera_capture_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/camera_capture_helpers.inc" RESULT_VARIABLE camera_capture_result)
    if(NOT camera_capture_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare equipped-camera encoder regression")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        tests/prepare_camera_capture_test.py vendor/mgs/source/equip/jpegcam.c)
    add_executable(mgs_camera_capture_test tests/mgs_camera_capture_test.c src/mgs_memory.c)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        vendor/mgs/source/overlays/rank/chara/pocket/entry.c
        vendor/mgs/source/overlays/rank/chara/pocket/entry_state.c
        vendor/mgs/source/overlays/rank/chara/pocket/pkt_back.c
        vendor/mgs/source/overlays/rank/chara/pocket/entry_internal.h
        vendor/mgs/source/overlays/rank/chara/pocket/pocket_native.h
        vendor/mgs/source/overlays/rank/overlay2.c)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        vendor/mgs/source/overlays/rank/menu/pocket_card.c
        vendor/mgs/source/overlays/rank/menu/pocket_ui.c
        vendor/mgs/source/overlays/rank/menu/pocket_task.c)
    add_executable(mgs_rank_graphics_test tests/mgs_rank_graphics_test.c)
    add_executable(mgs_escape_snake_test tests/mgs_escape_snake_test.c)
    add_executable(mgs_escape_liquid_test tests/mgs_escape_liquid_test.c)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        vendor/mgs/source/overlays/s19b/takabe/jeep_sne/jeep_sne.c)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        vendor/mgs/source/overlays/s19b/takabe/jeep_mrl/jeep_mrl.c
        vendor/mgs/source/overlays/s19b/takabe/jeep_mrl/jeep_mrl_native.h
        vendor/mgs/source/overlays/s19b/jeep_vehicles.h)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        vendor/mgs/source/overlays/s19b/takabe/jeep_srl.c
        vendor/mgs/source/overlays/s19b/takabe/jeep_srl_native.h
        vendor/mgs/source/overlays/s19b/overlay2.c)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        vendor/mgs/source/overlays/s19a/props_native.h vendor/mgs/source/overlays/s19a/props_data.c
        vendor/mgs/source/overlays/s19a/props_snake.c vendor/mgs/source/overlays/s19a/props_companion.c)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        vendor/mgs/source/animal/liquid/liquid_think.c vendor/mgs/source/animal/liquid/liquid_tactics.c
        vendor/mgs/source/animal/liquid/liquid_sequence.c vendor/mgs/source/animal/liquid/liquid_native.h
        vendor/mgs/source/animal/liquid/liquid_action.c vendor/mgs/source/libhzd/near.c)
    foreach(recovered_target IN ITEMS mgs_water_test mgs_camera_state_test mgs_camera_card_test mgs_camera_capture_test mgs_camera_files_test mgs_camera_controls_test mgs_camera_animation_test mgs_camera_photo_test mgs_countdown_test mgs_rex_helpers_test mgs_liquid_leaf_test mgs_liquid_dispatch_test mgs_liquid_climb_test mgs_boss_terminal_test mgs_torture_test mgs_tank_completion_test mgs_snake18_state_test mgs_snake18_target_test mgs_snake18_wall_test mgs_s19_action_test mgs_s19_commander_test mgs_s19_timer_test mgs_s19_footprint_test mgs_garage_state_test mgs_garage_aim_test mgs_jeep_road_test mgs_jeep_driver_test mgs_rank_stats_test mgs_escape_snake_test mgs_escape_liquid_test mgs_rank_award_test mgs_rank_graphics_test mgs_rank_pocket_test mgs_pocket_entry_test mgs_pocket_entry_render_test mgs_rank_pocket_state_test mgs_pocket_back_test mgs_rank_pocket_worker_test mgs_brf_draw_test mgs_brf_state_test mgs_brf_decode_test mgs_brf_init_test mgs_brf_graph_final_test mgs_brf_graph_early_test mgs_brf_camera_test mgs_brf_late_test mgs_brf_core_test mgs_brf_render_test)
        target_include_directories(${recovered_target} PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
            include vendor/mgs/source vendor/mgs/source/include)
        target_compile_definitions(${recovered_target} PRIVATE MGS_NATIVE INTEGRAL)
        target_compile_options(${recovered_target} PRIVATE -UNDEBUG -fwrapv -fno-strict-aliasing -funsigned-char)
        target_link_libraries(${recovered_target} PRIVATE psyz)
        add_test(NAME ${recovered_target} COMMAND ${recovered_target})
        set_tests_properties(${recovered_target} PROPERTIES TIMEOUT 15)
    endforeach()

    add_executable(mgs_sight_test tests/mgs_sight_test.c src/mgs_sight.c)
    target_sources(mgs_escape_snake_test PRIVATE src/mgs_invulnerability.c)
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_claymore_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/claymore_helpers.inc" RESULT_VARIABLE claymore_test_result)
    if(NOT claymore_test_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare claymore trajectory regression")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        tests/prepare_claymore_test.py tests/prepare_mantis_test.py
        vendor/mgs/source/okajima/claymore.c vendor/mgs/source/libgv/util.c)
    add_executable(mgs_claymore_test tests/mgs_claymore_test.c)
    target_include_directories(mgs_claymore_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        include vendor/mgs/source vendor/mgs/source/include vendor/psyz/psyz/include)
    target_compile_definitions(mgs_claymore_test PRIVATE __psyz MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_claymore_test PRIVATE -UNDEBUG)
    add_test(NAME mgs_claymore_test COMMAND mgs_claymore_test)
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_s03d_commander_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/s03d_commander_helpers.inc" RESULT_VARIABLE s03d_commander_test_result)
    if(NOT s03d_commander_test_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare guard commander regressions")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        tests/prepare_s03d_commander_test.py tests/prepare_mantis_test.py
        vendor/mgs/source/overlays/s03d/animal/zako/zakocom.c
        vendor/mgs/source/animal/zako11e/zk11ecom.c
        vendor/mgs/source/animal/zako14/zako14com.c)
    add_executable(mgs_s14e_commander_test tests/mgs_s14e_commander_test.c)
    target_include_directories(mgs_s14e_commander_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        include vendor/mgs/source vendor/mgs/source/include vendor/psyz/psyz/include)
    target_compile_definitions(mgs_s14e_commander_test PRIVATE __psyz MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_s14e_commander_test PRIVATE -UNDEBUG)
    add_test(NAME mgs_s14e_commander_test COMMAND mgs_s14e_commander_test)
    add_executable(mgs_s11e_commander_test tests/mgs_s11e_commander_test.c)
    target_include_directories(mgs_s11e_commander_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        include vendor/mgs/source vendor/mgs/source/include vendor/psyz/psyz/include)
    target_compile_definitions(mgs_s11e_commander_test PRIVATE __psyz MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_s11e_commander_test PRIVATE -UNDEBUG)
    add_test(NAME mgs_s11e_commander_test COMMAND mgs_s11e_commander_test)
    add_executable(mgs_s03d_commander_test tests/mgs_s03d_commander_test.c)
    target_include_directories(mgs_s03d_commander_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        include vendor/mgs/source vendor/mgs/source/include vendor/psyz/psyz/include)
    target_compile_definitions(mgs_s03d_commander_test PRIVATE __psyz MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_s03d_commander_test PRIVATE -UNDEBUG)
    add_test(NAME mgs_s03d_commander_test COMMAND mgs_s03d_commander_test)
    add_executable(mgs_s10_demo_test tests/mgs_s10_demo_test.c)
    target_include_directories(mgs_s10_demo_test PRIVATE vendor/mgs/source vendor/mgs/source/include)
    add_executable(mgs_s10_meryl_test tests/mgs_s10_meryl_test.c)
    target_include_directories(mgs_s10_meryl_test PRIVATE vendor/mgs/source vendor/mgs/source/include)
    foreach(part IN ITEMS action think commander)
        add_executable(mgs_s10_zako_${part}_test tests/mgs_s10_zako_${part}_test.c)
        target_include_directories(mgs_s10_zako_${part}_test PRIVATE vendor/mgs/source vendor/mgs/source/include)
    endforeach()
    foreach(part IN ITEMS action think)
        add_executable(mgs_s14_${part}_test tests/mgs_s14_${part}_test.c)
        target_include_directories(mgs_s14_${part}_test PRIVATE include vendor/mgs/source vendor/mgs/source/include)
        target_compile_definitions(mgs_s14_${part}_test PRIVATE MGS_NATIVE INTEGRAL)
        target_compile_options(mgs_s14_${part}_test PRIVATE -UNDEBUG -fwrapv -fno-strict-aliasing -funsigned-char)
        target_link_libraries(mgs_s14_${part}_test PRIVATE psyz)
        add_test(NAME mgs_s14_${part}_test COMMAND mgs_s14_${part}_test)
        set_tests_properties(mgs_s14_${part}_test PROPERTIES TIMEOUT 15)
    endforeach()
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_mantis_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/mantis_helpers.inc" RESULT_VARIABLE mantis_test_result)
    if(NOT mantis_test_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare recovered Mantis helper tests.")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS tests/prepare_mantis_test.py
        vendor/mgs/source/libgv/util.c
        vendor/mgs/source/chara/psyco/mempsy.c
        vendor/mgs/source/overlays/s07b/chara/meryl07b/meryl07b.c
        vendor/mgs/source/overlays/s07b/chara/psyco/psyco.c)
    add_executable(mgs_mantis_helpers_test tests/mgs_mantis_helpers_test.c)
    target_include_directories(mgs_mantis_helpers_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        vendor/mgs/source vendor/mgs/source/include)
    target_compile_definitions(mgs_mantis_helpers_test PRIVATE MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_mantis_helpers_test PRIVATE -fwrapv -fno-strict-aliasing -funsigned-char)
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_ninja_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/ninja_helpers.inc" RESULT_VARIABLE ninja_test_result)
    if(NOT ninja_test_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare Ninja reference tests")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS tests/prepare_ninja_test.py
        vendor/mgs/source/overlays/s08b/animal/ninja/ninja.c
        vendor/mgs/source/overlays/s08b/animal/ninja/ninja_native_actions.h
        vendor/mgs/source/overlays/s08b/animal/ninja/ninja_native_combat.h
        vendor/mgs/source/overlays/s08b/animal/ninja/ninja_native_data.h
        vendor/mgs/source/overlays/s08b/animal/ninja/ninja_native_work.h)
    add_executable(mgs_ninja_helpers_test tests/mgs_ninja_helpers_test.c)
    target_include_directories(mgs_ninja_helpers_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        vendor/mgs/source vendor/mgs/source/include)
    target_compile_definitions(mgs_ninja_helpers_test PRIVATE MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_ninja_helpers_test PRIVATE -fwrapv -fno-strict-aliasing -funsigned-char)
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_hind_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/hind_helpers.inc" RESULT_VARIABLE hind_test_result)
    if(NOT hind_test_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare Hind reference test")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS tests/prepare_hind_test.py
        vendor/mgs/source/overlays/s11g/kojo/hindbody.c
        vendor/mgs/source/overlays/s11g/kojo/hindbody2.c
        vendor/mgs/source/overlays/s11g/okajima/11g_demo.c
        vendor/mgs/source/takabe/puthzd.c
        vendor/mgs/source/kojo/inverlt.c)
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_tower_demo_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/tower_demo_helpers.inc" RESULT_VARIABLE tower_demo_test_result)
    if(NOT tower_demo_test_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare tower cinematic reference test")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS tests/prepare_tower_demo_test.py
        vendor/mgs/source/overlays/s11b/okajima/11b_demo.c
        vendor/mgs/source/okajima/crsh_smk.c)
    add_executable(mgs_tower_demo_test tests/mgs_tower_demo_test.c)
    target_include_directories(mgs_tower_demo_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        vendor/mgs/source vendor/mgs/source/include)
    target_compile_definitions(mgs_tower_demo_test PRIVATE MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_tower_demo_test PRIVATE -fwrapv -fno-strict-aliasing -funsigned-char)
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_lens_flare_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/lens_flare_helpers.inc" RESULT_VARIABLE lens_flare_test_result)
    if(NOT lens_flare_test_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare lens-flare reference test")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS tests/prepare_lens_flare_test.py
        vendor/mgs/source/okajima/lens_fl.c)
    add_executable(mgs_lens_flare_test tests/mgs_lens_flare_test.c)
    target_include_directories(mgs_lens_flare_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        vendor/mgs/source vendor/mgs/source/include)
    target_compile_definitions(mgs_lens_flare_test PRIVATE MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_lens_flare_test PRIVATE -fwrapv -fno-strict-aliasing -funsigned-char)
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_rappel_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/rappel_helpers.inc" RESULT_VARIABLE rappel_test_result)
    if(NOT rappel_test_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare rappel reference test")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS tests/prepare_rappel_test.py
        vendor/mgs/source/overlays/s11d/chara/hind/hind.c
        vendor/mgs/source/overlays/s11d/chara/hind/hind_native.h)
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_rope_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/rope_helpers.inc" RESULT_VARIABLE rope_test_result)
    if(NOT rope_test_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare rope physics reference test")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS tests/prepare_rope_test.py
        vendor/mgs/source/overlays/s11d/chara/rope/rope.c
        vendor/mgs/source/overlays/s11d/chara/rope/rope_native_motion.h
        vendor/mgs/source/overlays/s11d/chara/rope/rope_native_setup.h)
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_jeep_packets_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/jeep_packets.inc" RESULT_VARIABLE jeep_packets_test_result)
    if(NOT jeep_packets_test_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare jeep packet regression test")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS tests/prepare_jeep_packets_test.py
        vendor/mgs/source/overlays/s19b/takabe/jeep/jspark.c)
    add_executable(mgs_jeep_packets_test tests/mgs_jeep_packets_test.c)
    target_include_directories(mgs_jeep_packets_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        vendor/mgs/source vendor/mgs/source/include)
    target_compile_definitions(mgs_jeep_packets_test PRIVATE MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_jeep_packets_test PRIVATE -fno-strict-aliasing)
    add_executable(mgs_rope_test tests/mgs_rope_test.c src/mgs_math.c)
    target_include_directories(mgs_rope_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        vendor/mgs/source vendor/mgs/source/include)
    target_compile_definitions(mgs_rope_test PRIVATE MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_rope_test PRIVATE -fwrapv -fno-strict-aliasing -funsigned-char)
    add_executable(mgs_rappel_test tests/mgs_rappel_test.c)
    target_include_directories(mgs_rappel_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        vendor/mgs/source vendor/mgs/source/include)
    target_compile_definitions(mgs_rappel_test PRIVATE MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_rappel_test PRIVATE -fwrapv -fno-strict-aliasing -funsigned-char)
    add_executable(mgs_hind_helpers_test tests/mgs_hind_helpers_test.c)
    target_include_directories(mgs_hind_helpers_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        vendor/mgs/source vendor/mgs/source/include)
    target_compile_definitions(mgs_hind_helpers_test PRIVATE MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_hind_helpers_test PRIVATE -fwrapv -fno-strict-aliasing -funsigned-char)
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/prepare_valcan_test.py"
        --output "${CMAKE_CURRENT_BINARY_DIR}/valcan_navigation.inc" RESULT_VARIABLE valcan_test_result)
    if(NOT valcan_test_result EQUAL 0)
        message(FATAL_ERROR "Could not prepare Valcan reference test")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS tests/prepare_valcan_test.py
        vendor/mgs/source/overlays/s15c/okajima/valcan/valcan.c)
    add_executable(mgs_valcan_navigation_test tests/mgs_valcan_navigation_test.c)
    target_include_directories(mgs_valcan_navigation_test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}"
        vendor/mgs/source vendor/mgs/source/include)
    target_compile_definitions(mgs_valcan_navigation_test PRIVATE MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_valcan_navigation_test PRIVATE -fwrapv -fno-strict-aliasing -funsigned-char)
    add_executable(mgs_dyncon_state_test tests/mgs_dyncon_state_test.c)
    target_include_directories(mgs_dyncon_state_test PRIVATE vendor/mgs/source vendor/mgs/source/include)
    target_compile_definitions(mgs_dyncon_state_test PRIVATE MGS_NATIVE INTEGRAL)
    target_compile_options(mgs_dyncon_state_test PRIVATE -fwrapv -fno-strict-aliasing -funsigned-char)
    add_executable(mgs_dyncon_geometry_test tests/mgs_dyncon_geometry_test.c src/mgs_math.c)
    target_include_directories(mgs_dyncon_geometry_test PRIVATE vendor/mgs/source vendor/mgs/source/include)
    target_compile_definitions(mgs_dyncon_geometry_test PRIVATE MGS_NATIVE)
    target_compile_options(mgs_dyncon_geometry_test PRIVATE -fwrapv -fno-strict-aliasing)
    add_executable(mgs_mods_test tests/test_mods.c src/mgs_mods.c)
    add_executable(mgs_sdk_test tests/mgs_sdk_test.c src/mgs_sdk.c src/mgs_controller_ports.c)
    target_include_directories(mgs_sdk_test PRIVATE vendor/mgs/source vendor/mgs/source/include)
    target_compile_definitions(mgs_sdk_test PRIVATE MGS_NATIVE INTEGRAL)
    add_executable(mgs_cd_test tests/test_cd.c)
    add_executable(mgs_audio_test tests/test_audio.c)
    add_executable(mgs_spu_sweep_test tests/test_spu_sweep.c)
    add_executable(mgs_spu_irq_clock_test tests/test_spu_irq_clock.c src/mgs_threads.c)
    add_executable(mgs_replay_clock_test tests/test_replay_clock.c)
    target_compile_options(mgs_replay_clock_test PRIVATE -UNDEBUG)
    target_link_libraries(mgs_replay_clock_test PRIVATE psyz)
    add_test(NAME mgs_replay_clock_test COMMAND mgs_replay_clock_test)
    set_tests_properties(mgs_replay_clock_test PROPERTIES TIMEOUT 15)
    add_executable(mgs_gpu_feedback_test tests/test_gpu_feedback.c src/mgs_gpu.c)
    add_executable(mgs_gpu_mask_test tests/test_gpu_mask.c)
    add_executable(mgs_gpu_upload_arena_test tests/test_gpu_upload_arena.c)
    add_executable(mgs_gpu_edges_test tests/mgs_gpu_edges_test.c)
    target_include_directories(mgs_gpu_edges_test PRIVATE vendor/psyz/psyz/src)
    add_test(NAME mgs_software_edges_test COMMAND mgs_gpu_edges_test software)
    set_tests_properties(mgs_software_edges_test PROPERTIES TIMEOUT 15)
    add_executable(mgs_gpu_texture_coordinates_test tests/test_gpu_texture_coordinates.c)
    add_executable(mgs_widescreen_gpu_test tests/mgs_widescreen_gpu_test.c)
    foreach(test_target IN ITEMS mgs_gpu_edges_test mgs_gpu_texture_coordinates_test mgs_widescreen_gpu_test)
        target_compile_options(${test_target} PRIVATE -UNDEBUG)
        target_link_libraries(${test_target} PRIVATE psyz)
        add_test(NAME ${test_target} COMMAND ${test_target})
        add_test(NAME ${test_target}_scaled COMMAND ${test_target} scaled)
        set_tests_properties(${test_target} ${test_target}_scaled PROPERTIES TIMEOUT 15)
    endforeach()
    add_test(NAME mgs_widescreen_gpu_8x_test COMMAND mgs_widescreen_gpu_test 8x)
    set_tests_properties(mgs_widescreen_gpu_8x_test PROPERTIES TIMEOUT 30)
    add_executable(mgs_gpu_output_test tests/test_gpu_output.c)
    target_compile_options(mgs_gpu_output_test PRIVATE -UNDEBUG)
    target_link_libraries(mgs_gpu_output_test PRIVATE psyz)
    add_test(NAME mgs_gpu_output_test COMMAND mgs_gpu_output_test)
    set_tests_properties(mgs_gpu_output_test PROPERTIES TIMEOUT 30)
    add_executable(mgs_gpu_framebuffer_scale_test tests/mgs_gpu_framebuffer_scale_test.c)
    target_compile_options(mgs_gpu_framebuffer_scale_test PRIVATE -UNDEBUG)
    target_link_libraries(mgs_gpu_framebuffer_scale_test PRIVATE psyz)
    add_executable(mgs_gpu_2d_atlas_test tests/mgs_gpu_2d_atlas_test.c)
    target_compile_options(mgs_gpu_2d_atlas_test PRIVATE -UNDEBUG)
    target_link_libraries(mgs_gpu_2d_atlas_test PRIVATE psyz)
    foreach(atlas_scale IN ITEMS 1 2 8)
        add_test(NAME mgs_gpu_2d_atlas_${atlas_scale}x_test
            COMMAND mgs_gpu_2d_atlas_test ${atlas_scale})
        set_tests_properties(mgs_gpu_2d_atlas_${atlas_scale}x_test PROPERTIES TIMEOUT 30)
    endforeach()
    foreach(framebuffer_scale IN ITEMS 1 2 8)
        add_test(NAME mgs_gpu_framebuffer_${framebuffer_scale}x_test
            COMMAND mgs_gpu_framebuffer_scale_test ${framebuffer_scale})
        set_tests_properties(mgs_gpu_framebuffer_${framebuffer_scale}x_test PROPERTIES TIMEOUT 30)
    endforeach()
    add_executable(mgs_software_mask_test tests/test_software_mask.c)
    target_include_directories(mgs_software_mask_test PRIVATE vendor/psyz/psyz/src)
    add_test(NAME mgs_gpu_mask_scaled_test COMMAND mgs_gpu_mask_test scaled)
    set_tests_properties(mgs_gpu_mask_scaled_test PROPERTIES TIMEOUT 15)
    add_test(NAME mgs_gpu_upload_arena_scaled_test COMMAND mgs_gpu_upload_arena_test scaled)
    set_tests_properties(mgs_gpu_upload_arena_scaled_test PROPERTIES TIMEOUT 15)
    foreach(test_target IN ITEMS mgs_gpu_upload_arena_test mgs_spu_irq_clock_test mgs_spu_sweep_test mgs_jeep_packets_test mgs_rope_test mgs_rappel_test mgs_lens_flare_test mgs_tower_demo_test mgs_hind_helpers_test mgs_environment_test mgs_ninja_helpers_test mgs_dyncon_state_test mgs_s10_zako_action_test mgs_s10_zako_think_test mgs_s10_zako_commander_test mgs_valcan_navigation_test mgs_mantis_helpers_test mgs_dyncon_geometry_test mgs_s10_meryl_test mgs_sight_test mgs_s10_demo_test mgs_fog_test mgs_software_mask_test mgs_gpu_mask_test mgs_math_test mgs_vlc_test mgs_mdec_test mgs_overlay_test mgs_threads_test mgs_gte_test mgs_rotation_test mgs_mods_test mgs_sdk_test mgs_cd_test mgs_audio_test mgs_gpu_feedback_test)
        target_include_directories(${test_target} PRIVATE include)
        target_compile_options(${test_target} PRIVATE -UNDEBUG)
        target_link_libraries(${test_target} PRIVATE psyz)
        add_test(NAME ${test_target} COMMAND ${test_target})
        set_tests_properties(${test_target} PROPERTIES TIMEOUT 15)
    endforeach()
    add_test(NAME import_content COMMAND "${Python3_EXECUTABLE}" -m unittest tests.test_import_content)
    set_tests_properties(import_content PROPERTIES WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
    add_test(NAME list_assets COMMAND "${Python3_EXECUTABLE}" -m unittest tests.test_list_assets)
    set_tests_properties(list_assets PROPERTIES WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
    add_test(NAME generate_sources COMMAND "${Python3_EXECUTABLE}" -m unittest tests.test_generate_sources)
    set_tests_properties(generate_sources PROPERTIES WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
    add_test(NAME native_encoding COMMAND "${Python3_EXECUTABLE}" -m unittest tests.test_native_encoding)
    set_tests_properties(native_encoding PROPERTIES WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
    add_test(NAME audit_stages COMMAND "${Python3_EXECUTABLE}" -m unittest tests.test_audit_stages)
    set_tests_properties(audit_stages PROPERTIES WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
    add_test(NAME patch_stack COMMAND "${Python3_EXECUTABLE}" -m unittest tests.test_patch_stack)
    set_tests_properties(patch_stack PROPERTIES WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" TIMEOUT 30)
endif()
