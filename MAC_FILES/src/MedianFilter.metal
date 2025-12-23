//
// MedianFilter.metal
// AFX Nuke Plugins - Metal Compute Shader
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
using namespace metal;

// Swap function for sorting
inline void swap(thread float* a, thread float* b) {
    float temp = *a;
    *a = *b;
    *b = temp;
}

// Sort two values
inline void sort2(thread float* a, thread float* b) {
    if (*a > *b) {
        swap(a, b);
    }
}

// Quick median for 9 elements (3x3 kernel)
float median9(thread float* p) {
    sort2(&p[1], &p[2]); sort2(&p[4], &p[5]); sort2(&p[7], &p[8]);
    sort2(&p[0], &p[1]); sort2(&p[3], &p[4]); sort2(&p[6], &p[7]);
    sort2(&p[1], &p[2]); sort2(&p[4], &p[5]); sort2(&p[7], &p[8]);
    sort2(&p[0], &p[3]); sort2(&p[5], &p[8]); sort2(&p[4], &p[7]);
    sort2(&p[3], &p[6]); sort2(&p[1], &p[4]); sort2(&p[2], &p[5]);
    sort2(&p[4], &p[7]); sort2(&p[4], &p[2]); sort2(&p[6], &p[4]);
    sort2(&p[4], &p[2]);
    return p[4];
}

// Quick median for 25 elements (5x5 kernel)
float median25(thread float* p) {
    sort2(&p[0],  &p[1]);  sort2(&p[3],  &p[4]);  sort2(&p[2],  &p[4]);
    sort2(&p[2],  &p[3]);  sort2(&p[6],  &p[7]);  sort2(&p[5],  &p[7]);
    sort2(&p[5],  &p[6]);  sort2(&p[9],  &p[10]); sort2(&p[8],  &p[10]);
    sort2(&p[8],  &p[9]);  sort2(&p[12], &p[13]); sort2(&p[11], &p[13]);
    sort2(&p[11], &p[12]); sort2(&p[15], &p[16]); sort2(&p[14], &p[16]);
    sort2(&p[14], &p[15]); sort2(&p[18], &p[19]); sort2(&p[17], &p[19]);
    sort2(&p[17], &p[18]); sort2(&p[21], &p[22]); sort2(&p[20], &p[22]);
    sort2(&p[20], &p[21]); sort2(&p[23], &p[24]); sort2(&p[2],  &p[5]);
    sort2(&p[3],  &p[6]);  sort2(&p[0],  &p[6]);  sort2(&p[0],  &p[3]);
    sort2(&p[4],  &p[7]);  sort2(&p[1],  &p[7]);  sort2(&p[1],  &p[4]);
    sort2(&p[11], &p[14]); sort2(&p[8],  &p[14]); sort2(&p[8],  &p[11]);
    sort2(&p[12], &p[15]); sort2(&p[9],  &p[15]); sort2(&p[9],  &p[12]);
    sort2(&p[13], &p[16]); sort2(&p[10], &p[16]); sort2(&p[10], &p[13]);
    sort2(&p[20], &p[23]); sort2(&p[17], &p[23]); sort2(&p[17], &p[20]);
    sort2(&p[21], &p[24]); sort2(&p[18], &p[24]); sort2(&p[18], &p[21]);
    sort2(&p[19], &p[22]); sort2(&p[8],  &p[17]); sort2(&p[9],  &p[18]);
    sort2(&p[0],  &p[18]); sort2(&p[0],  &p[9]);  sort2(&p[10], &p[19]);
    sort2(&p[1],  &p[19]); sort2(&p[1],  &p[10]); sort2(&p[11], &p[20]);
    sort2(&p[2],  &p[20]); sort2(&p[2],  &p[11]); sort2(&p[12], &p[21]);
    sort2(&p[3],  &p[21]); sort2(&p[3],  &p[12]); sort2(&p[13], &p[22]);
    sort2(&p[4],  &p[22]); sort2(&p[4],  &p[13]); sort2(&p[14], &p[23]);
    sort2(&p[5],  &p[23]); sort2(&p[5],  &p[14]); sort2(&p[15], &p[24]);
    sort2(&p[6],  &p[24]); sort2(&p[6],  &p[15]); sort2(&p[7],  &p[16]);
    sort2(&p[7],  &p[19]); sort2(&p[13], &p[21]); sort2(&p[15], &p[23]);
    sort2(&p[7],  &p[13]); sort2(&p[7],  &p[15]); sort2(&p[1],  &p[9]);
    sort2(&p[3],  &p[11]); sort2(&p[5],  &p[17]); sort2(&p[11], &p[17]);
    sort2(&p[9],  &p[17]); sort2(&p[4],  &p[10]); sort2(&p[6],  &p[12]);
    sort2(&p[7],  &p[14]); sort2(&p[4],  &p[6]);  sort2(&p[4],  &p[7]);
    sort2(&p[12], &p[14]); sort2(&p[10], &p[14]); sort2(&p[6],  &p[7]);
    sort2(&p[10], &p[12]); sort2(&p[6],  &p[10]); sort2(&p[6],  &p[17]);
    sort2(&p[12], &p[17]); sort2(&p[7],  &p[17]); sort2(&p[7],  &p[10]);
    sort2(&p[12], &p[18]); sort2(&p[7],  &p[12]); sort2(&p[10], &p[18]);
    sort2(&p[12], &p[20]); sort2(&p[10], &p[20]); sort2(&p[10], &p[12]);
    return p[12];
}

