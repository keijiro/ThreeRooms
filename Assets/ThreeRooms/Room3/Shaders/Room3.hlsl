#include "../../Common/Shaders/Common.hlsl"
#include "../../Common/Shaders/SimplexNoise3D.hlsl"

// Cube map shadow caster; Used to render point light shadows on platforms
// that lacks depth cube map support.
#if defined(SHADOWS_CUBE) && !defined(SHADOWS_CUBE_IN_DEPTH_TEX)
#define PASS_CUBE_SHADOWCASTER
#endif

// Shader uniforms
half4 _Color;
half _Glossiness;
half _Metallic;
float _LocalTime;

// Null input attributes
struct Attributes {};

// Fragment varyings
struct Varyings
{
    float4 position : SV_POSITION;

#if defined(PASS_CUBE_SHADOWCASTER)
    // Cube map shadow caster pass
    float3 shadow : TEXCOORD0;

#elif defined(UNITY_PASS_SHADOWCASTER)
    // Default shadow caster pass

#else
    // GBuffer construction pass
    float3 wnormal : NORMAL;
    float3 wposition : TEXCOORD1;
    half3 ambient : TEXCOORD2;

#endif
};

//
// Vertex stage
//

Attributes Vertex(Attributes input) { return input; }

//
// Geometry stage
//

Varyings VertexOutput(float3 position, half3 normal)
{
    Varyings o;

    float4 cpos = UnityObjectToClipPos(float4(position, 1));
    float3 wpos = mul(unity_ObjectToWorld, float4(position, 1)).xyz;
    float3 wnrm = UnityObjectToWorldNormal(normal);

#if defined(PASS_CUBE_SHADOWCASTER)
    // Cube map shadow caster pass: Transfer the shadow vector.
    o.position = cpos;
    o.shadow = wpos - _LightPositionRange.xyz;

#elif defined(UNITY_PASS_SHADOWCASTER)
    // Default shadow caster pass: Apply the shadow bias.
    float scos = dot(wnrm, normalize(UnityWorldSpaceLightDir(wpos)));
    wpos -= wnrm * unity_LightShadowBias.z * sqrt(1 - scos * scos);
    o.position = UnityApplyLinearShadowBias(cpos);

#else
    // GBuffer construction pass
    o.position = cpos;
    o.wposition = wpos;
    o.wnormal = wnrm;
    o.ambient = ShadeSHPerVertex(wnrm, 0);

#endif
    return o;
}

float3 GetVertexPos(float phi, float l)
{
    return float3(cos(phi), sin(phi), 0) * l;
}

[maxvertexcount(64)]
void Geometry(
    triangle Attributes input[3],
    uint pid : SV_PrimitiveID,
    inout TriangleStream<Varyings> outStream
)
{
    float offs = frac(_Time.y);

    uint ix = pid % 6;
    uint iy = pid / 6;
    uint seed = abs(pid - floor(_Time.y) * 6);

    float width = 0.5 + sin(_Time.y * 2 + Random(seed) * 8) * 0.45;

    float phi1 = (ix + 0) * UNITY_PI / 3;
    float phi2 = (ix + 1) * UNITY_PI / 3;

    float w2 = lerp(0.1, 0.3, Random(ix * 6 + floor(_Time.y)));
    float w2d = lerp(0.1, 0.3, Random(ix * 6 + floor(_Time.y) + 1));
    w2 = lerp(w2, w2d, smoothstep(0, 0.5, frac(_Time.y)));
    float l1 = (iy + offs + 0) * w2;
    float l2 = (iy + offs + width) * w2;

    float3 v1 = GetVertexPos(phi1, l1);
    float3 v2 = GetVertexPos(phi1, l2);
    float3 v3 = GetVertexPos(phi2, l1);
    float3 v4 = GetVertexPos(phi2, l2);

    float3 n1 = float3(0, 0, 1);
    outStream.Append(VertexOutput(v1, n1));
    outStream.Append(VertexOutput(v2, n1));
    outStream.Append(VertexOutput(v3, n1));
    outStream.Append(VertexOutput(v4, n1));
    outStream.RestartStrip();
}

//
// Fragment phase
//

#if defined(PASS_CUBE_SHADOWCASTER)

// Cube map shadow caster pass
half4 Fragment(Varyings input) : SV_Target
{
    float depth = length(input.shadow) + unity_LightShadowBias.x;
    return UnityEncodeCubeShadowDepth(depth * _LightPositionRange.w);
}

#elif defined(UNITY_PASS_SHADOWCASTER)

// Default shadow caster pass
half4 Fragment() : SV_Target { return 0; }

#else

// GBuffer construction pass
void Fragment(
    Varyings input,
    out half4 outGBuffer0 : SV_Target0,
    out half4 outGBuffer1 : SV_Target1,
    out half4 outGBuffer2 : SV_Target2,
    out half4 outEmission : SV_Target3
)
{
    // PBS workflow conversion (metallic -> specular)
    half3 c_diff, c_spec;
    half refl10;
    c_diff = DiffuseAndSpecularFromMetallic(
        _Color, _Metallic, // input
        c_spec, refl10     // output
    );

    // Update the GBuffer.
    UnityStandardData data;
    data.diffuseColor = c_diff;
    data.occlusion = 1;
    data.specularColor = c_spec;
    data.smoothness = _Glossiness;
    data.normalWorld = input.wnormal;
    UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

    // Calculate ambient lighting and output to the emission buffer.
    half3 sh = ShadeSHPerPixel(data.normalWorld, input.ambient, input.wposition);
    outEmission = half4(sh * c_diff, 1);
}

#endif
