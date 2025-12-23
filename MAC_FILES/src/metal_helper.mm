// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
// Metal Helper Implementation for AFX Nuke Plugins

#ifdef __APPLE__
#ifdef USE_METAL

#import <Metal/Metal.h>
#import <Foundation/Foundation.h>

#include "include/metal_helper.h"
#include <vector>
#include <mutex>

namespace afx {

// Parameters structure matching the Metal shader
struct MedianParams {
    int med_size_i;
    int med_size_o;
    int med_n_i;
    int med_n_o;
    float m_lerp;
    float m_i_lerp;
    float sharpness;
    int width;
    int height;
};

// Implementation class holding Metal objects
class MetalDeviceImpl {
public:
    id<MTLDevice> device;
    id<MTLCommandQueue> commandQueue;
    id<MTLLibrary> library;
    id<MTLComputePipelineState> pipelineState;
    std::mutex metal_mutex;  // Protect Metal operations from concurrent access
    
    MetalDeviceImpl() : device(nil), commandQueue(nil), library(nil), pipelineState(nil) {}
    
    ~MetalDeviceImpl() {
        // ARC will clean up
    }
};

MetalDevice::MetalDevice() : impl_(std::make_unique<MetalDeviceImpl>()) {
    @autoreleasepool {
        // Get default Metal device
        impl_->device = MTLCreateSystemDefaultDevice();
        
        if (!impl_->device) {
            throw MetalException("Failed to create Metal device");
        }
        
        // Create command queue
        impl_->commandQueue = [impl_->device newCommandQueue];
        if (!impl_->commandQueue) {
            throw MetalException("Failed to create command queue");
        }
        
        // Load Metal shader library
        // Try to load from default library (compiled into app)
        NSError* error = nil;
        impl_->library = [impl_->device newDefaultLibrary];
        
        if (!impl_->library) {
            // If default library not available, try to compile from source
            // In production, you'd bundle the pre-compiled .metallib file
            throw MetalException("Failed to load Metal shader library");
        }
        
        // Get the kernel function
        id<MTLFunction> kernelFunction = [impl_->library newFunctionWithName:@"medianFilter"];
        if (!kernelFunction) {
            throw MetalException("Failed to find medianFilter function in Metal library");
        }
        
        // Create compute pipeline state
        impl_->pipelineState = [impl_->device newComputePipelineStateWithFunction:kernelFunction
                                                                            error:&error];
        if (!impl_->pipelineState) {
            NSString* errorMsg = error ? [error localizedDescription] : @"Unknown error";
            throw MetalException(std::string("Failed to create pipeline state: ") + 
                               [errorMsg UTF8String]);
        }
    }
}

MetalDevice::~MetalDevice() {
    // Unique_ptr will clean up impl_
}

bool MetalDevice::IsAvailable() const {
    return impl_->device != nil;
}

std::string MetalDevice::GetDeviceName() const {
    if (!impl_->device) {
        return "No Metal device";
    }
    
    @autoreleasepool {
        NSString* name = [impl_->device name];
        return std::string([name UTF8String]);
    }
}

void MetalDevice::ExecuteMedianFilter(
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
    float sharpness)
{
    // Lock mutex to prevent concurrent Metal access
    std::lock_guard<std::mutex> lock(impl_->metal_mutex);
    
    @autoreleasepool {
        // Create texture descriptor for input
        MTLTextureDescriptor* inputDescriptor = [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:MTLPixelFormatR32Float
                                         width:width
                                        height:height
                                     mipmapped:NO];
        inputDescriptor.usage = MTLTextureUsageShaderRead;
        inputDescriptor.storageMode = MTLStorageModeManaged;
        
        // Create input texture
        id<MTLTexture> inputTexture = [impl_->device newTextureWithDescriptor:inputDescriptor];
        if (!inputTexture) {
            throw MetalException("Failed to create input texture");
        }
        
        // Copy input data to texture
        MTLRegion region = MTLRegionMake2D(0, 0, width, height);
        [inputTexture replaceRegion:region
                         mipmapLevel:0
                           withBytes:input_data
                         bytesPerRow:input_pitch];
        
        // Create texture descriptor for output
        MTLTextureDescriptor* outputDescriptor = [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:MTLPixelFormatR32Float
                                         width:width
                                        height:height
                                     mipmapped:NO];
        outputDescriptor.usage = MTLTextureUsageShaderWrite;
        outputDescriptor.storageMode = MTLStorageModeManaged;
        
        // Create output texture
        id<MTLTexture> outputTexture = [impl_->device newTextureWithDescriptor:outputDescriptor];
        if (!outputTexture) {
            throw MetalException("Failed to create output texture");
        }
        
        // Create parameter buffer
        MedianParams params;
        params.med_size_i = med_size_i;
        params.med_size_o = med_size_o;
        params.med_n_i = med_n_i;
        params.med_n_o = med_n_o;
        params.m_lerp = m_lerp;
        params.m_i_lerp = m_i_lerp;
        params.sharpness = sharpness;
        params.width = width;
        params.height = height;
        
        id<MTLBuffer> paramBuffer = [impl_->device newBufferWithBytes:&params
                                                               length:sizeof(MedianParams)
                                                              options:MTLResourceStorageModeShared];
        if (!paramBuffer) {
            throw MetalException("Failed to create parameter buffer");
        }
        
        // Create command buffer
        id<MTLCommandBuffer> commandBuffer = [impl_->commandQueue commandBuffer];
        if (!commandBuffer) {
            throw MetalException("Failed to create command buffer");
        }
        
        // Create compute command encoder
        id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
        if (!encoder) {
            throw MetalException("Failed to create compute encoder");
        }
        
        // Set pipeline state
        [encoder setComputePipelineState:impl_->pipelineState];
        
        // Set textures and buffers
        [encoder setTexture:inputTexture atIndex:0];
        [encoder setTexture:outputTexture atIndex:1];
        [encoder setBuffer:paramBuffer offset:0 atIndex:0];
        
        // Calculate thread group sizes
        MTLSize threadGroupSize = MTLSizeMake(16, 16, 1);
        MTLSize threadGroups = MTLSizeMake(
            (width + threadGroupSize.width - 1) / threadGroupSize.width,
            (height + threadGroupSize.height - 1) / threadGroupSize.height,
            1
        );
        
        // Dispatch threads
        [encoder dispatchThreadgroups:threadGroups
                threadsPerThreadgroup:threadGroupSize];
        
        // End encoding
        [encoder endEncoding];
        
        // Commit command buffer
        [commandBuffer commit];
        
        // Wait for completion
        [commandBuffer waitUntilCompleted];
        
        // Check for errors
        if (commandBuffer.status == MTLCommandBufferStatusError) {
            NSError* error = commandBuffer.error;
            NSString* errorMsg = error ? [error localizedDescription] : @"Unknown error";
            throw MetalException(std::string("Metal command buffer error: ") + 
                               [errorMsg UTF8String]);
        }
        
        // Copy output data back to CPU
        [outputTexture getBytes:output_data
                    bytesPerRow:output_pitch
                     fromRegion:region
                    mipmapLevel:0];
    }
}

void MetalDevice::Synchronize() {
    // Metal command buffers are synchronous in this implementation
    // If using async command buffers, you'd wait here
}

} // namespace afx

#endif // USE_METAL
#endif // __APPLE__