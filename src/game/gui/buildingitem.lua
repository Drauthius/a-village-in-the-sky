local InfoPanelItem = require "src.game.gui.infopanelitem"

local spriteSheet = require "src.game.spritesheet"

local BuildingItem = InfoPanelItem:subclass("BuildingItem")

function BuildingItem:initialize(x, y, h, fontNormal, fontBold, entity)
	InfoPanelItem.initialize(self, x, y, 160, h)

	self.sprite = entity:get("SpriteComponent"):getSprite()
	self.fontNormal = fontNormal
	self.fontBold = fontBold
	self.entity = entity
end

function BuildingItem:drawOverride(offset)
	spriteSheet:draw(self.sprite, self.x + offset + 2, self.y + 2)
end

function BuildingItem:select()
	InfoPanelItem.select(self)

	return self.entity
end

return BuildingItem
