using UnityEngine;
using System.Collections;

[AddComponentMenu("Kineblur/Kineblur")]
public class Kineblur : MonoBehaviour
{
    static int[] exposureTimeTable = { 1, 8, 15, 30, 60, 125 };

    [SerializeField] Shader _shader;
    [SerializeField] Shader _motionBlurShader;

    Material _motionBlurMaterial;
    RenderTexture _velocityBuffer;
    GameObject _cloneObject;

    public enum ExposureTime { Realtime, OnePerEight, OnePerFifteen, OnePerThirty, OnePerSixty, OnePerOneTwentyFive }
    public enum VelocityFilter { Off, Low, Medium, High }
    public enum SampleCount { Low, Medium, High }

    [SerializeField] ExposureTime _exposureTime = ExposureTime.Realtime;
    [SerializeField] VelocityFilter _velocityFilter = VelocityFilter.Medium;
    [SerializeField] SampleCount _sampleCount = SampleCount.Medium;
    [SerializeField] bool _debug;

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
        if (_velocityBuffer == null)
        {
            Graphics.Blit(source, destination);
            return;
        }

        if (_sampleCount == SampleCount.Low)
        {
            _motionBlurMaterial.DisableKeyword("QUALITY_MEDIUM");
            _motionBlurMaterial.DisableKeyword("QUALITY_HIGH");
        }
        else if (_sampleCount == SampleCount.Medium)
        {
            _motionBlurMaterial.EnableKeyword("QUALITY_MEDIUM");
            _motionBlurMaterial.DisableKeyword("QUALITY_HIGH");
        }
        else
        {
            _motionBlurMaterial.DisableKeyword("QUALITY_MEDIUM");
            _motionBlurMaterial.EnableKeyword("QUALITY_HIGH");
        }

        RenderTexture rt1 = null;
        RenderTexture rt2 = null;

        if (_velocityFilter == VelocityFilter.Off)
        {
            _motionBlurMaterial.SetTexture("_VelocityTex", _velocityBuffer);
        }
        else
        {
            {
                var width = _velocityBuffer.width;
                var height = _velocityBuffer.height;
                var format = _velocityBuffer.format;
                rt1 = RenderTexture.GetTemporary(width, height, 0, format);
                rt2 = RenderTexture.GetTemporary(width, height, 0, format);
            }

            _motionBlurMaterial.SetFloat("_BlurDistance", 1.5f);

            if (_exposureTime == 0)
            {
                _motionBlurMaterial.SetFloat("_VelocityScale", 1);
            }
            else
            {
                var s = 1.0f / (Time.smoothDeltaTime * exposureTimeTable[(int)_exposureTime]);
                _motionBlurMaterial.SetFloat("_VelocityScale", s);
            }

            Graphics.Blit(_velocityBuffer, rt1, _motionBlurMaterial, 0);
            Graphics.Blit(rt1, rt2, _motionBlurMaterial, 1);

            if (_velocityFilter != VelocityFilter.Low)
            {
                Graphics.Blit(rt2, rt1, _motionBlurMaterial, 0);
                Graphics.Blit(rt1, rt2, _motionBlurMaterial, 1);
            }

            if (_velocityFilter == VelocityFilter.High)
            {
                Graphics.Blit(rt2, rt1, _motionBlurMaterial, 0);
                Graphics.Blit(rt1, rt2, _motionBlurMaterial, 1);
            }

            _motionBlurMaterial.SetTexture("_VelocityTex", rt2);
        }

        Graphics.Blit(source, destination, _motionBlurMaterial, _debug ? 3 : 2);

        if (rt1 != null) RenderTexture.ReleaseTemporary(rt1);
        if (rt2 != null) RenderTexture.ReleaseTemporary(rt2);
    }
}
