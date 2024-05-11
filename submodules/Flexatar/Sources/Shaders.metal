#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;


typedef struct
{

    float4 clipSpacePosition [[position]];
 
    float2 textureCoordinate;
//    float2 borderMaskCoordinate;
//    uint   layer [[render_target_array_index]];

} RasterizerData;

vertex RasterizerData mouthVertex(const device float2* textCoord [[ buffer(0) ]],
                                  const device float2* mandalaBshp [[ buffer(1) ]],
                                  const device int4 &index [[ buffer(2) ]],
                                  const device float4 &weight [[ buffer(3) ]],
                                  const device float2 &pivot [[ buffer(4) ]],
                                  const device float &mouthScale [[ buffer(5) ]],
                                  const device float2 &position [[ buffer(6) ]],
                                  const device matrix_float4x4 &zRotMatrix [[buffer(7)]],
                                  unsigned int vid [[ vertex_id ]]) {
    RasterizerData out;
    out.textureCoordinate = textCoord[vid];
    out.textureCoordinate.y = 1 - out.textureCoordinate.y;
    int idx = vid*5;
    float2 result = mandalaBshp[idx + index.x]*weight.x
                  + mandalaBshp[idx + index.y]*weight.y
                  + mandalaBshp[idx + index.z]*weight.z;
    result -= pivot;
    
    result *= mouthScale;
    result.x *= -1;
    result = (zRotMatrix * float4(result, 0 ,1)).xy;
    result += position;
    out.clipSpacePosition = float4(result.yx, 0.25, 1);
    return out;
}

fragment half4 mouhtFragment(RasterizerData in [[stage_in]],
                             const device int4 &index [[ buffer(0) ]],
                             texture2d_array<half,access::sample> colorTexture1 [[texture(1) ]],
                             const device float4 &weight [[ buffer(2) ]],
                             const device float2 &teethKeyPoint [[ buffer(3) ]],
                             const device int &isTop [[ buffer(4) ]]
                             ) {
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    
    half4 col = colorTexture1.sample(textureSampler, in.textureCoordinate, index.x)*weight.x+
                      colorTexture1.sample(textureSampler, in.textureCoordinate, index.y)*weight.y+
                      colorTexture1.sample(textureSampler, in.textureCoordinate, index.z)*weight.z;
    const float2 uv = in.textureCoordinate;
    if (isTop == 1){
        if (uv.y<teethKeyPoint.x) {col.a = 0; }
    }else{
        if (uv.y>teethKeyPoint.y){
            col.xyz *= (uv.y - teethKeyPoint.x)/(teethKeyPoint.y-teethKeyPoint.x);
        }
    }
    
    return col;
}

vertex RasterizerData clearVertex(const device float2* textCoord [[ buffer(0) ]],
                                  const device float4* mandalaBshp [[ buffer(1) ]],
                                  const device int4 &index [[ buffer(2) ]],
                                  const device float4 &weight [[ buffer(3) ]],
                                  const device float2* speachBshp [[ buffer(4) ]],
                                  const device float4 &speachWeight1 [[ buffer(5) ]],
                                  const device float4 &speachWeight2 [[ buffer(6) ]],
                                  const device matrix_float4x4 &viewModelMatrix [[buffer(7)]],
                                  const device matrix_float4x4 &extraRotMatrix [[buffer(8)]],
                                  const device float2* eyebrowBshp [[ buffer(9) ]],
                                  const device float4 &params [[ buffer(10) ]],
                                  const device matrix_float4x4 &zRotMatrix [[buffer(11)]],
                                  const device float2* blinkBshp [[ buffer(12) ]],
                                  unsigned int vid [[ vertex_id ]]) {
    RasterizerData out;
    out.textureCoordinate = (textCoord[vid]*float2(1.0,-1.0) + float2(1.0))/float2(2.0);
    int idx = vid*5;
    float4 result = mandalaBshp[idx + index.x]*weight.x
                  + mandalaBshp[idx + index.y]*weight.y
                  + mandalaBshp[idx + index.z]*weight.z;
    result.xy += speachWeight1.x * speachBshp[idx] + speachWeight1.y * speachBshp[idx+1]
        + speachWeight1.z * speachBshp[idx+2] + speachWeight1.w * speachBshp[idx+3]
        + speachWeight2.x * speachBshp[idx+4];
    result.xy += eyebrowBshp[vid]*params.x;
    result.xy += blinkBshp[vid]*params.z;
    
    result = extraRotMatrix * result;
    result = viewModelMatrix * result;
    
    result.x = atan(result.x/result.z)*5.0;
    result.y = atan(result.y/result.z)*5.0;
    result.z=0.5;
    
    result.y-=4.0;
    result = zRotMatrix * result;
    result.y+=4.0;
    
    result.x += speachWeight2.y;
    result.y -= speachWeight2.z;
    result.xy *= 0.8 + speachWeight2.w;
    result.y *= params.y;
    out.clipSpacePosition = result.yxzw;
    return out;
}

fragment half4 clearFragment(RasterizerData in [[stage_in]],
                             const device int4 &index [[ buffer(0) ]],
                             texture2d_array<half,access::sample> colorTexture1 [[texture(1) ]],
                             const device float4 &weight [[ buffer(2) ]],
                             texture2d<half,access::sample> mouthLineMask [[texture(3) ]],
                             const device float &opFactor [[ buffer(4) ]]) {
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    
    half4 col = colorTexture1.sample(textureSampler, in.textureCoordinate, index.x)*weight.x+
                      colorTexture1.sample(textureSampler, in.textureCoordinate, index.y)*weight.y+
                      colorTexture1.sample(textureSampler, in.textureCoordinate, index.z)*weight.z;
    
    col.a *= opFactor*mouthLineMask.sample(textureSampler, in.textureCoordinate).x+(1-opFactor);
    return col;
}
