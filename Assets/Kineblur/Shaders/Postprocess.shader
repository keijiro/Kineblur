Shader "Hidden/Kineblur/Postprocess"
{
    Properties
    {
        _MainTex        ("-", 2D) = ""{}
        _VelocityTex    ("-", 2D) = ""{}
    }

    CGINCLUDE

    #include "UnityCG.cginc"

    sampler2D _MainTex;
    float4 _MainTex_TexelSize;

    sampler2D _VelocityTex;
    float4 _VelocityTex_TexelSize;

    const int nSample = 8;

    half4 frag(v2f_img i) : SV_Target 
    {
        float2 v = tex2D(_VelocityTex, i.uv).xy;
        float4 s = tex2D(_MainTex, i.uv);

        for (int si = 0; si < nSample; si++)
        {
            float2 d = v * (si - (nSample - 1) / 2) / nSample;
            s += tex2D(_MainTex, i.uv + d);
        }

        return s / nSample;
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
            #pragma fragment frag
            ENDCG
        }
    }
}
