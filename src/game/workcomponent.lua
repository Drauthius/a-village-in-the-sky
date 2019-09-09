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

local ResourceComponent = require "src.game.resourcecomponent"

local WorkComponent = class("WorkComponent")

WorkComponent.static.UNEMPLOYED = 0
WorkComponent.static.WOODCUTTER = 1
WorkComponent.static.MINER = 2
WorkComponent.static.BLACKSMITH = 3
WorkComponent.static.FARMER = 4
WorkComponent.static.BAKER = 5
WorkComponent.static.BUILDER = 6

WorkComponent.static.RESOURCE_TO_WORK = {
	[ResourceComponent.WOOD] = WorkComponent.WOODCUTTER,
	[ResourceComponent.IRON] = WorkComponent.MINER,
	[ResourceComponent.TOOL] = WorkComponent.BLACKSMITH,
	[ResourceComponent.GRAIN] = WorkComponent.FARMER,
	[ResourceComponent.BREAD] = WorkComponent.BAKER,
}

WorkComponent.static.WORK_TO_RESOURCE = {
	[WorkComponent.WOODCUTTER] = ResourceComponent.WOOD,
	[WorkComponent.MINER] = ResourceComponent.IRON,
	[WorkComponent.BLACKSMITH] = ResourceComponent.TOOL,
	[WorkComponent.FARMER] = ResourceComponent.GRAIN,
	[WorkComponent.BAKER] = ResourceComponent.BREAD,
}

WorkComponent.static.WORK_NAME = {
	[WorkComponent.UNEMPLOYED] = "unemployed",
	[WorkComponent.WOODCUTTER] = "woodcutter",
	[WorkComponent.MINER] = "miner",
	[WorkComponent.BLACKSMITH] = "blacksmith",
	[WorkComponent.FARMER] = "farmer",
	[WorkComponent.BAKER] = "baker",
	[WorkComponent.BUILDER] = "builder"
}

-- TODO: These could be automatically generated from sprite information,
--       or slice information?
WorkComponent.static.WORK_PLACES = {
	[WorkComponent.WOODCUTTER] = {
		{ rotation = 90, ogi = -2, ogj = 0 },
		{ rotation = 270, ogi = 0, ogj = -2 }
	},
	[WorkComponent.MINER] = {
		{ rotation = 90, ogi = -2, ogj = 0 },
		{ rotation = 270, ogi = 0, ogj = -2 }
	},
	[WorkComponent.FARMER] = {
		{ rotation = 315, ogi = 1, ogj = -2 }
	}
}

function WorkComponent.static:save()
	return {
		type = self.type,
		completion = self.completion
	}
end

function WorkComponent.static.load(_, data)
	local component = WorkComponent(data.type)

	component.completion = data.completion

	return component
end

function WorkComponent:initialize(workType)
	self.type = workType
	self.completion = 0.0
end

function WorkComponent:getType()
	return self.type
end

function WorkComponent:getTypeName()
	return WorkComponent.WORK_NAME[self.type]
end

function WorkComponent:getWorkGrids()
	return WorkComponent.WORK_PLACES[self.type]
end

function WorkComponent:increaseCompletion(value)
	self.completion = self.completion + value
end

function WorkComponent:isComplete()
	return self.completion >= 100.0
end

function WorkComponent:reset()
	self.completion = 0.0
end

return WorkComponent
