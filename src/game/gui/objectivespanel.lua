local Timer = require "lib.hump.timer"

local Widget = require "src.game.gui.widget"

local spriteSheet = require "src.game.spritesheet"

local ObjectivesPanel = Widget:subclass("ObjectivesPanel")

ObjectivesPanel.static.uniqueID = 0

function ObjectivesPanel:initialize(eventManager, y)
	self.eventManager = eventManager
	self.panels = {}
	self.font = love.graphics.newFont("asset/font/Norse.otf", 15)
	self.panelSprite1 = spriteSheet:getSprite("objectives-panel")
	self.panelSprite2 = spriteSheet:getSprite("objectives-panel2")
	self.panelData1 = spriteSheet:getData("objectives-panel-text")
	self.panelData2 = spriteSheet:getData("objectives-panel2-text")

	-- Widget:
	self.x, self.y = 1, y
	self.ox, self.oy = 0, 0
	self.w, self.h = self.panelSprite1:getWidth(), 0
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

function ObjectivesPanel:addObjective(text, skipTween)
	local numPanels = #self.panels

	local panel
	if self.font:getWidth(text) > self.panelData1.bounds.w then
		self.font:setLineHeight(1.2)
		panel = Widget(self.x, self.y + self.h - 1, 0, 0, self.panelSprite2)
		panel:addText(text, self.font, spriteSheet:getOutlineColor(),
		              self.panelData2.bounds.x, self.panelData2.bounds.y, self.panelData2.bounds.w)
	else
		panel = Widget(self.x, self.y + self.h - 1, 0, 0, self.panelSprite1)
		panel:addText(text, self.font, spriteSheet:getOutlineColor(),
		              self.panelData1.bounds.x, self.panelData1.bounds.y, self.panelData1.bounds.w)
	end

	self.h = self.h + panel:getHeight()
	table.insert(self.panels, panel)
	panel.uniqueID = ObjectivesPanel.uniqueID
	ObjectivesPanel.static.uniqueID = ObjectivesPanel.uniqueID + 1

	if not skipTween then
		-- Create a nice tween effect (reverse of the remove one).
		local panelNum = numPanels + 1
		self.panels[panelNum].sx, self.panels[panelNum].sy = 1, 0
		local oldOy = self.panels[panelNum].text.oy
		self.panels[panelNum].text.oy = 0

		local time = 2.5
		local tween = "in-bounce"

		self.panels[panelNum].timers = {
			Timer.tween(time, self.panels[panelNum].text, { oy = oldOy }, tween),
			Timer.tween(time, self.panels[panelNum], { sy = 1 }, tween)
		}
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
	assert(not self.panels[panelNum].removed, "Objective already removed")

	for _,timer in ipairs(self.panels[panelNum].timers) do
		Timer.cancel(timer)
	end

	local time = 2.5
	local tween = "in-bounce"

	Timer.tween(time, self.panels[panelNum].text, { oy = 0 }, tween)
	Timer.tween(time, self.panels[panelNum], { y = self.panels[panelNum].y + self.panels[panelNum].h }, tween)
	Timer.tween(time, self.panels[panelNum], { sy = 0 }, tween, function()
		-- Another objective might have been removed since last time, so calculate the panel number again
		local newPanelNum
		for i,panel in ipairs(self.panels) do
			if panel.uniqueID == uniqueID then
				newPanelNum = i
				break
			end
		end
		self.h = self.h - self.panels[newPanelNum]:getHeight()
		table.remove(self.panels, newPanelNum)
		for i=newPanelNum,#self.panels do
			local y = i == 1 and self.y or (self.panels[i].y - self.panels[i-1].h)
			Timer.tween(0.5, self.panels[i], { y = y }, tween)
		end
	end)

	self.panels[panelNum].removed = true
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
