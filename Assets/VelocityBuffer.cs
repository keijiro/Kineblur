using UnityEngine;
using System.Collections;

public class VelocityBuffer : MonoBehaviour
{
    [SerializeField] Shader _shader;

    void OnEnable()
    {
        GetComponent<Camera>().SetReplacementShader(_shader, null);
    }

    void OnDisable()
    {
        GetComponent<Camera>().ResetReplacementShader();
    }
}
