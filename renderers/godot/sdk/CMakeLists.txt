cmake_minimum_required(VERSION 3.24)
project(mgs_visual_mod LANGUAGES CXX)

if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
    message(FATAL_ERROR "Godot extensions run in the 64-bit renderer process")
endif()
set(GODOTCPP_BUILD_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/build_profile.json" CACHE FILEPATH "")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${GODOTCPP_BUILD_PROFILE}")
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../../../vendor/godot-cpp" godot-cpp)
add_library(mgs_visual_mod SHARED example_mod.cpp)
target_link_libraries(mgs_visual_mod PRIVATE godot-cpp::template_debug)
target_compile_features(mgs_visual_mod PRIVATE cxx_std_17)
set_target_properties(mgs_visual_mod PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/mod/bin"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/mod/bin")
configure_file(example.gdextension "${CMAKE_BINARY_DIR}/mod/example.gdextension" COPYONLY)
configure_file(mod.json "${CMAKE_BINARY_DIR}/mod/mod.json" COPYONLY)
configure_file(stage.tscn "${CMAKE_BINARY_DIR}/mod/stage.tscn" COPYONLY)
