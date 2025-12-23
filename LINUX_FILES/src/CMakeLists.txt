# Define the shared library for the plugins
add_library(afx-nuke-plugins SHARED
    afx_anti_alias.cpp
    afx_chroma_key.cpp
    afx_despill.cpp
    afx_glow.cpp
    afx_median.cpp
    afx_noise_map.cpp
    afx_soft_clip.cpp
    afx_tone_map.cpp
    mlaa.cpp
)

# Platform-specific linking
if(${CMAKE_HOST_SYSTEM_NAME} MATCHES "Darwin") # macOS
    target_link_libraries(afx-nuke-plugins PRIVATE DDImage GLEW
        "-framework QuartzCore"
        "-framework IOKit"
        "-framework CoreFoundation"
        "-framework Carbon"
        "-framework ApplicationServices"
        "-framework OpenGL"
        "-framework AGL"
    )
elseif(${CMAKE_HOST_SYSTEM_NAME} MATCHES "Linux") # Linux
    target_link_libraries(afx-nuke-plugins PRIVATE DDImage OpenGL)
endif()

# Link to Nuke library explicitly
target_link_libraries(afx-nuke-plugins PRIVATE /opt/Nuke14.1v8/libDDImage.so OpenGL)

# Install the library to the specified location
install(TARGETS afx-nuke-plugins DESTINATION ${CMAKE_INSTALL_PREFIX})

