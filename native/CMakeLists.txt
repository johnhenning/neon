cmake_minimum_required(VERSION 3.24)
project(NeonNative VERSION 0.2.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
enable_testing()
add_subdirectory(core)
if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  enable_language(OBJCXX)
  set(CMAKE_OBJCXX_STANDARD 23)
  set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)
  add_executable(NeonNative MACOSX_BUNDLE macos/NativeApp.mm)
  target_link_libraries(NeonNative PRIVATE neon_portable_core "-framework AppKit" "-framework Foundation" "-framework QuartzCore")
  target_compile_options(NeonNative PRIVATE -fobjc-arc -Wall -Wextra)
  set_target_properties(NeonNative PROPERTIES
    OUTPUT_NAME Neon
    MACOSX_BUNDLE_GUI_IDENTIFIER com.johnhenning.neon.nativeprototype
    MACOSX_BUNDLE_BUNDLE_NAME "Neon"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/macos/Info.plist")
  enable_testing()
  add_test(NAME native_ui COMMAND NeonNative --smoke-test)
  set_tests_properties(native_ui PROPERTIES TIMEOUT 45)
endif()

if(APPLE)
  enable_language(OBJCXX)
  set(CMAKE_OBJCXX_STANDARD 23)
  set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)
  add_library(neon_apple_document apple/DocumentSession.mm apple/LibraryStore.mm apple/EditorialTheme.mm apple/ContextMenu.mm apple/InlineTitle.mm apple/Settings.mm apple/History.mm)
  target_include_directories(neon_apple_document PUBLIC apple)
  target_link_libraries(neon_apple_document PUBLIC neon_portable_core "-framework Foundation" "-framework CoreText" "-framework CoreGraphics" "-framework QuartzCore")
  target_compile_options(neon_apple_document PRIVATE -fobjc-arc -Wall -Wextra)
endif()
if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
  add_executable(NeonMobile MACOSX_BUNDLE ios/NativeApp.mm)
  target_link_libraries(NeonMobile PRIVATE neon_apple_document "-framework UIKit")
  target_compile_options(NeonMobile PRIVATE -fobjc-arc -Wall -Wextra)
  set_target_properties(NeonMobile PROPERTIES
    OUTPUT_NAME Neon
    MACOSX_BUNDLE_BUNDLE_NAME "Neon"
    MACOSX_BUNDLE_GUI_IDENTIFIER com.johnhenning.neon.applepreview
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/ios/Info.plist"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO")
endif()
if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  add_executable(apple_session_test apple/session_test.mm)
  target_link_libraries(apple_session_test PRIVATE neon_apple_document)
  target_compile_options(apple_session_test PRIVATE -fobjc-arc -Wall -Wextra)
  add_test(NAME apple_document_session COMMAND apple_session_test)
endif()

file(GLOB NEON_FONTS CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/resources/fonts/*.ttf" "${CMAKE_CURRENT_SOURCE_DIR}/resources/fonts/*OFL.txt")
set_source_files_properties(${NEON_FONTS} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
if(TARGET NeonNative)
  target_link_libraries(NeonNative PRIVATE neon_apple_document)
  target_sources(NeonNative PRIVATE ${NEON_FONTS})
endif()
if(TARGET NeonMobile)
  target_sources(NeonMobile PRIVATE ${NEON_FONTS})
endif()
