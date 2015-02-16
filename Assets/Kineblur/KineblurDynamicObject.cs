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
