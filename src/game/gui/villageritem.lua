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

local InfoPanelItem = require "src.game.gui.infopanelitem"

local ScaledSprite = require "src.game.scaledsprite"
local WorkComponent = require "src.game.workcomponent"
local ProgressBar = require "src.game.gui.progressbar"

local spriteSheet = require "src.game.spritesheet"

local VillagerItem = InfoPanelItem:subclass("VillagerItem")

VillagerItem.static.DETAILS = {
	{ "Name", "getName" },
	{ "Age", "getAge" },
	{ "Hunger", "getHunger" },
	{ "Sleepiness", "getSleepiness" },
	{},
	{ "Occupation", "getOccupationName", true },
	{ "Strength", "getStrength" },
	{ "Craftsmanship", "getCraftsmanship" }
}

function VillagerItem:initialize(x, y, h, fontNormal, fontBold, entity)
	InfoPanelItem.initialize(self, x, y, 160, h)

	local sprite
	if entity:has("AdultComponent") then
		local hairy = entity:get("VillagerComponent"):isHairy() and "(Hairy) " or ""
		sprite = spriteSheet:getSprite("villagers "..hairy.."0",
			entity:get("VillagerComponent"):getGender() .. " - S")
	else
		sprite = spriteSheet:getSprite("children 0",
			(entity:get("VillagerComponent"):getGender() == "male" and "boy" or "girl") .. " - S")
	end

	self.sprite = ScaledSprite:fromSprite(sprite, 4)
	self.fontNormal = fontNormal
	self.fontBold = fontBold
	self.entity = entity

	self.strengthBar = ProgressBar(0, 0, 100, 10, spriteSheet:getSprite("headers", "strength-icon"))
	self.craftsmanshipBar = ProgressBar(0, 0, 100, 10, spriteSheet:getSprite("headers", "craftsmanship-icon"))
	self:setPosition(self.x, self.y)
end

