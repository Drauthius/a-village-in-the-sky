local class = require "lib.middleclass"
local babel = require "lib.babel"

local DetailsPanel = require "src.game.gui.detailspanel"
local InfoPanel = require "src.game.gui.infopanel"
local Widget = require "src.game.gui.widget"

local UnassignedEvent = require "src.game.unassignedevent"

local AssignmentComponent = require "src.game.assignmentcomponent"
local BuildingComponent = require "src.game.buildingcomponent"
local ConstructionComponent = require "src.game.constructioncomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local TileComponent = require "src.game.tilecomponent"
local WorkComponent = require "src.game.workcomponent"

local blueprint = require "src.game.blueprint"
local screen = require "src.screen"
local soundManager = require "src.soundmanager"
local spriteSheet = require "src.game.spritesheet"
local state = require "src.game.state"

local GUI = class("GUI")

function GUI:initialize(engine, eventManager)
	self.engine = engine
	self.eventManager = eventManager

	self.screenWidth, self.screenHeight = screen:getDimensions()

	self.resourceFont = love.graphics.newFont("asset/font/Norse-Bold.otf", 16)
	self.menuFont = love.graphics.newFont("asset/font/Norse.otf", 26)
	self.yearPanel = spriteSheet:getSprite("year-panel")
	self.yearPanel.number = spriteSheet:getData("year-number")
	self.yearPanel.text = spriteSheet:getData("year-text")
	self.menuButton = spriteSheet:getSprite("menu-button")
	self.menuButton.data = spriteSheet:getData("menutext-position")

	self.resourcePanel = {
		sprite = spriteSheet:getSprite("resource-panel"),
		resources = {
			ResourceComponent.WOOD,
			ResourceComponent.IRON,
			ResourceComponent.TOOL,
			ResourceComponent.GRAIN,
			ResourceComponent.BREAD
		}
	}

	for _,resource in ipairs(self.resourcePanel.resources) do
		local res = ResourceComponent.RESOURCE_NAME[resource]
		local resCapitalized = res:gsub("^%l", string.upper)
		local work = WorkComponent.WORK_NAME[WorkComponent.RESOURCE_TO_WORK[resource]]

		self.resourcePanel[res] = {
			sprite =spriteSheet:getSprite("headers", work .. "-icon"),
			icon = spriteSheet:getData(resCapitalized .. "-icon"),
			text = spriteSheet:getData(resCapitalized .. "-text")
		}
		self.resourcePanel[work] = {
			sprite = spriteSheet:getSprite("headers", "occupied-icon"),
			icon = spriteSheet:getData(resCapitalized .. "-occupation-icon"),
			text = spriteSheet:getData(resCapitalized .. "-occupation-text")
		}
	end

	self.resourcePanel.villagers = {
		sprite = spriteSheet:getSprite("headers", "occupied-icon"),
		icon = spriteSheet:getData("Villagers-icon"),
		text = spriteSheet:getData("Villagers-text")
	}
	self.resourcePanel.children = {
		sprite = spriteSheet:getSprite("headers", "occupied-icon"),
		icon = spriteSheet:getData("Children-icon"),
		text = spriteSheet:getData("Children-text")
	}

	-- Between buttons
	local padding = 5

	local tileButtonSprite = spriteSheet:getSprite("button 0")
	self.tileButton = Widget(
		1, self.screenHeight - tileButtonSprite:getHeight() - 1,
		1, 1, tileButtonSprite)
	self.tileButton.closed = tileButtonSprite
	self.tileButton.opened = spriteSheet:getSprite("button 1")

	local buildingButtonSprite = spriteSheet:getSprite("button 2")
	self.buildingButton = Widget(
		1, select(2, self.tileButton:getPosition()) - buildingButtonSprite:getHeight() - padding,
		1, 1, buildingButtonSprite)
	self.buildingButton.closed = buildingButtonSprite
	self.buildingButton.opened = spriteSheet:getSprite("button 3")

	local listEventButtonSprite = spriteSheet:getSprite("button 8")
	self.listEventButton = Widget(
		self.screenWidth - listEventButtonSprite:getWidth() - 1,
		self.screenHeight - listEventButtonSprite:getHeight() - 1,
		1, 1, listEventButtonSprite)
	self.listEventButton.closed = listEventButtonSprite
	self.listEventButton.opened = spriteSheet:getSprite("button 9")

	local listPeopleButtonSprite = spriteSheet:getSprite("button 4")
	self.listPeopleButton = Widget(
		self.screenWidth - listPeopleButtonSprite:getWidth() - 1,
		select(2, self.listEventButton:getPosition()) - listPeopleButtonSprite:getHeight() - padding,
		1, 1, listPeopleButtonSprite)
	self.listPeopleButton.closed = listPeopleButtonSprite
	self.listPeopleButton.opened = spriteSheet:getSprite("button 5")

	local listBuildingButtonSprite = spriteSheet:getSprite("button 6")
	self.listBuildingButton = Widget(
		self.screenWidth - listBuildingButtonSprite:getWidth() - 1,
		select(2, self.listPeopleButton:getPosition()) - listBuildingButtonSprite:getHeight() - padding,
		1, 1, listBuildingButtonSprite)
	self.listBuildingButton.closed = listBuildingButtonSprite
	self.listBuildingButton.opened = spriteSheet:getSprite("button 7")

	self.widgets = {
		tile = self.tileButton,
		building = self.buildingButton,
		listEvent = self.listEventButton,
		listPeople = self.listPeopleButton,
		listBuilding = self.listBuildingButton
	}

	local leftx = self.tileButton:getPosition()
	local left = self.tileButton:getDimensions()
	left = left + leftx + 3
	local right = self.listEventButton:getPosition()
	right = right - 3
	self.infoPanel = InfoPanel(right - left)
	self.infoPanel:hide()

	self.detailsPanel = DetailsPanel(select(2, self.listBuildingButton:getPosition()) - padding, function(button)
		self:_handleDetailsButtonPress(button)
	end)
	self.detailsPanel:hide()
