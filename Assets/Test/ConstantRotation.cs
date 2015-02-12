using UnityEngine;
using System.Collections;

public class ConstantRotation : MonoBehaviour
{
    public float speed = 90;

    void Update()
    {
        transform.localRotation =
            Quaternion.AngleAxis(speed * Time.deltaTime, Vector3.up) *
            transform.localRotation;
    }
}
