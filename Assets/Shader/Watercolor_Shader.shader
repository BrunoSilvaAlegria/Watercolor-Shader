Shader "Custom/Watercolor_Shader"
{
    Properties
    {
        //Original color texture
        //_BaseColor("Base Color", Color) = (1,1,1,1)
        _AlbedoMap("Albedo Map", 2D) = "white" {}

        //Watercolor properties
        _Pigment("Pigment Texture", 2D) = "white" {} //Pigment type (staining)
        _PigmentStrength("Pigment Strenght", Range(0, 1)) = 1 //Manages how strong the pigment's effect is
        _EdgeDarkening("Edge Darkening Amount", Float) = 1 //Manages how dark the banding edges are
        _Banding("Banding Amount", Range(1, 10)) = 3 //Manages light intensity considering watercolor look (flat washes)
        _BandingNoise("Banding Noise", 2D) = "white" {} //Noise for irregular borders
        _BandingSoftness("Banding Softness", Range(0, 1)) = 0.2 //Manages how soft the banding borders are

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
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
                float4 shadowCoord : TEXCOORD3;
            };

            TEXTURE2D(_AlbedoMap);
            SAMPLER(sampler_AlbedoMap);
            TEXTURE2D(_Pigment);
            SAMPLER(sampler_Pigment);
            TEXTURE2D(_BandingNoise);
            SAMPLER(sampler_BandingNoise);
            TEXTURE2D(_GrainNormal);
            SAMPLER(sampler_GrainNormal);

            CBUFFER_START(UnityPerMaterial)
                float4 _GrainNormal_ST;
                float4 _Pigment_ST;
                float4 _BandingNoise_ST;
                float4 _BaseColor;
                float _PigmentStrength;
                float _EdgeDarkening;
                float _Banding;
                float _BandingSoftness;
                float _GrainNormalIntensity;
                float _GrainRoughness;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs pos = GetVertexPositionInputs(IN.positionOS.xyz); //Get the VertexPositionInputs of the vertex, which contains the position in world space
                VertexNormalInputs nor = GetVertexNormalInputs(IN.normalOS); //Get the VertexNormalInputs of the vertex, which contains the normal in world space
                
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz); //Object space to homogenous space    
                OUT.positionWS = pos.positionWS;
                OUT.normalWS = normalize(nor.normalWS); 
                OUT.uv = IN.uv;
                OUT.shadowCoord = GetShadowCoord(pos);
            
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //Base color
                half4 color = SAMPLE_TEXTURE2D(_AlbedoMap, sampler_AlbedoMap, IN.uv);
                //half4 color = _BaseColor;
                
                
                //Sample the grain normal with TRANSFORM_TEX to apply tilling and offset to tex coords within material properties
                half4 grainSample = SAMPLE_TEXTURE2D(_GrainNormal, sampler_GrainNormal, TRANSFORM_TEX(IN.uv, _GrainNormal));
                half grainLum = dot(grainSample.rgb, half3(0.299, 0.587, 0.114)); //Y(brightness) matrix = more consistent contrast
                //half grainLum_saturated = saturate(grainLum * _GrainNormalIntensity); //Clamping (basically if value > max value=max, same for minimum)
                half grainBlend = lerp(1.0h, grainLum, saturate((half)_GrainRoughness)); //_GrainRoughness = 0 -> no grain | _GrainRoughness = 1 -> all grain (grainLum)
                color *= grainBlend;

                //Pigment 
                float pigment = SAMPLE_TEXTURE2D(_Pigment, sampler_Pigment, TRANSFORM_TEX(IN.uv, _Pigment));

                float stains = pigment * (_PigmentStrength + 0.5);
                
                //Lighting
                Light light = GetMainLight(IN.shadowCoord); //Get the properties of the main light (directional) for the shadow coordinates
                float3 lightDirection = normalize(light.direction);
                float shadows = light.shadowAttenuation;
                float NdotL = saturate(dot(IN.normalWS, lightDirection));
                NdotL *= shadows;

                half3 finalColor = color.rgb * stains * NdotL;
                
                return half4(finalColor, color.a); //Set the fragment color to the color map multiplied by the interpolated amount of light
            }
            ENDHLSL
        }
    }
}