end

function GUI:back()
	if not self:_clearPlacing() then
		if self.infoPanel:isShown() or self.detailsPanel:isShown() then
			soundManager:playEffect("drawerClosed")
			self.infoPanel:hide()
			self.infoPanelShowing = nil
			self.detailsPanel:hide()
		else
			print("toggle main menu")
			soundManager:playEffect("toggleMainMenu")
		end
	else
		soundManager:playEffect("placingCleared")
	end
end

function GUI:placed()
	assert(state:isPlacing())
	self.infoPanel.content.selected = nil
	state:clearPlacing()
end

function GUI:update(dt)
	for type,widget in pairs(self.widgets) do
		if type == self.infoPanelShowing then
			widget.sprite = widget.opened
		else
			widget.sprite = widget.closed
		end
	end
	self.detailsPanel:update(dt)
end

function GUI:draw()
	love.graphics.setColor(1, 1, 1)

	do -- Resource panel
		local x = (self.screenWidth - self.resourcePanel.sprite:getWidth()) / 2
		spriteSheet:draw(self.resourcePanel.sprite, x, 0)

		for _,resource in ipairs(self.resourcePanel.resources) do
			local res = ResourceComponent.RESOURCE_NAME[resource]
			local work = WorkComponent.WORK_NAME[WorkComponent.RESOURCE_TO_WORK[resource]]

			spriteSheet:draw(
				self.resourcePanel[res].sprite,
				x + self.resourcePanel[res].icon.bounds.x,
				self.resourcePanel[res].icon.bounds.y)

			spriteSheet:draw(
				self.resourcePanel[work].sprite,
				x + self.resourcePanel[work].icon.bounds.x,
				self.resourcePanel[work].icon.bounds.y)

			love.graphics.setFont(self.resourceFont)
			love.graphics.setColor(0, 0, 0)
			love.graphics.print(tostring(state:getNumResources(resource)),
				x + self.resourcePanel[res].text.bounds.x,
				self.resourcePanel[res].text.bounds.y)

			love.graphics.print("0",
				x + self.resourcePanel[work].text.bounds.x,
				self.resourcePanel[work].text.bounds.y)

			love.graphics.setColor(1, 1, 1)
		end

		spriteSheet:draw(
			self.resourcePanel.villagers.sprite,
			x + self.resourcePanel.villagers.icon.bounds.x,
			self.resourcePanel.villagers.icon.bounds.y)
		spriteSheet:draw(
			self.resourcePanel.children.sprite,
			x + self.resourcePanel.children.icon.bounds.x,
			self.resourcePanel.children.icon.bounds.y)

		love.graphics.setFont(self.resourceFont)
		love.graphics.setColor(0, 0, 0)
		love.graphics.print(tostring(state:getNumMaleVillagers() + state:getNumFemaleVillagers()),
			x + self.resourcePanel.villagers.text.bounds.x,
			self.resourcePanel.villagers.text.bounds.y)

		love.graphics.print(tostring(state:getNumMaleChildren() + state:getNumFemaleChildren()),
			x + self.resourcePanel.children.text.bounds.x,
			self.resourcePanel.children.text.bounds.y)

		love.graphics.setColor(1, 1, 1)
	end

	do -- Year panel
		local x, y = 1, 1
		spriteSheet:draw(self.yearPanel, x, y)

		love.graphics.setColor(0, 0, 0)

		local h = (self.yearPanel.text.bounds.h - self.menuFont:getHeight()) / 2
		love.graphics.setFont(self.menuFont)
		love.graphics.printf(babel.translate("Year"),
			x + self.yearPanel.text.bounds.x,
			y + self.yearPanel.text.bounds.y + h,
			self.yearPanel.text.bounds.w,
			"center")

		h = (self.yearPanel.number.bounds.h - self.menuFont:getHeight()) / 2
		love.graphics.setFont(self.menuFont)
		love.graphics.printf(math.floor(state:getYear()),
			x + self.yearPanel.number.bounds.x,
			y + self.yearPanel.number.bounds.y + h,
			self.yearPanel.number.bounds.w,
			"center")

		love.graphics.setColor(1, 1, 1)
	end

	do -- Menu button
		local x, y = self.screenWidth - self.menuButton:getWidth() - 1, 1
		spriteSheet:draw(self.menuButton, x, y)

		local h = (self.menuButton.data.bounds.h - self.menuFont:getHeight()) / 2
		love.graphics.setColor(0, 0, 0)
		love.graphics.setFont(self.menuFont)
		love.graphics.printf(babel.translate("Menu"),
			x + self.menuButton.data.bounds.x,
			y + self.menuButton.data.bounds.y + h,
			self.menuButton.data.bounds.w,
			"center")
		love.graphics.setColor(1, 1, 1)
	end

	for _,widget in pairs(self.widgets) do
		widget:draw()
	end

	self.infoPanel:draw()
	self.detailsPanel:draw()
