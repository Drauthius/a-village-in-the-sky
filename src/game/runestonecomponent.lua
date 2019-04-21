local class = require "lib.middleclass"

local RunestoneComponent = class("RunestoneComponent")

function RunestoneComponent:initialize(level)
	self.level = level or 0
end

function RunestoneComponent:getLevel()
	return self.level
end

return RunestoneComponent
