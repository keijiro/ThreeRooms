using UnityEngine;
using System.Collections.Generic;
using System.Linq;

namespace ThreeRooms
{
    public class NullMesh : ScriptableObject
    {
        [SerializeField] int _triangleCount = 10;

        public Mesh mesh { get { return _mesh; } }

        [SerializeField] Mesh _mesh;

        #if UNITY_EDITOR

        public void Rebuild()
        {
            var vcount = _triangleCount * 3;
            _mesh.Clear();
            _mesh.SetVertices(Enumerable.Repeat(Vector3.zero, 1).ToList());
            _mesh.SetTriangles(Enumerable.Repeat(0, vcount).ToList(), 0);
            _mesh.bounds = new Bounds(Vector3.zero, Vector3.one * 1e+6f);
            _mesh.UploadMeshData(true);
        }

        #endif

        void OnEnable()
        {
            if (_mesh == null)
            {
                _mesh = new Mesh();
                _mesh.name = "Null Mesh";
            }
        }
    }
}
