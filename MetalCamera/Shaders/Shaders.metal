//
//  DefaultVideoShader.metal
//  MetalCamera
//
//  Created by Boris Dering on 14.04.20.
//  Copyright © 2020 Boris Dering. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position [[ position ]];
    float2 texture_coordinates;
};

vertex Vertex vertex_default_video_shader(device const bool *is_mirrored [[buffer(1)]],
                                          uint id [[vertex_id]]) {
    
    float4x4 positions = float4x4(float4(-1,  1, 0, 1), // V0
                                  float4( 1,  1, 0, 1), // V1
                                  float4(-1, -1, 0, 1), // V2
                                  float4( 1, -1, 0, 1));// V3
                                  
    float4x2 texture_coordinates;
    
    if (*is_mirrored) {
        texture_coordinates = float4x2(float2(0, 0),
                                       float2(0, 1),
                                       float2(1, 0),
                                       float2(1, 1));
    } else {
       texture_coordinates = float4x2(float2(0, 1),
                                      float2(0, 0),
                                      float2(1, 1),
                                      float2(1, 0));
    }
    
    return Vertex {
        .position = positions[id],
        .texture_coordinates = texture_coordinates[id],
    };
}

fragment half4 fragment_default_video_shader(Vertex in [[ stage_in ]],
                                             texture2d<float> texture [[ texture(0) ]],
                                             sampler sampler2d [[ sampler(0) ]]) {
    
    float2 texture_coordinates = in.texture_coordinates;
    return half4(texture.sample(sampler2d, texture_coordinates));
}
