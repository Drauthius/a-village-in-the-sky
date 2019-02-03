local class = require "lib.middleclass"

local WorkingComponent = class("WorkingComponent")

function WorkingComponent:initialize()
	self.working = false
end

function WorkingComponent:getWorking()
	return self.working
end

function WorkingComponent:setWorking(working)
	self.working = working
end

return WorkingComponent
