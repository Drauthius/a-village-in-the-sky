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

local TargetReachedEvent = class("TargetReachedEvent")

function TargetReachedEvent:initialize(villager, target, rotation, nextStop)
	self.villager = villager
	self.target = target
	self.rotation = rotation
	self.nextStop = nextStop
end

function TargetReachedEvent:getVillager()
	return self.villager
end

function TargetReachedEvent:getTarget()
	return self.target
end

function TargetReachedEvent:getRotation()
	return self.rotation
end

function TargetReachedEvent:getNextStop()
	return self.nextStop
end

return TargetReachedEvent
