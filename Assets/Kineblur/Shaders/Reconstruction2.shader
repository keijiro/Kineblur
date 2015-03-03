//
// Kineblur - Motion blur post effect for Unity.
//
// Copyright (C) 2015 Keijiro Takahashi
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
// the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

// Motion blur reconstruction filter.
Shader "Hidden/Kineblur/Reconstruction2"
{
    Properties
    {
        _MainTex        ("-", 2D) = ""{}
        _VelocityTex    ("-", 2D) = ""{}
        _NeighborMaxTex ("-", 2D) = ""{}
    }

    CGINCLUDE

    #include "UnityCG.cginc"

    sampler2D _MainTex;
    float4 _MainTex_TexelSize;

    sampler2D _VelocityTex;
    float4 _VelocityTex_TexelSize;

    sampler2D _NeighborMaxTex;
    float4 _NeighborMaxTex_TexelSize;

    sampler2D_float _CameraDepthTexture;

    static const int sample_count = 32;

    // Local functions.

    float nrand(float2 uv)
    {
        return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
    }

    float cone(float T, float l_V)
    {
        return saturate(1.0 - T / l_V);
    }

    float cylinder(float T, float l_V)
    {
        return 1.0 - smoothstep(0.95 * l_V, 1.05 * l_V, T);
    }

    float soft_depth_compare(float za, float zb)
    {
        return saturate(1.0 - (zb - za) / 0.001);
    }

    // Reconstruction filter.

    half4 frag_reconstruction(v2f_img i) : SV_Target
    {
        float2 X = i.uv / _MainTex_TexelSize.xy;
        float2 X_uv = i.uv;

        float2 jitter = float2(
            nrand(X_uv + float2(2, 3)),
            nrand(X_uv + float2(7, 5))
        );
        jitter *= _NeighborMaxTex_TexelSize.xy / 2;

        float2 V_X = tex2D(_VelocityTex, X_uv).xy;
        float2 V_N = tex2D(_NeighborMaxTex, X_uv + jitter).xy;
        float  Z_X = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, X_uv));

        float l_V_X = length(V_X);
        float l_V_N = length(V_N);

        float weight = 1.0 / max(length(V_X), 0.5);
        float3 sum = tex2D(_MainTex, i.uv).rgb * weight;

        float t = -1.0 + nrand(X_uv) / (sample_count + 1);
        for (int c = 0; c < sample_count; c++)
        {
            float T = abs(l_V_N * t);

            float2 Y = X + V_N * t;
            float2 Y_uv = Y * _MainTex_TexelSize.xy;

            float2 V_Y = tex2D(_VelocityTex, Y_uv);
            float l_V_Y = length(V_Y);

            float  Z_Y = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, Y_uv));

            float f = soft_depth_compare(Z_X, Z_Y);
            float b = soft_depth_compare(Z_Y, Z_X);

            float alpha = 0;
            alpha += f * cone(T, l_V_Y);
            alpha += b * cone(T, l_V_X);
            alpha += cylinder(T, l_V_Y) * cylinder(T, l_V_X) * 2;

            weight += alpha;
            sum += tex2D(_MainTex, Y_uv).rgb * alpha;

            t += 2.0 / (sample_count + 1);
        }

        return float4(sum / weight, 1);
    }

    // Debug shader (visualizes the velocity buffer).

    half4 frag_debug(v2f_img i) : SV_Target
    {
        float2 v = tex2D(_NeighborMaxTex, i.uv).xy / 30 + 0.5;
        return half4(v, 0.5, 1);
    }

    ENDCG 

    Subshader
    {
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            Fog { Mode off }      
            CGPROGRAM
            #pragma target 3.0
            #pragma glsl
            #pragma vertex vert_img
            #pragma fragment frag_reconstruction
            ENDCG
        }
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            Fog { Mode off }      
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_debug
            ENDCG
        }
    }
}
