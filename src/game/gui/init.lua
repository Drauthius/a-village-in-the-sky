local babel = require "lib.babel"
local class = require "lib.middleclass"
local vector = require "lib.hump.vector"

local DetailsPanel = require "src.game.gui.detailspanel"
local InfoPanel = require "src.game.gui.infopanel"
local ResourcePanel = require "src.game.gui.resourcepanel"
local Widget = require "src.game.gui.widget"

local UnassignedEvent = require "src.game.unassignedevent"

local AssignmentComponent = require "src.game.assignmentcomponent"
local BuildingComponent = require "src.game.buildingcomponent"
local ConstructionComponent = require "src.game.constructioncomponent"
local TileComponent = require "src.game.tilecomponent"
local WorkComponent = require "src.game.workcomponent"

local blueprint = require "src.game.blueprint"
local screen = require "src.screen"
local soundManager = require "src.soundmanager"
local spriteSheet = require "src.game.spritesheet"
local state = require "src.game.state"

local GUI = class("GUI")

function GUI:initialize(engine, eventManager, map)
	self.engine = engine
	self.eventManager = eventManager
	self.map = map

	self.screenWidth, self.screenHeight = screen:getDimensions()

	self.menuFont = love.graphics.newFont("asset/font/Norse.otf", 26)
	self.yearPanel = spriteSheet:getSprite("year-panel")
	self.yearPanel.number = spriteSheet:getData("year-number")
	self.yearPanel.text = spriteSheet:getData("year-text")
	self.menuButton = spriteSheet:getSprite("menu-button")
	self.menuButton.data = spriteSheet:getData("menutext-position")

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

	self.resourcePanel = ResourcePanel()

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

	-- Update the arrows.
	if state:getSelection() then
		local selection = state:getSelection()
		if true then --FIXME: Cache? -- if not self.arrows or self.arrows.selection ~= selection then
			self.arrows = {}

			self._getVillagerPosition = self._getVillagerPosition or function(villager, out)
				out.x, out.y = villager:get("GroundComponent"):getIsometricPosition()

				if not villager:has("PositionComponent") then -- Inside something
					out.alwaysShow = true
				end
			end

			local buildingIcon = spriteSheet:getSprite("headers", "house-icon")
			local childIcon = spriteSheet:getSprite("headers", "child-icon")
			local villagerIcon = spriteSheet:getSprite("headers", "occupied-icon")

			if selection:has("VillagerComponent") then
				local villager = {}
				if selection:has("AdultComponent") then
					villager.icon = villagerIcon
				else
					villager.icon = childIcon
				end

				self._getVillagerPosition(selection, villager)

				table.insert(self.arrows, villager)

				if selection:get("VillagerComponent"):getHome() then
					local home = {
						icon = buildingIcon,
						alwaysShow = true
					}

					local targetGrid = selection:get("VillagerComponent"):getHome():get("PositionComponent"):getToGrid()
					home.x, home.y = self.map:gridToWorldCoords(targetGrid.gi, targetGrid.gj)

					table.insert(self.arrows, home)
				end

				if selection:has("AdultComponent") then
					local adult = selection:get("AdultComponent")
					local workPlace = adult:getWorkPlace()
					local ti, tj = adult:getWorkArea()

					if workPlace or ti then
						local work = {
							icon = spriteSheet:getSprite("headers", WorkComponent.WORK_NAME[adult:getOccupation()].."-icon"),
							alwaysShow = true
						}

						if workPlace then
							local targetGrid = workPlace:get("PositionComponent"):getToGrid()
							work.x, work.y = self.map:gridToWorldCoords(targetGrid.gi, targetGrid.gj)
						elseif ti and tj then
							work.x, work.y = self.map:tileToWorldCoords(ti + 0.5, tj + 0.5)
						end

						table.insert(self.arrows, work)
					end
				end
			elseif selection:has("AssignmentComponent") then
				for _,assignee in ipairs(selection:get("AssignmentComponent"):getAssignees()) do
					local villager = {
						icon = villagerIcon,
						alwaysShow = true
					}
					self._getVillagerPosition(assignee, villager)

					table.insert(self.arrows, villager)
				end

				if selection:has("DwellingComponent") then
					for _,child in ipairs(selection:get("DwellingComponent"):getChildren()) do
						local villager = {
							icon = childIcon,
							alwaysShow = true
						}
						self._getVillagerPosition(child, villager)

						table.insert(self.arrows, villager)
					end
				end
			end
		end
	else
		self.arrows = nil
	end
end

