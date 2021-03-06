#include "Uniforms.glsl"
#include "Samplers.glsl"
#include "Transform.glsl"

#include "ScreenPos.glsl"

varying vec3 vTexCoord;

varying vec2 vScreenPos;
varying vec3 vFarRay;




#ifdef COMPILEVS

vec3 GetViewFarRay(vec4 clipPos)
{
    return vec3(cFrustumSize.x * clipPos.x,
                cFrustumSize.y * clipPos.y,
                cFrustumSize.z);
}

void VS()
{

    mat4 modelMatrix = iModelMatrix;
    vec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vScreenPos = GetScreenPosPreDiv(gl_Position);
    vFarRay = GetViewFarRay(gl_Position);


    vTexCoord = vec3(GetTexCoord(iTexCoord), GetDepth(gl_Position));
}

#endif


#ifdef COMPILEPS

#define NUM_SAMPLES 9.0
#define NUM_SPIRAL_TURNS 7.0

uniform vec3 cFrustumSize;
uniform vec4 cGBufferOffsets;

uniform vec4 cProjInfo;
uniform mat3 cView;

uniform float cNoiseMult;

uniform float cProjScale;
uniform float cProjScale2;

uniform float cRadius;
uniform float cBias;

uniform float cIntensityDivR6;



vec3 GetViewPosition(vec2 ssPos, float depth)
{
    // eye_z = depth(0=camera .. 1=far) * far
    float eye_z = depth * cFrustumSize.z;

    return vec3(ssPos * cProjInfo.xy + cProjInfo.zw, 1.0) * eye_z;
}

float rand(vec2 co)
{
    return fract(sin(dot(co, vec2(12.9898,78.233))) * 43758.5453);
}


//debug occlusion


void PS()
{

    vec3 edC = texture2D(sDepthBuffer, vScreenPos).rgb;
    float depthC = DecodeDepth(edC);

    vec3 vsC = GetViewPosition(vScreenPos, depthC);

    float intensity = cIntensityDivR6;

    float randomAngle = fract( pow(vScreenPos.x, vScreenPos.y) * 43758.5453 ) / cGBufferInvSize.x;

    //normals
    vec3 vsN = normalize( cross(dFdy(vsC), dFdx(vsC)) );


    float ssDiskRadius = cProjScale2 * cProjScale * cRadius / vsC.z; 
        
    float sum = 0.0;
    float radius2 = cRadius * cRadius;
    const float epsilon = 0.01;
    
    for (float i = 0.0; i < NUM_SAMPLES; ++i)
    {
        float alpha = (i + 0.5) * (1.0 / NUM_SAMPLES);
        float angle = randomAngle + alpha * (NUM_SPIRAL_TURNS * 6.28);
        
        vec2 ssOffset = floor( alpha * ssDiskRadius * vec2(cos(angle), sin(angle)) );
        vec2 ssP = vScreenPos + ssOffset * cGBufferInvSize;

        float depthP = DecodeDepth(texture2D(sDepthBuffer, ssP).rgb);
        vec3 vsP = GetViewPosition(ssP, depthP);
            
        vec3 v = vsP - vsC;
        
        float vv = dot(v, v);
        float vn = dot(v, vsN);

        float f = max(radius2 - vv, 0.0);
        sum += f * f * f * max((vn - cBias) / (epsilon + vv), 0.0);

    }

    float occlusion = max(0.0, 1.0 - sum * intensity * (5.0 / NUM_SAMPLES));

    //gl_FragColor = vec4(occlusion, edC.rg, 1.0);

    gl_FragColor = vec4(vsN,1) * 100.0 ;

    //gl_FragColor = vec4(EncodeDepth(vTexCoord.z), 1.0);
}

#endif
