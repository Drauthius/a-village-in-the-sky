local babel = require "lib.babel"
local class = require "lib.middleclass"
local Timer = require "lib.hump.timer"

local BuildItem = require "src.game.gui.builditem"
local BuildingItem = require "src.game.gui.buildingitem"
local Button = require "src.game.gui.button"
local VillagerItem = require "src.game.gui.villageritem"

local SelectionChangedEvent = require "src.game.selectionchangedevent"

local BuildingComponent = require "src.game.buildingcomponent"
local TileComponent = require "src.game.tilecomponent"

local blueprint = require "src.game.blueprint"
local screen = require "src.screen"
local spriteSheet = require "src.game.spritesheet"
local state = require "src.game.state"

local InfoPanel = class("InfoPanel")

InfoPanel.static.panelWidth = 32 -- The width of each panel sprite.
InfoPanel.static.scrollTime = 0.0030 -- Seconds per pixel??
InfoPanel.static.scrollMove = 150
InfoPanel.static.scrollEase = "in-out-sine"

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
			local target = math.min(limit, self.ox + InfoPanel.scrollMove)
			if self.scroll then
				Timer.cancel(self.scroll)
			end
			self.scroll = Timer.tween(InfoPanel.scrollTime * math.abs(target - self.ox),
			                          self, {ox = target}, InfoPanel.scrollEase, function()
				if math.ceil(self.ox) >= limit then
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
			if self.scroll then
				Timer.cancel(self.scroll)
			end
			self.scroll = Timer.tween(InfoPanel.scrollTime * math.abs(target - self.ox),
			                          self, {ox = target}, InfoPanel.scrollEase, function()
				if math.floor(self.ox) <= limit then
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

function InfoPanel:setContent(type)
	self.type = type
	self.ox = 0

	if self.selected ~= nil then
		self.eventManager:fireEvent(SelectionChangedEvent(nil))
	end

	local content = {}
	local margin = 10
	local mysteryOffset = 3 -- Probably something to do with the line thickness of items??
	local x = self.contentBounds.x + mysteryOffset

	if type == InfoPanel.CONTENT.PLACE_TERRAIN then
		for _,terrain in pairs({ TileComponent.GRASS, TileComponent.FOREST, TileComponent.MOUNTAIN }) do
			local sprite = spriteSheet:getSprite(TileComponent.TILE_NAME[terrain] .. "-tile")
			local w, h = sprite:getWidth() + margin, self.contentBounds.h -- We assume that all sprites are the same width.

			local item = BuildItem(x, self.contentBounds.y, w, h, sprite, self.itemFont, terrain, false, function(it)
				return blueprint:createPlacingTile(it:getType())
			end)

			x = x + item:getDimensions() + margin
			table.insert(content, item)
		end
	elseif type == InfoPanel.CONTENT.PLACE_BUILDING then
		for _,building in pairs({ BuildingComponent.DWELLING, BuildingComponent.BLACKSMITH,
		                          BuildingComponent.FIELD, BuildingComponent.BAKERY }) do
			local sprite = spriteSheet:getSprite(BuildingComponent.BUILDING_NAME[building] ..
			                                     (building == BuildingComponent.FIELD and "" or " 0"))
			local w, h = sprite:getWidth() + margin, self.contentBounds.h -- We assume that all sprites are the same width.

			local item = BuildItem(x, self.contentBounds.y, w, h, sprite, self.itemFont, building, true, function(it)
				return blueprint:createPlacingBuilding(it:getType())
			end)

			x = x + item:getDimensions() + margin
			table.insert(content, item)
		end
	elseif type == InfoPanel.CONTENT.LIST_BUILDINGS then
		margin = 5 -- ?
		for _,entity in pairs(self.engine:getEntitiesWithComponent("BuildingComponent")) do
			local item = BuildingItem(x, self.contentBounds.y, self.contentBounds.h, self.itemFont, self.itemFontBold, entity)

			x = x + item:getDimensions() + margin
			table.insert(content, item)

			if state:getSelection() == entity then
				self.selected = #content
				item:select()
			end
		end
	elseif type == InfoPanel.CONTENT.LIST_VILLAGERS then
		margin = 5 -- ?
		for _,entity in pairs(self.engine:getEntitiesWithComponent("VillagerComponent")) do
			local item = VillagerItem(x, self.contentBounds.y, self.contentBounds.h, self.itemFont, self.itemFontBold, entity)

			x = x + item:getDimensions() + margin
			table.insert(content, item)

			if state:getSelection() == entity then
				self.selected = #content
				item:select()
			end
		end
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

function InfoPanel:show()
	self.hidden = false
	self:minimize(false)
	self.ox = 0
end

function InfoPanel:hide()
	self.hidden = true
	self.type = nil

	if self.selected ~= nil then
		self.eventManager:fireEvent(SelectionChangedEvent(nil))
	end
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
				return
			end
			if released and button:isPressed() then
				button:getAction()()
			end
			return button:setPressed(not released)
		end
	end

	if released and not self.minimized then
		for i,item in ipairs(self.content) do
			if item:isWithin(x - self.ox, y) then
				if self.selected then
					self.content[self.selected]:unselect()
				end

				local selection, isPlacing = nil, false

				if self.selected ~= i then
					selection = item:select()
					self.selected = i
					isPlacing = self.type == InfoPanel.CONTENT.PLACE_TERRAIN or self.type == InfoPanel.CONTENT.PLACE_BUILDING
				else
					-- Clear the selection when clicking the same thing again.
					self.selected = nil
				end

				return self.eventManager:fireEvent(SelectionChangedEvent(selection, isPlacing))
			end
		end
	end
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
