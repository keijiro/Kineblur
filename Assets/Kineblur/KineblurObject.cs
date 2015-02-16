using UnityEngine;
using System.Collections;

[AddComponentMenu("Kineblur/Kineblur Object")]
public class KineblurObject : MonoBehaviour
{
    static int propertyID;

    Renderer targetRenderer;
    Matrix4x4 previousMVP;
    MaterialPropertyBlock propertyBlock;

    Matrix4x4 CalculateMVP()
    {
        var mainCamera = Camera.main;

        Matrix4x4 M = targetRenderer.localToWorldMatrix;
        Matrix4x4 V = mainCamera.worldToCameraMatrix;
        Matrix4x4 P = GL.GetGPUProjectionMatrix(mainCamera.projectionMatrix, true);

        return P * V * M;
    }

    void Awake()
    {
        propertyID = Shader.PropertyToID("_VelocityBuffer_MVP");
        propertyBlock = new MaterialPropertyBlock();
    }

    void Start()
    {
        targetRenderer = GetComponent<Renderer>();
        previousMVP = CalculateMVP();
    }

    void LateUpdate()
    {
        propertyBlock.Clear();
        propertyBlock.AddMatrix(propertyID, previousMVP);
        targetRenderer.SetPropertyBlock(propertyBlock);

        previousMVP = CalculateMVP();
    }
}
