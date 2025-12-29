Shader "Custom/Watercolor_Shader"
{
    Properties
    {
        //Original color texture
        _DiffuseColor("Diffuse Color", Color) = (1,1,1,1)
        _AlbedoTex("Albedo Texture", 2D) = "white" {}

        //Outline
        _OutlineAmount("Outline Amount", Range(0, 1)) = 0.25
        _OutlineColor("Outline Color", Color) = (0.5,0.5,0.5,1)

        //Paper Granulation properties
        _GrainNormal("Grain Texture", 2D) = "white" {} //Height or Normal texture
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
            Name "Watery Shadows"
            Tags { "LightMode" = "UniversalForward" }

            Cull Back
            //ZWrite On
            //ZTest LEqual
            Blend One Zero //Opaque

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float2 uv : TEXCOORD1;
                float4 shadowCoord : TEXCOORD2;
            };

            TEXTURE2D(_AlbedoTex);
            SAMPLER(sampler_AlbedoTex);
            TEXTURE2D(_GrainNormal);
            SAMPLER(sampler_GrainNormal);

            CBUFFER_START(UnityPerMaterial)
                float4 _DiffuseColor; 
                float4 _AlbedoTex_ST;               
                float4 _GrainNormal_ST;
                float _GrainRoughness;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz); //Object space to homogenous space    
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                OUT.uv = IN.uv;
                OUT.shadowCoord = TransformWorldToShadowCoord(TransformObjectToWorld(IN.positionOS.xyz));
            
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //Diffuse color
                //half4 color = _DiffuseColor;
                half4 color = SAMPLE_TEXTURE2D(_AlbedoTex, sampler_AlbedoTex, TRANSFORM_TEX(IN.uv, _AlbedoTex));
                
                //Grain
                //Sample the grain normal with TRANSFORM_TEX to apply tilling and offset to tex coords within material properties
                half4 grain = SAMPLE_TEXTURE2D(_GrainNormal, sampler_GrainNormal, TRANSFORM_TEX(IN.uv, _GrainNormal));
                half grainLum = dot(grain.rgb, half3(0.299, 0.587, 0.114)); //Y(brightness) matrix = more consistent contrast
                //half grainLum_saturated = saturate(grainLum * _GrainNormalIntensity); //Clamping (basically if value > max value=max, same for minimum)
                half grainBlend = lerp(1.0h, grainLum, saturate((half)_GrainRoughness)); //_GrainRoughness = 0 -> no grain | _GrainRoughness = 1 -> all grain (grainLum)
                color *= grainBlend;

                //Lighting
                Light light = GetMainLight(IN.shadowCoord); //Get the properties of the main light (directional) for the shadow coordinates
                float3 lightDirection = normalize(light.direction);
                float shadows = light.shadowAttenuation;
                float NdotL = saturate(dot(IN.normalWS, lightDirection));
                NdotL *= shadows;

                return color * NdotL;

            }
            ENDHLSL
        }

        Pass
        {
            Name "Outline"

            Cull Front

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
                       
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD3;
            };  

            CBUFFER_START(UnityPerMaterial)
                float _OutlineAmount;
                float4 _OutlineColor;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 worldPos = TransformObjectToWorld(IN.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);

                worldPos += float4(normalize(normalWS), 0) * _OutlineAmount;
                OUT.positionHCS = TransformWorldToHClip(worldPos);
                OUT.positionWS = worldPos;
 
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 outlineColor = _OutlineColor;

                return _OutlineColor;
            }
            ENDHLSL
        }
    }
}