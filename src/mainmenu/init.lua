local babel = require "lib.babel"
local GameState = require "lib.hump.gamestate"
local Timer = require "lib.hump.timer"

local Game = require "src.game"
local Options = require "src.mainmenu.options"
local Profiles = require "src.mainmenu.profiles"

local Button = require "src.game.gui.button"
local ScaledSprite = require "src.game.scaledsprite"

local screen = require "src.screen"
local spriteSheet = require "src.game.spritesheet"

local MainMenu = {}

local function _createClouds(variant)
	local particleSystem = love.graphics.newParticleSystem(spriteSheet:getImage(), 1000)
	local sprite = spriteSheet:getSprite("thumbnail-clouds", "cloud-"..variant)

	particleSystem:setQuads(sprite:getQuad())
	local _, _, w,h = sprite:getQuad():getViewport()
	particleSystem:setOffset(w / 2, h / 2)
	particleSystem:setEmitterLifetime(-1)
	particleSystem:setEmissionRate(love.math.random(6,8) / 1000)
	particleSystem:setParticleLifetime(100000)
	particleSystem:setSpeed(love.math.random(20, 30) / -10, 0)
	particleSystem:setSizes(5.0, 3.5)

	local dw, dh = screen:getDrawDimensions()
	particleSystem:setPosition(dw * 1.2, dh / 2)
	particleSystem:setEmissionArea("normal", 0, dh / 3.5)

	return particleSystem
end

function MainMenu:init()
	self.image = ScaledSprite:fromSprite(spriteSheet:getSprite("thumbnail-foreground"), 5)
	self.font = love.graphics.newFont("asset/font/Norse-Bold.otf", 72)
	self.textAlpha = 0.0
	self.buttonFont = love.graphics.newFont("asset/font/Norse-Bold.otf", 32)
	self.authorAlpha = 0.0
	self.authorFont = love.graphics.newFont("asset/font/Norse-Bold.otf", 28)
	self.buttonAlpha = 0.0

	self.offsetX = 0.0
	self.cloudOffset = 0.1
	self.textOffset = 1.0
	self.authorOffset = 3.0
	self.buttonOffset = 1.5

	self.newGameButton = Button(0, 0, 0, 0, "details-button", self.buttonFont)
	self.newGameButton:setText(babel.translate("New Game"))
	self.newGameButton.action = function()
		GameState.switch(Game, self.nextFreeProfile)
	end

	self.resumeButton = Button(0, 0, 0, 0, "details-button", self.buttonFont)
	self.resumeButton:setText(babel.translate("Resume"))
	self.resumeButton.action = function()
		GameState.switch(Game, self.latest)
	end

	self.profilesButton = Button(0, 0, 0, 0, "details-button", self.buttonFont)
	self.profilesButton:setText(babel.translate("Profiles"))
	self.profilesButton.action = function()
		GameState.push(Profiles)
	end

	self.optionsButton = Button(0, 0, 0, 0, "details-button", self.buttonFont)
	self.optionsButton:setText(babel.translate("Options"))
	self.optionsButton.action = function()
		GameState.push(Options)
	end

	self.quitButton = Button(0, 0, 0, 0, "details-button", self.buttonFont)
	self.quitButton:setText(babel.translate("Quit"))
	self.quitButton.action = function()
		love.event.quit()
	end

	self.clouds = {
		_createClouds(1),
		_createClouds(2),
		_createClouds(3),
		_createClouds(4),
		_createClouds(5),
		_createClouds(6),
		_createClouds(7),
		_createClouds(8),
		_createClouds(9)
	}
end

function MainMenu:enter(previous, init)
	self.hasProfiles = false
	self.nextFreeProfile = nil
	for i=1,Profiles.NUM_PROFILES do
		if love.filesystem.getInfo("save"..i, "file") then
			self.hasProfiles = true
		elseif not self.nextFreeProfile then
			self.nextFreeProfile = i
		end
	end
	if self.hasProfiles and love.filesystem.getInfo("latest", "file") then
		local content = love.filesystem.read("latest")
		if tonumber(content) ~= nil and
		   tonumber(content) <= Profiles.NUM_PROFILES and
		   love.filesystem.getInfo("save"..content, "file") then
			self.latest = content
		else
			love.filesystem.remove("latest")
		end
	end

	if init and self.latest then
		return GameState.switch(Game, self.latest)
	end

	self.buttons = {}
	if self.latest then
		table.insert(self.buttons, self.resumeButton)
	else
		table.insert(self.buttons, self.newGameButton)
	end
	if self.hasProfiles then
		table.insert(self.buttons, self.profilesButton)
	end
	table.insert(self.buttons, self.optionsButton)
	table.insert(self.buttons, self.quitButton)

	self:resize()

	love.graphics.setBackgroundColor(0.757, 0.875, 0.969)

	for _=1,10000 do
		self:update(0.5)
	end

	Timer.after(0.5, function()
		Timer.tween(1.5, self, { textAlpha = 1.0 }, "out-quart", function()
			Timer.tween(0.8, self, { buttonAlpha = 1.0 }, "out-quart")
		end)
		Timer.after(0.8, function()
			Timer.tween(1.0, self, { authorAlpha = 1.0 }, "out-quart")
		end)
	end)
