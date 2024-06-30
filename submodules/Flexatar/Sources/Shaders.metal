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

typedef struct
{

    float4 clipSpacePosition [[position]];
 
    float2 textureCoordinate;
    float2 textureCoordinate1;
//    float2 borderMaskCoordinate;
//    uint   layer [[render_target_array_index]];

} RasterizerData1;

vertex RasterizerData mouthVertex(const device float2* textCoord [[ buffer(0) ]],
                                  const device float2* mandalaBshp [[ buffer(1) ]],
                                  const device int4 &index [[ buffer(2) ]],
                                  const device float4 &weight [[ buffer(3) ]],
                                  const device float2 &pivot [[ buffer(4) ]],
                                  const device float &mouthScale [[ buffer(5) ]],
                                  const device float2 &position [[ buffer(6) ]],
                                  const device matrix_float4x4 &zRotMatrix [[buffer(7)]],
                                  const device int &isRotated[[ buffer(8) ]],
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
    if (isRotated == 1){
        result.xy = result.yx;
    }else{
        result.y *= -1;
    }
//    result.xy = result.yx;
    out.clipSpacePosition = float4(result.xy, 0.25, 1);
    return out;
}

fragment half4 mouhtFragment(RasterizerData in [[stage_in]],
                             const device int4 &index [[ buffer(0) ]],
                             texture2d_array<half,access::sample> colorTexture1 [[texture(1) ]],
                             const device float4 &weight [[ buffer(2) ]],
                             const device float2 &teethKeyPoint [[ buffer(3) ]],
                             const device int &isTop [[ buffer(4) ]],
                             const device float &alpha [[ buffer(5) ]]
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
    col.a *= alpha;
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
                                  const device int &isRotated[[ buffer(13) ]],
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
    if (isRotated == 1){
        result.xy = result.yx;
    }else{
        result.y *= -1;
    }
//    result.xy = result.yx;
    out.clipSpacePosition = result;
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



vertex RasterizerData1 videoFlxVertex(const device float2* vertexArray [[ buffer(0) ]],
                                     const device matrix_float4x4 &videoOrientationMatrix [[buffer(1)]],
                                     const device float2* faceUV [[ buffer(2) ]],
                                     const device float2* speachBshp [[ buffer(4) ]],
                                     const device float4 &speachWeight1 [[ buffer(5) ]],
                                     const device float4 &speachWeight2 [[ buffer(6) ]],
                                      const device int &isRotated[[ buffer(7) ]],
                                      const device float &screenRatio[[ buffer(8) ]],
                                     unsigned int vid [[ vertex_id ]]) {
    RasterizerData1 out;
    const float mouthScale = speachWeight2.y;
    float2 result = vertexArray[vid];
    float2 uv = float2(1,1) - (videoOrientationMatrix * float4(result-float2(0.5,0.5), 0.0, 1.0)).xy-float2(0.5,0.5);
//    float2 uv = (videoOrientationMatrix * float4(result, 0.0, 1.0)).xy ;
//    out.textureCoordinate = (uv + float2(1))/float2(2);
    out.textureCoordinate = uv;
    out.textureCoordinate1 = (faceUV[vid]*float2(1.0,-1.0) + float2(1.0))/float2(2.0);
//    result *= float2(2);
//    result -= float2(1);
//    out.textureCoordinate = (uv + float2(1))/float2(2);
    int idx = vid*5;
    result += (speachWeight1.x * speachBshp[idx] + speachWeight1.y * speachBshp[idx+1]
        + speachWeight1.z * speachBshp[idx+2] + speachWeight1.w * speachBshp[idx+3]
        + speachWeight2.x * speachBshp[idx+4])*mouthScale/0.4;
    result = result.xy*float2(2)-float2(1);
    result.x *= -1;
    result.y *= screenRatio;
    if (isRotated == 1){
        result.xy = result.yx;
    }else{
        result.y *= -1;
    }
    out.clipSpacePosition = float4(result, 0.0, 1.0);
//    out.textureCoordinate = (vertexArray[vid] + float2(1))/float2(2);
    return out;
}

fragment half4 videoFlxFragment(RasterizerData1 in [[stage_in]],
                                texture2d<half,access::sample> videoTexture [[texture(0) ]],
                                texture2d<half,access::sample> mouthLineMask [[texture(1) ]],
                                const device float &opFactor [[ buffer(2) ]]
                                ) {
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    
    half4 col = videoTexture.sample(textureSampler, in.textureCoordinate);
    col.a *= opFactor*mouthLineMask.sample(textureSampler, in.textureCoordinate1).x+(1-opFactor);
    return col;
 
}


// ===== effects shader =====

typedef struct
{

    float4 clipSpacePosition [[position]];
 
    float2 textureCoordinate;
    float hybridWeight;
//    float2 borderMaskCoordinate;
//    uint   layer [[render_target_array_index]];

} RasterizerDataEffect;
vertex RasterizerDataEffect headEffectsVertex(const device float2* textCoord [[ buffer(0) ]],
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
                                  
                                  const device float4* mandalaBshp1 [[ buffer(13) ]],
                                  const device int &effectID [[ buffer(14) ]],
                                  const device int &isRotated[[ buffer(15) ]],
                                  unsigned int vid [[ vertex_id ]]) {
    RasterizerDataEffect out;
    const float2 coordinates = textCoord[vid];
    out.textureCoordinate = (coordinates*float2(1.0,-1.0) + float2(1.0))/float2(2.0);
    int idx = vid*5;
    const float mixWeight = params.w;
    float4 result;
    const float4 result1 = mandalaBshp[idx + index.x]*weight.x
    + mandalaBshp[idx + index.y]*weight.y
    + mandalaBshp[idx + index.z]*weight.z;
    const float4 result2 = mandalaBshp1[idx + index.x]*weight.x
    + mandalaBshp1[idx + index.y]*weight.y
    + mandalaBshp1[idx + index.z]*weight.z;
    
    if (effectID == 0){
        result = result1 * mixWeight + result2 * (1.0-mixWeight);
        out.hybridWeight = -1.0;
        
    }else{
        float theta = mixWeight * 6.28;
        float3 linePoint = float3(sin(theta),cos(theta),1.0);
        float3 curPoint = float3(coordinates + float2(0.0,-0.15),1.0);
        float s = dot(cross(linePoint,curPoint),float3(0,0,1.0));
        float w = clamp(s/0.15,-1.0,1.0);
        w+=1.0;
        w/=2.0;
        out.hybridWeight = w;
        result = result1 * w + result2 * (1.0-w);
        
    }
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
    if (isRotated == 1){
        result.xy = result.yx;
    }else{
        result.y *= -1;
    }
    out.clipSpacePosition = result;
    return out;
}

fragment half4 headEffectsFragment(RasterizerDataEffect in [[stage_in]],
                             const device int4 &index [[ buffer(0) ]],
                             texture2d_array<half,access::sample> colorTexture1 [[texture(1) ]],
                             const device float4 &weight [[ buffer(2) ]],
                             texture2d<half,access::sample> mouthLineMask [[texture(3) ]],
                             const device float &opFactor [[ buffer(4) ]],
                             const device float &mixWeight [[ buffer(5) ]],
                             texture2d_array<half,access::sample> colorTexture2 [[texture(6) ]]
                                   
                             ) {
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    
    float mw;
    if (in.hybridWeight<0) {
        mw = mixWeight;
    }else{
        mw = in.hybridWeight;
    }
    half4 col = (colorTexture1.sample(textureSampler, in.textureCoordinate, index.x)*weight.x+
                      colorTexture1.sample(textureSampler, in.textureCoordinate, index.y)*weight.y+
                      colorTexture1.sample(textureSampler, in.textureCoordinate, index.z)*weight.z)*mw
    +(colorTexture2.sample(textureSampler, in.textureCoordinate, index.x)*weight.x+
      colorTexture2.sample(textureSampler, in.textureCoordinate, index.y)*weight.y+
      colorTexture2.sample(textureSampler, in.textureCoordinate, index.z)*weight.z)*(1-mw);
    
    
    col.a *= opFactor*mouthLineMask.sample(textureSampler, in.textureCoordinate).x+(1-opFactor);
    return col;
}
