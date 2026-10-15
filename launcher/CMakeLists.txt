find_program(MGS_CSC csc.exe PATHS "$ENV{WINDIR}/Microsoft.NET/Framework/v4.0.30319" NO_DEFAULT_PATH REQUIRED)
set(MGS_RENDERER_ID "legacy")
set(MGS_RENDERER_NAME "Legacy 0.2")
set(MGS_RENDERER_BACKEND "native")
set(MGS_RENDERER_ARCH "x86")
set(MGS_RENDERER_ENGINE "")
set(MGS_RENDERER_PROJECT "")
set(MGS_RENDERER_ASSETS "")
if(MGS_RENDERER_MODULE)
    get_filename_component(MGS_RENDERER_ID "${MGS_RENDERER_MODULE}" NAME)
    set(MGS_RENDERER_NAME "${MGS_RENDERER_ID}")
endif()
if(TARGET psyz_renderer)
    get_target_property(godot_renderer psyz_renderer MGS_GODOT_SCENE)
    if(godot_renderer)
        set(MGS_RENDERER_ID "godot")
        set(MGS_RENDERER_NAME "Godot")
        set(MGS_RENDERER_BACKEND "godot")
        set(MGS_RENDERER_ARCH "x64")
        file(RELATIVE_PATH MGS_RENDERER_ENGINE "${CMAKE_BINARY_DIR}" "${PROJECT_SOURCE_DIR}/.tools/godot-4.8-dev7/Godot_v4.8-dev7_win64_console.exe")
        file(RELATIVE_PATH MGS_RENDERER_PROJECT "${CMAKE_BINARY_DIR}" "${PROJECT_SOURCE_DIR}/renderers/godot/project")
        file(RELATIVE_PATH MGS_RENDERER_ASSETS "${CMAKE_BINARY_DIR}" "${PROJECT_SOURCE_DIR}/.local/godot-content")
    endif()
endif()
configure_file(BuildInfo.cs.in BuildInfo.cs @ONLY)
configure_file(renderer.json.in "${CMAKE_BINARY_DIR}/renderer.json" @ONLY)
set(launcher_sources "${CMAKE_CURRENT_SOURCE_DIR}/Launcher.cs"
    "${CMAKE_CURRENT_SOURCE_DIR}/Launcher.Game.cs"
    "${CMAKE_CURRENT_SOURCE_DIR}/Launcher.Progress.cs" "${CMAKE_CURRENT_SOURCE_DIR}/StartupProgress.cs"
    "${CMAKE_CURRENT_SOURCE_DIR}/Launcher.Renderers.cs" "${CMAKE_CURRENT_SOURCE_DIR}/RendererPackage.cs"
    "${CMAKE_CURRENT_SOURCE_DIR}/RendererCatalog.cs"
    "${CMAKE_CURRENT_SOURCE_DIR}/PresentationContract.cs" "${CMAKE_CURRENT_SOURCE_DIR}/PresentationSession.cs"
    "${CMAKE_CURRENT_SOURCE_DIR}/RendererSession.cs"
    "${CMAKE_CURRENT_SOURCE_DIR}/Settings.cs" "${CMAKE_CURRENT_SOURCE_DIR}/GameLaunch.cs"
    "${CMAKE_CURRENT_SOURCE_DIR}/DisplaySettings.cs" "${CMAKE_CURRENT_SOURCE_DIR}/SettingsRegistry.cs"
    "${CMAKE_CURRENT_SOURCE_DIR}/SettingsBridge.cs"
    "${CMAKE_CURRENT_SOURCE_DIR}/LanguageImport.cs" "${CMAKE_CURRENT_SOURCE_DIR}/LanguageImportDialog.cs"
    "${CMAKE_CURRENT_SOURCE_DIR}/ModPackage.cs" "${CMAKE_CURRENT_SOURCE_DIR}/ModsPanel.cs"
    "${CMAKE_CURRENT_SOURCE_DIR}/GodotProject.cs" "${CMAKE_CURRENT_SOURCE_DIR}/GodotSession.cs"
    "${CMAKE_CURRENT_BINARY_DIR}/BuildInfo.cs")
