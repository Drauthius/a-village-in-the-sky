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

local class = require "lib.middleclass"

local ResourceComponent = require "src.game.resourcecomponent"
local WorkComponent = require "src.game.workcomponent"

local screen = require "src.screen"
local spriteSheet = require "src.game.spritesheet"
local state = require "src.game.state"

local ResourcePanel = class("ResourcePanel")

function ResourcePanel:initialize()
	self.font = love.graphics.newFont("asset/font/Norse-Bold.otf", 16)
	self.fontShadow = love.graphics.newFont("asset/font/Norse-Bold.otf", 18)
	self.spriteBatch = love.graphics.newSpriteBatch(spriteSheet:getImage(), 32, "static")

	local background = spriteSheet:getSprite("resource-panel")
	local screenWidth = screen:getDrawDimensions()

	self.x = (screenWidth - background:getWidth()) / 2
	self.spriteBatch:add(background:getQuad())

	self.resources = {
		ResourceComponent.WOOD,
		ResourceComponent.IRON,
		ResourceComponent.TOOL,
		ResourceComponent.GRAIN,
		ResourceComponent.BREAD
	}

	self.workers = {}
	for _,resource in ipairs(self.resources) do
		self.workers[resource] = 0
	end

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

	local offset = self.font:getDPIScale() == 1 and 0 or math.floor(self.font:getDPIScale())

	for _,resource in ipairs(self.resources) do
		local res = ResourceComponent.RESOURCE_NAME[resource]
		local work = WorkComponent.WORK_NAME[WorkComponent.RESOURCE_TO_WORK[resource]]

		self:_drawText(tostring(state:getNumResources(resource)),
			self.x + self[res].text.bounds.x + offset,
			self[res].text.bounds.y + math.floor((self[res].text.bounds.h - self.font:getHeight()) / 2 + offset))

		self:_drawText(tostring(self.workers[resource]),
			self.x + self[work].text.bounds.x + offset,
			self[work].text.bounds.y + math.floor((self[work].text.bounds.h - self.font:getHeight()) / 2 + offset))
	end

	self:_drawText(tostring(state:getNumMaleVillagers() + state:getNumFemaleVillagers()),
		self.x + self.villagers.text.bounds.x + offset,
		self.villagers.text.bounds.y + math.floor((self.villagers.text.bounds.h - self.font:getHeight()) / 2 + offset))

	self:_drawText(tostring(state:getNumMaleChildren() + state:getNumFemaleChildren()),
		self.x + self.children.text.bounds.x + offset,
		self.children.text.bounds.y + math.floor((self.children.text.bounds.h - self.font:getHeight()) / 2 + offset))

	love.graphics.setColor(1, 1, 1)
end

function ResourcePanel:setWorkers(resource, numWorkers)
	self.workers[resource] = numWorkers
end

function ResourcePanel:_drawText(text, x, y)
	-- Shadow/outline
	--love.graphics.setColor(spriteSheet:getOutlineColor())
	--love.graphics.setFont(self.fontShadow)
	--love.graphics.print(text, x, y)

	-- Text
	--love.graphics.setColor(1, 1, 1)
	love.graphics.setColor(spriteSheet:getOutlineColor())
	love.graphics.setFont(self.font)
	love.graphics.print(text, x, y)
end

return ResourcePanel
