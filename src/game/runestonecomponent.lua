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

local RunestoneComponent = class("RunestoneComponent")

function RunestoneComponent.static:save()
	return {
		level = self.level
	}
end

function RunestoneComponent.static.load(_, data)
	return RunestoneComponent(data.level)
end

function RunestoneComponent:initialize(level)
	self.level = level or 1
end

function RunestoneComponent:getLevel()
	return self.level
end

function RunestoneComponent:setLevel(level)
	self.level = level
end

return RunestoneComponent
