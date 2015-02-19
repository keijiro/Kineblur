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

// Gaussian blur filter (used to reduce discontinuity in the velocity map).
Shader "Hidden/Kineblur/Gaussian"
{
    Properties
    {
        _MainTex("-", 2D) = "white" {}
    }

    CGINCLUDE

    #include "UnityCG.cginc"

    sampler2D _MainTex;
    float4 _MainTex_TexelSize;

    // Coefficients for the linear sampling Gaussian filter.
    // http://rastergrid.com/blog/2010/09/efficient-gaussian-blur-with-linear-sampling/
    static const float offset[3] = { 0.0, 1.3846153846, 3.2307692308 };
    static const float weight[3] = { 0.2270270270, 0.3162162162, 0.0702702703 };

    // Filter function of the separable Gaussian filter.
    float4 gaussian_filter(float2 uv, float2 stride)
    {
        float4 s = tex2D(_MainTex, uv) * weight[0];
        for (int i = 1; i < 3; i++)
        {
            float2 d = stride * offset[i];
            s += tex2D(_MainTex, uv + d) * weight[i];
            s += tex2D(_MainTex, uv - d) * weight[i];
        }
        return s;
    }

    // Quarter downsampling.
    half4 frag_quarter(v2f_img i) : SV_Target
    {
        float4 s;
        s  = tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(-1, -1));
        s += tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(+1, -1));
        s += tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(-1, +1));
        s += tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(+1, +1));
        return s / 4;
    }

    // Separable Gaussian filter functions (horizontal/vertical).
    half4 frag_blur_h(v2f_img i) : SV_Target
    {
        return gaussian_filter(i.uv, float2(_MainTex_TexelSize.x, 0));
    }
    half4 frag_blur_v(v2f_img i) : SV_Target
    {
        return gaussian_filter(i.uv, float2(0, _MainTex_TexelSize.y));
    }

    ENDCG 

    Subshader
    {
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            Fog { Mode off }      
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_quarter
            ENDCG
        }
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            Fog { Mode off }      
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_blur_h
            #pragma target 3.0
            #pragma glsl
            ENDCG
        }
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            Fog { Mode off }      
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_blur_v
            #pragma target 3.0
            #pragma glsl
            ENDCG
        }
    }
}
