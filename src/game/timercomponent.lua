local class = require "lib.middleclass"

local Timer = require "lib.hump.timer"

local TimerComponent = class("TimerComponent")

function TimerComponent:initialize(delay, after)
	self.timer = Timer.new()
	if delay and after then
		self.timer:after(delay, after)
	end
end

function TimerComponent:increase(dt)
	self.timer:update(dt)
end

function TimerComponent:getTimer()
	return self.timer
end

return TimerComponent
