find_program(MGS_CSC csc.exe PATHS "$ENV{WINDIR}/Microsoft.NET/Framework/v4.0.30319" NO_DEFAULT_PATH REQUIRED)
configure_file(BuildInfo.cs.in BuildInfo.cs @ONLY)
set(launcher_sources "${CMAKE_CURRENT_SOURCE_DIR}/Launcher.cs"
    "${CMAKE_CURRENT_SOURCE_DIR}/Settings.cs" "${CMAKE_CURRENT_SOURCE_DIR}/GameLaunch.cs"
    "${CMAKE_CURRENT_BINARY_DIR}/BuildInfo.cs")
set(launcher_output "${CMAKE_BINARY_DIR}/RE-INTEGRAL.exe")
file(TO_NATIVE_PATH "${launcher_output}" launcher_native_output)
file(TO_NATIVE_PATH "${CMAKE_CURRENT_BINARY_DIR}/BuildInfo.cs" launcher_build_info)
file(TO_NATIVE_PATH "${PROJECT_SOURCE_DIR}/assets/branding/re-integral-logo.png" launcher_logo)
add_custom_command(OUTPUT "${launcher_output}"
    COMMAND "${MGS_CSC}" /nologo /target:winexe /platform:x86 /optimize+
        /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Xml.dll
        /win32manifest:app.manifest "/resource:${launcher_logo},logo.png"
        "/out:${launcher_native_output}" Launcher.cs Settings.cs GameLaunch.cs "${launcher_build_info}"
    DEPENDS ${launcher_sources} app.manifest "${PROJECT_SOURCE_DIR}/assets/branding/re-integral-logo.png"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" VERBATIM)
add_custom_target(reintegral_launcher ALL DEPENDS "${launcher_output}")
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
endif()
