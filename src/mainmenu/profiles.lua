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
local serpent = require "lib.serpent"
local GameState = require "lib.hump.gamestate"
local Timer = require "lib.hump.timer"

local Game = require "src.game"

local ProfilePanel = require "src.mainmenu.profilepanel"

local Button = require "src.game.gui.button"

local ScaledSprite = require "src.game.scaledsprite"

local screen = require "src.screen"
local spriteSheet = require "src.game.spritesheet"

local Profiles = {}

Profiles.NUM_PROFILES = 4

function Profiles:init()
	self.buttonFont = love.graphics.newFont("asset/font/Norse-Bold.otf", 32)

	self.backButton = Button(0, 0, 0, 0, "details-button", self.buttonFont)
	self.backButton:setText(babel.translate("Back"))
	self.backButton.action = function()
		self.confirmDeletion = nil
		GameState.pop(self)
	end

	self.confirmDeletion = nil
	self.confirmationFont = love.graphics.newFont("asset/font/Norse-Bold.otf", 48)
	self.confirmationDialogue = ScaledSprite:fromSprite(spriteSheet:getSprite("year-panel"), 4.0)
	self.confirmationPosition = { 0, 0 }

	self.deleteButton = Button(0, 0, 0, 0, "details-button", self.buttonFont)
	self.deleteButton:setText(babel.translate("Delete"))
	self.deleteButton.action = function()
		love.filesystem.remove("save"..self.confirmDeletion)
		self.confirmDeletion = nil
		self:_updateProfiles()
	end

	self.cancelButton = Button(0, 0, 0, 0, "details-button", self.buttonFont)
	self.cancelButton:setText(babel.translate("Cancel"))
	self.cancelButton.action = function()
		self.confirmDeletion = nil
	end

	self.panels = {
		ProfilePanel(),
		ProfilePanel(),
		ProfilePanel(),
		ProfilePanel()
	}

	self.deleteButtons = {
		Button(0, 0, 0, 0, "trashcan", false),
		Button(0, 0, 0, 0, "trashcan", false),
		Button(0, 0, 0, 0, "trashcan", false),
		Button(0, 0, 0, 0, "trashcan", false)
	}
	for i,button in ipairs(self.deleteButtons) do
		button.action = function()
			self.confirmDeletion = i
		end
	end
end

function Profiles:enter(from)
	self.mainMenu = from
	self.font = self.mainMenu.font

	self.mainMenu:leave()
	self.mainMenu:moveLeft()

	local dw = screen:getDrawDimensions()
	self.offsetX = dw * 1.1

	self:resize()

	Timer.tween(0.4, self, { offsetX = 0.0 }, "out-sine")
	Timer.tween(0.5, self.mainMenu.imagePosition, { [1] = dw / 2 - self.mainMenu.image:getWidth() / 2 }, "out-sine")

	self:_updateProfiles()
end

function Profiles:leave()
	self.mainMenu:moveBack()

	local dw = screen:getDrawDimensions()
	Timer.tween(0.4, self, { offsetX = dw * 1.1 })

	self.mainMenu = nil
end

function Profiles:update(dt)
	self.mainMenu:update(dt)

	for _,button in ipairs(self.buttons) do
		if button:isPressed() then
			local x, y = screen:getCoordinate(love.mouse.getPosition())
			if not button:isWithin(x, y) then
				button:setPressed(false)
			end
			return
		end
	end
end

