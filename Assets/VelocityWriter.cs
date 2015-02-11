using UnityEngine;
using System.Collections;

public class VelocityWriter : MonoBehaviour
{
    Matrix4x4 previousMVP;

    void Start()
    {
        previousMVP = CalcMVP();
    }

    void LateUpdate()
    {
        renderer.material.SetMatrix("_VelocityBuffer_MVP", previousMVP);
        previousMVP = CalcMVP();
    }

    Matrix4x4 CalcMVP()
    {
        Matrix4x4 M = transform.localToWorldMatrix;
        Matrix4x4 V = Camera.main.worldToCameraMatrix;
        Matrix4x4 P = Camera.main.projectionMatrix;
        return P * V * M;
    }
}
