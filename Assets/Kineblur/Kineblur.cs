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
using UnityEngine.Rendering;
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

    // Sample count.
    public enum SampleCount { Low, Medium, High }

    [SerializeField] SampleCount _sampleCount = SampleCount.Medium;

    public SampleCount sampleCount {
        get { return _sampleCount; }
        set { _sampleCount = value; }
    }

    // Depth filter strength.
    [SerializeField] float _depthFilter = 5;

    public float depthFilter {
        get { return _depthFilter; }
        set { _depthFilter = value; }
    }

    // Visualization mode (exposed only to Editor).
    public enum Visualization { Off, Velocity, NeighborMax }

    [SerializeField] Visualization _visualization;

    #endregion

    #region External Asset References

    [SerializeField] Shader _velocityShader;
    [SerializeField] Shader _backgroundShader;
    [SerializeField] Mesh _backgroundMesh;
    [SerializeField] Shader _filterShader;
    [SerializeField] Shader _reconstructionShader;

    // Materials for handling the shaders.
    Material _backgroundMaterial;
    Material _filterMaterial;
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

    void SetUpResources()
    {
        if (_backgroundMaterial == null) {
            _backgroundMaterial = new Material(_backgroundShader);
            _backgroundMaterial.hideFlags = HideFlags.HideAndDontSave;
        }

        if (_filterMaterial == null) {
            _filterMaterial = new Material(_filterShader);
            _filterMaterial.hideFlags = HideFlags.HideAndDontSave;
        }

        if (_reconstructionMaterial == null) {
            _reconstructionMaterial = new Material(_reconstructionShader);
            _reconstructionMaterial.hideFlags = HideFlags.HideAndDontSave;
        }
    }

    void UpdateReconstructionMaterial()
    {
        if (_sampleCount == SampleCount.Low)
        {
            _reconstructionMaterial.DisableKeyword("QUALITY_MEDIUM");
            _reconstructionMaterial.DisableKeyword("QUALITY_HIGH");
        }
        else if (_sampleCount == SampleCount.Medium)
        {
            _reconstructionMaterial.EnableKeyword("QUALITY_MEDIUM");
            _reconstructionMaterial.DisableKeyword("QUALITY_HIGH");
        }
        else
        {
            _reconstructionMaterial.DisableKeyword("QUALITY_MEDIUM");
            _reconstructionMaterial.EnableKeyword("QUALITY_HIGH");
        }

        if (_exposureTime == 0)
        {
            _filterMaterial.SetFloat("_VelocityScale", 1);
        }
        else
        {
            var s = Time.smoothDeltaTime * exposureTimeTable[(int)_exposureTime];
            _filterMaterial.SetFloat("_VelocityScale", 1.0f / s);
        }

        _filterMaterial.SetFloat("_MaxBlurRadius", 40);
        _reconstructionMaterial.SetFloat("_MaxBlurRadius", 40);

        _reconstructionMaterial.SetFloat("_DepthFilterStrength", _depthFilter);
    }

    #endregion

    #region MonoBehaviour Functions

    void Start()
    {
        _previousVPMatrix = CalculateVPMatrix();

        // Default velocity writer matrix for static objects.
        Shader.SetGlobalMatrix("_KineblurBackMatrix", Matrix4x4.identity);
    }

    void OnEnable()
    {
        if (_velocityCamera == null)
        {
            SetUpResources();

            // Make a velocity camera instance.
            _velocityCamera = new GameObject("Velocity Camera", typeof(Camera));
            _velocityCamera.hideFlags = HideFlags.HideAndDontSave;

            // Make a command buffer for writing background velocity.
            var cmd = new CommandBuffer();
            cmd.name = "Background Velocity";
            cmd.DrawMesh(_backgroundMesh, Matrix4x4.identity, _backgroundMaterial);

            // Set up the velocity camera.
            var cam = _velocityCamera.GetComponent<Camera>();
            cam.enabled = false;
            cam.AddCommandBuffer(CameraEvent.AfterForwardOpaque, cmd);
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

        // Needs a camera depth texture for the depth filter.
        //if (_depthFilter)
            cam.depthTextureMode |= DepthTextureMode.Depth;

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
        vcam.depthTextureMode = DepthTextureMode.None;
        vcam.backgroundColor = Color.black;
        vcam.targetTexture = _velocityBuffer;
        vcam.RenderWithShader(_velocityShader, "RenderType");
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        // Simply blit if not ready.
        if (_velocityBuffer == null) {
            Graphics.Blit(source, destination);
            return;
        }

        UpdateReconstructionMaterial();

        var tw = _velocityBuffer.width;
        var th = _velocityBuffer.height;

        RenderTexture vbuffer = RenderTexture.GetTemporary(tw, th, 0, RenderTextureFormat.ARGB2101010);
        RenderTexture tile1 = RenderTexture.GetTemporary(tw / 10, th / 10, 0, RenderTextureFormat.RGHalf);
        RenderTexture tile2 = RenderTexture.GetTemporary(tw / 40, th / 40, 0, RenderTextureFormat.RGHalf);
        RenderTexture tile3 = RenderTexture.GetTemporary(tw / 40, th / 40, 0, RenderTextureFormat.RGHalf);

        source.filterMode = FilterMode.Point;
        vbuffer.filterMode = FilterMode.Point;
        tile1.filterMode = FilterMode.Point;
        tile2.filterMode = FilterMode.Point;
        tile3.filterMode = FilterMode.Point;

        Graphics.Blit(_velocityBuffer, vbuffer, _filterMaterial, 0);
        Graphics.Blit(vbuffer, tile1, _filterMaterial, 1);
        Graphics.Blit(tile1, tile2, _filterMaterial, 2);
        Graphics.Blit(tile2, tile3, _filterMaterial, 4);

        _reconstructionMaterial.SetTexture("_VelocityTex", vbuffer);
        _reconstructionMaterial.SetTexture("_NeighborMaxTex", tile3);
        Graphics.Blit(source, destination, _reconstructionMaterial, (int)_visualization);

        RenderTexture.ReleaseTemporary(vbuffer);
        RenderTexture.ReleaseTemporary(tile1);
        RenderTexture.ReleaseTemporary(tile2);
        RenderTexture.ReleaseTemporary(tile3);
    }

    #endregion
}
