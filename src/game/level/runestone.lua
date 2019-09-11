--[[
Copyright (C) 2019  Albert Diserholt (@Drauthius)

This file is part of A Village in the Sky.

A Village in the Sky is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

A Village in the Sky is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with A Village in the Sky. If not, see <http://www.gnu.org/licenses/>.
--]]

local lovetoys = require "lib.lovetoys.lovetoys"

local Level = require "src.game.level"

local InteractiveComponent = require "src.game.interactivecomponent"
local PositionComponent = require "src.game.positioncomponent"
local SpriteComponent = require "src.game.spritecomponent"
local TileComponent = require "src.game.tilecomponent"

local RunestoneLevel = Level:subclass("RunestoneLevel")

local blueprint = require "src.game.blueprint"
local spriteSheet = require "src.game.spritesheet"

function RunestoneLevel:initial()
	for i,tiles in ipairs({ {0,0}, {2,1}, {0,3} }) do
		local tile = lovetoys.Entity()
		tile:add(TileComponent(TileComponent.GRASS, unpack(tiles)))
		local dx, dy = self.map:tileToWorldCoords(unpack(tiles))
		tile:add(SpriteComponent(spriteSheet:getSprite("grass-tile"), dx - self.map.halfTileWidth, dy))
		self.engine:addEntity(tile)
		self.map:addTile(TileComponent.GRASS, unpack(tiles))

		local runestone = blueprint:createRunestone(i)
		local x, y, minGrid, maxGrid = self.map:addObject(runestone, unpack(tiles))
		runestone:get("SpriteComponent"):setDrawPosition(x, y)
		runestone:add(PositionComponent(minGrid, maxGrid, unpack(tiles)))
		InteractiveComponent:makeInteractive(runestone, x, y)
		self.engine:addEntity(runestone)
	end
end

return RunestoneLevel
