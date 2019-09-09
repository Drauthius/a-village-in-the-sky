--[[
Copyright (C) 2019  Albert Diserholt (@Drauthius)

This file is part of A Village in the Sky.

A Village in the Sky is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

A Village in the Sky is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with A Village in the Sky. If not, see <http://www.gnu.org/licenses/>.
--]]

local babel = require "lib.babel"

local Widget = require "src.game.gui.widget"

local Button = require "src.game.gui.button"
local ProgressBar = require "src.game.gui.progressbar"

-- XXX: Too much logic in the GUI?
local BuildingComponent = require "src.game.buildingcomponent"
local ConstructionComponent = require "src.game.constructioncomponent"
local ResourceComponent = require "src.game.resourcecomponent"

local BuildingRazedEvent = require "src.game.buildingrazedevent"
local ConstructionCancelledEvent = require "src.game.constructioncancelledevent"
local RunestoneUpgradingEvent = require "src.game.runestoneupgradingevent"

local screen = require "src.screen"
local spriteSheet = require "src.game.spritesheet"
local state = require "src.game.state"

local DetailsPanel = Widget:subclass("DetailsPanel")

DetailsPanel.static.BUTTON = {
	HIDDEN = 0,
	CANCEL = 1,
	DESTROY = 2,
	UPGRADE = 3
}

function DetailsPanel:initialize(eventManager, y)
	self.eventManager = eventManager

	self.font = love.graphics.newFont("asset/font/Norse.otf", 16)
	self.fontBold = love.graphics.newFont("asset/font/Norse-Bold.otf", 16)
	self.fontHeader = love.graphics.newFont("asset/font/Norse-Bold.otf", 24)

	local background = spriteSheet:getSprite("details-panel")

	local screenWidth, _ = screen:getDrawDimensions()
	Widget.initialize(self, screenWidth - background:getWidth(), math.max(0, y - background:getHeight()), 0, 0, background)

	local buttonSprite = spriteSheet:getSprite("details-button (Up)")
	self.button = Button(self.x + 2 + (background:getWidth() - buttonSprite:getWidth()) / 2,
	                     self.y + background:getHeight() - buttonSprite:getHeight() - self.font:getHeight() - 6,
	                     1, 5, "details-button", self.fontBold)
	self.buttonState = DetailsPanel.BUTTON.HIDDEN

	self.villagerDetails = {
		{ "Name", "getName" },
		{ "Age", "getAge" },
		{ "Hunger", "getHunger" },
		{ "Sleepiness", "getSleepiness" },
		{},
		{ "Occupation", "getOccupationName", true },
		{ "Strength", "getStrength" },
		{ "Craftsmanship", "getCraftsmanship" }
	}
end

function DetailsPanel:update(dt)
	if not self:isShown() then
		return
	end

	if self.button:isPressed() then
		if not self.button:isWithin(screen:getCoordinate(love.mouse.getPosition())) then
			self.button:setPressed(false)
		end
		-- FIXME: Would be nice if the button could be activate again if the pressed mouse hovers over the button
		-- again, but it would require some refactoring of the click events.
	end
end

