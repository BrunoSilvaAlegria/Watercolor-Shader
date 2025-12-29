Shader "Custom/Watercolor_Shader"
{
    Properties
    {
        //Original color texture
        _DiffuseColor("Diffuse Color", Color) = (1,1,1,1)
        _AlbedoTex("Albedo Texture", 2D) = "white" {}

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
            Name "Watery Shadows"
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
                float4 positionWS : TEXCOORD1;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float2 uv : TEXCOORD1;
                float4 shadowCoord : TEXCOORD2;
                float3 positionWS : TEXCOORD3;
            };

            TEXTURE2D(_AlbedoTex);
            SAMPLER(sampler_AlbedoTex);
            TEXTURE2D(_GrainNormal);
            SAMPLER(sampler_GrainNormal);

            CBUFFER_START(UnityPerMaterial)
                float4 _DiffuseColor; 
                float4 _AlbedoTex_ST; 
                float4 _ShadowColor;              
                float4 _GrainNormal_ST;
                float _GrainRoughness;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz); //Object space to homogenous space    
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                OUT.uv = IN.uv;
                OUT.shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
            
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //Diffuse color
                half4 color = SAMPLE_TEXTURE2D(_AlbedoTex, sampler_AlbedoTex, TRANSFORM_TEX(IN.uv, _AlbedoTex));
                
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
                lighting *= shadows;

                //Double smoothstep flattens lighting, exaggerates mid-tones and removes hard falloff.
                shadows = smoothstep(0.7, 1.5, shadows * 2);
                shadows = smoothstep(0.2, 0.8, shadows);                 
                
                //float3 texColor = lerp(color.rgb, _ShadowColor + ambient, 0);
                //texColor = lerp(texColor, 1, 1- color.a);
                
                float3 litColor = ambient + (_DiffuseColor.rgb * lighting);
                float3 shadowedColor = litColor * _ShadowColor;

                float3 finalColor = lerp(shadowedColor, litColor, shadows);
                finalColor *= grainBlend;
                //float3 diffuse = _DiffuseColor.rgb * smoothstep(0.35, 0.4, texColor) * texColor;
                
                //float3 diffuseTemp = (ambient + diffuse) * _ShadowColor.rgb;
                //diffuseTemp *= grainBlend;

                return float4(finalColor, 1);

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