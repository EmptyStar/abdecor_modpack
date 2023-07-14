-- Asuna implements its own version of this biome feature
if minetest.get_modpath("asuna_core") then
  return
end

--
-- Initialization
--

local enclosing_nodes = {
  "mapgen_stone",
}

local valid_enclosing_nodes = {}

local cids = {
  water = minetest.get_content_id("mapgen_water_source"),
  lava = minetest.get_content_id("mapgen_lava_source"),
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
		table.insert(enclosing_nodes,node)
	end
end

--
-- Implementation
--

-- Add all valid enclosing nodes by node ID
for _,node in ipairs(enclosing_nodes) do
  valid_enclosing_nodes[minetest.get_content_id(node)] = true
end

-- Add all stone nodes to valid enclosing nodes
minetest.register_on_mods_loaded(function()
	for node,def in pairs(minetest.registered_nodes) do
		if def.groups and def.groups.stone and def.groups.stone > 0 then
			valid_enclosing_nodes[minetest.get_content_id(node)] = true
		end
	end
end)

-- Add stone group to enclosing nodes
table.insert(enclosing_nodes,"group:stone")

abdecor.register_advanced_decoration("abdecor_cave_flows",{
  target = {
    place_on = enclosing_nodes,
    sidelen = 80,
    spawn_by = enclosing_nodes,
    num_spawn_by = 9,
    fill_ratio = 0.000015,
    y_max = -30,
    y_min = -31000,
    flags = "all_ceilings",
  },
  fn = function(mapgen)
    -- Get provided values
    local va = mapgen.voxelarea
    local vdata = mapgen.data
    local vparam2 = mapgen.param2
    local pos = mapgen.pos

    -- Get stride values and set position
    local ystride = va.ystride
    local zstride = va.zstride
    local pos = va:index(pos.x,pos.y,pos.z)

    -- Liquid must be enclosed to its sides and above
    for _,adjacent in ipairs({
      ystride,
      1,
      -1,
      zstride,
      -zstride,
    }) do
      if not valid_enclosing_nodes[vdata[pos + adjacent]] then
        return -- liquid is not fully enclosed
      end
    end

    -- Liquid must have sufficient clearance below
    -- Scanning from bottom up should typically fail faster than top down
    for below = pos - ystride * 8, pos - ystride, ystride do
      if vdata[below] ~= minetest.CONTENT_AIR then
        return -- not enough space between ceiling and ground
      end
    end

    -- Fill the position and all air below with liquid based on climate
    -- Dry/hot climates are more likely to be lava, vice-versa with water
    local liquid = (function()
      local heatmap = minetest.get_mapgen_object("heatmap") or {}
      local humiditymap = minetest.get_mapgen_object("humiditymap") or {}
      local pos2d = mapgen.index2d(mapgen.pos)
      local heat = heatmap[pos2d] or 50
      local humidity = humiditymap[pos2d] or 50
      local climate = 50 + (heat / 2 - 25) - (humidity / 2 - 25)
      local pos_random = PcgRandom(mapgen.seed):next(-29,29) + climate
      return pos_random > 50 and cids.lava or cids.water
    end)()
    vdata[pos] = liquid
    pos = pos - ystride
  end,
  flags = {
    liquid = true,
    param2 = true,
  },
})