function DetailsPanel:draw()
	if not self:isShown() then
		return
	end

	Widget.draw(self)
	self.buttonState = DetailsPanel.BUTTON.HIDDEN

	-- The text area.
	local x, y, w, h = self.x + 5, self.y + 13, self.w - 6 --, self.h - 13

	local selection = state:getSelection()

	if selection:has("VillagerComponent") then
		local villager = selection:get("VillagerComponent")
		local adult = selection:has("AdultComponent") and selection:get("AdultComponent")

		love.graphics.setColor(spriteSheet:getOutlineColor())

		for _,details in ipairs(self.villagerDetails) do
			local key, value, adultComp = details[1], details[2], details[3]
			if not key then
				if not adult then
					break
				end
			else
				key = key .. ": "
				if adultComp then
					value = adult[value](adult)
				else
					value = villager[value](villager)
				end
				if type(value) == "number" then
					value = string.format("%.2f", value)
				end
				love.graphics.setFont(self.fontBold)
				love.graphics.print(key, x, y)

				love.graphics.setFont(self.font)
				love.graphics.print(value, x + self.fontBold:getWidth(key), y)
				y = y + math.floor(self.fontBold:getHeight() * 1.5)
			end
		end
	elseif selection:has("BuildingComponent") then
		local building = selection:get("BuildingComponent")
		local type = building:getType()
		local name = babel.translate(BuildingComponent.BUILDING_NAME[type])

		love.graphics.setFont(self.fontHeader)
		love.graphics.setColor(spriteSheet:getOutlineColor())
		love.graphics.printf(name, x, y, w - 2, "right")

		y = y + self.fontHeader:getHeight() * 1.2

		if selection:has("ConstructionComponent") then
			local construction = selection:get("ConstructionComponent")
			local materials = construction:getRemainingResources()

			-- Draw "Under construction" header thingy.
			local underConstruction = babel.translate("Under construction")
			local oy = self.fontBold:getHeight() * 0.4
			love.graphics.setFont(self.font)
			love.graphics.printf(underConstruction, x, y - oy, w, "right")
			y = y - oy + self.font:getHeight() + 2

			-- Underline?
			--[[local textWidth = self.font:getWidth(underConstruction)
			love.graphics.setLineWidth(1)
			love.graphics.setLineStyle("rough")
			love.graphics.line(x + w - textWidth, y, x + w, y)
			y = y + 4
			--]]

			-- Draw material list
			y = y + self:_drawMaterialList("Missing", materials, x, y) + 1

			-- Draw progress bar
			local ox = self.font:getWidth(" 100%")
			local progressBar = ProgressBar(x, y, w - ox, 10, spriteSheet:getSprite("headers", "builder-icon"))
			progressBar:draw(construction:getValueDone(), construction:getValueBuildable())

			love.graphics.setColor(spriteSheet:getOutlineColor())
			love.graphics.print(" "..construction:getPercentDone().."%",
			                    x + w - ox,
			                    y + (progressBar.icon:getHeight() - self.font:getHeight()) / 2)

			y = y + progressBar.icon:getHeight() + 1
			self.buttonState = DetailsPanel.BUTTON.CANCEL
		end

		if selection:has("RunestoneComponent") then
			local runestone = selection:get("RunestoneComponent")
			local underConstruction = selection:has("ConstructionComponent")
			local stage = babel.translate("Stage") .. ": "

			love.graphics.setFont(self.fontBold)
			love.graphics.print(stage, x, y)
			local ox = self.fontBold:getWidth(stage)

			love.graphics.setFont(self.font)
			love.graphics.print(tostring(runestone:getLevel()), x + ox, y)

			if underConstruction then
				ox = ox + self.font:getWidth(runestone:getLevel())
				love.graphics.print(" >> "..tostring(runestone:getLevel() + 1), x + ox, y)
			elseif ConstructionComponent.MATERIALS[BuildingComponent.RUNESTONE][runestone:getLevel() + 1] then
				self.buttonState = DetailsPanel.BUTTON.UPGRADE
			end
		elseif self.buttonState == DetailsPanel.BUTTON.HIDDEN then
			self.buttonState = DetailsPanel.BUTTON.DESTROY
		end

		if self.buttonState ~= DetailsPanel.BUTTON.HIDDEN then
			-- Re-purpose for additions based on the button's position.
			x, y = self.button:getPosition()
			w, h = self.button:getDimensions()
			local ox = -1
			local oy = self.font:getHeight() + 1

			-- Background covering the button and the cost/refund
			love.graphics.setColor(spriteSheet:getWoodPalette().outline)
			love.graphics.setLineWidth(1)
			love.graphics.setLineStyle("rough")
			love.graphics.rectangle("line", x - ox, y + 1, w + ox, h + oy)

			local buttonText, resourceText, resources
			if self.buttonState == DetailsPanel.BUTTON.CANCEL then
				buttonText = "Cancel"
				resourceText = "Refund"
				resources = selection:get("ConstructionComponent"):getRefundedResources()
			elseif self.buttonState == DetailsPanel.BUTTON.DESTROY then
				buttonText = "Destroy"
				resourceText = "Refund"
				resources = ConstructionComponent:getRefundedResources(selection:get("BuildingComponent"):getType())
			elseif self.buttonState == DetailsPanel.BUTTON.UPGRADE then
				buttonText = "Upgrade"
				resourceText = "Cost"
				local runestone = selection:get("RunestoneComponent")
				resources = ConstructionComponent.MATERIALS[BuildingComponent.RUNESTONE][runestone:getLevel()]
			end

			self.button:setText(buttonText)

			self:_drawMaterialList(resourceText, resources, x - ox + 1, y + h + 2)

			love.graphics.setColor(1, 1, 1)
			self.button:draw()
		end
	else
		return
	end

	love.graphics.setColor(1, 1, 1)
end

function DetailsPanel:hide()
end

function DetailsPanel:isShown()
	return state:getSelection() ~= nil
end

function DetailsPanel:handlePress(x, y, released)
	assert(self:isShown())

	if self.buttonState ~= DetailsPanel.BUTTON.HIDDEN and self.button:isWithin(x, y) then
		if released and self.button:isPressed() then
			local selection = state:getSelection()

			if self.buttonState == DetailsPanel.BUTTON.CANCEL then
				self.eventManager:fireEvent(ConstructionCancelledEvent(selection))
			elseif self.buttonState == DetailsPanel.BUTTON.DESTROY then
				self.eventManager:fireEvent(BuildingRazedEvent(selection))
			elseif self.buttonState == DetailsPanel.BUTTON.UPGRADE then
				self.eventManager:fireEvent(RunestoneUpgradingEvent(selection))
			end
		end
		self.button:setPressed(not released)
	end
end

function DetailsPanel:_drawMaterialList(label, materials, x, y)
	label = babel.translate(label) .. ": "

	love.graphics.setFont(self.fontBold)
	love.graphics.print(label, x, y)

	local ox = self.fontBold:getWidth(label)
	local hasResources = false

	love.graphics.setFont(self.font)
	local spacing = self.font:getWidth(" ")

	for resource,amount in pairs(materials) do
		if amount > 0 then
			hasResources = true
			local count = amount .. "x"
			love.graphics.setColor(spriteSheet:getOutlineColor())

			love.graphics.print(count, x + ox, y)
			ox = ox + self.font:getWidth(count) + 1

			local icon = spriteSheet:getSprite("headers", ResourceComponent.RESOURCE_NAME[resource].."-icon")
			love.graphics.setColor(1, 1, 1)
			spriteSheet:draw(icon, x + ox, math.floor(y - (self.font:getHeight() - icon:getHeight()) / 2) + 1)
			ox = ox + icon:getWidth() + spacing
		end
	end

	if not hasResources then
		love.graphics.print("--", x + ox, y)
	end

	return self.fontBold:getHeight()
end

return DetailsPanel
