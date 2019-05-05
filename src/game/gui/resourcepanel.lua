local class = require "lib.middleclass"

local ResourceComponent = require "src.game.resourcecomponent"
local WorkComponent = require "src.game.workcomponent"

local screen = require "src.screen"
local spriteSheet = require "src.game.spritesheet"
local state = require "src.game.state"

local ResourcePanel = class("ResourcePanel")

function ResourcePanel:initialize()
	self.font = love.graphics.newFont("asset/font/Norse-Bold.otf", 16)
	self.spriteBatch = love.graphics.newSpriteBatch(spriteSheet:getImage(), 32, "static")

	local background = spriteSheet:getSprite("resource-panel")
	local screenWidth = screen:getDimensions()

	self.x = (screenWidth - background:getWidth()) / 2
	self.spriteBatch:add(background:getQuad())

	self.resources = {
		ResourceComponent.WOOD,
		ResourceComponent.IRON,
		ResourceComponent.TOOL,
		ResourceComponent.GRAIN,
		ResourceComponent.BREAD
	}

	local villagerIcon = spriteSheet:getSprite("headers", "occupied-icon")
	for _,resource in ipairs(self.resources) do
		local name = ResourceComponent.RESOURCE_NAME[resource]
		local nameCapitalized = name:gsub("^%l", string.upper)
		local work = WorkComponent.WORK_NAME[WorkComponent.RESOURCE_TO_WORK[resource]]

		self[name] = {
			text = spriteSheet:getData(nameCapitalized .. "-text")
		}
		self[work] = {
			text = spriteSheet:getData(nameCapitalized .. "-occupation-text")
		}

		local resourceIcon = spriteSheet:getSprite("headers", work .. "-icon")
		local resourceData = spriteSheet:getData(nameCapitalized .. "-icon")
		local occupationData = spriteSheet:getData(nameCapitalized .. "-occupation-icon")

		self.spriteBatch:add(resourceIcon:getQuad(), resourceData.bounds.x, resourceData.bounds.y)
		self.spriteBatch:add(villagerIcon:getQuad(), occupationData.bounds.x, occupationData.bounds.y)
	end

	local villagerData = spriteSheet:getData("Villagers-icon")
	local childrenData = spriteSheet:getData("Children-icon")
	self.villagers = {
		text = spriteSheet:getData("Villagers-text")
	}
	self.children = {
		text = spriteSheet:getData("Children-text")
	}

	self.spriteBatch:add(villagerIcon:getQuad(), villagerData.bounds.x, villagerData.bounds.y)
	self.spriteBatch:add(villagerIcon:getQuad(), childrenData.bounds.x, childrenData.bounds.y)
end

function ResourcePanel:draw()
	love.graphics.draw(self.spriteBatch, self.x)

	love.graphics.setFont(self.font)

	for _,resource in ipairs(self.resources) do
		local res = ResourceComponent.RESOURCE_NAME[resource]
		local work = WorkComponent.WORK_NAME[WorkComponent.RESOURCE_TO_WORK[resource]]

		love.graphics.setColor(0, 0, 0)
		love.graphics.print(tostring(state:getNumResources(resource)),
			self.x + self[res].text.bounds.x,
			self[res].text.bounds.y)

		love.graphics.print("0",
			self.x + self[work].text.bounds.x,
			self[work].text.bounds.y)

		love.graphics.setColor(1, 1, 1)
	end

	love.graphics.setColor(0, 0, 0)
	love.graphics.print(tostring(state:getNumMaleVillagers() + state:getNumFemaleVillagers()),
		self.x + self.villagers.text.bounds.x,
		self.villagers.text.bounds.y)

	love.graphics.print(tostring(state:getNumMaleChildren() + state:getNumFemaleChildren()),
		self.x + self.children.text.bounds.x,
		self.children.text.bounds.y)

	love.graphics.setColor(1, 1, 1)
end

return ResourcePanel
