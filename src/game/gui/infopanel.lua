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

local babel = require "lib.babel"
local class = require "lib.middleclass"
local Timer = require "lib.hump.timer"

local BuildItem = require "src.game.gui.builditem"
local BuildingItem = require "src.game.gui.buildingitem"
local Button = require "src.game.gui.button"
local EventItem = require "src.game.gui.eventitem"
local VillagerItem = require "src.game.gui.villageritem"

local SelectionChangedEvent = require "src.game.selectionchangedevent"

local BuildingComponent = require "src.game.buildingcomponent"
local TileComponent = require "src.game.tilecomponent"

local blueprint = require "src.game.blueprint"
local hint = require "src.game.hint"
local screen = require "src.screen"
local spriteSheet = require "src.game.spritesheet"
local state = require "src.game.state"

local InfoPanel = class("InfoPanel")

InfoPanel.static.panelWidth = 32 -- The width of each panel sprite.
InfoPanel.static.scrollTime = 0.0020 -- Seconds per pixel??
InfoPanel.static.scrollMove = 300
InfoPanel.static.scrollEase = "in-out-sine"
InfoPanel.static.scrollEaseCatchup = "out-sine"

InfoPanel.static.CONTENT = {
	PLACE_TERRAIN = 1,
	PLACE_BUILDING = 2,
	LIST_EVENTS = 3,
	LIST_VILLAGERS = 4,
	LIST_BUILDINGS = 5
}

InfoPanel.static.CONTENT_NAME = {
	[InfoPanel.CONTENT.PLACE_TERRAIN] = "Terrain",
	[InfoPanel.CONTENT.PLACE_BUILDING] = "Build",
	[InfoPanel.CONTENT.LIST_EVENTS] = "Events",
	[InfoPanel.CONTENT.LIST_VILLAGERS] = "Villagers",
	[InfoPanel.CONTENT.LIST_BUILDINGS] = "Buildings"
}

