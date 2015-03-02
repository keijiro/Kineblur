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

    static const int sample_count = 24;

    // Local functions.

    float2 norm(float2 v)
    {
        float l = length(v);
        return l > 0.5 ? v / l : float2(0, 0);
    }

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

    float zcompare(float za, float zb)
    {
        return saturate(1.0 - 4 * (zb - za) / min(za, zb));
    }

    float2 rnmix(float2 a, float2 b, float p)
    {
        return norm(lerp(a, b, saturate(p)));
    }

    // Reconstruction filter.

    half4 frag_reconstruction(v2f_img i) : SV_Target
    {
        float2 p = i.uv / _MainTex_TexelSize.xy;
        float2 p_uv = i.uv;

        float2 jitter = float2(nrand(p_uv), nrand(p_uv + float2(2,3))) * _MainTex_TexelSize.xy * 8;
        float2 v_max = tex2D(_NeighborMaxTex, p_uv + jitter).xy;

        float2 w_n = norm(v_max);
        float2 v_c = tex2D(_VelocityTex, p_uv).xy;
        float2 w_p = float2(-w_n.y, w_n.x);

        if (dot(w_p, v_c) < 0.0) w_p = -w_p;

        float2 w_c = rnmix(w_p, norm(v_c), (length(v_c) - 0.5) / 1.5);

        float totalWeight = (float)sample_count / (max(length(v_c), 0.5) * 40);
        float3 result = tex2D(_MainTex, p_uv) * totalWeight;

        float Z_p = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, p_uv));

        float t = -1.0 + nrand(p_uv) / (sample_count + 1);
        for (int c = 0; c < sample_count; c++)
        {
            float2 d = (fmod(c, 2) < 1) ? v_c : v_max;
            float T = abs(t * length(v_max));
            float2 S = t * d + p;
            float2 S_uv = S * _MainTex_TexelSize.xy;

            float2 v_S = tex2D(_VelocityTex, S_uv);
            float3 colorSample = tex2D(_MainTex, S_uv);

            float Z_S = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, S_uv));

            float f = zcompare(Z_p, Z_S);
            float b = zcompare(Z_S, Z_p);

            float w_A = abs(dot(w_c, norm(d)));
            float w_B = abs(dot(norm(v_S), norm(d)));

            float weight = 0.0;
            weight += f * cone(T, length(v_S) + 1e-6) * w_B;
            weight += b * cone(T, length(v_c) + 1e-6) * w_A;
            weight += cylinder(T, min(length(v_S), length(v_c))) * max(w_A, w_B) * 2;

            totalWeight += weight;
            result += colorSample * weight;

            t += 2.0 / (sample_count + 1);
        }

        return float4(result / totalWeight, 1);
    }

    // Debug shader (visualizes the velocity buffer).

    half4 frag_debug(v2f_img i) : SV_Target
    {
        //float2 v = tex2D(_VelocityTex, i.uv).xy * 8 + 0.5;
        float2 v = tex2D(_NeighborMaxTex, i.uv).xy * 8 + 0.5;
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
