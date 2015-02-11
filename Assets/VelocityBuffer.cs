using UnityEngine;
using System.Collections;

public class VelocityBuffer : MonoBehaviour
{
    [SerializeField] Shader _shader;

    RenderTexture _velocityBuffer;
    GameObject _cloneObject;

    void OnEnable()
    {
        if (_cloneObject == null)
        {
            _cloneObject = new GameObject("Velocity Camera", typeof(Camera));
            _cloneObject.camera.enabled = false;
            _cloneObject.hideFlags = HideFlags.HideAndDontSave;
        }
    }

    void OnDisable()
    {
        if (_cloneObject != null) DestroyImmediate(_cloneObject);
    }

    void OnPreRender()
    {
        if (_velocityBuffer != null)
            RenderTexture.ReleaseTemporary(_velocityBuffer);

        _velocityBuffer = RenderTexture.GetTemporary((int)camera.pixelWidth, (int)camera.pixelHeight, 24, RenderTextureFormat.RGFloat);

        var vc = _cloneObject.camera;
        vc.CopyFrom(camera);
        vc.backgroundColor = Color.black;
        vc.clearFlags = CameraClearFlags.SolidColor;
        vc.targetTexture = _velocityBuffer;
        vc.RenderWithShader(_shader, null);
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (_velocityBuffer != null)
            Graphics.Blit(_velocityBuffer, destination);
        else
            Graphics.Blit(source, destination);
    }
}
