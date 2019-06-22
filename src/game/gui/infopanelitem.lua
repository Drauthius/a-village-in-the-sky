local Widget = require "src.game.gui.widget"

local spriteSheet = require "src.game.spritesheet"

local InfoPanelItem = Widget:subclass("InfoPanelItem")

function InfoPanelItem:initialize(x, y, w, h)
	self.x, self.y = x, y
	self.w, self.h = w, h
	self.ox, self.oy = 0, 0
	self.sprite = nil
	self.selected = false
end

function InfoPanelItem:draw(offset)
	offset = offset or 0

	-- Background
	local color = spriteSheet:getWoodPalette().medium
	love.graphics.setColor(color[1], color[2], color[3], 0.6)
	love.graphics.rectangle("fill",
		self.x + self.ox + offset,
		self.y + self.oy,
		self.w - self.ox,
		self.h - self.oy)

	love.graphics.setColor(1, 1, 1, 1)

	-- Actual content
	if self.drawOverride then
		self:drawOverride(offset)
	elseif self.sprite then
		self.x = self.x + offset -- Hack :)
		Widget.draw(self)
		self.x = self.x - offset
	end

	-- Content overlay
	if self.drawOverlay then
		self:drawOverlay(offset)
	end

	-- Outline
	if self.selected then
		local thickness = 3
		love.graphics.setLineWidth(thickness)
		love.graphics.setColor(1, 0.5, 0)
		love.graphics.rectangle("line",
				self.x + self.ox + offset - 1,
				self.y + self.oy,
				self.w - self.ox + 2,
				self.h - self.oy - 2)
		love.graphics.setColor(1, 1, 1)
	else
		love.graphics.setLineWidth(1)
		love.graphics.setColor(spriteSheet:getWoodPalette().outline)
		love.graphics.rectangle("line",
				self.x + self.ox + offset - 2,
				self.y + self.oy - 2,
				self.w - self.ox + 4,
				self.h - self.oy + 2)
		love.graphics.setColor(1, 1, 1)

		local thickness = 3
		love.graphics.setLineWidth(thickness)

		local topLeft = { self.x + self.ox + offset, self.y + self.oy }
		local topRight = { topLeft[1] + self.w - self.ox, topLeft[2] }
		local bottomRight = { topRight[1], topRight[2] + self.h - self.oy - thickness }
		local bottomLeft = { topLeft[1], bottomRight[2] }

		love.graphics.setColor(spriteSheet:getWoodPalette().bright)
		love.graphics.line(
			bottomLeft[1], bottomLeft[2],
			topLeft[1], topLeft[2],
			topRight[1], topRight[2])
		love.graphics.setColor(spriteSheet:getWoodPalette().dark)
		love.graphics.line(
			topRight[1], topRight[2],
			bottomRight[1], bottomRight[2],
			bottomLeft[1], bottomLeft[2])
		love.graphics.setColor(1, 1, 1)

	end
end

function InfoPanelItem:select()
	self.selected = true
end

function InfoPanelItem:unselect()
	self.selected = false
end

return InfoPanelItem