// Partition function for quickselect
int partition(thread float* arr, int low, int high) {
    float pivot = arr[high];
    int i = low - 1;
    
    for (int j = low; j < high; j++) {
        if (arr[j] <= pivot) {
            i++;
            swap(&arr[i], &arr[j]);
        }
    }
    swap(&arr[i + 1], &arr[high]);
    return i + 1;
}

// Quickselect for arbitrary size arrays
float quickselect(thread float* arr, int n, int k) {
    int low = 0;
    int high = n - 1;
    
    while (low <= high) {
        int pi = partition(arr, low, high);
        
        if (pi == k) {
            return arr[pi];
        } else if (pi < k) {
            low = pi + 1;
        } else {
            high = pi - 1;
        }
    }
    
    return arr[k];
}

// Parameters passed to the kernel
struct MedianParams {
    int med_size_i;     // Inner median size
    int med_size_o;     // Outer median size
    int med_n_i;        // Inner number of elements
    int med_n_o;        // Outer number of elements
    float m_lerp;       // Lerp factor
    float m_i_lerp;     // Inverse lerp factor
    float sharpness;    // Sharpness parameter
    int width;          // Image width
    int height;         // Image height
};

// Main median filter kernel
kernel void medianFilter(
    texture2d<float, access::sample> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant MedianParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    // Check bounds
    if (gid.x >= uint(params.width) || gid.y >= uint(params.height)) {
        return;
    }
    
    // Create sampler for reading input with edge clamping
    constexpr sampler textureSampler(
        mag_filter::nearest,
        min_filter::nearest,
        address::clamp_to_edge
    );
    
    int med_size_o = params.med_size_o;
    int med_size_i = params.med_size_i;
    
    // Get original pixel value
    float2 coord = float2(gid.x, gid.y);
    float original_value = inTexture.sample(textureSampler, (coord + 0.5) / float2(params.width, params.height)).r;
    
    // Collect values in neighborhood
    float values[625]; // Max size for 25x25 kernel (med_size=12)
    int count = 0;
    
    // Compute statistics for inner and outer regions
    float sum_i = 0.0f, sum_o = 0.0f;
    float sum_sq_i = 0.0f, sum_sq_o = 0.0f;
    int count_i = 0, count_o = 0;
    
    int med_size_2 = med_size_o * 2;
    
    for (int dy = -med_size_o; dy <= med_size_o; dy++) {
        for (int dx = -med_size_o; dx <= med_size_o; dx++) {
            float2 sample_coord = coord + float2(dx, dy);
            float2 tex_coord = (sample_coord + 0.5) / float2(params.width, params.height);
            float value = inTexture.sample(textureSampler, tex_coord).r;
            
            values[count++] = value;
            
            // Determine if on border
            int abs_dy = (dy < 0) ? -dy : dy;
            int abs_dx = (dx < 0) ? -dx : dx;
            
            if (abs_dy == med_size_o || abs_dx == med_size_o) {
                // Outer ring
                sum_o += value;
                sum_sq_o += value * value;
                count_o++;
            } else if (abs_dy <= med_size_i && abs_dx <= med_size_i) {
                // Inner region
                sum_i += value;
                sum_sq_i += value * value;
                count_i++;
            }
        }
    }
    
    // Compute median
    float median = 0.0f;
    
    if (count == 9) {
        median = median9(values);
    } else if (count == 25) {
        median = median25(values);
    } else {
        // Use quickselect for other sizes
        median = quickselect(values, count, count / 2);
    }
    
    // Compute statistics for sharpness
    float mean = (sum_i + sum_o) / float(count);
    float variance = ((sum_sq_i + sum_sq_o) / float(count)) - (mean * mean);
    variance = max(variance, 0.0f);
    float std_dev = sqrt(variance);
    
    // Apply sharpness
    std_dev = clamp(params.sharpness * 3.0f * std_dev, 0.0f, 1.0f);
    
    // Lerp between median and original based on std_dev
    float result = (1.0f - std_dev) * median + std_dev * original_value;
    
    // Write output
    outTexture.write(float4(result, result, result, 1.0f), gid);
}
