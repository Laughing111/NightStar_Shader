using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CallShader : MonoBehaviour
{

    public Material ma;
    private Vector4 pos=Vector4.zero;

    // Update is called once per frame
    void Update()
    {
        pos.x = Input.mousePosition.x;
        pos.y = Input.mousePosition.y;
        ma.SetVector("_iMouse", pos);
    }
}
