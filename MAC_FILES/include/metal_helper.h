// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Metal Helper for AFX Nuke Plugins
// Provides C++ interface to Metal compute

#ifndef AFX_METAL_HELPER_H_
#define AFX_METAL_HELPER_H_

#ifdef __APPLE__
#ifdef USE_METAL

#include "include/bounds.h"
#include <memory>
#include <string>

namespace afx {

// Forward declarations for Metal types (hidden from C++)
class MetalDeviceImpl;
class MetalTextureImpl;
class MetalBufferImpl;

// Metal device manager
class MetalDevice {
public:
    MetalDevice();
    ~MetalDevice();
    
    // Check if Metal is available
    bool IsAvailable() const;
    
    // Get device name
    std::string GetDeviceName() const;
    
    // Execute median filter kernel
    void ExecuteMedianFilter(
        const float* input_data,
        float* output_data,
        int width,
        int height,
        size_t input_pitch,
        size_t output_pitch,
        int med_size_i,
        int med_size_o,
        int med_n_i,
        int med_n_o,
        float m_lerp,
        float m_i_lerp,
        float sharpness
    );
    
    // Synchronize - wait for all GPU work to complete
    void Synchronize();
    
private:
    std::unique_ptr<MetalDeviceImpl> impl_;
};

// Exception class for Metal errors
class MetalException : public std::runtime_error {
public:
    explicit MetalException(const std::string& message)
        : std::runtime_error(message) {}
};

} // namespace afx

#endif // USE_METAL
#endif // __APPLE__

#endif // AFX_METAL_HELPER_H_
