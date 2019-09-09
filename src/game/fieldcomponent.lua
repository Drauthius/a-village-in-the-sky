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

local FieldComponent = class("FieldComponent")

FieldComponent.static.UNCULTIVATED = 0
FieldComponent.static.PLOWED = 1
FieldComponent.static.SEEDED = 2
FieldComponent.static.GROWING = 3
FieldComponent.static.HARVESTING = 4
FieldComponent.static.IN_PROGRESS = 5

FieldComponent.static.STATE_NAMES = {
	[FieldComponent.UNCULTIVATED] = "uncultivated",
	[FieldComponent.PLOWED] = "plowed",
	[FieldComponent.SEEDED] = "seeded",
	[FieldComponent.GROWING] = "growing",
	[FieldComponent.HARVESTING] = "harvesting"
}

function FieldComponent.static:save(cassette)
	return {
		state = self.state,
		enclosure = cassette:saveEntity(self.enclosure),
		index = self.index
	}
end

function FieldComponent.static.load(cassette, data)
	local component = FieldComponent(cassette:loadEntity(data.enclosure), data.index)

	component:setState(data.state)

	return component
end

function FieldComponent:initialize(enclosure, index)
	self:setState(FieldComponent.UNCULTIVATED)
	self:setEnclosure(enclosure)
	self:setIndex(index)
end

function FieldComponent:getState()
	return self.state
end

function FieldComponent:setState(state)
	self.state = state
end

function FieldComponent:getEnclosure()
	assert(self.enclosure)
	return self.enclosure
end

function FieldComponent:setEnclosure(enclosure)
	self.enclosure = enclosure
end

function FieldComponent:getIndex()
	return self.index
end

function FieldComponent:setIndex(index)
	self.index = index
end

return FieldComponent
