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

local GroundComponent = class("GroundComponent")

function GroundComponent.static:save()
	return {
		gx = self.gx,
		gy = self.gy
	}
end

function GroundComponent.static.load(_, data)
	return GroundComponent(data.gx, data.gy)
end

function GroundComponent:initialize(gx, gy)
	self:setPosition(gx, gy)
end

function GroundComponent:getPosition()
	return self.gx, self.gy
end

function GroundComponent:getIsometricPosition()
	return (self.gx - self.gy) / 2, (self.gx + self.gy) / 4
end

function GroundComponent:setPosition(gx, gy)
	self.gx, self.gy = gx, gy
end

return GroundComponent