set(launcher_output "${CMAKE_BINARY_DIR}/RE-INTEGRAL.exe")
file(TO_NATIVE_PATH "${launcher_output}" launcher_native_output)
file(TO_NATIVE_PATH "${CMAKE_CURRENT_BINARY_DIR}/BuildInfo.cs" launcher_build_info)
file(TO_NATIVE_PATH "${PROJECT_SOURCE_DIR}/assets/branding/re-integral-logo.png" launcher_logo)
add_custom_command(OUTPUT "${launcher_output}"
    COMMAND "${MGS_CSC}" /nologo /target:winexe /platform:x86 /optimize+
        /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Xml.dll
        /reference:System.IO.Compression.dll /reference:System.Web.Extensions.dll
        /win32manifest:app.manifest "/resource:${launcher_logo},logo.png"
        "/out:${launcher_native_output}" Launcher.cs Launcher.Game.cs Launcher.Renderers.cs RendererPackage.cs RendererCatalog.cs PresentationContract.cs PresentationSession.cs RendererSession.cs Settings.cs GameLaunch.cs LanguageImport.cs LanguageImportDialog.cs
        ModPackage.cs ModsPanel.cs GodotProject.cs GodotSession.cs Launcher.Progress.cs StartupProgress.cs DisplaySettings.cs SettingsRegistry.cs SettingsBridge.cs "${launcher_build_info}"
    DEPENDS ${launcher_sources} app.manifest "${PROJECT_SOURCE_DIR}/assets/branding/re-integral-logo.png"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" VERBATIM)
add_custom_target(reintegral_launcher ALL DEPENDS "${launcher_output}")
set(settings_host_output "${CMAKE_BINARY_DIR}/settings-host.exe")
file(TO_NATIVE_PATH "${settings_host_output}" settings_host_native_output)
add_custom_command(OUTPUT "${settings_host_output}"
    COMMAND "${MGS_CSC}" /nologo /target:exe /platform:x86 /optimize+ /reference:System.Xml.dll /reference:System.Web.Extensions.dll
        "/out:${settings_host_native_output}" SettingsHost.cs Settings.cs DisplaySettings.cs SettingsRegistry.cs SettingsBridge.cs
    DEPENDS SettingsHost.cs Settings.cs DisplaySettings.cs SettingsRegistry.cs SettingsBridge.cs
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" VERBATIM)
add_custom_target(reintegral_settings_host ALL DEPENDS "${settings_host_output}")
add_dependencies(reintegral_launcher reintegral_settings_host)
set(importer_sources import_language.py import_content.py list_assets.py language_assets.py
    language_mapping.py language_pack.py language_script.py language_stream.py build_language_importer.py)
list(TRANSFORM importer_sources PREPEND "${PROJECT_SOURCE_DIR}/tools/")
set(importer_output "${CMAKE_BINARY_DIR}/language-importer/language-importer.exe")
add_custom_command(OUTPUT "${importer_output}"
    COMMAND "${Python3_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tools/build_language_importer.py"
        --build-directory "${CMAKE_BINARY_DIR}"
    DEPENDS ${importer_sources} "${PROJECT_SOURCE_DIR}/requirements.txt"
        "${PROJECT_SOURCE_DIR}/licenses/Apache-2.0.txt" "${PROJECT_SOURCE_DIR}/licenses/zlib.txt"
        "${PROJECT_SOURCE_DIR}/licenses/importer-runtime.txt"
    VERBATIM)
add_custom_target(reintegral_language_importer ALL DEPENDS "${importer_output}")
add_dependencies(reintegral_launcher reintegral_language_importer)
if(BUILD_TESTING)
    set(community_source "${PROJECT_SOURCE_DIR}/renderers/community-wireframe")
    set(community_test_output "${CMAKE_BINARY_DIR}/community_wire_tests.exe")
    file(TO_NATIVE_PATH "${community_test_output}" community_test_native_output)
    file(TO_NATIVE_PATH "${PROJECT_SOURCE_DIR}/tests/community_wire.cs" community_test_source)
    file(TO_NATIVE_PATH "${community_source}/Wire.cs" community_wire_source)
    file(TO_NATIVE_PATH "${community_source}/Surface.cs" community_surface_source)
    add_custom_command(OUTPUT "${community_test_output}"
        COMMAND "${MGS_CSC}" /nologo /target:exe /platform:x86 /reference:System.Drawing.dll
            "/out:${community_test_native_output}" "${community_test_source}"
            "${community_wire_source}" "${community_surface_source}"
        DEPENDS "${PROJECT_SOURCE_DIR}/tests/community_wire.cs"
            "${community_source}/Wire.cs" "${community_source}/Surface.cs" VERBATIM)
    add_custom_target(community_wire_tests ALL DEPENDS "${community_test_output}")
    add_test(NAME community_wire COMMAND "${community_test_output}")
    set(presentation_test_output "${CMAKE_BINARY_DIR}/presentation_session_tests.exe")
    file(TO_NATIVE_PATH "${presentation_test_output}" presentation_test_native_output)
    file(TO_NATIVE_PATH "${PROJECT_SOURCE_DIR}/tests/presentation_session.cs" presentation_test_source)
    add_custom_command(OUTPUT "${presentation_test_output}"
        COMMAND "${MGS_CSC}" /nologo /target:exe /platform:x86 /reference:System.Web.Extensions.dll
            "/reference:${launcher_native_output}" "/out:${presentation_test_native_output}"
            "${presentation_test_source}"
        DEPENDS "${PROJECT_SOURCE_DIR}/tests/presentation_session.cs" "${launcher_output}" VERBATIM)
    add_custom_target(presentation_session_tests ALL DEPENDS "${presentation_test_output}")
    add_test(NAME presentation_readiness COMMAND "${presentation_test_output}")
    set(renderer_test_output "${CMAKE_BINARY_DIR}/reintegral_renderer_tests.exe")
    file(TO_NATIVE_PATH "${renderer_test_output}" renderer_test_native_output)
    file(TO_NATIVE_PATH "${PROJECT_SOURCE_DIR}/tests/launcher_renderers.cs" renderer_test_source)
    add_custom_command(OUTPUT "${renderer_test_output}"
        COMMAND "${MGS_CSC}" /nologo /target:exe /platform:x86 /reference:System.Xml.dll /reference:System.Web.Extensions.dll
            "/out:${renderer_test_native_output}" "${renderer_test_source}" Settings.cs GameLaunch.cs DisplaySettings.cs RendererPackage.cs RendererCatalog.cs PresentationContract.cs
        DEPENDS "${PROJECT_SOURCE_DIR}/tests/launcher_renderers.cs" Settings.cs GameLaunch.cs DisplaySettings.cs RendererPackage.cs RendererCatalog.cs PresentationContract.cs
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" VERBATIM)
    add_custom_target(reintegral_renderer_tests ALL DEPENDS "${renderer_test_output}")
    add_test(NAME launcher_renderers COMMAND "${renderer_test_output}")
    set(test_output "${CMAKE_BINARY_DIR}/reintegral_launcher_tests.exe")
    file(TO_NATIVE_PATH "${test_output}" test_native_output)
    file(TO_NATIVE_PATH "${PROJECT_SOURCE_DIR}/tests/launcher_settings.cs" test_native_source)
    add_custom_command(OUTPUT "${test_output}"
        COMMAND "${MGS_CSC}" /nologo /target:exe /platform:x86 /reference:System.Xml.dll
            "/out:${test_native_output}" "${test_native_source}" Settings.cs GameLaunch.cs DisplaySettings.cs
        DEPENDS "${PROJECT_SOURCE_DIR}/tests/launcher_settings.cs" Settings.cs GameLaunch.cs DisplaySettings.cs
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" VERBATIM)
    add_custom_target(reintegral_launcher_tests ALL DEPENDS "${test_output}")
    add_test(NAME launcher_settings COMMAND "${test_output}")
    set(import_test_output "${CMAKE_BINARY_DIR}/reintegral_import_tests.exe")
    file(TO_NATIVE_PATH "${import_test_output}" import_test_native_output)
    file(TO_NATIVE_PATH "${PROJECT_SOURCE_DIR}/tests/launcher_import.cs" import_test_source)
    add_custom_command(OUTPUT "${import_test_output}"
        COMMAND "${MGS_CSC}" /nologo /target:exe /platform:x86 /reference:System.Xml.dll
            "/out:${import_test_native_output}" "${import_test_source}" LanguageImport.cs GameLaunch.cs Settings.cs DisplaySettings.cs
        DEPENDS "${PROJECT_SOURCE_DIR}/tests/launcher_import.cs" LanguageImport.cs GameLaunch.cs Settings.cs DisplaySettings.cs
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" VERBATIM)
    add_custom_target(reintegral_import_tests ALL DEPENDS "${import_test_output}")
    add_test(NAME launcher_import COMMAND "${import_test_output}")
    set(mod_test_output "${CMAKE_BINARY_DIR}/reintegral_mod_tests.exe")
    file(TO_NATIVE_PATH "${mod_test_output}" mod_test_native_output)
    file(TO_NATIVE_PATH "${PROJECT_SOURCE_DIR}/tests/launcher_mods.cs" mod_test_source)
    add_custom_command(OUTPUT "${mod_test_output}"
        COMMAND "${MGS_CSC}" /nologo /target:exe /platform:x86 /reference:System.Xml.dll
            /reference:System.IO.Compression.dll /reference:System.Web.Extensions.dll
            "/out:${mod_test_native_output}" "${mod_test_source}" Settings.cs ModPackage.cs GodotProject.cs GodotSession.cs StartupProgress.cs RendererSession.cs GameLaunch.cs DisplaySettings.cs SettingsRegistry.cs SettingsBridge.cs
        DEPENDS "${PROJECT_SOURCE_DIR}/tests/launcher_mods.cs" Settings.cs ModPackage.cs GodotProject.cs GodotSession.cs StartupProgress.cs RendererSession.cs GameLaunch.cs DisplaySettings.cs SettingsRegistry.cs SettingsBridge.cs
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" VERBATIM)
    add_custom_target(reintegral_mod_tests ALL DEPENDS "${mod_test_output}")
    add_test(NAME launcher_mods COMMAND "${mod_test_output}")
    set(registry_test_output "${CMAKE_BINARY_DIR}/reintegral_settings_registry_tests.exe")
    file(TO_NATIVE_PATH "${registry_test_output}" registry_test_native_output)
    file(TO_NATIVE_PATH "${PROJECT_SOURCE_DIR}/tests/launcher_settings_registry.cs" registry_test_source)
    add_custom_command(OUTPUT "${registry_test_output}"
        COMMAND "${MGS_CSC}" /nologo /target:exe /platform:x86 /reference:System.Xml.dll /reference:System.Web.Extensions.dll
            "/out:${registry_test_native_output}" "${registry_test_source}" Settings.cs GameLaunch.cs DisplaySettings.cs SettingsRegistry.cs SettingsBridge.cs
        DEPENDS "${PROJECT_SOURCE_DIR}/tests/launcher_settings_registry.cs" Settings.cs GameLaunch.cs DisplaySettings.cs SettingsRegistry.cs SettingsBridge.cs
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" VERBATIM)
    add_custom_target(reintegral_settings_registry_tests ALL DEPENDS "${registry_test_output}")
    add_test(NAME launcher_settings_registry COMMAND "${registry_test_output}")
    add_test(NAME bundled_importer_help COMMAND "${importer_output}" --help)
endif()
