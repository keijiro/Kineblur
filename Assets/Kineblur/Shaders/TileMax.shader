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

// Velocity filter passes.
Shader "Hidden/Kineblur/Velocity Filters"
{
    Properties
    {
        _MainTex("-", 2D) = "white" {}
    }

    CGINCLUDE

    #include "UnityCG.cginc"

    sampler2D _MainTex;
    float4 _MainTex_TexelSize;

    // Tile size.
    static const int tile_divisor = 30;

    // Returns the largest magnitude vector.
    half2 vmax(half2 v1, half2 v2)
    {
        return lerp(v1, v2, dot(v1, v1) < dot(v2, v2));
    }

    // Rescaling filter.
    half4 frag_rescale(v2f_img i) : SV_Target
    {
        half2 v = tex2D(_MainTex, i.uv);

        // Scale the velocity vector into pixel unit.
        v /= _MainTex_TexelSize.xy;

        // Clamp the vector with the tile size.
        half lv = length(v);
        v *= min(lv, tile_divisor) / max(lv, 1e-6);

        return half4(v, 0, 0);
    }

    // TileMax filter.
    half4 frag_tile_max(v2f_img i) : SV_Target
    {
        float2 uv = i.uv - _MainTex_TexelSize.xy * tile_divisor / 2;

        float2 du = float2(_MainTex_TexelSize.x, 0);
        float2 dv = float2(0, _MainTex_TexelSize.y);

        half2 v = 0;

        for (int ix = 0; ix < tile_divisor; ix++)
        {
            float2 uv2 = uv;
            for (int iy = 0; iy < tile_divisor; iy++)
            {
                v = vmax(v, tex2D(_MainTex, uv2).rg);
                uv2 += du;
            }
            uv += dv;
        }

        return half4(v, 0, 0);
    }

    // NeighborMax filter.
    half4 frag_neighbor_max(v2f_img i) : SV_Target
    {
        static const half cw = 1.01f; // center weight tweak

        half2 tx = _MainTex_TexelSize.xy;

        half2 v1 = tex2D(_MainTex, i.uv + tx * half2(-1, -1)).rg;
        half2 v2 = tex2D(_MainTex, i.uv + tx * half2( 0, -1)).rg;
        half2 v3 = tex2D(_MainTex, i.uv + tx * half2(+1, -1)).rg;

        half2 v4 = tex2D(_MainTex, i.uv + tx * half2(-1,  0)).rg;
        half2 v5 = tex2D(_MainTex, i.uv + tx * half2( 0,  0)).rg * cw;
        half2 v6 = tex2D(_MainTex, i.uv + tx * half2(+1,  0)).rg;

        half2 v7 = tex2D(_MainTex, i.uv + tx * half2(-1, +1)).rg;
        half2 v8 = tex2D(_MainTex, i.uv + tx * half2( 0, +1)).rg;
        half2 v9 = tex2D(_MainTex, i.uv + tx * half2(+1, +1)).rg;

        half2 va = vmax(v1, vmax(v2, v3));
        half2 vb = vmax(v4, vmax(v5, v6));
        half2 vc = vmax(v7, vmax(v8, v9));

        return half4(vmax(va, vmax(vb, vc)) / cw, 0, 0);
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
            #pragma fragment frag_rescale
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
