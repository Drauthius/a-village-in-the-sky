local class = require "lib.middleclass"

local RunestoneComponent = class("RunestoneComponent")

function RunestoneComponent:initialize()
	self.level = 0
end

function RunestoneComponent:getLevel()
	return self.level
end

return RunestoneComponent
