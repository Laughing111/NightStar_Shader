Shader "PixleShader/NightStar" {
	Properties{
		_iMouse ("MousePos", vector) = (1,1,0,0)
		_MainTex("MainTex",2D)="white"{}
	}
    SubShader{
      Pass {
        CGPROGRAM
// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
#pragma exclude_renderers gles
        #pragma vertex vert    
        #pragma fragment frag 
        //使用低精度来提升片段着色器的运行速度 一般指fp16 半精度
        #pragma fragmentoption ARB_precision_hint_fastest     
        #include "UnityCG.cginc"   
        #pragma target 3.0      
        //定义各种常用宏
        #define vec2 float2
        #define vec3 float3
        #define vec4 float4
        #define mat2 float2x2
        #define mat3 float3x3
        #define mat4 float4x4
        #define iGlobalTime _Time.y
        #define mod fmod
        #define mix lerp
        #define fract frac
        #define texture2D tex2D
        //_ScreenParams为屏幕的分辨率
        #define iResolution _ScreenParams


        #define PI2 6.28318530718
        #define pi 3.14159265358979
        #define halfpi (pi * 0.5)
        #define oneoverpi (1.0 / pi)

		//#define SIMPLE
		#define S(a, b, t) smoothstep(a, b, t)
		fixed NUM_LAYERS =0.25;
        
		vec2 _iMouse;
        //自己声明的变量
        const float phi = (1+ sqrt(5))*0.5;
        struct v2f {
          float4 pos : SV_POSITION;
          float4 scrPos : TEXCOORD0;
        };

		float N21(vec2 p) {
	vec3 a = fract(vec3(p.xyx) * vec3(213.897, 653.453, 253.098));
    a += dot(a, a.yzx + 79.76);
    return fract((a.x + a.y) * a.z);
}

vec2 GetPos(vec2 id, vec2 offs, float t) {
    float n = N21(id+offs);
    float n1 = fract(n*10);
    float n2 = fract(n*100);
    float a = t+n;
    return offs + vec2(sin(a*n1), cos(a*n2))*0.4;
}

float GetT(vec2 ro, vec2 rd, vec2 p) {
	return dot(p-ro, rd); 
}

float LineDist(vec3 a, vec3 b, vec3 p) {
	return length(cross(b-a, p-a))/length(p-a);
}

float df_line( in vec2 a, in vec2 b, in vec2 p)
{
    vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa,ba) /(dot(ba,ba)), 0.0, 1.0);	
	return length(pa - ba * h);
}

float drawLine(vec2 a, vec2 b, vec2 uv) {
    float r1 = 0.04;
    float r2 = 0.01;
    
    float d = df_line(a, b, uv);
    float d2 = length(a-b);
    float fade = S(1.5, 0.5, d2);
    
    fade += S(0.05, 0.02, abs(d2-0.75));
    return S(r1, r2, d)*fade;
}

float NetLayer(vec2 st, float n, float t) {
    vec2 id = floor(st)+n;

    st = fract(st)-0.5;
   
    vec2 p[9];
    int i=0;
    for(float y=-1; y<=1; y++) {
    	for(float x=-1; x<=1; x++) {
            p[i++] = GetPos(id, vec2(x,y), t);
    	}
    }
    
    float m = 0;
    float sparkle = 0;
    
    for(int i=0; i<9; i++) {
        m += drawLine(p[4], p[i], st);

        float d = length(st-p[i]);

        float s = (0.005/(d*d));
        s *= S(1, 0.7, d);
        float pulse = sin((fract(p[i].x)+fract(p[i].y)+t)*5.0)*0.4+0.6;
        pulse = pow(pulse, 20);

        s *= pulse;
        sparkle += s;
    }
    
    m += drawLine(p[1], p[3], st);
	m += drawLine(p[1], p[5], st);
    m += drawLine(p[7], p[5], st);
    m += drawLine(p[7], p[3], st);
    
    float sPhase = (sin(t+n)+sin(t*0.1))*0.25+0.5;
    sPhase += pow(sin(t*0.1)*0.5+0.5, 50)*5;
    m += sparkle*sPhase;//(*.5+.5);
    
    return m;
}
	
fixed4 mainImage(vec2 fragCoord)
{
    vec2 uv = (fragCoord-iResolution.xy*0.5)/iResolution.y;
	vec2 M = _iMouse.xy/iResolution.xy-0.5;
    
    float t = iGlobalTime*0.1;
    
    float s = sin(t);
    float c = cos(t);
    mat2 rot = mat2(c, -s, s, c);
    vec2 st = mul(uv,rot);  
	M =mul(M,rot)*2.0;
    
    float m = 0;
    for(float i=0; i<1; i+=0.25) {
        float z = fract(t+i);
        float size = mix(15, 1., z);
        float fade = S(0, 0.6, z)*S(1, 0.8, z);
        
        m += fade * NetLayer(mul(st,size)-mul(M,z), i, iGlobalTime);
    }
    
	//float fft  = 0;
    //float glow = -uv.y*fft*2;
   
    vec3 baseCol = vec3(s, cos(t*0.4), -sin(t*0.24))*0.4+0.6;
    vec3 col = baseCol*m;
    //col += baseCol*glow;
    
    #ifdef SIMPLE
    uv = mul(uv,10);
    col = mul(vec3(1,1,1),NetLayer(uv, 0, iGlobalTime));
    uv = fract(uv);
    //if(uv.x>.98 || uv.y>.98) col += 1.;
    #else
    col *= 1-dot(uv,uv);
    t = mod(iGlobalTime, 230);
    col *= S(0, 20, t)*S(224, 200, t);
    #endif
    
    return vec4(col,1);
}

        //顶点片元函数的声明，main函数的声明创建
        v2f vert(appdata_base v) {
          v2f o;
          o.pos = UnityObjectToClipPos(v.vertex);
          //将顶点转成屏幕坐标
          o.scrPos = ComputeScreenPos(o.pos);
          return o;
        }
       
        fixed4 frag(v2f _iParam) : COLOR0 {
          /*
          1.在四维中有xyzw四个分量 其中xyz三个点与w相除得到归一化的点
          2.(_iParam.srcPos.xy/_iParam.srcPos.w)将得到在屏幕中归一化后的屏幕位置
          3.最后与屏幕的分辨率相乘获得具体的位置
          */
           vec2 fragCoord = ((_iParam.scrPos.xy / _iParam.scrPos.w) * _ScreenParams.xy);
           return mainImage(fragCoord);
          }
          ENDCG
        }

		
    }
      FallBack Off
}





