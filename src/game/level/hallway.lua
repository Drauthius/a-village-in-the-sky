local lovetoys = require "lib.lovetoys.lovetoys"

local Level = require "src.game.level"

local AssignmentComponent = require "src.game.assignmentcomponent"
local BuildingComponent = require "src.game.buildingcomponent"
local ConstructionComponent = require "src.game.constructioncomponent"
local GroundComponent = require "src.game.groundcomponent"
local InteractiveComponent = require "src.game.interactivecomponent"
local PositionComponent = require "src.game.positioncomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local SpriteComponent = require "src.game.spritecomponent"
local TileComponent = require "src.game.tilecomponent"

local HallwayLevel = Level:subclass("HallwayLevel")

local blueprint = require "src.game.blueprint"
local spriteSheet = require "src.game.spritesheet"
local state = require "src.game.state"

function HallwayLevel:initiate(engine, map)
	local tile = lovetoys.Entity()
	tile:add(TileComponent(TileComponent.GRASS, 0, 0))
	tile:add(SpriteComponent(spriteSheet:getSprite("grass-tile"), -map.halfTileWidth))
	engine:addEntity(tile)
	map:addTile(TileComponent.GRASS, 0, 0)

	for gi=0,map.gridsPerTile - 1 do
		for gj=0,map.gridsPerTile - 1 do
			if gi == math.floor(map.gridsPerTile / 2) then
				if gj % 2 == 0 then
					local villager = blueprint:createVillager(nil, nil, "male", 20)

					villager:add(PositionComponent(map:getGrid(gi, gj), nil, 0, 0))
					villager:add(GroundComponent(map:gridToGroundCoords(gi + 0.5, gj + 0.5)))

					engine:addEntity(villager)
				end
			else
				local type = math.floor(map.gridsPerTile / 2) > gi and ResourceComponent.WOOD or ResourceComponent.TOOL
				local resource = blueprint:createResourcePile(type, 3)

				map:addResource(resource, map:getGrid(gi, gj))

				local ox, oy = map:gridToWorldCoords(gi, gj)
				ox = ox - map.halfGridWidth
				oy = oy - resource:get("SpriteComponent"):getSprite():getHeight() + map.gridHeight

				resource:get("SpriteComponent"):setDrawPosition(ox, oy)
				resource:add(PositionComponent(map:getGrid(gi, gj), nil, 0, 0))

				engine:addEntity(resource)
				state:increaseResource(type, resource:get("ResourceComponent"):getResourceAmount())
			end
		end
	end

	tile = lovetoys.Entity()
	tile:add(TileComponent(TileComponent.GRASS, 0, -1))
	tile:add(SpriteComponent(spriteSheet:getSprite("grass-tile"), 0, -map.halfTileHeight))
	engine:addEntity(tile)
	map:addTile(TileComponent.GRASS, 0, -1)

	local dwelling = blueprint:createPlacingBuilding(BuildingComponent.DWELLING)
	local ax, ay, minGrid, maxGrid = map:addObject(dwelling, 0, -1)
	dwelling:get("SpriteComponent"):setDrawPosition(ax, ay)
	dwelling:add(PositionComponent(minGrid, maxGrid, 0, -1))
	dwelling:add(ConstructionComponent(BuildingComponent.DWELLING))
	dwelling:add(AssignmentComponent(4))
	InteractiveComponent:makeInteractive(dwelling, ax, ay)
	dwelling:remove("PlacingComponent")
	engine:addEntity(dwelling)
end

return HallwayLevel
