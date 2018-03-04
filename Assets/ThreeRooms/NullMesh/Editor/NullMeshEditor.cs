using UnityEngine;
using UnityEditor;
using System.IO;
using System.Collections.Generic;

namespace ThreeRooms
{
    [CustomEditor(typeof(NullMesh))]
    public class NullMeshEditor : Editor
    {
        SerializedProperty _triangleCount;

        void OnEnable()
        {
            _triangleCount = serializedObject.FindProperty("_triangleCount");
        }

        public override void OnInspectorGUI()
        {
            serializedObject.Update();

            EditorGUI.BeginChangeCheck();
            EditorGUILayout.PropertyField(_triangleCount);
            var rebuild = EditorGUI.EndChangeCheck();

            serializedObject.ApplyModifiedProperties();

            if (rebuild) ((NullMesh)target).Rebuild();
        }

        [MenuItem("Assets/Create/ThreeRooms/Null Mesh")]
        public static void CreateNullMeshAsset()
        {
            // Make a proper path from the current selection.
            var path = AssetDatabase.GetAssetPath(Selection.activeObject);
            if (string.IsNullOrEmpty(path))
                path = "Assets";
            else if (Path.GetExtension(path) != "")
                path = path.Replace(Path.GetFileName(path), "");
            var assetPathName = AssetDatabase.GenerateUniqueAssetPath(path + "/Null Mesh.asset");

            // Create a null mesh asset.
            var asset = ScriptableObject.CreateInstance<NullMesh>();
            AssetDatabase.CreateAsset(asset, assetPathName);
            AssetDatabase.AddObjectToAsset(asset.mesh, asset);

            // Build an initial mesh for the asset.
            asset.Rebuild();

            // Save the generated mesh asset.
            AssetDatabase.SaveAssets();

            // Tweak the selection.
            EditorUtility.FocusProjectWindow();
            Selection.activeObject = asset;
        }
    }
}
