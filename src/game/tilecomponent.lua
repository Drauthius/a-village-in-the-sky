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

local class = require "lib.middleclass"

local TileComponent = class("TileComponent")

TileComponent.static.GRASS = 0
TileComponent.static.FOREST = 1
TileComponent.static.MOUNTAIN = 2

TileComponent.static.TILE_NAME = {
	[TileComponent.static.GRASS] = "grass",
	[TileComponent.static.FOREST] = "forest",
	[TileComponent.static.MOUNTAIN] = "mountain"
}

function TileComponent.static:save()
	return {
		type = self.type,
		ti = self.ti,
		tj = self.tj
	}
end

function TileComponent.static.load(_, data)
	return TileComponent(data.type, data.ti, data.tj)
end

function TileComponent:initialize(type, ti, tj)
	self:setType(type)
	self:setPosition(ti, tj)
end

function TileComponent:setType(type)
	self.type = type
end

function TileComponent:getType()
	return self.type
end

function TileComponent:getPosition()
	return self.ti, self.tj
end

function TileComponent:setPosition(ti, tj)
	self.ti, self.tj = ti, tj
end

return TileComponent
