local class = require "lib.middleclass"

local Timer = require "lib.hump.timer"

local TimerComponent = class("TimerComponent")

-- 1 minute is 1 year.
TimerComponent.static.YEARS_TO_SECONDS = 60
TimerComponent.static.YEARS_PER_SECOND = 1 / TimerComponent.YEARS_TO_SECONDS

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
