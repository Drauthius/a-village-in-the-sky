local class = require "lib.middleclass"

local RunestoneComponent = class("RunestoneComponent")

function RunestoneComponent.static:save()
	return {
		level = self.level
	}
end

function RunestoneComponent.static.load(_, data)
	return RunestoneComponent(data.level)
end

function RunestoneComponent:initialize(level)
	self.level = level or 1
end

function RunestoneComponent:getLevel()
	return self.level
end

function RunestoneComponent:setLevel(level)
	self.level = level
end

return RunestoneComponent
