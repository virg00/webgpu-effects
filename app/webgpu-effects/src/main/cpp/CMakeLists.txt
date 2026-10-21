cmake_minimum_required(VERSION 3.5.0)
project(webgpu_effects)

set(WGPU_DIR ${CMAKE_CURRENT_SOURCE_DIR}/third_party/wgpu)

add_library(wgpu_native STATIC IMPORTED)
set_target_properties(wgpu_native PROPERTIES IMPORTED_LOCATION ${WGPU_DIR}/lib/${OHOS_ARCH}/libwgpu_native.a)

add_library(webgpu_effects SHARED gpu.cpp)
target_include_directories(webgpu_effects PRIVATE ${WGPU_DIR}/include)
target_compile_options(webgpu_effects PRIVATE -std=c++17)
# Hide the static Rust symbols; only the NAPI module registration needs to be visible.
target_link_options(webgpu_effects PRIVATE -Wl,--exclude-libs,ALL -Wl,--gc-sections)
target_link_libraries(webgpu_effects PRIVATE wgpu_native libace_napi.z.so libnative_window.so libnative_image.so libnative_buffer.so libvulkan.so libhilog_ndk.z.so dl m)
