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
        _NeighborMaxTex ("-", 2D) = ""{}
    }

    CGINCLUDE

    #pragma multi_compile QUALITY_LOW QUALITY_MEDIUM QUALITY_HIGH

    #include "UnityCG.cginc"

    sampler2D _MainTex;
    float4 _MainTex_TexelSize;

    sampler2D _VelocityTex;
    float4 _VelocityTex_TexelSize;

    sampler2D _NeighborMaxTex;
    float4 _NeighborMaxTex_TexelSize;

    // Filter variables.
    float _MaxBlurRadius;
    float _DepthFilterStrength;

    // Filter coefficients.
    static const float sample_jitter = 2;

    #if QUALITY_HIGH
    static const int sample_count = 30;
    #elif QUALITY_MEDIUM
    static const int sample_count = 20;
    #else
    static const int sample_count = 10;
    #endif

    // Safer version of vector normalization.
    float2 safe_norm(float2 v)
    {
        float l = max(length(v), 1e-6);
        return v / l * step(0.5, l);
    }

    // Interleaved gradient function from CoD AW.
    // http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
    float gnoise(float2 uv, float2 offs)
    {
        uv = uv / _MainTex_TexelSize.xy + offs;
        float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
        return frac(magic.z * frac(dot(uv, magic.xy)));
    }

    // Jitter function for tile lookup.
    float2 jitter_tile(float2 uv)
    {
        float rx, ry;
        sincos(gnoise(uv, float2(3, 2)) * UNITY_PI * 2, ry, rx);
        return float2(rx, ry) * _NeighborMaxTex_TexelSize.xy / 4;
    }

    // Cone shaped interpolation.
    float cone(float T, float l_V)
    {
        return saturate(1.0 - T / l_V);
    }

    // Cylinder shaped interpolation.
    float cylinder(float T, float l_V)
    {
        return 1.0 - smoothstep(0.95 * l_V, 1.05 * l_V, T);
    }

    // Depth comparison function.
    float zcompare(float za, float zb)
    {
        return saturate(1.0 - _DepthFilterStrength * (zb - za) / min(za, zb));
    }

    // Lerp and normalization.
    float2 rnmix(float2 a, float2 b, float p)
    {
        return safe_norm(lerp(a, b, saturate(p)));
    }

    float3 sample_velocity(float2 uv)
    {
        float3 v = tex2D(_VelocityTex, uv);
        return float3((v.xy * 2 - 1) * _MaxBlurRadius, v.z);
    }

    // Sample weight calculation.
    float sample_weight(float2 d_n, float l_v_c, float z_p, float T, float2 S_uv, float w_A)
    {
        float3 temp = tex2D(_VelocityTex, S_uv);

        float2 v_S = (temp.xy * 2 - 1) * _MaxBlurRadius;
        float l_v_S = max(length(v_S), 0.5);

        float z_S = temp.z;

        float f = zcompare(z_p, z_S);
        float b = zcompare(z_S, z_p);

        float w_B = abs(dot(v_S / l_v_S, d_n));

        float weight = 0.0;
        weight += f * cone(T, l_v_S) * w_B;
        weight += b * cone(T, l_v_c) * w_A;
        weight += cylinder(T, min(l_v_S, l_v_c)) * max(w_A, w_B) * 2;

        return weight;
    }

    // Reconstruction filter.
    half4 frag_reconstruction(v2f_img i) : SV_Target
    {
        float2 p = i.uv / _MainTex_TexelSize.xy;
        float2 p_uv = i.uv;

        // Velocity vector at p.
        float3 v_c_t = sample_velocity(p_uv);
        float2 v_c = v_c_t.xy;
        float2 v_c_n = safe_norm(v_c);
        float l_v_c = max(length(v_c), 0.5);

        // Nightbor-max vector at p with small jitter.
        float2 v_max = tex2D(_NeighborMaxTex, p_uv + jitter_tile(p_uv)).xy;
        float2 v_max_n = safe_norm(v_max);
        float l_v_max = length(v_max);

        // Linearized depth at p.
        float z_p = v_c_t.z;

        // A vector perpendicular to v_max.
        float2 w_p = v_max_n.yx * float2(-1, 1);
        if (dot(w_p, v_c) < 0.0) w_p = -w_p;

        // Alternative sampling direction.
        float2 w_c = rnmix(w_p, v_c_n, (l_v_c - 0.5) / 1.5);

        // First itegration sample (center sample).
        float totalWeight = (float)sample_count / (l_v_c * 40);
        float3 result = tex2D(_MainTex, p_uv) * totalWeight;

        // Start from t = -1 with small jitter.
        float t = -1.0 + gnoise(p_uv, 0) * sample_jitter / (sample_count + sample_jitter);
        float dt = 2.0 / (sample_count + sample_jitter);

        // Precalc the w_A parameters.
        float w_A1 = dot(w_c, v_c_n);
        float w_A2 = dot(w_c, v_max_n);

        for (int c = 0; c < sample_count / 2; c++)
        {
            // Odd-numbered sample: sample along v_c.
            {
                float2 S_uv = (t * v_c + p) * _MainTex_TexelSize.xy;
                float weight = sample_weight(v_c_n, l_v_c, z_p, abs(t * l_v_max), S_uv, w_A1);

                result += tex2D(_MainTex, S_uv).rgb * weight;
                totalWeight += weight;

                t += dt;
            }
            // Even-numbered sample: sample along v_max.
            {
                float2 S_uv = (t * v_max + p) * _MainTex_TexelSize.xy;
                float weight = sample_weight(v_max_n, l_v_c, z_p, abs(t * l_v_max), S_uv, w_A2);

                result += tex2D(_MainTex, S_uv).rgb * weight;
                totalWeight += weight;

                t += dt;
            }
        }

        return float4(result / totalWeight, 1);
    }

    // Debug shader (visualizes the velocity buffers).
    half4 frag_velocity(v2f_img i) : SV_Target
    {
        half2 v = tex2D(_VelocityTex, i.uv).xy;
        return half4(v, 0.5, 1);
    }

    half4 frag_neighbormax(v2f_img i) : SV_Target
    {
        half2 v = tex2D(_NeighborMaxTex, i.uv).xy;
        v = (v / _MaxBlurRadius + 1) / 2;
        return half4(v, 0.5, 1);
    }

    half4 frag_depth(v2f_img i) : SV_Target
    {
        half z = frac(tex2D(_VelocityTex, i.uv).z * 128);
        return half4(z, z, z, 1);
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
            #pragma fragment frag_velocity
            ENDCG
        }
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            Fog { Mode off }      
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_neighbormax
            ENDCG
        }
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            Fog { Mode off }
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_depth
            ENDCG
        }
    }
}
