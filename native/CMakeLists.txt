cmake_minimum_required(VERSION 3.24)
project(NeonNative VERSION 0.3.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
enable_testing()
add_subdirectory(core)
if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  enable_language(OBJCXX)
  set(CMAKE_OBJCXX_STANDARD 23)
  set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)
  add_executable(NeonNative MACOSX_BUNDLE macos/NativeApp.mm macos/WorkspaceController.mm macos/LibraryController.mm)
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
  add_library(neon_apple_document apple/DocumentSession.mm apple/Preferences.mm apple/LibraryStore.mm apple/LibraryPresentation.mm apple/EditorialTheme.mm apple/ContextMenu.mm apple/Controls.mm apple/InlineTitle.mm apple/Settings.mm apple/History.mm)
  target_include_directories(neon_apple_document PUBLIC apple)
  target_link_libraries(neon_apple_document PUBLIC neon_portable_core "-framework Foundation" "-framework CoreText" "-framework CoreGraphics" "-framework QuartzCore")
  target_compile_options(neon_apple_document PRIVATE -fobjc-arc -Wall -Wextra)
endif()
if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
  add_executable(NeonMobile MACOSX_BUNDLE ios/NativeApp.mm ios/WorkspaceController.mm ios/WorkspaceTests.mm ios/LibraryController.mm)
  target_link_libraries(NeonMobile PRIVATE neon_apple_document "-framework UIKit")
  target_compile_options(NeonMobile PRIVATE -fobjc-arc -Wall -Wextra)
  set_target_properties(NeonMobile PROPERTIES
    OUTPUT_NAME Neon
    MACOSX_BUNDLE_BUNDLE_NAME "Neon"
    MACOSX_BUNDLE_GUI_IDENTIFIER com.johnhenning.neon.applepreview
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/ios/Info.plist"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
    XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO")
  target_sources(NeonMobile PRIVATE resources/ios-icons.xcassets)
  set_source_files_properties(resources/ios-icons.xcassets PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
endif()

# Makefile builds need an explicit asset catalog compiler step on macOS.
if(TARGET NeonNative)
  set(NEON_ICON_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/app-icons")
  set(NEON_ICON_ORIGINALS resources/app-icons/macos-light.png resources/app-icons/macos-dark.png)
  set_source_files_properties(${NEON_ICON_ORIGINALS} PROPERTIES MACOSX_PACKAGE_LOCATION Resources/app-icons)
  target_sources(NeonNative PRIVATE ${NEON_ICON_ORIGINALS})
  file(GLOB_RECURSE NEON_ICON_INPUTS CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/resources/macos-icons.xcassets/*")
  add_custom_command(
    OUTPUT "${NEON_ICON_OUTPUT}/Assets.car" "${NEON_ICON_OUTPUT}/AppIcon.icns"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${NEON_ICON_OUTPUT}"
    COMMAND xcrun actool "${CMAKE_CURRENT_SOURCE_DIR}/resources/macos-icons.xcassets"
      --compile "${NEON_ICON_OUTPUT}" --platform macosx
      --minimum-deployment-target 14.0 --app-icon AppIcon
      --output-partial-info-plist "${NEON_ICON_OUTPUT}/partial.plist"
    DEPENDS ${NEON_ICON_INPUTS}
    VERBATIM)
  set_source_files_properties("${NEON_ICON_OUTPUT}/Assets.car" "${NEON_ICON_OUTPUT}/AppIcon.icns"
    PROPERTIES GENERATED TRUE MACOSX_PACKAGE_LOCATION Resources)
  target_sources(NeonNative PRIVATE "${NEON_ICON_OUTPUT}/Assets.car" "${NEON_ICON_OUTPUT}/AppIcon.icns")
endif()
if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  add_executable(apple_library_controller_test macos/library_controller_test.mm macos/LibraryController.mm)
  target_link_libraries(apple_library_controller_test PRIVATE neon_apple_document "-framework AppKit")
  target_compile_options(apple_library_controller_test PRIVATE -fobjc-arc -Wall -Wextra)
  add_test(NAME apple_library_controller COMMAND apple_library_controller_test --smoke-library-controller)
  add_executable(apple_library_test apple/library_test.mm)
  target_link_libraries(apple_library_test PRIVATE neon_apple_document)
  target_compile_options(apple_library_test PRIVATE -fobjc-arc -Wall -Wextra)
  add_test(NAME apple_library_presentation COMMAND apple_library_test --smoke-library)
  add_executable(apple_session_test apple/session_test.mm)
  target_link_libraries(apple_session_test PRIVATE neon_apple_document)
  target_compile_options(apple_session_test PRIVATE -fobjc-arc -Wall -Wextra)
  add_test(NAME apple_document_session COMMAND apple_session_test)
  add_executable(apple_preferences_test apple/preferences_test.mm)
  target_link_libraries(apple_preferences_test PRIVATE neon_apple_document)
  target_compile_options(apple_preferences_test PRIVATE -fobjc-arc -Wall -Wextra)
  foreach(mode test reopen library focus typography menu settings history preset)
    add_test(NAME apple_preferences_${mode} COMMAND apple_preferences_test --smoke-${mode})
  endforeach()
  add_test(NAME apple_preferences_production COMMAND apple_preferences_test)
  add_test(NAME apple_preferences_ui COMMAND apple_preferences_test --ui-testing)
  set_tests_properties(apple_preferences_ui PROPERTIES ENVIRONMENT
    "NEON_UI_RUN_ID=e025235c-103f-420f-978e-96525bbdbce4;NEON_UI_PREFERENCES_JSON={\"appearance\":1,\"manuscriptSize\":20}")
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

if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  add_executable(apple_controls_test apple/controls_test.mm)
  target_link_libraries(apple_controls_test PRIVATE neon_apple_document "-framework AppKit")
  target_compile_options(apple_controls_test PRIVATE -fobjc-arc -Wall -Wextra)
  add_test(NAME apple_controls COMMAND apple_controls_test)
endif()

file(GLOB NEON_ARTWORK CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/resources/artwork/*.png" "${CMAKE_CURRENT_SOURCE_DIR}/resources/artwork/manifest.json")
set_source_files_properties(${NEON_ARTWORK} PROPERTIES MACOSX_PACKAGE_LOCATION Resources/artwork)
if(TARGET NeonNative)
  target_sources(NeonNative PRIVATE ${NEON_ARTWORK})
endif()
if(TARGET NeonMobile)
  target_sources(NeonMobile PRIVATE ${NEON_ARTWORK})
endif()

file(GLOB NEON_WORKSPACE_ICONS CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/resources/icons/*.png" "${CMAKE_CURRENT_SOURCE_DIR}/resources/icons/*.svg" "${CMAKE_CURRENT_SOURCE_DIR}/resources/icons/manifest.json")
set_source_files_properties(${NEON_WORKSPACE_ICONS} PROPERTIES MACOSX_PACKAGE_LOCATION Resources/icons)
if(TARGET NeonNative)
  target_sources(NeonNative PRIVATE ${NEON_WORKSPACE_ICONS})
endif()
if(TARGET NeonMobile)
  target_sources(NeonMobile PRIVATE ${NEON_WORKSPACE_ICONS})
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  add_executable(mac_workspace_test macos/workspace_test.mm macos/WorkspaceController.mm)
  target_include_directories(mac_workspace_test PRIVATE macos)
  target_link_libraries(mac_workspace_test PRIVATE neon_apple_document "-framework AppKit")
  target_compile_options(mac_workspace_test PRIVATE -fobjc-arc -Wall -Wextra)
  add_test(NAME mac_workspace COMMAND mac_workspace_test)
endif()
