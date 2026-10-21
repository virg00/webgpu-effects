cmake_minimum_required(VERSION 3.5.0)
project(shaderport_gles)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# shaderport's reference GLES 3.0 renderer (quizzyjoy/shaderport harmony/entry/src/main/cpp, Apache-2.0),
# built unmodified except for the NAPI module name — the comparison pages drive it exactly like its demo.
add_library(shaderport_gles SHARED shaderport/napi_init.cpp shaderport/renderer.cpp)
target_include_directories(shaderport_gles PRIVATE shaderport)
target_link_libraries(shaderport_gles PUBLIC libace_napi.z.so libEGL.so libGLESv3.so libnative_window.so
    libnative_vsync.so libhilog_ndk.z.so)
