local class = require "lib.middleclass"

local Timer = require "lib.hump.timer"

local BlinkComponent = class("BlinkComponent")

function BlinkComponent.static:makeBlinking(entity, color)
	-- A unique so that spam clicking works as expected.
	local unique = love.math.random()
	local blinkComponent = BlinkComponent(color, unique)
	blinkComponent.unique = unique
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

function BlinkComponent:initialize(color)
	self.color = color
	self.timer = 0.0
	self.active = true
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
