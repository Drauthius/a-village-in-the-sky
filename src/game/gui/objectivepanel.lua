local Widget = require "src.game.gui.widget"

local spriteSheet = require "src.game.spritesheet"

local ObjectivePanel = Widget:subclass("ObjectivePanel")

function ObjectivePanel:initialize(eventManager, y)
	self.eventManager = eventManager

	local background = spriteSheet:getSprite("details-panel")

	Widget.initialize(self, 0, y, 0, 0, background)
end

function ObjectivePanel:draw()
	--Widget.draw(self)
end

return ObjectivePanel
