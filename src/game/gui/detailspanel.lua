local class = require "lib.middleclass"

local Button = require "src.game.gui.button"

local screen = require "src.screen"
local spriteSheet = require "src.game.spritesheet"
local state = require "src.game.state"

local DetailsPanel = class("DetailsPanel")

function DetailsPanel:initialize(y, buttonEvents)
	self.buttonEvents = buttonEvents

	self.font = love.graphics.newFont("asset/font/Norse.otf", 16)
	self.fontBold = love.graphics.newFont("asset/font/Norse-Bold.otf", 16)

	self.background = spriteSheet:getSprite("details-panel")

	local screenWidth, _ = screen:getDimensions()
	self.bounds = {
		x = screenWidth - self.background:getWidth(),
		y = y - self.background:getHeight(),
		w = self.background:getWidth(),
		h = self.background:getHeight()
	}

	local buttonSprite = spriteSheet:getSprite("details-button (Up)")
	self.button = Button(self.bounds.x + (self.bounds.w - buttonSprite:getWidth()) / 2,
	                     self.bounds.y + self.bounds.h - buttonSprite:getHeight() * 2,
	                     1, 5, "details-button", self.fontBold)

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

	-- FIXME: Don't need to do this every frame...
	local selection = state:getSelection()
	if selection:has("RunestoneComponent") then
		if selection:has("ConstructionComponent") then
			self.button:setText("Cancel")
		else
			self.button:setText("Upgrade")
		end
	end
end

function DetailsPanel:draw()
	if not self:isShown() then
		return
	end

	spriteSheet:draw(self.background, self.bounds.x, self.bounds.y)

	local x, y = self.bounds.x + 5, self.bounds.y + 13

	love.graphics.setColor(0, 0, 0)

	local selection = state:getSelection()

	if selection:has("VillagerComponent") then
		local villager = selection:get("VillagerComponent")
		local adult = selection:has("AdultComponent") and selection:get("AdultComponent")

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
	elseif selection:has("RunestoneComponent") then
		local runestone = selection:get("RunestoneComponent")

		love.graphics.setFont(self.fontBold)
		love.graphics.print("Stage: ", x, y)

		love.graphics.setFont(self.font)
		love.graphics.print(tostring(runestone:getLevel()), x + self.fontBold:getWidth("Stage: "), y)

		love.graphics.setColor(1, 1, 1)
		self.button:draw()
	end

	love.graphics.setColor(1, 1, 1)
end

function DetailsPanel:hide()
	state:clearSelection()
end

function DetailsPanel:isShown()
	return state:getSelection() ~= nil
end

function DetailsPanel:isWithin(x, y)
	return x >= self.bounds.x and
		   y >= self.bounds.y and
		   x <= self.bounds.x + self.bounds.w and
		   y <= self.bounds.y + self.bounds.h
end

function DetailsPanel:handlePress(x, y, released)
	assert(self:isShown())

	-- XXX: Another check for whether the/a button is shown.
	if state:getSelection():has("RunestoneComponent") then
		if self.button:isWithin(x, y) then
			if released and self.button:isPressed() then
				if state:getSelection():has("ConstructionComponent") then
					self.buttonEvents("runestone-upgrade-cancel")
				else
					self.buttonEvents("runestone-upgrade")
				end
			end
			self.button:setPressed(not released)
		end
	end
end

return DetailsPanel