function GUI:draw(camera)
	love.graphics.setColor(1, 1, 1)

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

	-- Buttons
	for _,widget in pairs(self.widgets) do
		widget:draw()
	end

	-- Misc widgets
	self.resourcePanel:draw()
	self.infoPanel:draw()
	self.detailsPanel:draw()

	-- Point an arrow to the selected thing.
	-- Drawn above the UI, but in the world (for proper zoom effect).
	-- XXX: Move this to somewhere else?
	if self.arrows then
		local drawArea = screen:getDrawArea()
		camera:draw(drawArea.x, drawArea.y, drawArea.width, drawArea.height, function()
			local arrowIcon = spriteSheet:getSprite("headers", "arrow")

			for _,arrow in ipairs(self.arrows) do
				-- Only point if it is off screen or close to the edges.
				local cx, cy = camera:cameraCoords(arrow.x, arrow.y, drawArea.x, drawArea.y, drawArea.width, drawArea.height)
				local ox, oy = drawArea.width / 5, drawArea.height / 5
				if arrow.alwaysShow or
				   cx <= drawArea.x + ox or cy <= drawArea.y + oy or cx >= drawArea.width - ox or cy >= drawArea.height - oy then
					local halfWidth = drawArea.width / 2
					local halfHeight = drawArea.height / 2

					-- Centre of the screen (in screen/camera coordinates).
					local center = vector(camera:worldCoords(halfWidth, halfHeight,
					                                              drawArea.x, drawArea.y, drawArea.width, drawArea.height))
					local x, y, angle

					-- Angle between the points, with 3 o'clock being being zero degrees.
					angle = math.atan2(arrow.x - center.x, -(arrow.y - center.y))
					if angle < 0 then
						angle = math.abs(angle)
					else
						angle = 2 * math.pi - angle
					end

					love.graphics.setColor(1, 1, 1, 1)
					-- If inside the viewport
					if cx >= drawArea.x and cy >= drawArea.y and cx <= drawArea.width and cy <= drawArea.height then
						-- Draw the arrow (a bit away from the centre)
						love.graphics.draw(spriteSheet:getImage(), arrowIcon:getQuad(), arrow.x, arrow.y, -angle + math.pi/4,
						                   1, 1,
						                   -arrow.icon:getWidth()/4 + 2, -arrow.icon:getHeight()/4 + 2)
						-- Don't ask me about the different offsets and values.
						local offset = arrow.icon:getWidth()/2 + arrowIcon:getWidth()
						spriteSheet:draw(arrow.icon,
						                 arrow.x - arrow.icon:getWidth()/2 + math.cos(-angle + math.pi/2) * offset,
						                 arrow.y - arrow.icon:getHeight()/2 + math.sin(-angle + math.pi/2) * offset)
					else -- Outside the viewport. Calculate which edge to put the arrow.
						-- How far from the edge the arrow should be drawn (midpoint).
						local offset = ((arrow.icon:getHeight() + arrowIcon:getHeight())/2) * camera.scale

						-- Uses trigonometry to calculate where to put the arrow (in screen space).
						local degrees = (math.deg(angle) + 360) % 360 -- For ease of use.
						if degrees >= 300 or degrees <= 60 then -- Top
							local top = offset
							local w = (top - halfHeight) * math.tan(angle)
							x = halfWidth + w
							y = top
						elseif degrees >= 240 then -- Right
							local right = drawArea.width - offset
							local h = (right - halfWidth) * math.tan(angle + 3*math.pi/2)
							x = right
							y = halfHeight - h
						elseif degrees >= 120 then -- Bottom
							local bottom = drawArea.height - offset
							local w = (bottom - halfHeight) * math.tan(angle + math.pi)
							x = halfWidth + w
							y = bottom
						elseif degrees > 60 then -- Left
							local left = offset
							local h = (left - halfWidth) * math.tan(angle + math.pi/2)
							x = left
							y = halfHeight - h
						end

						-- Convert to world coordinates.
						x, y = camera:worldCoords(x, y, drawArea.x, drawArea.y, drawArea.width, drawArea.height)

						-- Draw the arrow and icon.
						love.graphics.draw(spriteSheet:getImage(), arrowIcon:getQuad(), x, y, -angle + math.pi/4,
						                   1, 1,
						                   arrow.icon:getWidth()/2 + 2, arrow.icon:getHeight()/2 + 2)
						spriteSheet:draw(arrow.icon, x - arrow.icon:getWidth()/2, y - arrow.icon:getHeight()/2)
					end
				end
			end
		end)
	end
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
