find_program(MGS_CSC csc.exe PATHS "$ENV{WINDIR}/Microsoft.NET/Framework/v4.0.30319" NO_DEFAULT_PATH REQUIRED)
configure_file(BuildInfo.cs.in BuildInfo.cs @ONLY)
set(launcher_sources "${CMAKE_CURRENT_SOURCE_DIR}/Launcher.cs"
    "${CMAKE_CURRENT_SOURCE_DIR}/Settings.cs" "${CMAKE_CURRENT_SOURCE_DIR}/GameLaunch.cs"
    "${CMAKE_CURRENT_SOURCE_DIR}/LanguageImport.cs" "${CMAKE_CURRENT_SOURCE_DIR}/LanguageImportDialog.cs"
    "${CMAKE_CURRENT_BINARY_DIR}/BuildInfo.cs")
set(launcher_output "${CMAKE_BINARY_DIR}/RE-INTEGRAL.exe")
file(TO_NATIVE_PATH "${launcher_output}" launcher_native_output)
file(TO_NATIVE_PATH "${CMAKE_CURRENT_BINARY_DIR}/BuildInfo.cs" launcher_build_info)
file(TO_NATIVE_PATH "${PROJECT_SOURCE_DIR}/assets/branding/re-integral-logo.png" launcher_logo)
add_custom_command(OUTPUT "${launcher_output}"
    COMMAND "${MGS_CSC}" /nologo /target:winexe /platform:x86 /optimize+
        /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Xml.dll
        /win32manifest:app.manifest "/resource:${launcher_logo},logo.png"
        "/out:${launcher_native_output}" Launcher.cs Settings.cs GameLaunch.cs LanguageImport.cs LanguageImportDialog.cs "${launcher_build_info}"
    DEPENDS ${launcher_sources} app.manifest "${PROJECT_SOURCE_DIR}/assets/branding/re-integral-logo.png"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" VERBATIM)
add_custom_target(reintegral_launcher ALL DEPENDS "${launcher_output}")
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
    set(test_output "${CMAKE_BINARY_DIR}/reintegral_launcher_tests.exe")
    file(TO_NATIVE_PATH "${test_output}" test_native_output)
    file(TO_NATIVE_PATH "${PROJECT_SOURCE_DIR}/tests/launcher_settings.cs" test_native_source)
    add_custom_command(OUTPUT "${test_output}"
        COMMAND "${MGS_CSC}" /nologo /target:exe /platform:x86 /reference:System.Xml.dll
            "/out:${test_native_output}" "${test_native_source}" Settings.cs GameLaunch.cs
        DEPENDS "${PROJECT_SOURCE_DIR}/tests/launcher_settings.cs" Settings.cs GameLaunch.cs
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" VERBATIM)
    add_custom_target(reintegral_launcher_tests ALL DEPENDS "${test_output}")
    add_test(NAME launcher_settings COMMAND "${test_output}")
    set(import_test_output "${CMAKE_BINARY_DIR}/reintegral_import_tests.exe")
    file(TO_NATIVE_PATH "${import_test_output}" import_test_native_output)
    file(TO_NATIVE_PATH "${PROJECT_SOURCE_DIR}/tests/launcher_import.cs" import_test_source)
    add_custom_command(OUTPUT "${import_test_output}"
        COMMAND "${MGS_CSC}" /nologo /target:exe /platform:x86 /reference:System.Xml.dll
            "/out:${import_test_native_output}" "${import_test_source}" LanguageImport.cs GameLaunch.cs Settings.cs
        DEPENDS "${PROJECT_SOURCE_DIR}/tests/launcher_import.cs" LanguageImport.cs GameLaunch.cs Settings.cs
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" VERBATIM)
    add_custom_target(reintegral_import_tests ALL DEPENDS "${import_test_output}")
    add_test(NAME launcher_import COMMAND "${import_test_output}")
    add_test(NAME bundled_importer_help COMMAND "${importer_output}" --help)
endif()
