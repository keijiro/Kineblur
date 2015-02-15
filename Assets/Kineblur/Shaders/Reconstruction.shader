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

    #include "UnityCG.cginc"

    sampler2D _MainTex;
    float4 _MainTex_TexelSize;

    sampler2D _VelocityTex;
    float4 _VelocityTex_TexelSize;

    float _VelocityScale;

    #ifdef QUALITY_LOW
    static const int sample_count = 5;
    #elif QUALITY_MEDIUM
    static const int sample_count = 9;
    #elif QUALITY_HIGH
    static const int sample_count = 19;
    #else // QUALITY_SUPER
    static const int sample_count = 31;
    #endif

    half4 frag_reconstruction(v2f_img i) : SV_Target
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