end

function GUI:updateInfoPanel()
	if self.infoPanel:isShown() then
		local content = {
			name = self.infoPanelShowing,
			margin = 5,
			items = {}
		}
		if self.infoPanelShowing == "tile" then
			for i,type in ipairs({ TileComponent.GRASS, TileComponent.FOREST, TileComponent.MOUNTAIN}) do
				table.insert(content.items, (spriteSheet:getSprite(TileComponent.TILE_NAME[type] .. "-tile")))
				content.items[i].onPress = function(item)
					local selected = content.selected
					self:_clearPlacing()

					if selected ~= i then
						local entity = blueprint:createPlacingTile(type)
						state:setPlacing(entity)
						self.engine:addEntity(entity)
						content.selected = i
					end
				end
			end
		elseif self.infoPanelShowing == "building" then
			for i,type in ipairs({ BuildingComponent.DWELLING, BuildingComponent.BLACKSMITH,
			                       BuildingComponent.FIELD, BuildingComponent.BAKERY}) do
				local name = BuildingComponent.BUILDING_NAME[type]
				table.insert(content.items, (spriteSheet:getSprite(name .. (type == BuildingComponent.FIELD and "" or " 0"))))
				content.items[i].onPress = function(item)
					local selected = content.selected
					self:_clearPlacing()

					if selected ~= i then
						local entity = blueprint:createPlacingBuilding(type)
						state:setPlacing(entity)
						self.engine:addEntity(entity)
						content.selected = i
					end
				end
			end
		end
		self.infoPanel:setContent(content)
	end
end

function GUI:handlePress(x, y, released)
	for type,widget in pairs(self.widgets) do
		if widget:isWithin(x, y) then
			if released then
				if self.infoPanel:isShown() and self.infoPanelShowing == type then
					soundManager:playEffect("drawerClosed")
					self.infoPanel:hide()
					self.infoPanelShowing = nil
				else
					soundManager:playEffect("drawerOpened")
					self.infoPanelShowing = type
					self.infoPanel:show()
					self:updateInfoPanel()
				end
				self:_clearPlacing()
			end
			return true
		end
	end

	if self.infoPanel:isShown() and self.infoPanel:isWithin(x, y) then
		if released then
			soundManager:playEffect("drawerSelected")
			-- Maybe add "self:_clearPlacing()" here?
			self.infoPanel:handlePress(x, y)
		end
		return true
	elseif self.detailsPanel:isShown() and self.detailsPanel:isWithin(x, y) then
		self.detailsPanel:handlePress(x, y, released)
		return true
	end

	return false
end

function GUI:_handleDetailsButtonPress(button)
	local selection = state:getSelection()
	if button == "runestone-upgrade" then
		selection:add(ConstructionComponent(BuildingComponent.RUNESTONE, selection:get("RunestoneComponent"):getLevel()))
		selection:add(AssignmentComponent(4))
		selection:get("SpriteComponent"):setNeedsRefresh(true)
	elseif button == "runestone-upgrade-cancel" then
		for _,assignee in ipairs(selection:get("AssignmentComponent"):getAssignees()) do
			self.eventManager:fireEvent(UnassignedEvent(selection, assignee))
		end
		-- TODO: Handle added/committed resources
		selection:remove("ConstructionComponent")
		selection:remove("AssignmentComponent")
		selection:get("SpriteComponent"):setNeedsRefresh(true)
	end
end

function GUI:_clearPlacing()
	-- Make sure no entity is left when changing between different panels.
	if state:isPlacing() then
		self.infoPanel.content.selected = nil
		self.engine:removeEntity(state:getPlacing(), true)
		state:clearPlacing()
		return true
	end
end

return GUI
