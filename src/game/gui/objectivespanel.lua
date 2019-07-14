local Timer = require "lib.hump.timer"

local Widget = require "src.game.gui.widget"

local spriteSheet = require "src.game.spritesheet"

local ObjectivesPanel = Widget:subclass("ObjectivesPanel")

ObjectivesPanel.static.uniqueID = 0

function ObjectivesPanel:initialize(eventManager, y)
	self.eventManager = eventManager
	self.panels = {}
	self.font = love.graphics.newFont("asset/font/Norse.otf", 15)
	self.panelSprite = spriteSheet:getSprite("objectives-panel")
	self.panelData = spriteSheet:getData("objectives-panel-text")

	-- Widget:
	self.x, self.y = 1, y
	self.ox, self.oy = 0, 0
	self.w, self.h = self.panelSprite:getWidth(), 0

	self:addObjective("This is a test objective")
	self:addObjective("Build a dwelling")
end

function ObjectivesPanel:draw()
	for i,panel in ipairs(self.panels) do
		panel:draw()

		-- Soften the harsh colour between the panels.
		if i ~= 1 then
			love.graphics.setColor(spriteSheet:getWoodPalette().dark)
			love.graphics.rectangle("fill", panel.x + 1, panel.y - 1, panel.w - 2, 2)
			love.graphics.setColor(1, 1, 1, 1)
		end
	end
end

function ObjectivesPanel:addObjective(text)
	local numPanels = #self.panels

	local panel = Widget(self.x, self.y + numPanels * self.panelSprite:getHeight() - 1, 0, 0, self.panelSprite)
	panel:addText(text, self.font, spriteSheet:getOutlineColor(),
	              self.panelData.bounds.x, self.panelData.bounds.y, self.panelData.bounds.w)
	table.insert(self.panels, panel)

	if self.font:getWidth(text) > self.panelData.bounds.w then
		print("Objective is too big for objective panel.") -- TODO
	end

	self.h = self.h + self.panelSprite:getHeight()

	panel.uniqueID = ObjectivesPanel.uniqueID
	ObjectivesPanel.uniqueID = ObjectivesPanel.uniqueID + 1

	do -- Create a nice tween effect (reverse of the remove one).
		local panelNum = numPanels + 1
		self.panels[panelNum].sx, self.panels[panelNum].sy = 1, 0
		self.panels[panelNum].text.oy = 0

		local time = 2.5
		local tween = "in-bounce"

		Timer.tween(time, self.panels[panelNum].text, { oy = self.panelData.bounds.y }, tween)
		Timer.tween(time, self.panels[panelNum], { sy = 1 }, tween)
	end

	return panel.uniqueID
end

function ObjectivesPanel:removeObjective(uniqueID)
	local panelNum
	for i,panel in ipairs(self.panels) do
		if panel.uniqueID == uniqueID then
			panelNum = i
			break
		end
	end
	assert(panelNum, "Unique objective ID not found.")

	local time = 2.5
	local tween = "in-bounce"

	Timer.tween(time, self.panels[panelNum].text, { oy = 0 }, tween)
	Timer.tween(time, self.panels[panelNum], { y = self.panels[panelNum].y + self.panels[panelNum].h }, tween)
	Timer.tween(time, self.panels[panelNum], { sy = 0 }, tween, function()
		table.remove(self.panels, panelNum)
		for i=panelNum,#self.panels do
			Timer.tween(0.5, self.panels[i], { y = self.panels[i].y - self.panels[i].h }, tween)
		end
	end)
end

function ObjectivesPanel:isWithin(x, y)
	if next(self.panels) then
		return Widget.isWithin(self, x, y)
	else
		return false
	end
end

function ObjectivesPanel:handlePress(released)
	if not released then
		return
	end

	self:removeObjective(self.panels[1].uniqueID)
end

return ObjectivesPanel
