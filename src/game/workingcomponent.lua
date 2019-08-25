local class = require "lib.middleclass"

local WorkingComponent = class("WorkingComponent")

function WorkingComponent.static:save()
	return {
		working = self.working
	}
end

function WorkingComponent.static.load(_, data)
	local component = WorkingComponent()

	component.working = data.working

	return component
end

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
