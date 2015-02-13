Shader "Hidden/Kineblur/Velocity Writer"
{
    CGINCLUDE

    #include "UnityCG.cginc"

    float4x4 _VelocityBuffer_MVP;

    struct appdata
    {
        float4 position : POSITION;
    };

    struct v2f
    {
        float4 position : SV_POSITION;
        float4 localPosition : TEXCOORD;
    };

    v2f vert(appdata v)
    {
        v2f o;
        o.position = mul(UNITY_MATRIX_MVP, v.position);
        o.localPosition = v.position;
        return o;
    }

    float4 frag(v2f i) : SV_Target
    {
        float4 p1 = mul(_VelocityBuffer_MVP, i.localPosition);
        float4 p2 = mul(UNITY_MATRIX_MVP, i.localPosition);
        return p2 - p1;
    }

    ENDCG

    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma glsl
            #pragma vertex vert
            #pragma fragment frag
            ENDCG
        }
    } 
}
