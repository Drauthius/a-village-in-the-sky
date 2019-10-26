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
local ProgressBar = require "src.game.gui.progressbar"

local soundManager = require "src.soundmanager"
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
	self.optionFont = self.mainMenu.buttonFont

	self.mainMenu:leave()
	self.mainMenu:moveRight()

	local dw = screen:getDrawDimensions()
	self.offsetX = dw * -1.1

	self:resize()

	self.sfxBar.value = soundManager:getEffectVolume()
	self.musicBar.value = soundManager:getMusicVolume()

	self.lastSfx = 0.0

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

	if self.lastSfx > 0.0 then
		self.lastSfx = self.lastSfx - dt
	end

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

	love.graphics.setFont(self.optionFont)
	love.graphics.setColor(spriteSheet:getOutlineColor())
	love.graphics.print(self.sfxText.text, self.sfxText.x + self.offsetX, self.sfxText.y)
	love.graphics.print(self.musicText.text, self.musicText.x + self.offsetX, self.musicText.y)

	love.graphics.setColor(1, 1, 1, 1)
	self.sfxBar:draw(self.sfxBar.value, 1.0, self.offsetX)
	self.musicBar:draw(self.musicBar.value, 1.0, self.offsetX)

	self.backButton:draw(self.offsetX)
end

function Options:keyreleased(key, scancode)
	if key == "escape" then
		GameState.pop()
	end
end

function Options:mousepressed(x, y)
	self.dragging = nil

	x, y = screen:getCoordinate(x, y)

	for _,button in ipairs(self.buttons) do
		if button:isWithin(x, y) then
			button:setPressed(true)
			return
		end
	end

	if self.sfxBar:isWithin(x, y) then
		self.dragging = "sfx"
		self:_updateSound(self.sfxBar, x)
	elseif self.musicBar:isWithin(x, y) then
		self.dragging = "music"
		self:_updateSound(self.musicBar, x)
	end
end

function Options:mousemoved(x, y)
	if not self.dragging then
		return
	end

	x = screen:getCoordinate(x, y)

	if self.dragging == "sfx" then
		self:_updateSound(self.sfxBar, x)
	elseif self.dragging == "music" then
		self:_updateSound(self.musicBar, x)
	end
end

function Options:mousereleased(x, y)
	if self.dragging then
		x = screen:getCoordinate(x, y)

		if self.dragging == "sfx" then
			self:_updateSound(self.sfxBar, x)
		elseif self.dragging == "music" then
			self:_updateSound(self.musicBar, x)
		end

		self.dragging = nil
		return
	end

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

	local effectText, musicText = babel.translate("Effects"), babel.translate("Music")

	local w = math.max(self.optionFont:getWidth(effectText), self.optionFont:getWidth(musicText))
	local x = dw / 5 - w
	local y = self.textPosition[2] + (self.backButton.y - self.textPosition[2]) / 2 - self.optionFont:getHeight() * 2.5
	self.sfxText = {
		text = effectText,
		x = x + w - self.optionFont:getWidth(effectText),
		y = y
	}
	self.musicText = {
		text = musicText,
		x = x + w - self.optionFont:getWidth(musicText),
		y = y + self.optionFont:getHeight() * 1.5
	}
	local icon = spriteSheet:getSprite("text-background")
	self.sfxBar = ProgressBar(
		x + w + 10, self.sfxText.y + self.optionFont:getHeight() / 4,
		dw / 2, icon:getHeight() / 2, icon)
	self.musicBar = ProgressBar(
		x + w + 10, self.musicText.y + self.optionFont:getHeight() / 4,
		dw / 2, icon:getHeight() / 2, icon)

	self.sfxBar.value = 0.0
	self.musicBar.value = 0.0
end

function Options:_updateSound(bar, x)
	local oldValue = bar.value
	bar.value = math.min(1.0, math.max(0.0, (x - bar.x) / bar.w))

	if oldValue ~= bar.value then
		if bar == self.sfxBar then
			soundManager:setEffectVolume(bar.value)
			if self.lastSfx <= 0.0 then
				self.lastSfx = soundManager.class.SFX.new_event:getDuration() * 0.9
				soundManager:playEffect("new_event")
			end
		elseif bar == self.musicBar then
			soundManager:setMusicVolume(bar.value)
		end
	end
end

return Options
