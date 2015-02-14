Shader "Hidden/Kineblur/Postprocess"
{
    Properties
    {
        _MainTex     ("-", 2D) = ""{}
        _VelocityTex ("-", 2D) = ""{}
    }

    CGINCLUDE

    #include "UnityCG.cginc"

    sampler2D _MainTex;
    float4 _MainTex_TexelSize;

    //

    float _BlurDistance;

    static const float blurWeights[7] = { 0.0205, 0.0855, 0.232, 0.324, 0.232, 0.0855, 0.0205 };

    half4 frag_prepass1(v2f_img i) : SV_Target
    {
        float2 acc = 0;
        float2 uv = i.uv - _MainTex_TexelSize.xy * float2(_BlurDistance * 3, 0);

        for (int c = 0; c < 7; c++)
        {
            acc += tex2D(_MainTex, uv).xy * blurWeights[c];
            uv += _MainTex_TexelSize.xy * float2(_BlurDistance, 0);
        }

        return half4(acc, 0, 0);
    }

    half4 frag_prepass2(v2f_img i) : SV_Target
    {
        float2 acc = 0;
        float2 uv = i.uv - _MainTex_TexelSize.xy * float2(0, _BlurDistance * 3);

        for (int c = 0; c < 7; c++)
        {
            acc += tex2D(_MainTex, uv).xy * blurWeights[c];
            uv += _MainTex_TexelSize.xy * float2(0, _BlurDistance);
        }

        return half4(acc, 0, 0);
    }


    //

    sampler2D _VelocityTex;
    float4 _VelocityTex_TexelSize;

    static const int nSamples = 20;

    half4 frag_scatter(v2f_img i) : SV_Target 
    {
        float2 v = tex2D(_VelocityTex, i.uv).xy;
        float4 s = tex2D(_MainTex, i.uv);

        for (int si = 0; si < nSamples; si++)
        {
            float2 d = v * (si - (nSamples - 1) / 2) / nSamples;
            s += tex2D(_MainTex, i.uv + d);
        }

        return s / nSamples;
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
            #pragma fragment frag_prepass1
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
            #pragma fragment frag_prepass2
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
            #pragma fragment frag_scatter
            ENDCG
        }
    }
}