function VillagerItem:drawOverride(offset)
	local colorSwap = self.entity:get("ColorSwapComponent")
	local oldColors = colorSwap:getReplacedColors()
	local newColors = colorSwap:getReplacingColors()
	local shader = love.graphics.getShader()

	local RenderSystem = require "src.game.rendersystem"

	-- Draw image of villager
	-- FIXME: Maybe DRY it up?
	shader:send("oldColor", RenderSystem.OLD_OUTLINE_COLOR, unpack(oldColors))
	shader:send("numColorReplaces", #newColors + 1)
	shader:send("newColor", RenderSystem.NEW_OUTLINE_COLOR, unpack(newColors or {}))
	shader:send("noShadow", true)

	spriteSheet:draw(self.sprite, self.x + offset + 2, self.y + 2)

	shader:send("numColorReplaces", 1)
	shader:send("noShadow", false)

	-- Draw text
	local sx, sy = self.x + offset, self.y + 5
	local oy = 2
	-- FIXME: Maybe DRY it up?
	local villager = self.entity:get("VillagerComponent")
	local adult = self.entity:has("AdultComponent") and self.entity:get("AdultComponent")
	for _,details in ipairs(VillagerItem.DETAILS) do
		local key, value, adultComp = details[1], details[2], details[3]
		if key == "Hunger" or key == "Sleepiness" then
			-- TODO: Experimental
			local icon = key == "Sleepiness" and spriteSheet:getSprite("headers", "sleepy-icon") or
			                                     spriteSheet:getSprite("headers", "hungry-icon")
			local w = 100
			local dh = -6
			value = villager[value](villager)
			local limit = math.floor(w * value)

			local bx = sx + self.w - w - 4
			local by = sy + oy - dh / 2

			-- Draw the bar background
			local background = spriteSheet:getWoodPalette().dark
			love.graphics.setColor(background[1], background[2], background[3], 0.5)
			love.graphics.rectangle("fill", bx, by, w, icon:getHeight() + dh)

			-- Draw the bar "progress"
			love.graphics.setColor(value, 1 - value, 0, 1)
			love.graphics.rectangle("fill", bx, by, limit, icon:getHeight() + dh)

			-- Draw the bar outline
			love.graphics.setColor(spriteSheet:getWoodPalette().outline)
			love.graphics.setLineWidth(1)
			love.graphics.setLineStyle("rough")
			love.graphics.rectangle("line", bx, by, w + 1, icon:getHeight() + dh + 1)

			-- Draw the icon
			love.graphics.setColor(1, 1, 1, 1)
			spriteSheet:draw(icon, math.min(sx + self.w - icon:getWidth(), bx + limit - icon:getWidth() / 2), sy + oy)

			oy = oy + icon:getHeight() + 1
		elseif not key then
			if not adult then
				break
			end
		elseif key == "Occupation" then
			local icon = ScaledSprite:fromSprite(spriteSheet:getSprite("headers", adult:getOccupationName() .. "-icon"), 2)
			spriteSheet:draw(icon, self.x + (self.sprite:getWidth() - icon:getWidth()) / 2 + offset + 2,
			                 self.y + self.sprite:getHeight() + 4)
		elseif key == "Strength" then
			self.strengthBar:draw(villager[value](villager), 1.0, offset, oy + 4)
			oy = oy + self.strengthBar.icon:getHeight() + 1
		elseif key == "Craftsmanship" then
			self.craftsmanshipBar:draw(villager[value](villager), 1.0, offset, oy + 4)
			oy = oy + self.craftsmanshipBar.icon:getHeight() + 1
		else
			key = babel.translate(key) .. ":"
			if adultComp then
				value = adult[value](adult)
			else
				value = villager[value](villager)
			end
			if type(value) == "number" then
				value = string.format("%.1f", value)
			end

			love.graphics.setColor(spriteSheet:getOutlineColor())

			local w = self.fontNormal:getWidth(value) + 2
			love.graphics.setFont(self.fontNormal)
			love.graphics.print(value, sx + self.w - w, sy + oy)

			love.graphics.setFont(self.fontBold)
			love.graphics.printf(key, sx, sy + oy, self.w - w - 1, "right")

			oy = oy + self.fontBold:getHeight() + 1
		end
	end
	love.graphics.setColor(1, 1, 1, 1)

	local icons = {}
	-- TODO: Some duplications from the RenderSystem:_drawHeader()
	-- Homeless icon.
	if not villager:getHome() then
		table.insert(icons, (spriteSheet:getSprite("headers", "no-home-icon")))
	end
	if villager:getSleepiness() > require("src.game.villagersystem").SLEEP.SLEEPINESS_THRESHOLD then -- XXX
		table.insert(icons, (spriteSheet:getSprite("headers", "sleepy-icon")))
	end
	if villager:getStarvation() > 0.0 then
		table.insert(icons, (spriteSheet:getSprite("headers", "hungry-icon")))
	end
	-- Out-of-resources icon
	if villager:getHome() and adult and not adult:getWorkArea() then
		local occupation = adult:getOccupation()
		if occupation == WorkComponent.WOODCUTTER then
			table.insert(icons, (spriteSheet:getSprite("headers", "missing-woodcutter-icon")))
		elseif occupation == WorkComponent.MINER then
			table.insert(icons, (spriteSheet:getSprite("headers", "missing-miner-icon")))
		end
	end
	-- Living with parents
	if villager:getHome() and adult and not villager:getHome():get("AssignmentComponent"):isAssigned(self.entity) then
		table.insert(icons, (spriteSheet:getSprite("headers", "living-with-parents-icon")))
	end
	-- Infertility
	if adult and not self.entity:has("FertilityComponent") then
		table.insert(icons, (spriteSheet:getSprite("headers", "infertility-icon")))
	end

	-- Scale up
	for k,icon in ipairs(icons) do
		icons[k] = ScaledSprite:fromSprite(icon, 2)
	end

	local numIcons = #icons
	if numIcons > 0 then
		local margin = -1
		-- Assumes that each icon has the same width.
		local iconWidth = numIcons * icons[1]:getWidth() + margin * (numIcons - 1)
		sx = self.x + (self.w - iconWidth) / 2
		sy = self.y + self.h - icons[1]:getHeight() - 2
		for _,icon in ipairs(icons) do
			spriteSheet:draw(icon, sx + offset, sy)
			sx = sx + icon:getWidth() + margin
		end
	end
end

function VillagerItem:setPosition(x, y)
	InfoPanelItem.setPosition(self, x, y)

	self.strengthBar.x = self.x + self.w - self.strengthBar.w - 4
	self.strengthBar.y = self.y
	self.craftsmanshipBar.x = self.x + self.w - self.craftsmanshipBar.w - 4
	self.craftsmanshipBar.y = self.y
end

function VillagerItem:select()
	InfoPanelItem.select(self)

	return self:getEntity()
end

function VillagerItem:getEntity()
	return self.entity
end

function VillagerItem:getType()
	if self.entity:has("AdultComponent") then
		return "Adult"
	else
		return "Child"
	end
end

return VillagerItem
