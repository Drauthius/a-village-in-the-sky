local babel = require "lib.babel"
local table = require "lib.table"

local Widget = require "src.game.gui.widget"

local ScaledSprite = require "src.game.scaledsprite"

local spriteSheet = require "src.game.spritesheet"

local ProfilePanel = Widget:subclass("ProfilePanel")

ProfilePanel.static.YEAR_FONT = love.graphics.newFont("asset/font/Norse-Bold.otf", 50)
ProfilePanel.static.STAT_FONT = love.graphics.newFont("asset/font/Norse.otf", 40)

function ProfilePanel:initialize()
	self.scale = 2.0
	Widget.initialize(self, 0, 0, 0, 0, ScaledSprite:fromSprite(spriteSheet:getSprite("year-panel"), self.scale))

	local data = spriteSheet:getData("year-text")
	self:addText("", ProfilePanel.YEAR_FONT, spriteSheet:getOutlineColor(),
	             data.bounds.x * self.scale, data.bounds.y * self.scale, data.bounds.w * self.scale, "center")

	self.stats = table.clone(spriteSheet:getData("year-number"), true)
	for k,v in pairs(self.stats.bounds) do
		self.stats.bounds[k] = v * self.scale
	end
end

function ProfilePanel:setContent(year, numVillagers, numTiles, numBuildings)
	if year and numVillagers and numBuildings then
		self.hasContent = true
		self:setText(babel.translate("Year %year%", { year = year }))
		self.numVillagers = numVillagers
		self.numTiles = numTiles
		self.numBuildings = numBuildings
	else
		self.hasContent = false
		self:setText(babel.translate("New game"))
	end
	self.corrupt = false
	self.disabled = false
end

function ProfilePanel:setCorrupt()
	self.hasContent = false
	self.corrupt = true
	self.disabled = true
	self:setText("Corrupted!")
end

function ProfilePanel:isDisabled()
	return self.disabled == true
end

function ProfilePanel:draw(ox, oy)
	ox, oy = ox or 0, oy or 0
	Widget.draw(self, ox, oy)

	if self.hasContent then
		love.graphics.setFont(ProfilePanel.STAT_FONT)
		love.graphics.setColor(spriteSheet:getOutlineColor())
		local x, y = self.x + self.stats.bounds.x + ox, self.y + self.stats.bounds.y + oy

		local villagerIcon = ProfilePanel.VILLAGER_ICON
		if not villagerIcon then
			villagerIcon = ScaledSprite:fromSprite(spriteSheet:getSprite("headers", "occupied-icon"), 3.0)
			ProfilePanel.static.VILLAGER_ICON = villagerIcon
		end
		local tileIcon = ProfilePanel.TILE_ICON
		if not tileIcon then
			tileIcon = ScaledSprite:fromSprite(spriteSheet:getSprite("headers", "terrain-icon"), 3.0)
			ProfilePanel.static.TILE_ICON = tileIcon
		end
		local buildingIcon = ProfilePanel.BUILDING_ICON
		if not buildingIcon then
			buildingIcon = ScaledSprite:fromSprite(spriteSheet:getSprite("headers", "house-icon"), 3.0)
			ProfilePanel.static.BUILDING_ICON = buildingIcon
		end

		love.graphics.printf(tostring(self.numVillagers), x,
		                     y + (self.stats.bounds.h - ProfilePanel.STAT_FONT:getHeight()) / 2,
		                     self.stats.bounds.w - buildingIcon:getWidth(), "left")
		love.graphics.printf(tostring(self.numTiles), x,
		                     y + (self.stats.bounds.h - ProfilePanel.STAT_FONT:getHeight()) / 2,
		                     self.stats.bounds.w / 2, "right")

		love.graphics.printf(tostring(self.numBuildings), x,
		                     y + (self.stats.bounds.h - ProfilePanel.STAT_FONT:getHeight()) / 2,
		                     self.stats.bounds.w - buildingIcon:getWidth(), "right")
		love.graphics.setColor(1, 1, 1, 1)

		spriteSheet:draw(villagerIcon,
		                 x + ProfilePanel.STAT_FONT:getWidth(tostring(self.numVillagers)),
		                 y + (self.stats.bounds.h - villagerIcon:getHeight()) / 2)
		spriteSheet:draw(tileIcon,
		                 x + self.stats.bounds.w / 2,
						 y + (self.stats.bounds.h - tileIcon:getHeight()) / 2)
		spriteSheet:draw(buildingIcon,
		                 x + self.stats.bounds.w - buildingIcon:getWidth(),
		                 y + (self.stats.bounds.h - villagerIcon:getHeight()) / 2)
	end
end

return ProfilePanel
