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

local ColorSwapComponent = class("ColorSwapComponent")

function ColorSwapComponent.static:save()
	return {
		groups = self.groups,
		oldColors = self.oldColors,
		newColors = self.newColors
	}
end

function ColorSwapComponent.static.load(_, data)
	local component = ColorSwapComponent()

	component.groups = data.groups
	component.oldColors = data.oldColors
	component.newColors = data.newColors

	return component
end

function ColorSwapComponent:initialize()
	self.groups = {}
	self.oldColors = {}
	self.newColors = {}
end

function ColorSwapComponent:add(group, oldColors, newColors)
	assert(#oldColors == #newColors)
	assert(not self.groups[group], "Overwriting color group: "..tostring(group))

	self.groups[group] = { #self.oldColors, #oldColors }

	for i=1,#oldColors do
		table.insert(self.oldColors, oldColors[i])
		table.insert(self.newColors, newColors[i])
	end
end

function ColorSwapComponent:replace(group, newColors)
	assert(self.groups[group], "No such color group: "..tostring(group))

	local offset, count = unpack(self.groups[group])
	assert(count == #newColors,
		"Group "..tostring(group).." uses "..tonumber(count).." colors. "..tonumber(#newColors).." received.")

	for i=1,count do
		self.newColors[i+offset] = newColors[i]
	end
end

function ColorSwapComponent:getGroup(group)
	if not self.groups[group] then
		return nil
	end

	local offset, count = unpack(self.groups[group])
	local ret = {}
	for i=1,count do
		table.insert(ret, self.newColors[i+offset])
	end

	return ret
end

function ColorSwapComponent:getReplacedColors()
	return self.oldColors
end

function ColorSwapComponent:getReplacingColors()
	return self.newColors
end

return ColorSwapComponent
