local lovetoys = require "lib.lovetoys.lovetoys"

local TimerSystem = lovetoys.System:subclass("TimerSystem")

function TimerSystem.requires()
	return {"TimerComponent"}
end

function TimerSystem:update(dt)
	for _,entity in pairs(self.targets) do
		entity:get("TimerComponent"):increase(dt)
	end
end

return TimerSystem
