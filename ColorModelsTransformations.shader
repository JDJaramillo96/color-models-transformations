Shader "Hidden/ColorModelsTransformations"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
	}

	SubShader
	{
		//No culling or depth
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert_img
			#pragma fragment frag
			#pragma fragmentoption ARB_precision_hint_fastest
			
			#include "UnityCG.cginc"

			//Properties
			sampler2D _MainTex;

			/**/
			//Taked from: http://www.chilliant.com/rgb2hsv.html **************************************************
			/**/

			//HUE to RGB 
			float3 HUEtoRGB(float H)
			{
				float R = abs(H * 6 - 3) - 1;
				float G = 2 - abs(H * 6 - 2);
				float B = 2 - abs(H * 6 - 4);
				
				return saturate(float3(R, G, B));
			}

			//RGB to HCV 
			float Epsilon = 1e-10;

			float3 RGBtoHCV(float3 RGB)
			{
				//Based on work by Sam Hocevar and Emil Persson
				float4 P = (RGB.g < RGB.b) ? float4(RGB.bg, -1.0, 2.0 / 3.0) : float4(RGB.gb, 0.0, -1.0 / 3.0);
				float4 Q = (RGB.r < P.x) ? float4(P.xyw, RGB.r) : float4(RGB.r, P.yzx);
				float C = Q.x - min(Q.w, Q.y);
				float H = abs((Q.w - Q.y) / (6 * C + Epsilon) + Q.z);
				
				return float3(H, C, Q.x);
			}

			//HSV to RGB
			float3 HSVtoRGB(float3 HSV)
			{
				float3 RGB = HUEtoRGB(HSV.x);
				
				return ((RGB - 1) * HSV.y + 1) * HSV.z;
			}

			//HSL to RGB
			float3 HSLtoRGB(float3 HSL)
			{
				float3 RGB = HUEtoRGB(HSL.x);
				float C = (1 - abs(2 * HSL.z - 1)) * HSL.y;
				
				return (RGB - 0.5) * C + HSL.z;
			}

			
			//HCY to RGB
			float3 HCYwts = float3(0.299, 0.587, 0.114); // The weights of RGB contributions to luminance.
														 // Should sum to unity.
			float3 HCYtoRGB(float3 HCY)
			{
				float3 RGB = HUEtoRGB(HCY.x);
				float Z = dot(RGB, HCYwts);
				
				if (HCY.z < Z)
				{
					HCY.y *= HCY.z / Z;
				}
				else if (Z < 1)
				{
					HCY.y *= (1 - HCY.z) / (1 - Z);
				}
				
				return (RGB - Z) * HCY.y + HCY.z;
			}

			//HCL to RGB
			float HCLgamma = 3;
			float HCLy0 = 100;
			float HCLmaxL = 0.530454533953517; // == exp(HCLgamma / HCLy0) - 0.5
			float PI = 3.1415926536;

			float3 HCLtoRGB(float3 HCL)
			{
				float3 RGB = 0;
				
				if (HCL.z != 0)
				{
					float H = HCL.x;
					float C = HCL.y;
					float L = HCL.z * HCLmaxL;
					float Q = exp((1 - C / (2 * L)) * (HCLgamma / HCLy0));
					float U = (2 * L - C) / (2 * Q - 1);
					float V = C / Q;
					float T = tan((H + min(frac(2 * H) / 4, frac(-2 * H) / 8)) * PI * 2);
					H *= 6;
					
					if (H <= 1)
					{
						RGB.r = 1;
						RGB.g = T / (1 + T);
					}
					else if (H <= 2)
					{
						RGB.r = (1 + T) / T;
						RGB.g = 1;
					}
					else if (H <= 3)
					{
						RGB.g = 1;
						RGB.b = 1 + T;
					}
					else if (H <= 4)
					{
						RGB.g = 1 / (1 + T);
						RGB.b = 1;
					}
					else if (H <= 5)
					{
						RGB.r = -1 / T;
						RGB.b = 1;
					}
					else
					{
						RGB.r = 1;
						RGB.b = -T;
					}
					
					RGB = RGB * V + U;
				}
				return RGB;
			}

			//RGB to HSV
			float3 RGBtoHSV(float3 RGB)
			{
				float3 HCV = RGBtoHCV(RGB);
				float S = HCV.y / (HCV.z + Epsilon);
				
				return float3(HCV.x, S, HCV.z);
			}

			//RGB to HSL
			float3 RGBtoHSL(float3 RGB)
			{
				float3 HCV = RGBtoHCV(RGB);
				float L = HCV.z - HCV.y * 0.5;
				float S = HCV.y / (1 - abs(L * 2 - 1) + Epsilon);
				
				return float3(HCV.x, S, L);
			}

			//RGB to HCY
			float3 RGBtoHCY(float3 RGB)
			{
				//Corrected by David Schaeffer
				float3 HCV = RGBtoHCV(RGB);
				float Y = dot(RGB, HCYwts);
				float Z = dot(HUEtoRGB(HCV.x), HCYwts);
				
				if (Y < Z)
				{
					HCV.y *= Z / (Epsilon + Y);
				}
				else
				{
					HCV.y *= (1 - Z) / (Epsilon + 1 - Y);
				}
				
				return float3(HCV.x, HCV.y, Y);
			}

			//RGB to HCL
			float3 RGBtoHCL(float3 RGB)
			{
				float3 HCL;
				float H = 0;
				float U = min(RGB.r, min(RGB.g, RGB.b));
				float V = max(RGB.r, max(RGB.g, RGB.b));
				float Q = HCLgamma / HCLy0;
				HCL.y = V - U;
				
				if (HCL.y != 0)
				{
					H = atan2(RGB.g - RGB.b, RGB.r - RGB.g) / PI;
					Q *= U / V;
				}
				
				Q = exp(Q);
				HCL.x = frac(H / 2 - min(frac(H), frac(-H)) / 6);
				HCL.y *= Q;
				HCL.z = lerp(-U, V, Q) / (HCLmaxL * 2);
				
				return HCL;
			}

			/**/
			//Other color transformations
			/**/

			//RGB to YIQ
			float3 RGBtoYIQ(float3 RGB)
			{
				//Trasnformation matrix
				float3x3 transformationMatrix = float3x3(
					0.299, 0.587, 0.114,
					0.595716, -0.274453, -0.321263,
					0.211456, -0.522591, 0.311135
					);

				//YIQ Color calculation
				float1x3 yiq = mul(transformationMatrix, RGB.rgb);

				return transpose(yiq);
			}

			//YIQ to RGB
			float3 YIQtoRGB(float3 YIQ)
			{
				//Transformation matrix
				float3x3 transformationMatrix = float3x3(
					1, 0.9563, 0.6210,
					1, -0.2712, -0.6474,
					1, -1.1070, 1.7046
					);

				//RGB Color calculation
				float1x3 rgb = mul(transformationMatrix, YIQ.rgb);

				return transpose(rgb);
			}

			//Frag function
			float4 frag (v2f_img i) : SV_Target
			{
				float4 color = tex2D(_MainTex, i.uv);
				return color;
			}

			ENDCG
		}
	}
}
