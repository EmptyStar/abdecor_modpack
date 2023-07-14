--
-- Mod compatibility
--

-- Asuna implements its own version of this biome feature
if minetest.get_modpath("asuna_core") then
  return
end

--
-- Initialization
--

-- Collections of features based on climate
local climates = {
  temperate = {
    surface = {},
    surface_nodes = {},
    biomes = {},
    boulders = {
      "mossy_cobblestone_boulder_small",
      "mossy_cobblestone_boulder_medium",
    },
  },
  dry = {
    surface = {},
    surface_nodes = {},
    biomes = {},
    boulders = {
      "cobblestone_boulder_small",
      "cobblestone_boulder_medium",
    },
  },
  desert = {
    surface = {},
    surface_nodes = {},
    biomes = {},
    boulders = {
      "desert_boulder_small",
      "desert_boulder_medium",
    },
  },
}

--
-- Implementation
--

minetest.register_on_mods_loaded(function()
  -- Get relevant climates from biome data
  for biome,def in pairs(minetest.registered_biomes) do
    local top = def.node_top or "mapgen_stone"
    local filler = def.node_filler or "mapgen_stone"
    local heat = def.heat_point or 50
    local humidity = def.humidity_point or 50
    if def.y_min < 1 then
      -- this is a shore, ocean, or underground biome which will not have boulders
    elseif biome:find("desert") or top:find("sand") or filler:find("desert") then
      table.insert(climates.desert.biomes,biome)
      table.insert(climates.desert.surface,top)
      climates.desert.surface_nodes[minetest.get_content_id(top)] = true
      climates.desert.surface_nodes[minetest.get_content_id(filler)] = true
    elseif humidity < 40 and heat > 25 then
      table.insert(climates.dry.biomes,biome)
      table.insert(climates.dry.surface,top)
      climates.dry.surface_nodes[minetest.get_content_id(top)] = true
      climates.dry.surface_nodes[minetest.get_content_id(filler)] = true
    elseif heat > 25 then
      table.insert(climates.temperate.biomes,biome)
      table.insert(climates.temperate.surface,top)
      climates.temperate.surface_nodes[minetest.get_content_id(top)] = true
      climates.temperate.surface_nodes[minetest.get_content_id(filler)] = true
    end
  end

  -- Register boulder decor per climate
  for _,climate in pairs(climates) do
    for _,boulder in ipairs(climate.boulders) do
      local schematic = minetest.get_modpath("abdecor_boulders") .. "/schematics/" .. boulder .. ".mts"
      abdecor.register_advanced_decoration("abdecor_" .. boulder,{
        target = {
          place_on = climate.surface,
          sidelen = 80,
          fill_ratio = 0.000025,
          y_max = 31000,
          y_min = 1,
          biomes = climate.biomes,
        },
        fn = function(mapgen)
          -- Get provided values
          local va = mapgen.voxelarea
          local pos = va:index(mapgen.pos.x,mapgen.pos.y - 1,mapgen.pos.z)
          local vdata = mapgen.data
    
          -- Get stride values
          local ystride = va.ystride
          local zstride = va.zstride

          -- Check for surrounding space
          for i = 3, 4 do
            if vdata[pos + i * ystride] ~= minetest.CONTENT_AIR then
              return -- there's something above the boulder's location
            end
          end

          for i = -3, 3 do
            if vdata[pos + i * zstride + 3 * ystride] ~= minetest.CONTENT_AIR then
              return -- there's something occupying the surrounding space
            end
          end

          for i = -3, 3 do
            if vdata[pos + i + 3 * ystride] ~= minetest.CONTENT_AIR then
              return -- there's something occupying the surrounding space
            end
          end
    
          -- Check for flat ground
          for _,ground in ipairs({
            pos - 1,
            pos + 1,
            pos - zstride,
            pos + zstride,
            pos - 1 - zstride,
            pos + 1 - zstride,
            pos - zstride + 1,
            pos + zstride - 1,
          }) do
            if not climate.surface_nodes[vdata[ground]] then
              return -- the ground node is something else
            end
          end
    
          -- Place a boulder
          mapgen.place_schematic({
            pos = mapgen.pos,
            schematic = schematic,
            force_placement = true,
            flags = "place_center_x,place_center_z",
          })
        end,
        flags = {
          schematic = true,
        },
      })
    end
  end
end)