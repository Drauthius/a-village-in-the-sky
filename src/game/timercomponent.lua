local class = require "lib.middleclass"

local Timer = require "lib.hump.timer"

local TimerComponent = class("TimerComponent")

function TimerComponent:initialize()
	self.timer = Timer.new()
end

function TimerComponent:increase(dt)
	self.timer:update(dt)
end

function TimerComponent:getTimer()
	return self.timer
end

return TimerComponent
