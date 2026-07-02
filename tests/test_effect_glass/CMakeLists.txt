find_package(Qt6 REQUIRED COMPONENTS Test Core)

add_executable(test_effect_glass main.cpp)

target_link_libraries(test_effect_glass
    PRIVATE
        Qt::Core
        Qt::Test
)

target_compile_definitions(test_effect_glass
    PRIVATE
        SOURCE_DIR="${CMAKE_SOURCE_DIR}"
)

add_test(NAME test_effect_glass COMMAND test_effect_glass)

set_property(TEST test_effect_glass PROPERTY
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)

set_property(TEST test_effect_glass PROPERTY
    TIMEOUT 3
)
