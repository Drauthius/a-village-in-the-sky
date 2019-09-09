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

local state = require "src.game.state"

local ResourceSystem = lovetoys.System:subclass("ResourceSystem")

function ResourceSystem.requires()
	return {"ResourceComponent"}
end

function ResourceSystem:initialize(map)
	lovetoys.System.initialize(self)
	self.map = map
end

function ResourceSystem:update(dt)
end

-- Called when an entity gets the resource component.
function ResourceSystem:onAddEntity(entity)
	local resource = entity:get("ResourceComponent")

	-- Only update harvested resources.
	if resource:isExtracted() then
		local sprite = entity:get("SpriteComponent")
		local grid = entity:get("PositionComponent"):getGrid()

		local ox, oy = self.map:gridToWorldCoords(grid.gi, grid.gj)
		ox = ox - self.map.halfGridWidth
		oy = oy - sprite:getSprite():getHeight() + self.map.gridHeight

		sprite:setDrawPosition(ox, oy)

		state:increaseResource(resource:getResource(), resource:getResourceAmount())
		state:reserveResource(resource:getResource(), resource:getReservedAmount())
	end
end

-- Called when an entity with the resource component is removed, or the resource component is removed.
function ResourceSystem:onRemoveEntity(entity)
	-- FIXME: State updating is currently not handled here, since it is possible to partially take a resource.
end

return ResourceSystem
