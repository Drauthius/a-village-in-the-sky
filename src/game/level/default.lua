local lovetoys = require "lib.lovetoys.lovetoys"

local Level = require "src.game.level"

local AdultComponent = require "src.game.adultcomponent"
local AnimationComponent = require "src.game.animationcomponent"
local GroundComponent = require "src.game.groundcomponent"
local InteractiveComponent = require "src.game.interactivecomponent"
local PositionComponent = require "src.game.positioncomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local SpriteComponent = require "src.game.spritecomponent"
local TileComponent = require "src.game.tilecomponent"
local VillagerComponent = require "src.game.villagercomponent"

local blueprint = require "src.game.blueprint"
local state = require "src.game.state"

local DefaultLevel = Level:subclass("DefaultLevel")

function DefaultLevel:initiate(engine, map)
	do -- Initial tile.
		local spriteSheet = require "src.game.spritesheet"
		local tile = lovetoys.Entity()
		tile:add(TileComponent(TileComponent.GRASS, 0, 0))
		tile:add(SpriteComponent(spriteSheet:getSprite("grass-tile"), -map.halfTileWidth))
		engine:addEntity(tile)
		map:addTile(0, 0)
	end

	do -- Initial runestone.
		local runestone = blueprint:createRunestone()
		local x, y, grid = map:addObject(runestone, 0, 0)
		runestone:get("SpriteComponent"):setDrawPosition(x, y)
		runestone:get("PositionComponent"):setGrid(grid)
		runestone:get("PositionComponent"):setTile(0, 0)
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
			resource:get("PositionComponent"):setGrid(map:getGrid(gi, gj))
			resource:get("PositionComponent"):setTile(0, 0)

			engine:addEntity(resource)
			state:increaseResource(type, resource:get("ResourceComponent"):getResourceAmount())

			num = num - resource:get("ResourceComponent"):getResourceAmount()
		end
	end

	for type,num in pairs(startingVillagers) do
		for _=1,num do
			local villager = lovetoys.Entity()

			local gi, gj = unpack(table.remove(startingPositions) or {})
			if not gi or not gj then
				gi, gj = map:getFreeGrid(0, 0, "villager")
			end
			map:reserve(villager, map:getGrid(gi, gj))

			villager:add(PositionComponent(map:getGrid(gi, gj), 0, 0))
			villager:add(GroundComponent(map:gridToGroundCoords(gi + 0.5, gj + 0.5)))
			villager:add(VillagerComponent({
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
