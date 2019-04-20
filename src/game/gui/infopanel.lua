local class = require "lib.middleclass"

local screen = require "src.screen"
local spriteSheet = require "src.game.spritesheet"

local InfoPanel = class("InfoPanel")

InfoPanel.static.panelWidth = 32

function InfoPanel:initialize(width)
	self.hidden = false
	self.content = {}
	self.spriteBatch = love.graphics.newSpriteBatch(spriteSheet:getImage(), 16, "static")

	local centre = spriteSheet:getSprite("info-panel-centre")
	self.spriteBatch:add(centre:getQuad())

	self.bounds = {
		x = 0, y = 0, w = centre:getWidth(), h = centre:getHeight()
	}

	local panel = 0
	for x=InfoPanel.panelWidth,(width - centre:getWidth()) / 2,InfoPanel.panelWidth do
		local flipRight = false
		if x + InfoPanel.panelWidth > (width - centre:getWidth()) / 2 then
			panel = "left"
			flipRight = true
		else
			panel = panel > 6 and 1 or panel + 1
		end

		local sprite = spriteSheet:getSprite("info-panel-"..panel)

		self.spriteBatch:add(assert(sprite:getQuad(), "No quad for info-panel-"..tostring(panel)), -x)
		if flipRight then
			self.spriteBatch:add(sprite:getQuad(),
				centre:getWidth() + x,
				0, 0, -1, 1)
		else
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

	local barHeight = 16
	self.contentBounds = {
		x = self.bounds.x + InfoPanel.panelWidth,
		y = self.bounds.y + barHeight,
		w = self.bounds.w - InfoPanel.panelWidth * 2,
		h = self.bounds.h - barHeight
	}
end

function InfoPanel:draw()
	if self.hidden then
		return
	end

	love.graphics.draw(self.spriteBatch, self.x, self.y)

	--local start = self.contentBounds.x
	--for _,widget in ipairs(self.content.items) do
	--	spriteSheet:draw(widget,
	--			start + self.content.margin,
	--			self.contentBounds.y + (self.contentBounds.h - widget:getHeight()) / 2)
	--	start = start + widget:getWidth() + self.content.margin * 2
	--end

	for i,item in ipairs(self.content.items) do
		spriteSheet:draw(item,
				item.bounds.x + self.content.margin,
				item.bounds.y + (item.bounds.h - item:getHeight()) / 2)
		if self.content.selected == i then
			local thickness = 3
			love.graphics.setLineWidth(thickness)
			love.graphics.setColor(1, 0.5, 0)
			love.graphics.rectangle("line",
					item.bounds.x, item.bounds.y,
					item.bounds.w - thickness, item.bounds.h - thickness)
			love.graphics.setColor(1, 1, 1)
		end
	end

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
			w = item:getWidth() + 2 * margin,
			h = self.contentBounds.h
		}
		nextX = nextX + item.bounds.w + margin
	end
end

function InfoPanel:show()
	self.hidden = false
end

function InfoPanel:hide()
	self.hidden = true
end

function InfoPanel:isShown()
	return not self.hidden
end

function InfoPanel:isWithin(x, y)
	return x >= self.bounds.x and
		   y >= self.bounds.y and
		   x <= self.bounds.x + self.bounds.w and
		   y <= self.bounds.y + self.bounds.h
end

function InfoPanel:handlePress(x, y)
	for _,item in ipairs(self.content.items) do
		if x >= item.bounds.x and y >= item.bounds.y and
		   x <= item.bounds.x + item.bounds.w and y <= item.bounds.y + item.bounds.h then
			item:onPress()
			return
	   end
	end
end

return InfoPanel
