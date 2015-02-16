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
Shader "Hidden/Kineblur/Reconstruction"
{
    Properties
    {
        _MainTex        ("-", 2D) = ""{}
        _VelocityTex    ("-", 2D) = ""{}
        _VelocityScale  ("-", Float) = 1
    }

    CGINCLUDE

    #pragma multi_compile QUALITY_LOW QUALITY_MEDIUM QUALITY_HIGH QUALITY_SUPER
    #pragma multi_compile DITHER_OFF DITHER_ON

    #include "UnityCG.cginc"

    sampler2D _MainTex;
    float4 _MainTex_TexelSize;

    sampler2D _VelocityTex;
    float4 _VelocityTex_TexelSize;

    float _VelocityScale;

    #ifdef QUALITY_LOW
    static const int sample_count = 5;
    static const float dither_scale = 0.8;
    #elif QUALITY_MEDIUM
    static const int sample_count = 9;
    static const float dither_scale = 0.4;
    #elif QUALITY_HIGH
    static const int sample_count = 19;
    static const float dither_scale = 0.2;
    #else // QUALITY_SUPER
    static const int sample_count = 31;
    static const float dither_scale = 0.06;
    #endif

    // Interleaved gradient function from CoD AW.
    // http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare

    float interleaved_gradient(float2 uv)
    {
        float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
        return frac(magic.z * frac(dot(uv, magic.xy)));
    }

    float dither(float2 uv)
    {
        return interleaved_gradient(uv / _MainTex_TexelSize.xy);
    }

    // Reconstruction filter.

    half4 frag_reconstruction(v2f_img i) : SV_Target
    {
        float2 v = tex2D(_VelocityTex, i.uv).xy * _VelocityScale;

        #ifdef DITHER_ON
        v *= (dither(i.uv) - 0.5) * dither_scale + 1;
        #endif

        float2 ds = v / sample_count;
        float2 uv = i.uv - ds * (sample_count - 1) / 2;

        float4 s = 0;
        for (int c = 0; c < sample_count; c++)
        {
            s += tex2D(_MainTex, uv);
            uv += ds;
        }
        return s / sample_count;
    }

    // Debug shader (visualizes the velocity buffer).

    half4 frag_debug(v2f_img i) : SV_Target
    {
        float2 v = tex2D(_VelocityTex, i.uv).xy * 8 + 0.5;
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
