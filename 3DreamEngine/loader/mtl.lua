--[[
#mtl - Material Library File for .obj
--]]

return function(self, obj, path)
	--materials
	local material = obj.materials.None
	for l in love.filesystem.lines(path) do
		local v = string.split(l, " ")
		if v[1] == "newmtl" then
			obj.materials[l:sub(8)] = self:newMaterial(l:sub(8))
			material = obj.materials[l:sub(8)]
		elseif v[1] == "Ks" then -- specular color
			local metallic = math.sqrt(v[2]^2 + v[3]^2 + v[4]^2)
			material.metallic = math.min(1.0, math.max(0.0, metallic / 1024))
		elseif v[1] == "Ns" then -- specular exponent
			material.roughness = math.min(1.0, math.max(0.0, v[2] / 1024))
		elseif v[1] == "Kd" then -- diffuse
			material.color[1] = tonumber(v[2])
			material.color[2] = tonumber(v[3])
			material.color[3] = tonumber(v[4])
		elseif v[1] == "d" then
			material.color[4] = tonumber(v[2])
			if material.color[4] < 1 then
				material.alpha = true
			end
		elseif v[1] == "Tr" then
			material.color[4] = 1.0 - tonumber(v[2])
		elseif v[1] == "ior" then
			material.ior = tonumber(v[2])
		elseif v[1] == "cullMode" then
			material.cullMode = v[2]
		elseif v[1] == "emission" then
			material.emission = {tonumber(v[2]), tonumber(v[3]) or tonumber(v[2]), tonumber(v[4]) or tonumber(v[2])}
		elseif v[1] == "roughness" then
			material.roughness = tonumber(v[2])
		elseif v[1] == "metallic" then
			material.metallic = tonumber(v[2])
		elseif v[1] == "map_Ka" or v[1] == "map_Kd" then
			material.tex_albedo = obj.dir .. "/" .. (l:sub(8):match("(.+)%..+") or l:sub(8))
		elseif v[1] == "map_Kr" or v[1] == "map_Ks" then
			material.tex_roughness = obj.dir .. "/" .. (l:sub(8):match("(.+)%..+") or l:sub(8))
		elseif v[1] == "map_Km" then
			material.tex_metallic = obj.dir .. "/" .. (l:sub(8):match("(.+)%..+") or l:sub(8))
		elseif v[1] == "map_Kn" then
			material.tex_normal = obj.dir .. "/" .. (l:sub(8):match("(.+)%..+") or l:sub(8))
		elseif v[1] == "map_Ke" then
			material.tex_emission = obj.dir .. "/" .. (l:sub(8):match("(.+)%..+") or l:sub(8))
		elseif v[1] == "illum" then
			
		end
	end
end