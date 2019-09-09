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

local FertilityComponent = class("FertilityComponent")

function FertilityComponent.static:save()
	return {
		fertility = self.fertility
	}
end

function FertilityComponent.static.load(_, data)
	local component = FertilityComponent()

	component.fertility = data.fertility

	return component
end

function FertilityComponent:initialize()
	-- This is the chance to produce a baby per intercourse.
	self.fertility = love.math.random(55, 95) / 100.0
end

function FertilityComponent:getFertility()
	return self.fertility
end

function FertilityComponent:setFertility(fertility)
	self.fertility = fertility
end

return FertilityComponent
