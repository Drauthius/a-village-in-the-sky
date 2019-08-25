local babel = require "lib.babel"
local serpent = require "lib.serpent"
local GameState = require "lib.hump.gamestate"
local Timer = require "lib.hump.timer"

local Game = require "src.game"

local ProfilePanel = require "src.mainmenu.profilepanel"

local Button = require "src.game.gui.button"

local screen = require "src.screen"
local spriteSheet = require "src.game.spritesheet"

local Profiles = {}

Profiles.NUM_PROFILES = 4

function Profiles:init()
	self.buttonFont = love.graphics.newFont("asset/font/Norse-Bold.otf", 32)

	self.backButton = Button(0, 0, 0, 0, "details-button", self.buttonFont)
	self.backButton:setText(babel.translate("Back"))
	self.backButton.action = function()
		GameState.pop(self)
	end

	self.buttons = {
		self.backButton
	}

	self.panels = {
		ProfilePanel(),
		ProfilePanel(),
		ProfilePanel(),
		ProfilePanel()
	}

	for i,panel in ipairs(self.panels) do
		if love.filesystem.getInfo("save"..i, "file") then
			local content, err = love.filesystem.read("save"..i)
			if not content then
				print(err)
			else
				local ok, data = serpent.load(content, { safe = false }) -- Safety has to be turned off to load functions.
				if ok then
					panel:setContent(data.year, data.numVillagers, data.numBuildings)
				else
					print(data)
					panel:setCorrupt()
				end
			end
		else
			panel:setContent()
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

	self.backButton:draw(self.offsetX)
end

function Profiles:keyreleased(key, scancode)
	if key == "escape" then
		GameState.pop(self)
	end
end

function Profiles:mousepressed(x, y)
	x, y = screen:getCoordinate(x, y)

	for _,button in ipairs(self.buttons) do
		if button:isWithin(x, y) then
			button:setPressed(true)
			return
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
end

return Profiles
