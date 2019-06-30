local class = require "lib.middleclass"

local RunestoneUpgradingEvent = class("RunestoneUpgradingEvent")

function RunestoneUpgradingEvent:initialize(runestone)
	self.runestone = runestone
end

function RunestoneUpgradingEvent:getRunestone()
	return self.runestone
end

return RunestoneUpgradingEvent
