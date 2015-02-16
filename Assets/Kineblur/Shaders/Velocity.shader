Shader "Hidden/Kineblur/Velocity"
{
    CGINCLUDE

    #include "UnityCG.cginc"

    float4x4 _KineblurVPMatrix;
    float4x4 _KineblurBackMatrix;

    struct appdata
    {
        float4 position : POSITION;
    };

    struct v2f
    {
        float4 position : SV_POSITION;
        float4 coord1 : TEXCOORD0;
        float4 coord2 : TEXCOORD1;
    };

    v2f vert(appdata v)
    {
        v2f o;
        o.position = mul(UNITY_MATRIX_MVP, v.position);
        o.coord1 = o.position;
        o.coord2 = mul(_KineblurVPMatrix, mul(_KineblurBackMatrix, mul(_Object2World, v.position)));
        return o;
    }

    float2 frag(v2f i) : SV_Target
    {
        float2 p1 = i.coord1.xy / i.coord1.w;
        float2 p2 = i.coord2.xy / i.coord2.w;
        return (p2 - p1) / 2;
    }

    ENDCG

    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDCG
        }
    } 
}
