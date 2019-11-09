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

local PregnancyComponent = class("PregnancyComponent")

function PregnancyComponent.static:save(cassette)
	return {
		expected = self.expected,
		father = (self.father and self.father.alive) and cassette:saveEntity(self.father) or nil,
		fatherUnique = self.fatherUnique,
		inLabour = self.inLabour
	}
end

function PregnancyComponent.static.load(cassette, data)
	local component = PregnancyComponent:allocate()

	component.expected = data.expected
	component.father = data.father and cassette:loadEntity(data.father) or nil
	component.fatherUnique = data.fatherUnique
	component.inLabour = data.inLabour

	return component
end

function PregnancyComponent:initialize(expected, father)
	self.expected = expected
	self.father = father
	self.fatherUnique = father:get("VillagerComponent"):getUnique()
	self.inLabour = false
end

function PregnancyComponent:getExpected()
	return self.expected
end

function PregnancyComponent:setExpected(expected)
	self.expected = expected
end

function PregnancyComponent:isInLabour()
	return self.inLabour
end

function PregnancyComponent:setInLabour(inLabour)
	self.inLabour = inLabour
end

function PregnancyComponent:getFather()
	return self.father, self.fatherUnique
end

return PregnancyComponent
