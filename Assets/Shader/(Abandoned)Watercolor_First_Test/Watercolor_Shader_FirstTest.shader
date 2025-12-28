Shader "Custom/Watercolor_Shader_FirstTest"
{
    Properties
    {
        //Original color texture
        _DiffuseColor("Diffuse Color", Color) = (1,1,1,1)
        _AlbedoMap("Albedo Map", 2D) = "white" {}

        //Watercolor properties
        _Pigment1("Pigment Texture 1", 2D) = "black" {} //Pigment type 1 (staining)
        _Pigment2("Pigment Texture 2", 2D) = "black" {} //Pigment type 2 (staining)
        _Pigment1Strength("Pigment 1 Strength", Range(0, 1)) = 1 //Manages how strong the pigment 1 effect is
        _Pigment2Strength("Pigment 2 Strength", Range(0, 1)) = 1 //Manages how strong the pigment 2 effect is
        _EdgeDarkening("Edge Darkening Amount", Float) = 1 //Manages how dark the banding edges are

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
            Name "UniversalForward"
            Tags { "LightMode" = "UniversalForward" }

            Cull Back
            ZWrite On
            ZTest LEqual
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

            TEXTURE2D(_AlbedoMap);
            SAMPLER(sampler_AlbedoMap);
            TEXTURE2D(_Pigment1);
            SAMPLER(sampler_Pigment1);
            TEXTURE2D(_Pigment2);
            SAMPLER(sampler_Pigment2);
            TEXTURE2D(_GrainNormal);
            SAMPLER(sampler_GrainNormal);

            CBUFFER_START(UnityPerMaterial)
                float4 _GrainNormal_ST;
                float4 _Pigment1_ST;
                float4 _Pigment2_ST;
                float4 _DiffuseColor;
                float _Pigment1Strength;
                float _Pigment2Strength;
                float _EdgeDarkening;
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
                //half4 color = SAMPLE_TEXTURE2D(_AlbedoMap, sampler_AlbedoMap, IN.uv).rgb;
                //half4 color = _DiffuseColor;
                
                //Grain
                //Sample the grain normal with TRANSFORM_TEX to apply tilling and offset to tex coords within material properties
                half4 grain = SAMPLE_TEXTURE2D(_GrainNormal, sampler_GrainNormal, TRANSFORM_TEX(IN.uv, _GrainNormal));
                half grainLum = dot(grain.rgb, half3(0.299, 0.587, 0.114)); //Y(brightness) matrix = more consistent contrast
                //half grainLum_saturated = saturate(grainLum * _GrainNormalIntensity); //Clamping (basically if value > max value=max, same for minimum)
                half grainBlend = lerp(1.0h, grainLum, saturate((half)_GrainRoughness)); //_GrainRoughness = 0 -> no grain | _GrainRoughness = 1 -> all grain (grainLum)
                //color *= grainBlend;
                
                //Pigment 
                float4 pigment1 = SAMPLE_TEXTURE2D (_Pigment1, sampler_Pigment1, TRANSFORM_TEX(IN.uv, _Pigment1));
                float4 pigment2 = SAMPLE_TEXTURE2D(_Pigment2, sampler_Pigment2, TRANSFORM_TEX(IN.uv, _Pigment2));
                float4 watercolor = exp(-pigment1 * _Pigment1Strength) / exp(-pigment2 * _Pigment2Strength); //Beer–Lambert law (subtractive watercolor)

                //Lighting
                Light light = GetMainLight(IN.shadowCoord); //Get the properties of the main light (directional) for the shadow coordinates
                float3 lightDirection = normalize(light.direction);
                float shadows = light.shadowAttenuation;
                float NdotL = saturate(dot(IN.normalWS, lightDirection));
                NdotL *= shadows;

                //Edge darkening
                float edgeDarkening = lerp(1, saturate(dot(normalize(IN.normalWS), float3(0,1,0))), _EdgeDarkening);
                //color *= edgeDarkening;

                half3 finalColor = edgeDarkening * grainBlend * watercolor * NdotL;

                return half4(finalColor, watercolor.a);

            }
            ENDHLSL
        }
    }
}