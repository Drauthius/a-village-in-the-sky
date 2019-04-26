local lovetoys = require "lib.lovetoys.lovetoys"

local Level = require "src.game.level"

local InteractiveComponent = require "src.game.interactivecomponent"
local PositionComponent = require "src.game.positioncomponent"
local SpriteComponent = require "src.game.spritecomponent"
local TileComponent = require "src.game.tilecomponent"

local RunestoneLevel = Level:subclass("RunestoneLevel")

local blueprint = require "src.game.blueprint"
local spriteSheet = require "src.game.spritesheet"

function RunestoneLevel:initiate(engine, map)
	for i,tiles in ipairs({ {0,0}, {2,1}, {0,3} }) do
		local tile = lovetoys.Entity()
		tile:add(TileComponent(TileComponent.GRASS, unpack(tiles)))
		local dx, dy = map:tileToWorldCoords(unpack(tiles))
		tile:add(SpriteComponent(spriteSheet:getSprite("grass-tile"), dx - map.halfTileWidth, dy))
		engine:addEntity(tile)
		map:addTile(TileComponent.GRASS, unpack(tiles))

		local runestone = blueprint:createRunestone(i)
		local x, y, minGrid, maxGrid = map:addObject(runestone, unpack(tiles))
		runestone:get("SpriteComponent"):setDrawPosition(x, y)
		runestone:add(PositionComponent(minGrid, maxGrid, unpack(tiles)))
		InteractiveComponent:makeInteractive(runestone, x, y)
		engine:addEntity(runestone)
	end
end

return RunestoneLevel
