local class = require "lib.middleclass"
local Timer = require "lib.hump.timer"

local Button = require "src.game.gui.button"

local screen = require "src.screen"
local spriteSheet = require "src.game.spritesheet"

local InfoPanel = class("InfoPanel")

InfoPanel.static.panelWidth = 32
InfoPanel.static.scrollTime = 0.005 -- Pixels per second
InfoPanel.static.scrollMove = 75
InfoPanel.static.scrollEase = "in-out-sine"

function InfoPanel:initialize(width)
	self.hidden = false
	self.minimized = false
	self.content = {}
	self.spriteBatch = love.graphics.newSpriteBatch(spriteSheet:getImage(), 16, "static")

	local centre = spriteSheet:getSprite("info-panel-centre")
	self.spriteBatch:add(centre:getQuad())

	self.bounds = {
		x = 0, y = 0, w = centre:getWidth(), h = centre:getHeight()
	}

	local panel = 0
	for x=InfoPanel.panelWidth,(width - centre:getWidth()) / 2,InfoPanel.panelWidth do
		if x + InfoPanel.panelWidth > (width - centre:getWidth()) / 2 then
			panel = "left (Up)"
		else
			panel = panel > 6 and 1 or panel + 1
		end

		local sprite = spriteSheet:getSprite("info-panel-"..panel)

		if panel ~= "left (Up)" then -- The left/right buttons are handled elsewhere.
			-- Place to the left
			self.spriteBatch:add(assert(sprite:getQuad(), "No quad for info-panel-"..tostring(panel)), -x)
			-- Place to the right
			self.spriteBatch:add(sprite:getQuad(),
				centre:getWidth() + x - InfoPanel.panelWidth)
		end

		self.bounds.x = self.bounds.x - sprite:getWidth()
		self.bounds.w = self.bounds.w + sprite:getWidth() * 2
	end

	local screenWidth, screenHeight = screen:getDimensions()
	self.x, self.y = (screenWidth - centre:getWidth() ) / 2, screenHeight - centre:getHeight()

	self.bounds.x = self.x + self.bounds.x
	self.bounds.y = self.y
	self.oldY = self.y
	self.ox = 0

	self.barHeight = 23
	self.contentBounds = {
		x = self.bounds.x + InfoPanel.panelWidth,
		y = self.bounds.y + self.barHeight,
		w = self.bounds.w - InfoPanel.panelWidth * 2,
		h = self.bounds.h - self.barHeight
	}

	do -- Buttons
		self.leftButton = Button(self.bounds.x, self.bounds.y, 0, 0, "info-panel-left", false)
		self.leftButton:setAction(function()
			local limit = 0
			local target = math.min(limit, self.ox + InfoPanel.scrollMove)
			Timer.tween(InfoPanel.scrollTime * math.abs(target - self.ox), self, {ox = target}, InfoPanel.scrollEase, function()
				if math.floor(self.ox) <= limit then
					self.ox = limit
					self.leftButton:setDisabled(true)
					self.leftButton:setPressed(true)
				end
				self.rightButton:setDisabled(false)
				self.rightButton:setPressed(false)
			end)
		end)

		self.rightButton = Button(self.bounds.x + self.bounds.w, self.bounds.y, 0, 0, "info-panel-left", false)
		self.rightButton:setScale(-1, 1) -- Flip
		self.rightButton:setAction(function()
			local limit = self.contentBounds.w - self.contentBounds.length
			local target = math.max(limit, self.ox - InfoPanel.scrollMove)
			Timer.tween(InfoPanel.scrollTime * math.abs(target - self.ox), self, {ox = target}, InfoPanel.scrollEase, function()
				if math.ceil(self.ox) >= limit then
					self.ox = limit
					self.rightButton:setDisabled(true)
					self.rightButton:setPressed(true)
				end
				self.leftButton:setDisabled(false)
				self.leftButton:setPressed(false)
			end)
		end)

		local closeButton = spriteSheet:getSprite("close-button (Up)")
		local buttonX = (self.bounds.w + centre:getWidth()) / 2 - closeButton:getWidth() - 1
		local buttonY = 1
		self.closeButton = Button(self.x + buttonX, self.y + buttonY, 0, 0, "close-button", false)
		self.closeButton:setAction(function()
			self:hide()
		end)

		local minimizeButton = spriteSheet:getSprite("minimize-button (Up)")
		buttonX = buttonX - minimizeButton:getWidth()
		self.minimizeButton = Button(self.x + buttonX, self.y + buttonY, 0, 0, "minimize-button", false)
		self.minimizeButton:setAction(function()
			self:minimize(not self.minimized)
		end)

		-- Prioritize the close/minimize button for interaction.
		self.buttons = {
			self.closeButton, self.minimizeButton, self.leftButton, self.rightButton
		}
	end

	self.textBackgroundLeft = spriteSheet:getSprite("text-background-left")
	self.textBackgroundCentre = spriteSheet:getSprite("text-background-centre")
	self.font = love.graphics.newFont("asset/font/Norse.otf", self.barHeight - 2)
end

function InfoPanel:update(dt)
	if not self:isShown() then
		return
	end

	for _,button in ipairs(self.buttons) do
		-- FIXME: DRY (Same in detailspanel)
		if button:isPressed() and
		   not button:isDisabled() and
		   not button:isWithin(screen:getCoordinate(love.mouse.getPosition())) then
			button:setPressed(false)
		end
	end
end