function Profiles:draw()
	if self.mainMenu then
		self.mainMenu:draw()
	end

	love.graphics.setFont(self.font)
	local text = babel.translate("Profiles")
	local x, y = unpack(self.textPosition)
	x = x + self.offsetX
	local color = spriteSheet:getWoodPalette().dark
	love.graphics.setColor(color[1], color[2], color[3], self.textAlpha)
	love.graphics.print(text, x, y)
	color = spriteSheet:getWoodPalette().bright
	love.graphics.setColor(color[1], color[2], color[3], self.textAlpha)
	love.graphics.print(text, x - 3, y - 3)

	love.graphics.setColor(1, 1, 1, 1)

	for _,panel in ipairs(self.panels) do
		panel:draw(self.offsetX)
	end

	for _,button in ipairs(self.buttons) do
		if button ~= self.deleteButton and button ~= self.cancelButton then
			button:draw(self.offsetX)
		end
	end

	if self.confirmDeletion then
		love.graphics.setColor(0, 0, 0, 0.2)
		love.graphics.rectangle("fill", 0, 0, screen:getDrawDimensions())
		love.graphics.setColor(1, 1, 1, 1)

		x, y = unpack(self.confirmationPosition)
		spriteSheet:draw(self.confirmationDialogue, x, y)

		local upper = spriteSheet:getData("year-text")
		local scale = self.confirmationDialogue:getScale()

		text = babel.translate("Are you sure you want to delete profile "..self.confirmDeletion.."?")
		local _, seq = self.confirmationFont:getWrap(text, upper.bounds.w * scale)

		love.graphics.setColor(spriteSheet:getOutlineColor())
		love.graphics.setFont(self.confirmationFont)
		love.graphics.printf(text,
		                     x + upper.bounds.x * scale,
		                     y + upper.bounds.y * scale
		                       + ((upper.bounds.h * scale) - self.confirmationFont:getHeight() * #seq) / 2,
		                     upper.bounds.w * scale,
		                     "center")

		love.graphics.setColor(1, 1, 1, 1)
		self.deleteButton:draw()
		self.cancelButton:draw()
	end
end

function Profiles:keyreleased(key, scancode)
	if key == "escape" then
		if self.confirmDeletion then
			self.confirmDeletion = nil
		else
			GameState.pop(self)
		end
	end
end

function Profiles:mousepressed(x, y)
	x, y = screen:getCoordinate(x, y)

	for _,button in ipairs(self.buttons) do
		local dialogueButton = (button == self.deleteButton or button == self.cancelButton)

		if dialogueButton and self.confirmDeletion or
		   not dialogueButton and not self.confirmDeletion then
			if button:isWithin(x, y) then
				button:setPressed(true)
				return
			end
		end
	end
end

function Profiles:mousereleased(x, y)
	for _,button in ipairs(self.buttons) do
		if button:isPressed() then
			button:setPressed(false)
			button:action()
			return
		end
	end

	if self.confirmDeletion then
		return
	end

	x, y = screen:getCoordinate(x, y)
	for i,panel in ipairs(self.panels) do
		if panel:isWithin(x, y) and not panel:isDisabled() then
			return GameState.switch(Game, tostring(i))
		end
	end
end

function Profiles:resize()
	self.mainMenu:resize()

	local dw, dh = screen:getDrawDimensions()

	local header = babel.translate("Profiles")
	self.textPosition = { (dw - self.font:getWidth(header)) / 2, dh / 20 }
	self.panelPositions = {
		{ (dw / 1.8 - self.panels[1]:getWidth()) / 2, dh / 2 - self.panels[1]:getHeight() * 1.05 },
		{ dw / 2 + (dw / 2.2 - self.panels[1]:getWidth()) / 2, dh / 2 + self.panels[1]:getHeight() * 0.05 }
	}

	self.backButton.x = (dw - self.backButton:getWidth()) / 2
	self.backButton.y = dh - (dh - self.panelPositions[2][2] - self.panels[1]:getHeight() + self.backButton:getHeight())/2

	self.panels[1]:setPosition(self.panelPositions[1][1], self.panelPositions[1][2])
	self.panels[2]:setPosition(self.panelPositions[2][1], self.panelPositions[1][2])
	self.panels[3]:setPosition(self.panelPositions[1][1], self.panelPositions[2][2])
	self.panels[4]:setPosition(self.panelPositions[2][1], self.panelPositions[2][2])

	for i,button in ipairs(self.deleteButtons) do
		local x, y = self.panels[i]:getPosition()
		if i == 1 or i == 3 then
			x = x - button:getWidth() + 1
		else
			x = x + self.panels[i]:getWidth() - 1
		end
		if i == 3 or i == 4 then
			y = y + self.panels[i]:getHeight() - button:getHeight() - 1
		else
			y = y + 1
		end

		button.x, button.y = x, y
	end

	self.confirmationPosition = {
		(dw - self.confirmationDialogue:getWidth()) / 2,
		(dh - self.confirmationDialogue:getHeight()) / 2
	}

	local lower = spriteSheet:getData("year-number")
	local scale = self.confirmationDialogue:getScale()

	local x, y = unpack(self.confirmationPosition)
	self.cancelButton.x = x + lower.bounds.x * scale
	self.cancelButton.y = y + (lower.bounds.y + lower.bounds.h) * scale - self.cancelButton:getHeight()

	self.deleteButton.x = x + (lower.bounds.x + lower.bounds.w) * scale - self.deleteButton:getWidth()
	self.deleteButton.y = y + (lower.bounds.y + lower.bounds.h) * scale - self.deleteButton:getHeight()
end

function Profiles:_updateProfiles()
	self.buttons = {
		self.backButton,
		self.deleteButton,
		self.cancelButton
	}

	for i,panel in ipairs(self.panels) do
		if love.filesystem.getInfo("save"..i, "file") then
			local content, err = love.filesystem.read("save"..i)
			if not content then
				print(err)
				panel:setCorrupt()
			else
				local ok, data = serpent.load(content, { safe = false }) -- Safety has to be turned off to load functions.
				if ok then
					panel:setContent(data.year, data.numVillagers, data.numTiles, data.numBuildings)
				else
					print(data)
					panel:setCorrupt()
				end
			end

			table.insert(self.buttons, self.deleteButtons[i])
		else
			panel:setContent()
		end
	end

end

return Profiles
