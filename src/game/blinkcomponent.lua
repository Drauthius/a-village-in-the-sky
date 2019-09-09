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

local Timer = require "lib.hump.timer"

local BlinkComponent = class("BlinkComponent")

-- Blinking is currently only used for selection,
-- and there's not a really good reason to bother saving that.
BlinkComponent.static.save = false

function BlinkComponent.static:makeBlinking(entity, color)
	-- A unique so that spam clicking works as expected.
	local unique = love.math.random()
	local blinkComponent = BlinkComponent(color, unique)
	Timer.during(1.2, function(dt)
		blinkComponent:increaseTimer(dt)
		blinkComponent:setActive((blinkComponent:getTimer() % 0.44) < 0.22)
	end, function()
		if entity:has("BlinkComponent") and entity:get("BlinkComponent").unique == unique then
			entity:remove("BlinkComponent")
		end
	end)
	entity:set(blinkComponent)
end

function BlinkComponent:initialize(color, unique)
	self.color = color
	self.timer = 0.0
	self.active = true
	self.unique = unique or love.math.random()
end

function BlinkComponent:getColor()
	return self.color
end

function BlinkComponent:isActive()
	return self.active == true
end

function BlinkComponent:setActive(active)
	self.active = active
end

function BlinkComponent:getTimer()
	return self.timer
end

function BlinkComponent:increaseTimer(dt)
	self.timer = self.timer + dt
end

return BlinkComponent