function InfoPanel:initialize(engine, eventManager, width)
	self.engine = engine
	self.eventManager = eventManager
	self.hidden = false
	self.minimized = false
	self.content = {}
	self.selected = nil
	self.type = nil
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
			panel = panel >= 6 and 1 or panel + 1
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

	local screenWidth, screenHeight = screen:getDrawDimensions()
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
			local easing = InfoPanel.scrollEase
			self.scrollTarget = math.min(limit, (self.scrollTarget or self.ox) + InfoPanel.scrollMove)
			if self.scroll then
				Timer.cancel(self.scroll)
				easing = InfoPanel.scrollEaseCatchup
			end
			self.scroll = Timer.tween(InfoPanel.scrollTime * math.abs(self.scrollTarget - self.ox),
			                          self, {ox = self.scrollTarget}, easing, function()
				if math.ceil(self.ox) >= limit then
					self.ox = limit
					self.leftButton:setDisabled(true)
					self.leftButton:setPressed(true)
				end
				self.rightButton:setDisabled(false)
				self.rightButton:setPressed(false)
				self.scrollTarget = nil
			end)
		end)

		self.rightButton = Button(self.bounds.x + self.bounds.w, self.bounds.y, 0, 0, "info-panel-left", false)
		self.rightButton:setScale(-1, 1) -- Flip
		self.rightButton:setAction(function()
			local limit = self.contentBounds.w - self.contentBounds.length
			self.scrollTarget = math.max(limit, (self.scrollTarget or self.ox) - InfoPanel.scrollMove)
			local easing = InfoPanel.scrollEase
			if self.scroll then
				Timer.cancel(self.scroll)
				easing = InfoPanel.scrollEaseCatchup
			end
			self.scroll = Timer.tween(InfoPanel.scrollTime * math.abs(self.scrollTarget - self.ox),
			                          self, {ox = self.scrollTarget}, easing, function()
				if math.floor(self.ox) <= limit then
					self.ox = limit
					self.rightButton:setDisabled(true)
					self.rightButton:setPressed(true)
				end
				self.leftButton:setDisabled(false)
				self.leftButton:setPressed(false)
				self.scrollTarget = nil
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
	self.headerFont = love.graphics.newFont("asset/font/Norse-Bold.otf", 18)
	self.itemFont = love.graphics.newFont("asset/font/Norse.otf", 16)
	self.itemFontBold = love.graphics.newFont("asset/font/Norse-Bold.otf", 16)
end

function InfoPanel:update(dt)
	if not self:isShown() then
		return
	end

	for _,button in ipairs(self.buttons) do
		-- FIXME: DRY (Almost identical to the button in detailspanel)
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

	-- Draw all the items.
	if not self.minimized then
		-- Don't draw outside the content bounds (this takes care of scrolling)
		love.graphics.setStencilTest("greater", 0)

		for _,item in ipairs(self.content) do
			item:draw(self.ox)
		end

		hint:draw(true, self.ox)

		love.graphics.setStencilTest()
	end

	-- Draw the scroll buttons.
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

	-- Draw the header background.
	love.graphics.setFont(self.headerFont)
	local label = babel.translate(InfoPanel.CONTENT_NAME[self:getContentType()])
	local x, y = self.bounds.x + 1, self.bounds.y + 1
	spriteSheet:draw(self.textBackgroundLeft, x, y)
	x = x + self.textBackgroundLeft:getWidth()
	love.graphics.draw(spriteSheet:getImage(), self.textBackgroundCentre:getQuad(), x, y,
		0, self.headerFont:getWidth(label), 1)
	x = x + self.headerFont:getWidth(label) + self.textBackgroundLeft:getWidth()
	love.graphics.draw(spriteSheet:getImage(), self.textBackgroundLeft:getQuad(), x, y,
		0, -1, 1)

	-- Draw the header text.
	love.graphics.setColor(spriteSheet:getOutlineColor())
	love.graphics.print(label,
		self.bounds.x + 5, self.y + math.floor((self.barHeight - self.headerFont:getHeight()) / 2))
	love.graphics.setColor(1, 1, 1)

	-- Lastly, draw the bar buttons.
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

function InfoPanel:getContentType()
	return self.type
end

function InfoPanel:refresh()
	self:setContent(self:getContentType(), true)
end

function InfoPanel:setContent(type, refresh)
	self.type = type

	if not refresh then
		self.selected = nil
	end

	local content = {}
	local margin = 10

	if type == InfoPanel.CONTENT.PLACE_TERRAIN then
		local terrains = state:getAvailableTerrain() or { TileComponent.GRASS, TileComponent.FOREST, TileComponent.MOUNTAIN }
		for _,terrain in ipairs(terrains) do
			local sprite = spriteSheet:getSprite(TileComponent.TILE_NAME[terrain] .. "-tile")
			local w, h = sprite:getWidth() + margin, self.contentBounds.h -- We assume that all sprites are the same width.

			local item = BuildItem(0, self.contentBounds.y, w, h, sprite, self.itemFont, terrain, false, function(it)
				return blueprint:createPlacingTile(it:getType())
			end)

			table.insert(content, item)
		end
	elseif type == InfoPanel.CONTENT.PLACE_BUILDING then
		local buildings = state:getAvailableBuildings() or { BuildingComponent.DWELLING, BuildingComponent.BLACKSMITH,
		                                                     BuildingComponent.FIELD, BuildingComponent.BAKERY }
		for _,building in ipairs(buildings) do
			local sprite = spriteSheet:getSprite(BuildingComponent.BUILDING_NAME[building] ..
			                                     (building == BuildingComponent.FIELD and "" or " 0"))
			local w, h = sprite:getWidth() + margin, self.contentBounds.h -- We assume that all sprites are the same width.

			local item = BuildItem(0, self.contentBounds.y, w, h, sprite, self.itemFont, building, true, function(it)
				return blueprint:createPlacingBuilding(it:getType())
			end)

			table.insert(content, item)
		end
	elseif type == InfoPanel.CONTENT.LIST_BUILDINGS then
		margin = 5 -- ?
		for _,entity in pairs(self.engine:getEntitiesWithComponent("BuildingComponent")) do
			local item = BuildingItem(0, self.contentBounds.y, self.contentBounds.h, self.itemFont, self.itemFontBold, entity)

			table.insert(content, item)

			if state:getSelection() == entity then
				self.selected = #content
				item:select()
			end
		end

		table.sort(content, function(a, b)
			local ay = a:getEntity():get("BuildingComponent"):getYearBuilt()
			local by = b:getEntity():get("BuildingComponent"):getYearBuilt()
			if ay < by then
				return true
			elseif ay > by then
				return false
			else
				return a:getEntity().id > b:getEntity().id
			end
		end)
	elseif type == InfoPanel.CONTENT.LIST_VILLAGERS then
		margin = 5 -- ?
		for _,entity in pairs(self.engine:getEntitiesWithComponent("VillagerComponent")) do
			local item = VillagerItem(0, self.contentBounds.y, self.contentBounds.h, self.itemFont, self.itemFontBold, entity)

			table.insert(content, item)

			if state:getSelection() == entity then
				self.selected = #content
				item:select()
			end
		end

		table.sort(content, function(a, b)
			local ag, bg = a:getEntity():get("VillagerComponent"):getAge(), b:getEntity():get("VillagerComponent"):getAge()
			if ag > bg then
				return true
			elseif ag < bg then
				return false
			else
				return a:getEntity().id > b:getEntity().id
			end
		end)
	elseif type == InfoPanel.CONTENT.LIST_EVENTS then
		margin = 5 -- ?
		local events = state:getEvents()

		for i=#events,1,-1 do -- Latest first
			local event = events[i]
			local item = EventItem(0, self.contentBounds.y, self.contentBounds.h, self.itemFont, self.itemFontBold, event)

			table.insert(content, item)

			if i > state:getLastEventSeen() then
				item:setUnseen()
			end
		end

		if not refresh then
			state:setLastEventSeen(#events)
		end
	end

	local mysteryOffset = 3 -- Probably something to do with the line thickness of items??
	local x = self.contentBounds.x + mysteryOffset
	for _,item in ipairs(content) do
		item:setPosition(x, item.y)
		x = x + item:getDimensions() + margin
	end

	if refresh and self.ox ~= 0 and next(content) then
		self.ox = self.ox + content[1]:getWidth() + margin
	else
		self.ox = 0
	end

	self.content = content
	self.contentBounds.length = x - self.contentBounds.x - mysteryOffset

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

function InfoPanel:setHint(place)
	for _,content in ipairs(self.content) do
		if content:getType() == place then
			hint:rotateAround(content:getPosition() + content:getWidth() / 2,
			                  self.contentBounds.y + self.contentBounds.h / 2,
			                  content:getWidth() / 2.1, false, true)
			return
		end
	end

	error("Unknown hint location "..tostring(place))
end

function InfoPanel:show()
	self.hidden = false
	self:minimize(false)
	self.ox = 0
end

function InfoPanel:hide()
	self.hidden = true
	self.type = nil
end

function InfoPanel:isShown()
	return not self.hidden
end

function InfoPanel:minimize(min)
	self.minimized = min
	if self.minimized then
		self.y = select(2, screen:getDrawDimensions()) - self.barHeight + 5

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

		if self.ox > 0 then
			self.leftButton:setDisabled(false)
		end
		if self.contentBounds.length > self.contentBounds.w then
			self.rightButton:setDisabled(false)
		end
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
		if button:isWithin(x, y) then
			if button:isDisabled() then
				return false
			end
			if released and button:isPressed() then
				button:getAction()()
			end
			button:setPressed(not released)
			return true
		end
	end

	if released and not self.minimized then
		for i,item in ipairs(self.content) do
			if item:isWithin(x - self.ox, y) then
				if self.selected then
					self.content[self.selected]:unselect()
				end

				local selection = nil
				local isPlacing = self.type == InfoPanel.CONTENT.PLACE_TERRAIN or self.type == InfoPanel.CONTENT.PLACE_BUILDING

				if self.selected ~= i then
					selection = item:select()
					self.selected = i
				elseif not isPlacing then
					-- Keep on selecting it if it's not something that's being placed.
					selection = item:select()
				else
					-- Clear the selection when clicking the same thing again.
					self.selected = nil
					isPlacing = false
				end

				self.eventManager:fireEvent(SelectionChangedEvent(selection, isPlacing))
				return true
			end
		end

		-- Clicking outside should deselect.
		if self.selected then
			self.eventManager:fireEvent(SelectionChangedEvent(nil))
		end
	end

	return false
end

function InfoPanel:onSelectionChanged(event)
	local selection = event:getSelection()

	if selection and event:isPlacing() then
		return -- Probably originated from us, yeah?
	end

	-- Clear whatever happens to be selected (since it probably changed).
	if self.selected then
		self.content[self.selected]:unselect()
		self.selected = nil
	end

	-- Select the thing that was selected, if there is something relevant shown.
	if selection then
		if (self.type == InfoPanel.CONTENT.LIST_VILLAGERS and selection:has("VillagerComponent")) or
		   (self.type == InfoPanel.CONTENT.LIST_BUILDINGS and selection:has("BuildingComponent")) then
			for i,item in ipairs(self.content) do
				if item:getEntity() == selection then
					self.selected = i
					item:select()
					return
				end
			end
		end
	end
end

return InfoPanel
