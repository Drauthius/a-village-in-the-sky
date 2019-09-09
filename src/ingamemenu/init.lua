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
local GameState = require "lib.hump.gamestate"

local Button = require "src.game.gui.button"

local screen = require "src.screen"
local spriteSheet = require "src.game.spritesheet"
local soundManager = require "src.soundmanager"

local InGameMenu = {}

function InGameMenu:init()
	self.buttonFont = love.graphics.newFont("asset/font/Norse-Bold.otf", 28)

	local resumeButton = Button(0, 0, 0, 0, "details-button", self.buttonFont)
	resumeButton:setText(babel.translate("Resume"))
	resumeButton.action = function()
		GameState.pop(self)
	end

	local mainMenuButton = Button(0, 0, 0, 0, "details-button", self.buttonFont)
	mainMenuButton:setText(babel.translate("Main menu"))
	mainMenuButton.action = function()
		GameState.pop(self)
		GameState.switch(require("src.mainmenu"))
	end

	local quitButton = Button(0, 0, 0, 0, "details-button", self.buttonFont)
	quitButton:setText(babel.translate("Quit"))
	quitButton.action = function()
		love.event.quit()
	end

	self.buttons = {
		resumeButton,
		mainMenuButton,
		quitButton
	}

	self.panel = {
		x = 0,
		y = 0,
		w = resumeButton:getWidth() * 1.05,
		h = resumeButton:getHeight() * (#self.buttons + 0.25)
	}

	self:resize()
end

function InGameMenu:enter(from)
	self.oldState = from
	soundManager:playEffect("toggleMainMenu")
end

function InGameMenu:leave()
	soundManager:playEffect("toggleMainMenu")
end

function InGameMenu:update(dt)
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

function InGameMenu:draw()
	self.oldState:draw()

	local dw, dh = screen:getDrawDimensions()
	love.graphics.setColor(0.0, 0.0, 0.0, 0.3)
	love.graphics.rectangle("fill", 0, 0, dw, dh)

	love.graphics.setColor(spriteSheet:getWoodPalette().outline)
	love.graphics.rectangle("line", self.panel.x, self.panel.y, self.panel.w, self.panel.h)
	love.graphics.setColor(spriteSheet:getWoodPalette().medium)
	love.graphics.rectangle("fill", self.panel.x, self.panel.y, self.panel.w, self.panel.h)

	love.graphics.setColor(1, 1, 1, 1)
	for _,button in ipairs(self.buttons) do
		button:draw()
	end
end

function InGameMenu:quit()
	self.oldState:quit()
end

function InGameMenu:keyreleased(key, scancode)
	if key == "escape" then
		if scancode == "acback" then -- Android back button
			love.event.quit()
		else
			GameState.pop(self)
		end
	end
end

function InGameMenu:mousepressed(x, y)
	x, y = screen:getCoordinate(x, y)

	for _,button in ipairs(self.buttons) do
		if button:isWithin(x, y) then
			button:setPressed(true)
			return
		end
	end
end

function InGameMenu:mousereleased()
	for _,button in ipairs(self.buttons) do
		if button:isPressed() then
			button:setPressed(false)
			button:action()
			return
		end
	end
end

function InGameMenu:resize()
	if self.oldState then
		self.oldState:resize()
	end

	local dw, dh = screen:getDrawDimensions()

	self.panel.x = (dw - self.panel.w) / 2
	self.panel.y = (dh - self.panel.h) / 2

	local x = self.panel.x + (self.panel.w - self.buttons[1]:getWidth()) / 2
	local padding = (self.panel.h - (self.buttons[1]:getHeight() * #self.buttons)) / (#self.buttons + 1)
	local y = self.panel.y + padding
	for _,button in ipairs(self.buttons) do
		button.x, button.y = x, y
		y = y + padding + button:getHeight()
	end
end

return InGameMenu
