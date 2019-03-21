local class = require "lib.middleclass"

local screen = require "src.screen"
local spriteSheet = require "src.game.spritesheet"
local state = require "src.game.state"

local DetailsPanel = class("DetailsPanel")

function DetailsPanel:initialize(y)
	self.font = love.graphics.newFont("asset/font/Norse.otf", 16)
	self.fontBold = love.graphics.newFont("asset/font/Norse-Bold.otf", 16)

	self.image = spriteSheet:getSprite("details-panel")

	local screenWidth, _ = screen:getDimensions()
	self.bounds = {
		x = screenWidth - self.image:getWidth(),
		y = y - self.image:getHeight(),
		w = self.image:getWidth(),
		h = self.image:getHeight()
	}

	self.villagerDetails = {
		{ "Name", "getName" },
		{ "Age", "getAge" },
		{ "Food", "getAge" },
		{},
		{ "Occupation", "getOccupationName", true },
		{ "Strength", "getStrength" },
		{ "Craftsmanship", "getCraftsmanship" },
		{ "Sleepiness", "getSleepiness" }
	}
end

function DetailsPanel:draw()
	if not self:isShown() then
		return
	end

	spriteSheet:draw(self.image, self.bounds.x, self.bounds.y)

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

function DetailsPanel:handlePress(x, y)
end

return DetailsPanel
