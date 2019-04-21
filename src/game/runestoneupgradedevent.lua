local class = require "lib.middleclass"

local RunestoneUpgradedEvent = class("RunestoneUpgradedEvent")

function RunestoneUpgradedEvent:initialize(entity)
	self.entity = entity
end

function RunestoneUpgradedEvent:getRunestone()
	return self.entity
end

return RunestoneUpgradedEvent