function InfoPanel:draw()
	if self.hidden then
		return
	end

	love.graphics.stencil(function()
		love.graphics.setColorMask()
		love.graphics.draw(self.spriteBatch, self.x, self.y)
	end)

	if not self.minimized then
		love.graphics.setStencilTest("greater", 0)

		for i,item in ipairs(self.content.items) do
			spriteSheet:draw(item.sprite,
					item.bounds.x + self.content.margin + self.ox,
					item.bounds.y + (item.bounds.h - item.sprite:getHeight()) / 2)
			if self.content.overlay then
				self.content.overlay(item, self.ox)
			end
			if self.content.selected == i then
				local thickness = 3
				love.graphics.setLineWidth(thickness)
				love.graphics.setColor(1, 0.5, 0)
				love.graphics.rectangle("line",
						item.bounds.x + self.ox,
						item.bounds.y,
						item.bounds.w - thickness, item.bounds.h - thickness)
				love.graphics.setColor(1, 1, 1)
			end
		end

		love.graphics.setStencilTest()
	end

	self.leftButton:draw()
	self.rightButton:draw()

	-- Draw a shadow "behind" the left/right buttons.
	love.graphics.setColor(0, 0, 0, 0.25)
	local shadowWidth = 2
	love.graphics.rectangle("fill",
		self.leftButton.x + self.leftButton.w - 1,
		self.leftButton.y + self.barHeight - 2,
		shadowWidth, self.leftButton.h)
	love.graphics.rectangle("fill",
		self.rightButton.x - self.rightButton.w + 1 - shadowWidth,
		self.rightButton.y + self.barHeight - 2,
		shadowWidth, self.rightButton.h)
	love.graphics.setColor(1, 1, 1, 1)

	local x, y = self.bounds.x + 1, self.bounds.y + 1
	spriteSheet:draw(self.textBackgroundLeft, x, y)
	x = x + self.textBackgroundLeft:getWidth()
	love.graphics.draw(spriteSheet:getImage(), self.textBackgroundCentre:getQuad(), x, y,
		0, self.font:getWidth(self.content.name) * 0.8, 1) -- XXX: ???
	x = x + self.font:getWidth(self.content.name) * 0.8 + 4 -- XXX: ???
	love.graphics.draw(spriteSheet:getImage(), self.textBackgroundLeft:getQuad(), x, y,
		0, -1, 1)

	--spriteSheet:draw(self.textBackgroundLeft, self.bounds.x + 1, self.bounds.y + 1)
	--love.graphics.setColor(0, 0, 0)
	-- XXX: True pixel font won't have this problem.
	love.graphics.setColor(require("src.game.rendersystem").NEW_OUTLINE_COLOR)
	love.graphics.print(self.content.name,
		self.bounds.x + 5, self.y + math.ceil((self.barHeight - self.font:getHeight()) / 2) + 3)
	love.graphics.setColor(1, 1, 1)

	self.closeButton:draw()
	self.minimizeButton:draw()

	-- Show the bound
	--love.graphics.setLineWidth(4)
	--love.graphics.setColor(1, 0, 0)
	--love.graphics.rectangle("line", self.bounds.x, self.bounds.y, self.bounds.w, self.bounds.h)
	--love.graphics.setColor(1, 1, 1)
	--love.graphics.setColor(0, 1, 0)
	--love.graphics.rectangle("line", self.contentBounds.x, self.contentBounds.y,
	--		self.contentBounds.w, self.contentBounds.h)
	--love.graphics.setColor(1, 1, 1)
end

function InfoPanel:setContent(content)
	self.content = content
	local margin = self.content.margin or 0
	local nextX = self.contentBounds.x
	for _,item in ipairs(self.content.items) do
		item.bounds = {
			x = nextX,
			y = self.contentBounds.y,
			w = item.sprite:getWidth() + 2 * margin,
			h = self.contentBounds.h
		}
		nextX = nextX + item.bounds.w + margin
	end
	self.contentBounds.length = nextX - self.contentBounds.x

	self.leftButton:setDisabled(true)
	self.leftButton:setPressed(true)

	if self.contentBounds.length < self.contentBounds.w then
		self.rightButton:setDisabled(true)
		self.rightButton:setPressed(true)
	else
		self.rightButton:setDisabled(false)
		self.rightButton:setPressed(false)
	end
end

function InfoPanel:show()
	self.hidden = false
	self:minimize(false)
	self.ox = 0
end

function InfoPanel:hide()
	self.hidden = true
end

function InfoPanel:isShown()
	return not self.hidden
end

function InfoPanel:minimize(min)
	self.minimized = min
	if self.minimized then
		self.y = select(2, screen:getDimensions()) - self.barHeight + 5

		for _,button in ipairs(self.buttons) do
			if not button.oldY then
				button.oldY = button.y
			end
			button.y = button.oldY + (self.y - self.oldY)
		end

		self.leftButton:setDisabled(true)
		self.rightButton:setDisabled(true)
	else
		self.y = self.oldY

		for _,button in ipairs(self.buttons) do
			if not button.oldY then
				button.oldY = button.y
			end
			button.y = button.oldY
		end

		self.leftButton:setDisabled(false)
		self.rightButton:setDisabled(false)
	end

	self.bounds.y = self.y
end

function InfoPanel:isWithin(x, y)
	return x >= self.bounds.x and
		   y >= self.bounds.y and
		   x <= self.bounds.x + self.bounds.w and
		   y <= self.bounds.y + self.bounds.h
end

function InfoPanel:handlePress(x, y, released)
	for _,button in ipairs(self.buttons) do
		if button:isWithin(x, y) and not button:isDisabled() then
			if released and button:isPressed() then
				button:getAction()()
			end
			button:setPressed(not released)
			return
		end
	end

	if released and not self.minimized then
		for _,item in ipairs(self.content.items) do
			if x >= item.bounds.x + self.ox and y >= item.bounds.y and
			   x <= item.bounds.x + item.bounds.w + self.ox and y <= item.bounds.y + item.bounds.h then
				item:onPress()
				return
		   end
		end
	end
end

return InfoPanel
