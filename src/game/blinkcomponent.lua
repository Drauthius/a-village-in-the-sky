local class = require "lib.middleclass"

local Timer = require "lib.hump.timer"

local BlinkComponent = class("BlinkComponent")

function BlinkComponent.static:makeBlinking(entity, color)
	local blinkComponent = BlinkComponent(color)
	Timer.during(1.5, function(dt)
		blinkComponent:increaseTimer(dt)
		blinkComponent:setActive((blinkComponent:getTimer() % 0.5) < 0.25)
	end, function()
		entity:remove("BlinkComponent")
	end)
	entity:add(blinkComponent)
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
