cmake_minimum_required(VERSION 3.15...4.4)
project(itch-book VERSION 1.0
        DESCRIPTION "nasdaq itch book"
        LANGUAGES CXX)

set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(itch-book src/main.cpp)


target_compile_features(itch-book PRIVATE cxx_std_20)
target_compile_options(itch-book PRIVATE -Wall -Wextra -Werror)


include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/refs/tags/v1.18.0.zip
)
# For Windows: Prevent overriding the parent project's compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

enable_testing()

add_executable(
  hello_test
  tests/hello_test.ccp
)
target_link_libraries(
  hello_test
  GTest::gtest_main
)

include(GoogleTest)
gtest_discover_tests(hello_test)
