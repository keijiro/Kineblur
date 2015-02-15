using UnityEngine;
using System.Collections;

[AddComponentMenu("Kineblur/Kineblur")]
public class Kineblur : MonoBehaviour
{
    public enum ExposureTime { Realtime, OnePerFifteen, OnePerThirty, OnePerSixty, OnePerOneTwentyFive }
    [SerializeField] ExposureTime _exposureTime = ExposureTime.Realtime;

    public enum VelocityFilter { Off, Low, Medium, High }
    [SerializeField] VelocityFilter _velocityFilter = VelocityFilter.Low;

    public enum SampleCount { Low, Medium, High, UltraHigh }
    [SerializeField] SampleCount _sampleCount = SampleCount.Medium;

    [SerializeField] bool _debug;

    [SerializeField] Shader _gaussianShader;
    [SerializeField] Shader _reconstructionShader;
    [SerializeField] Shader _velocityShader;

    RenderTexture _velocityBuffer;
    GameObject _cloneCamera;
    Material _gaussianMaterial;
    Material _reconstructionMaterial;

    static int[] exposureTimeTable = { 1, 15, 30, 60, 125 };

    void Start()
    {
        _gaussianMaterial = new Material(_gaussianShader);
        _gaussianMaterial.hideFlags = HideFlags.HideAndDontSave;

        _reconstructionMaterial = new Material(_reconstructionShader);
        _reconstructionMaterial.hideFlags = HideFlags.HideAndDontSave;
    }

    void OnEnable()
    {
        if (_cloneCamera == null)
        {
            _cloneCamera = new GameObject("Velocity Camera", typeof(Camera));
            _cloneCamera.camera.enabled = false;
            _cloneCamera.hideFlags = HideFlags.HideAndDontSave;
        }
    }

    void OnDisable()
    {
        if (_cloneCamera != null) DestroyImmediate(_cloneCamera);
    }

    void OnPreRender()
    {
        if (_velocityBuffer != null) RenderTexture.ReleaseTemporary(_velocityBuffer);
        _velocityBuffer = RenderTexture.GetTemporary((int)camera.pixelWidth, (int)camera.pixelHeight, 24, RenderTextureFormat.RGHalf);

        var vc = _cloneCamera.camera;
        vc.CopyFrom(camera);
        vc.backgroundColor = Color.black;
        vc.clearFlags = CameraClearFlags.SolidColor;
        vc.targetTexture = _velocityBuffer;
        vc.RenderWithShader(_velocityShader, null);
    }

    int GetVelocityDownSampleLevel()
    {
        if (_velocityFilter == VelocityFilter.Medium) return 2;
        if (_velocityFilter == VelocityFilter.High) return 4;
        return 1;
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
            _reconstructionMaterial.DisableKeyword("QUALITY_MEDIUM");
            _reconstructionMaterial.DisableKeyword("QUALITY_HIGH");
            _reconstructionMaterial.DisableKeyword("QUALITY_SUPER");
        }
        else if (_sampleCount == SampleCount.Medium)
        {
            _reconstructionMaterial.EnableKeyword("QUALITY_MEDIUM");
            _reconstructionMaterial.DisableKeyword("QUALITY_HIGH");
            _reconstructionMaterial.DisableKeyword("QUALITY_SUPER");
        }
        else if (_sampleCount == SampleCount.Medium)
        {
            _reconstructionMaterial.DisableKeyword("QUALITY_MEDIUM");
            _reconstructionMaterial.EnableKeyword("QUALITY_HIGH");
            _reconstructionMaterial.DisableKeyword("QUALITY_SUPER");
        }
        else
        {
            _reconstructionMaterial.DisableKeyword("QUALITY_MEDIUM");
            _reconstructionMaterial.DisableKeyword("QUALITY_HIGH");
            _reconstructionMaterial.EnableKeyword("QUALITY_SUPER");
        }

        if (_exposureTime == 0)
        {
            _reconstructionMaterial.SetFloat("_VelocityScale", 1);
        }
        else
        {
            var s = 1.0f / (Time.smoothDeltaTime * exposureTimeTable[(int)_exposureTime]);
            _reconstructionMaterial.SetFloat("_VelocityScale", s);
        }

        RenderTexture rt1 = null;
        RenderTexture rt2 = null;

        if (_velocityFilter == VelocityFilter.Off)
        {
            _reconstructionMaterial.SetTexture("_VelocityTex", _velocityBuffer);
        }
        else
        {
            {
                var ds = GetVelocityDownSampleLevel();
                var width = _velocityBuffer.width / ds;
                var height = _velocityBuffer.height / ds;
                var format = _velocityBuffer.format;
                rt1 = RenderTexture.GetTemporary(width, height, 0, format);
                rt2 = RenderTexture.GetTemporary(width, height, 0, format);
            }

            if (_velocityFilter == VelocityFilter.Low)
            {
                Graphics.Blit(_velocityBuffer, rt1, _gaussianMaterial, 1);
                Graphics.Blit(rt1, rt2, _gaussianMaterial, 2);
            }
            else if (_velocityFilter == VelocityFilter.High)
            {
                Graphics.Blit(_velocityBuffer, rt2, _gaussianMaterial, 0);
                Graphics.Blit(rt2, rt1, _gaussianMaterial, 1);
                Graphics.Blit(rt1, rt2, _gaussianMaterial, 2);
            }
            else
            {
                Graphics.Blit(_velocityBuffer, rt2);
                Graphics.Blit(rt2, rt1, _gaussianMaterial, 1);
                Graphics.Blit(rt1, rt2, _gaussianMaterial, 2);
            }

            _reconstructionMaterial.SetTexture("_VelocityTex", rt2);
        }

        Graphics.Blit(source, destination, _reconstructionMaterial, _debug ? 1 : 0);

        if (rt1 != null) RenderTexture.ReleaseTemporary(rt1);
        if (rt2 != null) RenderTexture.ReleaseTemporary(rt2);
    }
}
