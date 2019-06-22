local babel = require "lib.babel"

local InfoPanelItem = require "src.game.gui.infopanelitem"

local BuildingComponent = require "src.game.buildingcomponent"
local ConstructionComponent = require "src.game.constructioncomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local TileComponent = require "src.game.tilecomponent"

local spriteSheet = require "src.game.spritesheet"

local BuildItem = InfoPanelItem:subclass("BuildItem")

function BuildItem:initialize(x, y, w, h, sprite, font, type, isBuilding, blueprint)
	InfoPanelItem.initialize(self, x, y, w, h)
	self.sprite = sprite
	self.type = type
	self.font = font
	self.isBuilding = isBuilding
	self.blueprint = blueprint

	-- Align the sprite in the centre.
	local dx = (self.w - sprite:getWidth()) / 2
	self.x = self.x + dx
	self.ox = self.ox - dx
	self.w = self.w - dx
	local dy = (self.h - sprite:getHeight()) / 2
	self.y = self.y + dy
	self.oy = self.oy - dy
	self.h = self.h - dy
end

function BuildItem:draw(offset)
	InfoPanelItem.draw(self, offset)
end

function BuildItem:drawOverlay(offset)
	local name
	if self.isBuilding then
		name = BuildingComponent.BUILDING_NAME[self.type]
	else
		name = TileComponent.TILE_NAME[self.type]
	end
	name = babel.translate(name)

	-- Some common set up
	love.graphics.setFont(self.font)
	love.graphics.setLineWidth(1)
	love.graphics.setLineStyle("rough")

	local sx, sy = self.x + self.ox + offset + 5, self.y + self.oy + 5
	local w, h = self.font:getWidth(name) + 1, self.font:getHeight() + 1

	-- Background for the label
	local color = spriteSheet:getWoodPalette().bright
	love.graphics.setColor(color[1], color[2], color[3], 0.5)
	love.graphics.rectangle("fill", sx, sy, w, h)
	love.graphics.setColor(spriteSheet:getWoodPalette().outline)
	love.graphics.rectangle("line", sx, sy, w + 1, h + 1)

	-- Print the label
	love.graphics.setColor(spriteSheet:getOutlineColor())
	love.graphics.print(name, sx, sy)

	if self.isBuilding then
		local materials = ConstructionComponent.MATERIALS[self.type]

		-- First pass to get the proper dimensions
		w, h = 0, 0
		for resource,amount in pairs(materials) do
			if amount > 0 then
				local icon = spriteSheet:getSprite("headers", ResourceComponent.RESOURCE_NAME[resource] .. "-icon")
				w = math.max(w, self.font:getWidth(amount.."x") + 1 + icon:getWidth()) + 1
				h = h + math.max(self.font:getHeight() + 1, icon:getHeight()) + 1
			end
		end

		sx, sy = self.x + self.w - w + offset - 5, self.y + self.oy + 5

		-- Background for the material cost
		love.graphics.setColor(color[1], color[2], color[3], 0.5)
		love.graphics.rectangle("fill", sx, sy, w, h)
		love.graphics.setColor(spriteSheet:getWoodPalette().outline)
		love.graphics.rectangle("line", sx, sy, w + 1, h + 1)

		local oy = 2
		for resource,amount in pairs(materials) do
			if amount > 0 then
				local icon = spriteSheet:getSprite("headers", ResourceComponent.RESOURCE_NAME[resource] .. "-icon")

				love.graphics.setColor(1, 1, 1, 1)
				spriteSheet:draw(icon, sx + w - icon:getWidth(), sy + oy + 1)

				love.graphics.setColor(spriteSheet:getOutlineColor())
				love.graphics.printf(amount.."x", sx + 1, sy + oy, w - icon:getWidth() - 2, "right")

				oy = oy + math.max(self.font:getHeight() + 1, icon:getHeight()) + 1
			end
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
end

function BuildItem:getType()
	return self.type
end

function BuildItem:select()
	InfoPanelItem.select(self)

	return self:blueprint()
end

return BuildItem
