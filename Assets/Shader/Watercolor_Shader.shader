Shader "Custom/Watercolor_Shader"
{
    Properties
    {
        //Original color texture
        _DiffuseColor("Diffuse Color", Color) = (1,1,1,1)

        //Watercolor Shadow
        _ShadowColor("Shadow Color", Color) = (1,1,1,1)

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
            Name "WateryShadows"
            Tags { "LightMode" = "UniversalForward" }

            Cull Back
            Blend One Zero //Opaque

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

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
                float3 positionWS : TEXCOORD3;
            };

            TEXTURE2D(_GrainNormal);
            SAMPLER(sampler_GrainNormal);

            CBUFFER_START(UnityPerMaterial)
                float4 _DiffuseColor; 
                float4 _ShadowColor;              
                float4 _GrainNormal_ST;
                float _GrainRoughness;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                
                VertexPositionInputs pos = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs norms = GetVertexNormalInputs(IN.normalOS);

                OUT.positionHCS = pos.positionCS;
                OUT.positionWS = pos.positionWS;
                OUT.normalWS = normalize(norms.normalWS);
                OUT.uv = IN.uv;
                OUT.shadowCoord = TransformWorldToShadowCoord(OUT.positionWS);
            
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {              
                //Grain
                //Sample the grain normal with TRANSFORM_TEX to apply tilling and offset to tex coords within material properties
                half4 grain = SAMPLE_TEXTURE2D(_GrainNormal, sampler_GrainNormal, TRANSFORM_TEX(IN.uv, _GrainNormal));
                half grainLum = dot(grain.rgb, half3(0.299, 0.587, 0.114)); //Y(brightness) matrix = more consistent contrast
                half grainBlend = lerp(1.0h, grainLum, saturate((half)_GrainRoughness)); //_GrainRoughness = 0 -> no grain | _GrainRoughness = 1 -> all grain (grainLum)

                //Lighting
                float3 ambient = SampleSH(IN.normalWS); //Ambient sampled with spherical harmonics
                
                Light light = GetMainLight(IN.shadowCoord); //Get the properties of the main light (directional) for the shadow coordinates
                float lighting = saturate(dot(IN.normalWS, normalize(light.direction)));
                float shadows = light.shadowAttenuation; //Shadow attenuation

                float3 litColor = _DiffuseColor.rgb * (light.color * lighting + ambient);
                float3 shadowedColor = _DiffuseColor * _ShadowColor + ambient/2;

                float3 finalColor = lerp(shadowedColor, litColor, shadows);
                finalColor *= grainBlend;

                return float4(finalColor, 1);

            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0 //Don't need color, only depth

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl" 

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs pos = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs norms = GetVertexNormalInputs(IN.normalOS);

                float3 positionWS = pos.positionWS;
                float3 normalWS = norms.normalWS;

                float3 lightDirection = _MainLightPosition.xyz; //Unity variable, in this case gets the directional light direction

                float4 positionHCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirection)); //Bias can be altered (in the inspector) because of ApplyShadowBias
                
                OUT.positionHCS = positionHCS; 

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                return 0;
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