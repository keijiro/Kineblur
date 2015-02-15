using UnityEngine;
using UnityEditor;
using System.Collections;

[CustomEditor(typeof(Kineblur)), CanEditMultipleObjects]
public class KineblurEditor : Editor
{
    SerializedProperty propExposureTime;
    SerializedProperty propVelocityFilter;
    SerializedProperty propSampleCount;
    SerializedProperty propDebug;

    GUIContent labelDebug;

    static int[] exposureOptions = { 0, 1, 2, 3, 4, 5 };

    static GUIContent[] exposureOptionLabels = {
        new GUIContent("Realtime"),
        new GUIContent("1 \u2044 8"),
        new GUIContent("1 \u2044 15"),
        new GUIContent("1 \u2044 30"),
        new GUIContent("1 \u2044 60"),
        new GUIContent("1 \u2044 125")
    };

    void OnEnable()
    {
        propExposureTime = serializedObject.FindProperty("_exposureTime");
        propVelocityFilter = serializedObject.FindProperty("_velocityFilter");
        propSampleCount = serializedObject.FindProperty("_sampleCount");
        propDebug = serializedObject.FindProperty("_debug");
        labelDebug = new GUIContent("Visualize Velocity");
    }

    public override void OnInspectorGUI()
    {
        serializedObject.Update();

        EditorGUILayout.IntPopup(propExposureTime, exposureOptionLabels, exposureOptions);
        EditorGUILayout.PropertyField(propVelocityFilter);
        EditorGUILayout.PropertyField(propSampleCount);
        EditorGUILayout.PropertyField(propDebug, labelDebug);

        serializedObject.ApplyModifiedProperties();
    }
}
