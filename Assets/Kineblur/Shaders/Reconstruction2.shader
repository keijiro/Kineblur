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

    static const int sample_count = 12;

    float cone(float2 X, float2 Y, float2 V)
    {
        return saturate(1.0 - length(X - Y) / length(V));
    }

    float cylinder(float2 X, float2 Y, float2 V)
    {
        float Vl = length(V);
        return 1.0 - smoothstep(0.95 * Vl, 1.05 * Vl, length(X - Y));
    }

    float soft_depth_compare(float za, float zb)
    {
        return saturate(1.0 - (za - zb) / 0.01);
    }

    // Reconstruction filter.

    float nrand(float2 uv)
    {
        return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
    }

    half4 frag_reconstruction(v2f_img i) : SV_Target
    {
        float2 X = i.uv;


        float2 V_X = tex2D(_VelocityTex, X).xy;
        float2 V_N = tex2D(_NeighborMaxTex, X).xy;
        float Z_X = -Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, X));

        float weight = min(1.0 / length(V_X), 1);
        float3 sum = tex2D(_MainTex, i.uv).rgb * weight;

        float t = -0.5;
        for (int c = 0; c < sample_count; c++)
        {
            float2 Y = X + V_N * t;

            float2 V_Y = tex2D(_VelocityTex, Y);
            float Z_Y = -Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, Y));

            float f = soft_depth_compare(Z_X, Z_Y);
            float b = soft_depth_compare(Z_Y, Z_X);

            float alpha = f * cone(Y, X, V_Y) + b * cone(X, Y, V_X) + cylinder(Y, X, V_Y) * cylinder(X, Y, V_X) * 2;

            weight += alpha;
            sum += tex2D(_MainTex, Y).rgb * alpha;

            t += 1.0 / sample_count;
        }

        return float4(sum / weight, 1);
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
