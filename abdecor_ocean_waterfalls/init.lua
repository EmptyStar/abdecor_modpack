-- Asuna implements its own version of this biome feature
if minetest.get_modpath("asuna_core") then
  return
end

--
-- Initialization
--

local cids = {
  water = minetest.get_content_id("mapgen_water_source"),
}

local wall_stones = {
	"mapgen_stone",
}

--
-- Mod compatibility
--

if minetest.get_modpath("default") then
	for _,node in ipairs({
		"default:desert_stone",
		"default:sandstone",
		"default:silver_sandstone",
		"default:stone_with_coal",
		"default:stone_with_iron",
		"default:stone_with_tin",
		"default:stone_with_copper",
		"default:stone_with_gold",
		"default:stone_with_diamond",
		"default:stone_with_mese",
	}) do
		table.insert(wall_stones,node)
	end
end

--
-- Advanced biome decoration
--

-- Valid wall stones are indexed by node ID
local valid_wall_stones = {}
for _,node in ipairs(wall_stones) do
	valid_wall_stones[minetest.get_content_id(node)] = true
end

-- Add all stone nodes to valid wall nodes
minetest.register_on_mods_loaded(function()
	for node,def in pairs(minetest.registered_nodes) do
		if def.groups and def.groups.stone and def.groups.stone > 0 then
			valid_wall_stones[minetest.get_content_id(node)] = true
		end
	end
end)

-- Include group:stone in spawn_by list
table.insert(wall_stones,"group:stone")

abdecor.register_advanced_decoration("abdecor_waterfalls",{
	target = {
		place_on = "mapgen_water_source",
		spawn_by = wall_stones,
		num_spawn_by = 3,
		sidelen = 80,
		fill_ratio = 0.11,
		y_max = 1,
		y_min = 1,
		flags = "liquid_surface",
	},
	fn = function(mapgen)
		-- Get provided values
		local pos = mapgen.pos
		local va = mapgen.voxelarea
		local vdata = mapgen.data

		-- Get stride values and adjust position
		local ystride = va.ystride
		local zstride = va.zstride
		pos = va:index(pos.x,pos.y + 1,pos.z)
		local too_low_pos = 0

		-- Get stone wall direction
		local cardinal = {
			-1,
			-zstride,
			1,
			zstride,
		}

		local found_stone = false
		local check_wall = nil
		for i = 1, 4 do
			local wallpos = pos + cardinal[i]
			local wallleft = cardinal[i % 4 + 1]
			local wallright = cardinal[(i + 2) % 4 + 1]
			check_wall = function(pos) -- is the entire row of wall nodes made of stone?
				return valid_wall_stones[vdata[pos]] and valid_wall_stones[vdata[pos + wallleft]] and valid_wall_stones[vdata[pos + wallright]] and true or false
			end
			if check_wall(wallpos) then
				pos = wallpos
				too_low_pos = pos
				found_stone = true
				break
			end
		end

		-- Do nothing if no stone wall found
		if not found_stone then
			return
		end

		-- Iterate above 'rows' of stone wall until we find something that isn't stone
		repeat
			pos = pos + ystride
		until not check_wall(pos)

		-- Set two below stone position to water if higher than one node
		local placepos = pos - 2 * ystride
		if placepos > too_low_pos then
			vdata[placepos] = cids.water
		end
	end,
	flags = {
		liquid = true,
	},
})