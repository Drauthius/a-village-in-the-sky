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
local Timer = require "lib.hump.timer"

local Button = require "src.game.gui.button"

local screen = require "src.screen"
local spriteSheet = require "src.game.spritesheet"

local Options = {}

function Options:init()
	self.buttonFont = love.graphics.newFont("asset/font/Norse-Bold.otf", 32)

	self.backButton = Button(0, 0, 0, 0, "details-button", self.buttonFont)
	self.backButton:setText(babel.translate("Back"))
	self.backButton.action = function()
		GameState.pop(self)
	end

	self.buttons = {
		self.backButton
	}
end

function Options:enter(from)
	self.mainMenu = from
	self.font = self.mainMenu.font

	self.mainMenu:leave()
	self.mainMenu:moveRight()

	local dw = screen:getDrawDimensions()
	self.offsetX = dw * -1.1

	self:resize()

	Timer.tween(0.4, self, { offsetX = 0.0 }, "out-sine")
	Timer.tween(0.5, self.mainMenu.imagePosition, { [1] = dw - self.mainMenu.image:getWidth() / 2 }, "out-sine")
end

function Options:leave()
	self.mainMenu:moveBack()

	local dw = screen:getDrawDimensions()
	Timer.tween(0.4, self, { offsetX = dw * -1.1 })

	self.mainMenu = nil
end

function Options:update(dt)
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

function Options:draw()
	if self.mainMenu then
		self.mainMenu:draw()
	end

	love.graphics.setFont(self.font)
	local text = babel.translate("Options")
	local x, y = unpack(self.textPosition)
	x = x + self.offsetX
	local color = spriteSheet:getWoodPalette().dark
	love.graphics.setColor(color[1], color[2], color[3], self.textAlpha)
	love.graphics.print(text, x, y)
	color = spriteSheet:getWoodPalette().bright
	love.graphics.setColor(color[1], color[2], color[3], self.textAlpha)
	love.graphics.print(text, x - 3, y - 3)

	love.graphics.setColor(1, 1, 1, 1)

	self.backButton:draw(self.offsetX)
end

function Options:keyreleased(key, scancode)
	if key == "escape" then
		GameState.pop()
	end
end

function Options:mousepressed(x, y)
	x, y = screen:getCoordinate(x, y)

	for _,button in ipairs(self.buttons) do
		if button:isWithin(x, y) then
			button:setPressed(true)
			return
		end
	end
end

function Options:mousereleased()
	for _,button in ipairs(self.buttons) do
		if button:isPressed() then
			button:setPressed(false)
			button:action()
			return
		end
	end
end

function Options:resize()
	self.mainMenu:resize()

	local dw, dh = screen:getDrawDimensions()

	local header = babel.translate("Options")
	self.textPosition = { (dw - self.font:getWidth(header)) / 2, dh / 20 }

	self.backButton.x = (dw - self.backButton:getWidth()) / 2
	self.backButton.y = dh / 1.1
end

return Options
