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

local PositionSystem = lovetoys.System:subclass("PositionSystem")

function PositionSystem.requires()
	return {"PositionComponent"}
end

function PositionSystem:initialize(map)
	lovetoys.System.initialize(self)
	self.map = map
end

function PositionSystem:update(dt)
end

-- Called when an entity gets the position component.
function PositionSystem:onAddEntity(entity)
	if entity:has("VillagerComponent") then
		local grid = entity:get("PositionComponent"):getGrid()
		self.map:occupy(entity, grid)
		entity:get("PositionComponent"):setTile(self.map:gridToTileCoords(grid.gi, grid.gj))
	end
end

-- Called when an entity with the position component is removed, or the position component is removed.
function PositionSystem:onRemoveEntity(entity)
	-- Unreserve any reserved grids.
	-- XXX: The call is different depending on the type of the entity.
	if entity:has("VillagerComponent") then
		self.map:unoccupy(entity, entity:get("PositionComponent"):getGrid())
	else
		self.map:remove(entity)
	end
end

return PositionSystem
