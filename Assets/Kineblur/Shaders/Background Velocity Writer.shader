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

// Velocity writer for backgorund.
Shader "Hidden/Kineblur/Background Velocity Writer"
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
        float4 position = float4(v.position.xyz, 0);
        o.coord1 = mul(UNITY_MATRIX_VP, position);
        o.coord2 = mul(_KineblurVPMatrix, position);
        o.position = o.coord1.xyww;
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
            Cull Off
            Fog { Mode off }      
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDCG
        }
    } 
}
