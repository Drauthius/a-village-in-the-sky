local lovetoys = require "lib.lovetoys.lovetoys"

local Level = require "src.game.level"

local GroundComponent = require "src.game.groundcomponent"
local InteractiveComponent = require "src.game.interactivecomponent"
local PositionComponent = require "src.game.positioncomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local SpriteComponent = require "src.game.spritecomponent"
local TileComponent = require "src.game.tilecomponent"

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
		map:addTile(TileComponent.GRASS, 0, 0)
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

			local grid = map:getFreeGrid(0, 0, type)
			map:addResource(resource, grid)

			local ox, oy = map:gridToWorldCoords(grid.gi, grid.gj)
			ox = ox - map.halfGridWidth
			oy = oy - resource:get("SpriteComponent"):getSprite():getHeight() + map.gridHeight

			resource:get("SpriteComponent"):setDrawPosition(ox, oy)
			resource:add(PositionComponent(grid, nil, 0, 0))

			engine:addEntity(resource)
			state:increaseResource(type, resource:get("ResourceComponent"):getResourceAmount())

			num = num - resource:get("ResourceComponent"):getResourceAmount()
		end
	end

	for type,num in pairs(startingVillagers) do
		for _=1,num do
			local villager = blueprint:createVillager(
				type:match("^male") and "male" or "female",
				type:match("Child$") and 5 or 20)

			local gi, gj = unpack(table.remove(startingPositions) or {})
			local grid
			if not gi or not gj then
				grid = map:getFreeGrid(0, 0, "villager")
				gi, gj = grid.gi, grid.gj
			else
				grid = map:getGrid(gi, gj)
			end
			map:reserve(villager, grid)

			villager:add(PositionComponent(grid, nil, 0, 0))
			villager:add(GroundComponent(map:gridToGroundCoords(gi + 0.5, gj + 0.5)))

			engine:addEntity(villager)
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
