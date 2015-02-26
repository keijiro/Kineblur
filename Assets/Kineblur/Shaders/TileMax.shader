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

// TileMax/NeighborMax filter.
Shader "Hidden/Kineblur/NeighborMax"
{
    Properties
    {
        _MainTex("-", 2D) = "white" {}
    }

    CGINCLUDE

    #include "UnityCG.cginc"

    sampler2D _MainTex;
    float4 _MainTex_TexelSize;

    static const int tile_divisor = 31;

    float3 vmax(float3 v1, float3 v2)
    {
        float p = dot(v1, v1) < dot(v2, v2);
        return lerp(v1, v2, p);
    }

    // TileMax filter.
    half4 frag_tile_max(v2f_img i) : SV_Target
    {
        float2 uv = i.uv - _MainTex_TexelSize.xy * tile_divisor / 2;
        float3 c_max = 0;

        for (int ix = 0; ix < tile_divisor; ix++)
        {
            float2 uv2 = uv;
            for (int iy = 0; iy < tile_divisor; iy++)
            {
                c_max = vmax(c_max, tex2D(_MainTex, uv2).rgb);
                uv2 += float2(_MainTex_TexelSize.x, 0);
            }
            uv += float2(0, _MainTex_TexelSize.y);
        }

        return half4(c_max, 1);
    }

    // NeighborMax filter.
    half4 frag_neighbor_max(v2f_img i) : SV_Target
    {
        float3 c1 = tex2D(_MainTex, i.uv + _MainTex_TexelSize.xy * float2(-1, -1)).rgb;
        float3 c2 = tex2D(_MainTex, i.uv + _MainTex_TexelSize.xy * float2( 0, -1)).rgb;
        float3 c3 = tex2D(_MainTex, i.uv + _MainTex_TexelSize.xy * float2( 1, -1)).rgb;

        float3 c4 = tex2D(_MainTex, i.uv + _MainTex_TexelSize.xy * float2(-1,  0)).rgb;
        float3 c5 = tex2D(_MainTex, i.uv + _MainTex_TexelSize.xy * float2( 0,  0)).rgb;
        float3 c6 = tex2D(_MainTex, i.uv + _MainTex_TexelSize.xy * float2( 1,  0)).rgb;

        float3 c7 = tex2D(_MainTex, i.uv + _MainTex_TexelSize.xy * float2(-1,  1)).rgb;
        float3 c8 = tex2D(_MainTex, i.uv + _MainTex_TexelSize.xy * float2( 0,  1)).rgb;
        float3 c9 = tex2D(_MainTex, i.uv + _MainTex_TexelSize.xy * float2( 1,  1)).rgb;

        float3 ca = vmax(c1, vmax(c2, c3));
        float3 cb = vmax(c4, vmax(c5, c6));
        float3 cc = vmax(c7, vmax(c8, c9));

        return half4(vmax(ca, vmax(cb, cc)), 1);
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
            #pragma fragment frag_tile_max
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
            #pragma fragment frag_neighbor_max
            #pragma target 3.0
            #pragma glsl
            ENDCG
        }
    }
}
