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

local BuildingComponent = require "src.game.buildingcomponent"

local EntranceComponent = class("EntranceComponent")

EntranceComponent.static.GRIDS = {
	[BuildingComponent.DWELLING] = {
		rotation = 225, ogi = -3, ogj = 1,
	},
	[BuildingComponent.BLACKSMITH] = {
		rotation = 135, ogi = 0, ogj = -8
	},
	[BuildingComponent.BAKERY] = {
		rotation = 135, ogi = 1, ogj = -6
	}
}

function EntranceComponent.static:save()
	return {
		type = self.type,
		open = self.open
	}
end

function EntranceComponent.static.load(_, data)
	local component = EntranceComponent(data.type)

	component.open = data.open

	return component
end

function EntranceComponent:initialize(buildingType)
	self.type = buildingType
	self.open = false
end

function EntranceComponent:getEntranceGrid()
	return EntranceComponent.GRIDS[self.type]
end

function EntranceComponent:isOpen()
	return self.open
end

function EntranceComponent:setOpen(open)
	self.open = open
end

function EntranceComponent:getAbsoluteGridCoordinate(owner)
	-- The entrance is an offset, so translate it to a real grid coordinate.
	local grid = owner:get("PositionComponent"):getGrid()
	local entrance = self:getEntranceGrid()

	return grid.gi + entrance.ogi, grid.gj + entrance.ogj
end

return EntranceComponent
