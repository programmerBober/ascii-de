cmake_minimum_required(VERSION 3.16)

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../VERSION")
    file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/../VERSION" ASCII_DE_VERSION_RAW LIMIT_COUNT 1)
    string(STRIP "${ASCII_DE_VERSION_RAW}" ASCII_DE_VERSION)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/../VERSION")
else()
    set(ASCII_DE_VERSION "0.1.0")
endif()

project(ascii-de-compositor VERSION 1.0.0 LANGUAGES CXX)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS
    Core
    DBus
    Gui
    Qml
    Quick
    WaylandCompositor
)

qt_add_executable(ascii-de-compositor
    main.cpp
    DesktopBridge.h
    DesktopBridge.cpp
    ScreenshotHelper.h
    ScreenshotHelper.cpp
    NotificationServer.h
    NotificationServer.cpp
    ClipboardHistory.h
    ClipboardHistory.cpp
)

find_package(Wayland COMPONENTS Server REQUIRED)

target_compile_options(ascii-de-compositor PRIVATE
    -Wall
    -Wextra
    -Wpedantic
)

target_link_options(ascii-de-compositor PRIVATE
    -Wl,--export-dynamic-symbol=wl_global_create
)

target_compile_definitions(ascii-de-compositor PRIVATE
    ASCII_DE_VERSION="${ASCII_DE_VERSION}"
)

target_link_libraries(ascii-de-compositor PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::WaylandCompositor
    Wayland::Server
    ${CMAKE_DL_LIBS}
)

install(TARGETS ascii-de-compositor
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
