cmake_minimum_required(VERSION 3.20)

project(loqer VERSION 1.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Aggressive Minification Flags
if(MSVC)
    set(CMAKE_CXX_FLAGS_RELEASE "/O2 /GL /Gy /MD /DNDEBUG")
    set(CMAKE_EXE_LINKER_FLAGS_RELEASE "/LTCG /OPT:REF /OPT:ICF /SUBSYSTEM:WINDOWS")
else()
    set(CMAKE_CXX_FLAGS_RELEASE "-O3 -flto -ffunction-sections -fdata-sections -DNDEBUG")
    set(CMAKE_EXE_LINKER_FLAGS_RELEASE "-Wl,--gc-sections -Wl,-s -flto -mwindows")
endif()

find_package(Qt6 REQUIRED COMPONENTS
    Core
    Gui
    Widgets
    Qml
    Quick
    QuickControls2
    Svg
)

set(SOURCES
    src/main.cpp
    src/qml_shims.cpp
    src/lenovo_hal.cpp
    loqer.qrc
)

add_executable(loqer ${SOURCES})

target_include_directories(loqer PRIVATE src)

target_link_libraries(loqer PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Svg
)

if(WIN32)
    target_link_libraries(loqer PRIVATE
        ole32
        oleaut32
        wbemuuid
        advapi32
    )
endif()
