local sh = { }

sh.type = "world"

function sh:getPixelId(dream, mat, shadow)
	local ID = 0
	
	--settings
	if shadow then
		ID = mat.discard and 1 or 0
	else
		if pass == 2 then
			--second pass
			ID = ID + 2 ^ 0
		elseif mat.discard or mat.dither or self.dither then
			--requires alpha test (discard)
			ID = ID + 2 ^ 1
		end
	end
	
	return ID
end

function sh:getVertexId(dream, mat, shadow)
	return 0
end

function sh:buildDefines(dream, mat, shadow)
	if shadow then
		return ""
	else
		return [[
			#ifdef PIXEL
			extern Image brdfLUT;
			
			extern vec2 screenScale;
			#endif
			
			//PBR lighting
			const float pi = 3.14159265359;
			const float ipi = 0.31830988618;
			
			float DistributionGGX(vec3 normal, vec3 halfView, float roughness) {
				float a = pow(roughness, 4.0);
				
				float NdotH = max(dot(normal, halfView), 0.0);
				float NdotH2 = NdotH * NdotH;
				
				float denom = NdotH2 * (a - 1.0) + 1.0;
				denom = pi * denom * denom;
				
				return a / max(denom, 0.01);
			}
			
			float GeometrySchlickGGX(float NdotV, float roughness) {
				float r = roughness + 1.0;
				float k = (r * r) * 0.125;
				float denom = NdotV * (1.0 - k) + k;
				return NdotV / denom;
			}
			
			float GeometrySmith(vec3 normal, vec3 view, vec3 light, float roughness) {
				float NdotV = max(dot(normal, view), 0.0);
				float NdotL = max(dot(normal, light), 0.0);
				float ggx2 = GeometrySchlickGGX(NdotV, roughness);
				float ggx1 = GeometrySchlickGGX(NdotL, roughness);
				return ggx1 * ggx2;
			}
			
			vec3 getLight(vec3 lightColor, vec3 viewVec, vec3 lightVec, vec3 normal, vec3 albedo, float roughness, float metallic, float translucent) {
				//TODO improve and cache the dot product
				if (dot(normal, lightVec) < 0.0) {
					lightVec = -lightVec;
					lightColor *= translucent;
				}
				
				//reflectance
				vec3 F0 = mix(vec3(0.04), albedo, metallic);
				
				vec3 halfVec = normalize(viewVec + lightVec);
				
				float NDF = DistributionGGX(normal, halfVec, roughness);   
				float G = GeometrySmith(normal, viewVec, lightVec, roughness);
				
				//fresnel
				float cosTheta = clamp(dot(halfVec, viewVec), 0.0, 1.0);
				vec3 fresnel = F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
				
				//specular
				vec3 nominator = NDF * G * fresnel;
				float denominator = 4.0 * max(dot(normal, viewVec), 0.0) * max(dot(normal, lightVec), 0.0) + 0.001;
				vec3 specular = nominator / denominator;
				
				//energy conservation
				vec3 kD = (vec3(1.0) - fresnel) * (1.0 - metallic);
				
				float lightAngle = max(dot(lightVec, normal), 0.0);
				return (kD * albedo * ipi + specular) * lightColor * lightAngle;
			}
		]]
	end
end

function sh:buildPixel(dream, mat, shadow)
	if shadow then
		return ""
	else
		return [[
		//TODO cache dot
		if (dot(normal, viewVec) < 0.0) {
			normal = -normal;
		}
		
		//PBR model data
		vec3 reflectVec = reflect(viewVec, normal); 
		float cosTheta = clamp(dot(normal, viewVec), 0.0, 1.0);
		vec3 F0 = mix(vec3(0.04), albedo.rgb, metallic);
		
		//fresnel
		vec3 F = F0 + (vec3(1.0) - F0) * pow(1.0 - cosTheta, 5.0);
		
		//specular and diffuse component
		vec3 kS = F;
		vec3 kD = (1.0 - kS) * (1.0 - metallic);
		
		//use the reflection texture as irradiance map approximation
		vec3 diffuse = reflection(normal, 1.0) * albedo.rgb;
		
		//final ambient color with reflection
		//approximate the specular part with brdf lookup table
		vec3 ref = reflection(reflectVec, roughness);
		vec2 brdf = Texel(brdfLUT, vec2(cosTheta, roughness)).rg;
		vec3 specular = ref * (F * brdf.x + vec3(brdf.y));
		
		//final color
		color = (kD * diffuse + specular) * ao + emission;
		
		//lighting
		color += light;
		
		//apply caustics
		color += caustics / alpha;
		
		//fog
	#ifdef FOG_ENABLED
		vec4 fogColor = getFog(depth, viewVec, viewPos);
		color = mix(color, fogcolor, fogColor.a);
	#endif
		
		//exposure
	#ifdef EXPOSURE_ENABLED
		color = vec3(1.0) - exp(-color * exposure);
	#endif
		
		//gamma correction
	#ifdef GAMMA_ENABLED
		color = pow(color, vec3(1.0 / gamma));
	#endif
		
		//distortion
	#ifdef REFRACTIONS_ENABLED
		if (refraction != 1.0) {
			vec2 startPixel = love_PixelCoord.xy * screenScale;
			
			//refract and transform back to pixel coord
			vec3 endPoint = vertexPos + normalize(refract(viewVec, normal, refraction)) * 0.15;
			vec4 endPixel = transformProj * vec4(endPoint, 1.0);
			endPixel /= endPixel.w;
			endPixel.xy = endPixel.xy * 0.5 + 0.5;
			
			//uv translation
			distortion = endPixel.xy - startPixel;
		}
	#endif
		]]
	end
end

function sh:buildVertex(dream, mat)
	return ""
end

function sh:perShader(dream, shaderObject)
	local shader = shaderObject.shader
	
	if shader:hasUniform("brdfLUT") then
		dream.initTextures:PBR()
		shader:send("brdfLUT", dream.textures.brdfLUT)
	end
end

function sh:perMaterial(dream, shaderObject, material)
	
end

function sh:perTask(dream, shaderObject, task)
	
end

return sh