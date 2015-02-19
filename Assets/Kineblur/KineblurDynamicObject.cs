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

using UnityEngine;
using System.Collections;

[AddComponentMenu("Kineblur/Kineblur Dynamic Object")]
public class KineblurDynamicObject : MonoBehaviour
{
    static int pidBackMatrix;

    Matrix4x4 previousModelMatrix;

    Renderer targetRenderer;
    MaterialPropertyBlock propertyBlock;

    void Awake()
    {
        if (pidBackMatrix == 0)
            pidBackMatrix = Shader.PropertyToID("_KineblurBackMatrix");

        propertyBlock = new MaterialPropertyBlock();
    }

    void Start()
    {
        targetRenderer = GetComponent<Renderer>();
        previousModelMatrix = targetRenderer.localToWorldMatrix;
    }

    void LateUpdate()
    {
        var current = targetRenderer.localToWorldMatrix;
        var back = previousModelMatrix * current.inverse;

        propertyBlock.SetMatrix(pidBackMatrix, back);
        targetRenderer.SetPropertyBlock(propertyBlock);

        previousModelMatrix = current;
    }
}