end

function MainMenu:resume(oldState)
	self.oldState = oldState

	Timer.after(1.0, function()
		self.oldState = nil
	end)

	self.textAlpha = 1.0
	self.buttonAlpha = 1.0
end

function MainMenu:leave()
	self.oldState = nil
end

function MainMenu:update(dt)
	for _,cloud in ipairs(self.clouds) do
		cloud:update(dt)
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

	Timer.update(dt)
end

function MainMenu:draw()
	for _,cloud in ipairs(self.clouds) do
		love.graphics.draw(cloud, self.cloudPosition[1] + self.offsetX * self.cloudOffset, self.cloudPosition[2])
	end

	spriteSheet:draw(self.image, unpack(self.imagePosition))

	love.graphics.setFont(self.font)
	local x, y = unpack(self.textPosition)
	x = x + self.offsetX * self.textOffset
	local color = spriteSheet:getWoodPalette().dark
	love.graphics.setColor(color[1], color[2], color[3], self.textAlpha)
	love.graphics.print("A Village in the Sky", x, y)
	color = spriteSheet:getWoodPalette().bright
	love.graphics.setColor(color[1], color[2], color[3], self.textAlpha)
	love.graphics.print("A Village in the Sky", x - 3, y - 3)

	love.graphics.setFont(self.authorFont)
	x, y = unpack(self.authorPosition)
	x = x + self.offsetX * self.authorOffset
	color = spriteSheet:getWoodPalette().dark
	love.graphics.setColor(color[1], color[2], color[3], self.authorAlpha)
	love.graphics.print("Created by @Drauthius", x, y)
	color = spriteSheet:getWoodPalette().bright
	love.graphics.setColor(color[1], color[2], color[3], self.authorAlpha)
	love.graphics.print("Created by @Drauthius", x - 1, y - 1)

	for _,button in ipairs(self.buttons) do
		love.graphics.setColor(1, 1, 1, self.buttonAlpha)
		button.text.color[4] = self.buttonAlpha
		button:draw(self.offsetX * self.buttonOffset)
	end

	if self.oldState then
		self.oldState:draw()
	end
end

function MainMenu:keyreleased(key, scancode)
	if key == "escape" then
		love.event.quit()
	end
end

function MainMenu:mousepressed(x, y)
	x, y = screen:getCoordinate(x, y)

	for _,button in ipairs(self.buttons) do
		if button:isWithin(x, y) then
			button:setPressed(true)
			return
		end
	end
end

function MainMenu:mousereleased()
	for _,button in ipairs(self.buttons) do
		if button:isPressed() then
			button:setPressed(false)
			button:action()
			return
		end
	end
end

function MainMenu:resize()
	local dw, dh = screen:getDrawDimensions()

	self.imagePosition = { dw - self.image:getWidth() * 1.5, (dh - self.image:getHeight()) / 2 }
	self.textPosition = { dw / 20, dh / 6 }
	self.authorPosition = { dw - self.authorFont:getWidth("Created by @Drauthius  "),
	                        dh - self.authorFont:getHeight() * 1.25 }
	self.cloudPosition = { 0, 0 }

	local x = dw / 8
	local y = dh / 2.5
	local padding = dh / 10

	for _,button in ipairs(self.buttons) do
		button.x, button.y = x, y
		y = y + padding
	end

	self.originalPositions = {
		image = self.imagePosition[1]
	}
end

function MainMenu:moveLeft()
	Timer.clear()

	local dw = screen:getDrawDimensions()
	Timer.tween(0.5, self, { offsetX = -dw }, "out-sine")
end

function MainMenu:moveRight()
	Timer.clear()

	local dw = screen:getDrawDimensions()
	Timer.tween(0.5, self, { offsetX = dw * 2 }, "out-sine")
end

function MainMenu:moveBack()
	Timer.clear()

	Timer.tween(0.5, self, { offsetX = 0 }, "out-sine")
	Timer.tween(0.5, self.imagePosition, { [1] = self.originalPositions.image }, "out-sine")
end

return MainMenu
