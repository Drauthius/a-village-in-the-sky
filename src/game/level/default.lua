local lovetoys = require "lib.lovetoys.lovetoys"

local Level = require "src.game.level"

local AdultComponent = require "src.game.adultcomponent"
local AnimationComponent = require "src.game.animationcomponent"
local ColorSwapComponent = require "src.game.colorswapcomponent"
local GroundComponent = require "src.game.groundcomponent"
local InteractiveComponent = require "src.game.interactivecomponent"
local PositionComponent = require "src.game.positioncomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local SpriteComponent = require "src.game.spritecomponent"
local TileComponent = require "src.game.tilecomponent"
local VillagerComponent = require "src.game.villagercomponent"

local blueprint = require "src.game.blueprint"
local spriteSheet = require "src.game.spritesheet"
local state = require "src.game.state"

local DefaultLevel = Level:subclass("DefaultLevel")

function DefaultLevel:initiate(engine, map)
	do -- Initial tile.
		local tile = lovetoys.Entity()
		tile:add(TileComponent(TileComponent.GRASS, 0, 0))
		tile:add(SpriteComponent(spriteSheet:getSprite("grass-tile"), -map.halfTileWidth))
		engine:addEntity(tile)
		map:addTile(0, 0)
	end

	do -- Initial runestone.
		local runestone = blueprint:createRunestone()
		local x, y, minGrid, maxGrid = map:addObject(runestone, 0, 0)
		runestone:get("SpriteComponent"):setDrawPosition(x, y)
		runestone:add(PositionComponent(minGrid, maxGrid, 0, 0))
		InteractiveComponent:makeInteractive(runestone, x, y)
		engine:addEntity(runestone)
	end

	local startingResources = {
		[ResourceComponent.WOOD] = 30,
		[ResourceComponent.IRON] = 6,
		[ResourceComponent.TOOL] = 12,
		[ResourceComponent.BREAD] = 6
	}

	local startingVillagers = {
		maleVillagers = 2,
		femaleVillagers = 2,
		maleChild = 1,
		femaleChild = 1
	}
	local startingPositions = {
		{ 11, 2 },
		{ 12, 6 },
		{ 12, 10 },
		{ 9, 12 },
		{ 5, 12 },
		{ 2, 11 },
	}

	for type,num in pairs(startingResources) do
		while num > 0 do
			local resource = blueprint:createResourcePile(type, math.min(3, num))

			local gi, gj = map:getFreeGrid(0, 0, type)
			map:addResource(resource, map:getGrid(gi, gj))

			local ox, oy = map:gridToWorldCoords(gi, gj)
			ox = ox - map.halfGridWidth
			oy = oy - resource:get("SpriteComponent"):getSprite():getHeight() + map.gridHeight

			resource:get("SpriteComponent"):setDrawPosition(ox, oy)
			resource:add(PositionComponent(map:getGrid(gi, gj), nil, 0, 0))

			engine:addEntity(resource)
			state:increaseResource(type, resource:get("ResourceComponent"):getResourceAmount())

			num = num - resource:get("ResourceComponent"):getResourceAmount()
		end
	end

	-- TODO: Grossly misplaced.
	local palette = spriteSheet:getSprite("villagers-palette")
	local colors = {
		skins = {
			-- Default:
			{ { palette:getPixel(4, 0) },
			  { palette:getPixel(5, 0) } },
			-- Fairer:
			{ { 0.761, 0.584, 0.510, 1 },
			  { 0.812, 0.663, 0.569, 1 } }
		},
		hairs = {
			-- Default:
			{ { palette:getPixel(6, 0) },
			  { palette:getPixel(7, 0) } },
			-- Lighter:
			{ { 0.490, 0.369, 0.145, 1 },
			  { 0.569, 0.471, 0.224, 1 } }
		},
		shirts = {
			-- Default:
			{ { palette:getPixel(8, 0) },
			  { palette:getPixel(9, 0) } },
			-- Lighter:
			{ { 0.506, 0.565, 0.600, 1 },
			  { 0.753, 0.812, 0.808, 1 } }
		},
		pants = {
			-- Default:
			{ { palette:getPixel(10, 0) },
			  { palette:getPixel(11, 0) } },
			-- Browner:
			{ { 0.212, 0.169, 0.129, 1 },
			  { 0.259, 0.204, 0.165, 1 } }
		},
		shoes = {
			-- Default:
			{ { palette:getPixel(12, 0) },
			  { palette:getPixel(13, 0) } }
		}
	}

	for type,num in pairs(startingVillagers) do
		for _=1,num do
			local villager = lovetoys.Entity()

			local gi, gj = unpack(table.remove(startingPositions) or {})
			if not gi or not gj then
				gi, gj = map:getFreeGrid(0, 0, "villager")
			end
			map:reserve(villager, map:getGrid(gi, gj))

			local colorSwap = ColorSwapComponent()
			local skinColor = colors.skins[love.math.random(1, #colors.skins)]
			for k,v in pairs(colors) do
				local color
				if k == "skins" then
					color = skinColor
				elseif k == "shoes" and love.math.random() < 0.5 then
					-- Barefoot!
					color = skinColor
				else
					color = v[love.math.random(1, #v)]
				end

				if color ~= v[1] then
					colorSwap:add(v[1], color)
				end
			end
			villager:add(colorSwap)
			villager:add(PositionComponent(map:getGrid(gi, gj), nil, 0, 0))
			villager:add(GroundComponent(map:gridToGroundCoords(gi + 0.5, gj + 0.5)))
			villager:add(VillagerComponent({
				hairy = love.math.random() <= 0.5,
				gender = type:match("^male") and "male" or "female",
				age = type:match("Child$") and 5 or 20 }))
			villager:add(SpriteComponent())
			villager:add(AnimationComponent())
			if not type:match("Child$") then
				villager:add(AdultComponent())
			end

			engine:addEntity(villager)

			-- XXX:
			state["increaseNum" .. type:gsub("^%l", string.upper):gsub("Child$", "Children")](state)
		end
	end
end

function Level:getResources(tileType)
	if tileType == TileComponent.GRASS then
		-- TODO: Would be nice with some trees, but not the early levels
		return 0, 0 --return math.max(0, math.floor((love.math.random(9) - 5) / 2)), 0
	elseif tileType == TileComponent.FOREST then
		return love.math.random(2, 6), 0
	elseif tileType == TileComponent.MOUNTAIN then
		return math.max(0, love.math.random(5) - 4), love.math.random(2, 4)
	end
end

return DefaultLevel
