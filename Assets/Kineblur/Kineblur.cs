using UnityEngine;
using System.Collections;

[AddComponentMenu("Kineblur/Kineblur")]
public class Kineblur : MonoBehaviour
{
    [SerializeField] Shader _shader;
    [SerializeField] Shader _motionBlurShader;

    Material _motionBlurMaterial;
    RenderTexture _velocityBuffer;
    GameObject _cloneObject;

    void Start()
    {
        _motionBlurMaterial = new Material(_motionBlurShader);
        _motionBlurMaterial.hideFlags = HideFlags.HideAndDontSave;
    }

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

        _velocityBuffer = RenderTexture.GetTemporary((int)camera.pixelWidth, (int)camera.pixelHeight, 24, RenderTextureFormat.RGHalf);

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
        {
            var rt1 = RenderTexture.GetTemporary(_velocityBuffer.width, _velocityBuffer.height, 0, RenderTextureFormat.RGHalf);
            var rt2 = RenderTexture.GetTemporary(_velocityBuffer.width, _velocityBuffer.height, 0, RenderTextureFormat.RGHalf);

            _motionBlurMaterial.SetFloat("_BlurDistance", 2);
            Graphics.Blit(_velocityBuffer, rt1, _motionBlurMaterial, 0);
            Graphics.Blit(rt1, rt2, _motionBlurMaterial, 1);
            Graphics.Blit(rt2, rt1, _motionBlurMaterial, 0);
            Graphics.Blit(rt1, rt2, _motionBlurMaterial, 1);
            Graphics.Blit(rt2, rt1, _motionBlurMaterial, 0);
            Graphics.Blit(rt1, rt2, _motionBlurMaterial, 1);

            _motionBlurMaterial.SetTexture("_VelocityTex", rt2);
            Graphics.Blit(source, destination, _motionBlurMaterial, 2);
            //Graphics.Blit(rt2, destination);

            RenderTexture.ReleaseTemporary(rt1);
            RenderTexture.ReleaseTemporary(rt2);
        }
        else
            Graphics.Blit(source, destination);
    }
}
