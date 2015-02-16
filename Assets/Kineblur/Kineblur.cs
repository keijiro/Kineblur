using UnityEngine;
using System.Collections;

[AddComponentMenu("Kineblur/Kineblur")]
public class Kineblur : MonoBehaviour
{
    #region Public Properties

    // Exposure time (shutter speed).
    public enum ExposureTime {
        Realtime, OnePerFifteen, OnePerThirty, OnePerSixty, OnePerOneTwentyFive
    }

    [SerializeField] ExposureTime _exposureTime = ExposureTime.Realtime;

    public ExposureTime exposureTime {
        get { return _exposureTime; }
        set { _exposureTime = value; }
    }

    // Velocity buffer filter.
    public enum VelocityFilter { Off, Low, Medium, High }

    [SerializeField] VelocityFilter _velocityFilter = VelocityFilter.Low;

    public VelocityFilter velocityFilter {
        get { return _velocityFilter; }
        set { _velocityFilter = value; }
    }

    // Sample count.
    public enum SampleCount { Low, Medium, High, UltraHigh }

    [SerializeField] SampleCount _sampleCount = SampleCount.Medium;

    public SampleCount sampleCount {
        get { return _sampleCount; }
        set { _sampleCount = value; }
    }

    // Dithering.
    [SerializeField] bool _dither;

    public bool dither {
        get { return _dither; }
        set { _dither = value; }
    }

    // Debug display (exposed only to Editor).
    [SerializeField] bool _debug;

    #endregion

    #region External Asset References

    [SerializeField] Shader _velocityShader;
    [SerializeField] Shader _gaussianShader;
    [SerializeField] Shader _reconstructionShader;

    // Materials for handling the shaders.
    Material _gaussianMaterial;
    Material _reconstructionMaterial;

    #endregion

    #region Private Objects

    // Velocity buffer.
    RenderTexture _velocityBuffer;

    // Velocity camera (used for rendering the velocity buffer).
    GameObject _velocityCamera;

    // V*P matrix in the previous frame.
    Matrix4x4 _previousVPMatrix;

    // Exposure time settings.
    static int[] exposureTimeTable = { 1, 15, 30, 60, 125 };

    #endregion

    #region Private Methods

    Matrix4x4 CalculateVPMatrix()
    {
        var cam = GetComponent<Camera>();
        Matrix4x4 V = cam.worldToCameraMatrix;
        Matrix4x4 P = GL.GetGPUProjectionMatrix(cam.projectionMatrix, true);
        return P * V;
    }

    int GetVelocityDownSampleLevel()
    {
        if (_velocityFilter == VelocityFilter.Medium) return 2;
        if (_velocityFilter == VelocityFilter.High) return 4;
        return 1;
    }

    void UpdateReconstructionMaterial()
    {
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

        if (_dither)
            _reconstructionMaterial.EnableKeyword("DITHER_ON");
        else
            _reconstructionMaterial.DisableKeyword("DITHER_ON");

        if (_exposureTime == 0)
        {
            _reconstructionMaterial.SetFloat("_VelocityScale", 1);
        }
        else
        {
            var s = Time.smoothDeltaTime * exposureTimeTable[(int)_exposureTime];
            _reconstructionMaterial.SetFloat("_VelocityScale", 1.0f / s);
        }
    }

    #endregion

    #region MonoBehaviour Functions

    void Start()
    {
        _gaussianMaterial = new Material(_gaussianShader);
        _gaussianMaterial.hideFlags = HideFlags.HideAndDontSave;

        _reconstructionMaterial = new Material(_reconstructionShader);
        _reconstructionMaterial.hideFlags = HideFlags.HideAndDontSave;

        _previousVPMatrix = CalculateVPMatrix();

        // Default velocity writer matrix for static objects.
        Shader.SetGlobalMatrix("_KineblurBackMatrix", Matrix4x4.identity);
    }

    void OnEnable()
    {
        if (_velocityCamera == null)
        {
            // Make a velocity camera instance.
            _velocityCamera = new GameObject("Velocity Camera", typeof(Camera));
            _velocityCamera.hideFlags = HideFlags.HideAndDontSave;
            _velocityCamera.GetComponent<Camera>().enabled = false;
        }
    }

    void OnDisable()
    {
        // Delete the velocity camera.
        if (_velocityCamera != null) DestroyImmediate(_velocityCamera);
    }

    void LateUpdate()
    {
        // Update the VP matrix for the velocity writer.
        Shader.SetGlobalMatrix("_KineblurVPMatrix", _previousVPMatrix);

        // Store the current VP matrix.
        _previousVPMatrix = CalculateVPMatrix();
    }

    void OnPreRender()
    {
        var cam = GetComponent<Camera>();
        var vcam = _velocityCamera.GetComponent<Camera>();

        // Recreate the velocity buffer.
        if (_velocityBuffer != null)
            RenderTexture.ReleaseTemporary(_velocityBuffer);

        _velocityBuffer = RenderTexture.GetTemporary(
            (int)cam.pixelWidth,
            (int)cam.pixelHeight,
            24,
            RenderTextureFormat.RGHalf
        );

        // Reset the velocity camera and request rendering.
        vcam.CopyFrom(cam);
        vcam.clearFlags = CameraClearFlags.SolidColor;
        vcam.backgroundColor = Color.black;
        vcam.targetTexture = _velocityBuffer;
        vcam.RenderWithShader(_velocityShader, null);
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        // Simply blit if not ready.
        if (_velocityBuffer == null) {
            Graphics.Blit(source, destination);
            return;
        }

        UpdateReconstructionMaterial();

        RenderTexture rt1 = null;
        RenderTexture rt2 = null;

        if (_velocityFilter == VelocityFilter.Off)
        {
            // Use the velocity buffer directly.
            _reconstructionMaterial.SetTexture("_VelocityTex", _velocityBuffer);
        }
        else
        {
            // Get temporary buffers.
            var ds = GetVelocityDownSampleLevel();
            var width = _velocityBuffer.width / ds;
            var height = _velocityBuffer.height / ds;
            var format = _velocityBuffer.format;
            rt1 = RenderTexture.GetTemporary(width, height, 0, format);
            rt2 = RenderTexture.GetTemporary(width, height, 0, format);

            if (_velocityFilter == VelocityFilter.Low)
            {
                // Apply the gaussian filter without downsampling.
                Graphics.Blit(_velocityBuffer, rt1, _gaussianMaterial, 1);
                Graphics.Blit(rt1, rt2, _gaussianMaterial, 2);
            }
            else if (_velocityFilter == VelocityFilter.Medium)
            {
                // Downsample (1/2) and then apply the gaussian filter.
                Graphics.Blit(_velocityBuffer, rt2);
                Graphics.Blit(rt2, rt1, _gaussianMaterial, 1);
                Graphics.Blit(rt1, rt2, _gaussianMaterial, 2);
            }
            else
            {
                // Downsample (1/4) and then apply the gaussian filter.
                Graphics.Blit(_velocityBuffer, rt2, _gaussianMaterial, 0);
                Graphics.Blit(rt2, rt1, _gaussianMaterial, 1);
                Graphics.Blit(rt1, rt2, _gaussianMaterial, 2);
            }

            // Use the filtered velocity buffer.
            _reconstructionMaterial.SetTexture("_VelocityTex", rt2);
        }

        // Reconstruction.
        Graphics.Blit(source, destination, _reconstructionMaterial, _debug ? 1 : 0);

        if (rt1 != null) RenderTexture.ReleaseTemporary(rt1);
        if (rt2 != null) RenderTexture.ReleaseTemporary(rt2);
    }

    #endregion
}
