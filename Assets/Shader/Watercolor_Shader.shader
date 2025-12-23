Shader "Custom/Watercolor_Shader"
{
    Properties
    {
        //Watercolor properties
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _BaseMap("Base Map", 2D) = "white" {}
        
        //Paper Granulation properties
        _GrainNormal("Grain Texture", 2D) = "white" {} //Height or Normal texture
        _GrainNormalIntensity("Grain Texture Intensity", Range(0, 1)) = 1 //Manages the intensity of the normal map
        _GrainRoughness("Grain Roughness", Range(0, 1)) = 0.5 //Manages how rough or smooth the paper is 

    }

    SubShader
    {
        Tags { 
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque" 
            "Queue" = "Geometry"
        }

        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode" = "UniversalForward" }

            Cull Back
            ZWrite On
            ZTest LEqual
            Blend One Zero //Opaque

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _MAIN_LIGHT_SHADOWS

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS   : TEXCOORD1;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_GrainNormal);
            SAMPLER(sampler_GrainNormal);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                float4 _GrainNormal_ST;
                float _GrainNormalIntensity;
                float _GrainRoughness;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;

                //Sample the grain normal with TRANSFORM_TEX to apply tilling and offset to tex coords within material properties
                half4 grainSample = SAMPLE_TEXTURE2D(_GrainNormal, sampler_GrainNormal, TRANSFORM_TEX(IN.uv, _GrainNormal));
                half grainLum = dot(grainSample.rgb, half3(0.299, 0.587, 0.114)); //Y(brightness) matrix = more consistent contrast
                grainLum = saturate(grainLum * _GrainNormalIntensity); //Clamping (basically if value > max value=max, same for minimum)
                half grainBlend = lerp(1.0h, grainLum, saturate((half)_GrainRoughness)); //_GrainRoughness = 0 -> no grain | _GrainRoughness = 1 -> all grain (grainLum)
                color *= grainBlend;
                return color;
            }
            ENDHLSL
        }
    }
}