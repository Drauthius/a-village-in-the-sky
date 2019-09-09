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

local PlacingComponent = class("PlacingComponent")

function PlacingComponent.static:save()
	return {
		isTileType = self.isTileType,
		type = self.type
	}
end

function PlacingComponent.static.load(_, data)
	return PlacingComponent(data.isTileType, data.type)
end

function PlacingComponent:initialize(isTile, type)
	self.isTileType = isTile
	self:setType(type)
end

function PlacingComponent:setType(type)
	self.type = type
end

function PlacingComponent:getType()
	return self.type
end

function PlacingComponent:isTile()
	return self.isTileType
end

return PlacingComponent
