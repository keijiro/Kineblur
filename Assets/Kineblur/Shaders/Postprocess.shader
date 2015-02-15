Shader "Hidden/Kineblur/Postprocess"
{
    Properties
    {
        _MainTex        ("-", 2D) = ""{}
        _VelocityTex    ("-", 2D) = ""{}
        _BlurDistance   ("-", Float) = 1
        _VelocityScale  ("-", Float) = 1
    }

    CGINCLUDE

    #pragma multi_compile QUALITY_LOW QUALITY_MEDIUM QUALITY_HIGH

    #include "UnityCG.cginc"

    sampler2D _MainTex;
    float4 _MainTex_TexelSize;

    // Prepass filter (Gaussian blur filter).

    float _BlurDistance;

    static const float blur_kernel[7] = { 0.0205, 0.0855, 0.232, 0.324, 0.232, 0.0855, 0.0205 };

    half4 blur_filter(float2 uv, float2 ds)
    {
        float2 acc = 0;
        uv -= ds * 3;
        for (int c = 0; c < 7; c++)
        {
            acc += tex2D(_MainTex, uv).xy * blur_kernel[c];
            uv += ds;
        }
        return half4(acc, 0, 0);
    }

    half4 frag_prepass_h(v2f_img i) : SV_Target
    {
        return blur_filter(i.uv, float2(_MainTex_TexelSize.x * _BlurDistance, 0));
    }

    half4 frag_prepass_v(v2f_img i) : SV_Target
    {
        return blur_filter(i.uv, float2(0, _MainTex_TexelSize.y * _BlurDistance));
    }

    // Reconstruction filter.

    sampler2D _VelocityTex;
    float4 _VelocityTex_TexelSize;
    float _VelocityScale;

    #ifdef QUALITY_LOW
    static const int sample_count = 5;
    #elif QUALITY_MEDIUM
    static const int sample_count = 9;
    #else // QUALITY_HIGH
    static const int sample_count = 18;
    #endif

    half4 frag_reconstruct(v2f_img i) : SV_Target
    {
        float2 v = tex2D(_VelocityTex, i.uv).xy * _VelocityScale;

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
            #pragma fragment frag_prepass_h
            ENDCG
        }
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            Fog { Mode off }      
            CGPROGRAM
            #pragma target 3.0
            #pragma glsl
            #pragma vertex vert_img
            #pragma fragment frag_prepass_v
            ENDCG
        }
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            Fog { Mode off }      
            CGPROGRAM
            #pragma target 3.0
            #pragma glsl
            #pragma vertex vert_img
            #pragma fragment frag_reconstruct
            ENDCG
        }
    }
}
