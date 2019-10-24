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
local vector = require "lib.hump.vector"
local GameState = require "lib.hump.gamestate"
local Timer = require "lib.hump.timer"

local InGameMenu = require "src.ingamemenu"

local Button = require "src.game.gui.button"
local DetailsPanel = require "src.game.gui.detailspanel"
local InfoPanel = require "src.game.gui.infopanel"
local ObjectivesPanel = require "src.game.gui.objectivespanel"
local ResourcePanel = require "src.game.gui.resourcepanel"
local Widget = require "src.game.gui.widget"

local WorkComponent = require "src.game.workcomponent"

local hint = require "src.game.hint"
local screen = require "src.screen"
local soundManager = require "src.soundmanager"
local spriteSheet = require "src.game.spritesheet"
local state = require "src.game.state"

local GUI = class("GUI")

function GUI:initialize(engine, eventManager, map)
	self.engine = engine
	self.eventManager = eventManager
	self.map = map

	self.menuFont = love.graphics.newFont("asset/font/Norse.otf", 26)
	self.menuButton = Button(0, 0, 0, 0, "menu-button", self.menuFont)
	self.menuButton:setText(babel.translate("Menu"))

	self.fastforwardButton = Button(0, 0, 0, 0, "fastforward-button", false)

	self.yearPanel = spriteSheet:getSprite("year-panel")
	self.yearPanel.number = spriteSheet:getData("year-number")
	self.yearPanel.text = spriteSheet:getData("year-text")

	-- Create the buttons (with bogus positions, since they're overwritten in resize() anyway).
	local tileButtonSprite = spriteSheet:getSprite("button 0")
	self.tileButton = Widget(0, 0, 1, 1, tileButtonSprite)
	self.tileButton.closed = tileButtonSprite
	self.tileButton.opened = spriteSheet:getSprite("button 1")

	local buildingButtonSprite = spriteSheet:getSprite("button 2")
	self.buildingButton = Widget(0, 0, 1, 1, buildingButtonSprite)
	self.buildingButton.closed = buildingButtonSprite
	self.buildingButton.opened = spriteSheet:getSprite("button 3")

	local listEventButtonSprite = spriteSheet:getSprite("button 8")
	self.listEventButton = Widget(0, 0, 1, 1, listEventButtonSprite)
	self.listEventButton.closed = listEventButtonSprite
	self.listEventButton.opened = spriteSheet:getSprite("button 9")

	local listPeopleButtonSprite = spriteSheet:getSprite("button 4")
	self.listPeopleButton = Widget(0, 0, 1, 1, listPeopleButtonSprite)
	self.listPeopleButton.closed = listPeopleButtonSprite
	self.listPeopleButton.opened = spriteSheet:getSprite("button 5")

	local listBuildingButtonSprite = spriteSheet:getSprite("button 6")
	self.listBuildingButton = Widget(0, 0, 1, 1, listBuildingButtonSprite)
	self.listBuildingButton.closed = listBuildingButtonSprite
	self.listBuildingButton.opened = spriteSheet:getSprite("button 7")

	self.buttons = {
		[InfoPanel.CONTENT.PLACE_TERRAIN] = self.tileButton,
		[InfoPanel.CONTENT.PLACE_BUILDING] = self.buildingButton,
		[InfoPanel.CONTENT.LIST_EVENTS] = self.listEventButton,
		[InfoPanel.CONTENT.LIST_VILLAGERS] = self.listPeopleButton,
		[InfoPanel.CONTENT.LIST_BUILDINGS] = self.listBuildingButton
	}

	self.eventPanel = {
		x = 0,
		y = 0,
		left = spriteSheet:getSprite("text-background-left"),
		centre = spriteSheet:getSprite("text-background-centre")
	}
	self.eventPanel.font = love.graphics.newFont("asset/font/Norse.otf", self.eventPanel.left:getHeight() - 1)

	self:resize(screen:getDrawDimensions())
	self:setHint(nil)
end

function GUI:resize(width, height)
	self.screenWidth, self.screenHeight = width, height

	-- Between buttons
	local padding = 3

	if height < screen.class.MIN_HEIGHT then
		padding = 1
	end

	self.menuButton.x, self.menuButton.y = 2, 2
	self.fastforwardButton.x = self.menuButton.x + self.menuButton:getWidth() + 2
	self.fastforwardButton.y = self.menuButton.y

	self.objectivesPanel = ObjectivesPanel(self.eventManager, 2, self.menuButton:getHeight() + 10)

	self.yearPanel.x, self.yearPanel.y = self.screenWidth - self.yearPanel:getWidth(), 0

	self.tileButton:setPosition(
		1,
		self.screenHeight - self.tileButton:getHeight() - 1)
	self.buildingButton:setPosition(
		1,
		select(2, self.tileButton:getPosition()) - self.buildingButton:getHeight() - padding)
	self.listEventButton:setPosition(
		self.screenWidth - self.listEventButton:getWidth() - 1,
		self.screenHeight - self.listEventButton:getHeight() - 1)
	self.listPeopleButton:setPosition(
		self.screenWidth - self.listPeopleButton:getWidth() - 1,
		select(2, self.listEventButton:getPosition()) - self.listPeopleButton:getHeight() - padding)
	self.listBuildingButton:setPosition(
		self.screenWidth - self.listBuildingButton:getWidth() - 1,
		select(2, self.listPeopleButton:getPosition()) - self.listBuildingButton:getHeight() - padding)

	-- XXX: Currently recreates a few things.
	self.resourcePanel = ResourcePanel()

	local leftx = self.tileButton:getPosition()
	local left = self.tileButton:getDimensions()
	left = left + leftx + 3
	local right = self.listEventButton:getPosition()
	right = right - 3
	self.infoPanel = InfoPanel(self.engine, self.eventManager, right - left)
	self.infoPanel:hide()

	self.detailsPanel = DetailsPanel(self.eventManager, select(2, self.listBuildingButton:getPosition()) - padding)
	self.detailsPanel:hide()

	local ox = 8
	self.eventPanel.x = self.listEventButton:getPosition() + self.listEventButton:getWidth() - ox
	self.eventPanel.y = select(2, self.listEventButton:getPosition()) + ox
end

function GUI:back()
	if self.infoPanel:isShown() then
		self:_closeInfoPanel()
	else
		GameState.push(InGameMenu)
	end
end

function GUI:update(dt)
	if self.menuButton:isPressed() then
		local x, y = screen:getCoordinate(love.mouse.getPosition())
		if not self.menuButton:isWithin(x, y) then
			self.menuButton:setPressed(false)
		end
	end

	for type,button in ipairs(self.buttons) do
		if type == self.infoPanel:getContentType() then
			button.sprite = button.opened
		else
			button.sprite = button.closed
		end
	end
	self.infoPanel:update(dt)
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
		local x, y = self.yearPanel.x, self.yearPanel.y
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

	-- Menu buttons
	self.menuButton:draw()
	self.fastforwardButton:draw()

	-- Buttons
	for _,button in ipairs(self.buttons) do
		button:draw()
	end

	-- Event label
	if state:getLastEventSeen() < state:getNumEvents() then
		-- Background (draw right to left, since x,y are the end)
		local text = tostring(state:getNumEvents() - state:getLastEventSeen())
		local x, y = self.eventPanel.x, self.eventPanel.y
		local w = self.eventPanel.font:getWidth(text)
		-- Right
		x = x - self.eventPanel.left:getWidth()
		love.graphics.draw(spriteSheet:getImage(), self.eventPanel.left:getQuad(), x, y, 0, -1, 1)
		-- Centre
		x = x - w
		love.graphics.draw(spriteSheet:getImage(), self.eventPanel.centre:getQuad(),
			x, y, 0, w - 4, 1) -- XXX: What's with the 4?
		-- Left
		x = x - self.eventPanel.left:getWidth()
		spriteSheet:draw(self.eventPanel.left, x, y)

		-- Text
		love.graphics.setFont(self.eventPanel.font)
		love.graphics.setColor(spriteSheet:getOutlineColor())
		love.graphics.print(text, x + 2, y)
		love.graphics.setColor(1, 1, 1, 1)
	end

	-- Misc widgets
	self.resourcePanel:draw()
	self.infoPanel:draw()
	self.detailsPanel:draw()
	self.objectivesPanel:draw()

	-- Point an arrow to the selected thing.
	-- Drawn above the UI, but in the world (for proper zoom effect).
	-- XXX: Move this to somewhere else?
	if self.arrows then
		local dx, dy, dw, dh = screen:getDrawArea()
		camera:draw(dx, dy, dw, dh, function()
			local arrowIcon = spriteSheet:getSprite("headers", "arrow")

			for _,arrow in ipairs(self.arrows) do
				-- Only point if it is off screen or close to the edges.
				local cx, cy = camera:cameraCoords(arrow.x, arrow.y, dx, dy, dw, dh)
				local ox, oy = dw / 5, dh / 5
				if arrow.alwaysShow or
				   cx <= dx + ox or cy <= dy + oy or cx >= dw - ox or cy >= dh - oy then
					local halfWidth = dw / 2
					local halfHeight = dh / 2

					-- Centre of the screen (in screen/camera coordinates).
					local center = vector(camera:worldCoords(halfWidth, halfHeight, dx, dy, dw, dh))
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
					if cx >= dx and cy >= dy and cx <= dw and cy <= dh then
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
							local right = dw - offset
							local h = (right - halfWidth) * math.tan(angle + 3*math.pi/2)
							x = right
							y = halfHeight - h
						elseif degrees >= 120 then -- Bottom
							local bottom = dh - offset
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
						-- FIXME: The state now has the top left and bottom right corners in world coordinates, so it
						--        might be more efficient to calculate the positions there directly.
						x, y = camera:worldCoords(x, y, dx, dy, dw, dh)

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

function GUI:handlePress(x, y, released)
	for type,button in ipairs(self.buttons) do
		if button:isWithin(x, y) then
			if released then
				if self.infoPanel:isShown() and self.infoPanel:getContentType() == type then
					self:_closeInfoPanel()
				else
					soundManager:playEffect("drawer_opened")
					self.infoPanel:setContent(type)
					self.infoPanel:show()

					self:updateHint()

					state:showBuildingHeaders(type == InfoPanel.CONTENT.LIST_BUILDINGS)
					state:showVillagerHeaders(type == InfoPanel.CONTENT.LIST_VILLAGERS)
				end
			end
			return true
		end
	end

	if self.infoPanel:isShown() and self.infoPanel:isWithin(x, y) then
		if released then
			soundManager:playEffect("drawer_selected")
		end
		self.infoPanel:handlePress(x, y, released)

		-- Check whether the panel was closed by the click.
		if not self.infoPanel:isShown() then
			self:_closeInfoPanel()
		end
		return true
	elseif self.detailsPanel:isShown() and self.detailsPanel:isWithin(x, y) then
		self.detailsPanel:handlePress(x, y, released)
		return true
	elseif self.objectivesPanel:isWithin(x, y) then
		self.objectivesPanel:handlePress(released)
		return true
	end

	if self.menuButton:isWithin(x, y) then
		if released and self.menuButton:isPressed() then
			GameState.push(InGameMenu)
		end
		self.menuButton:setPressed(not released)
		return true
	end

	if self.fastforwardButton:isWithin(x, y) and not released then
		-- FIXME: The fast-forward button behaves a bit inconsistently with other buttons.
		self.fastforwardButton:setPressed(not self.fastforwardButton:isPressed())
		love.event.push("fastforward", self.fastforwardButton:isPressed())
		return true
	end

	return false
end

function GUI:addObjective(...)
	return self.objectivesPanel:addObjective(...)
end

function GUI:removeObjective(...)
	return self.objectivesPanel:removeObjective(...)
end

function GUI:setHint(place, subplace)
	if not place then
		hint:hide()
		self.hint = nil
		self.infoPanel:setHint(nil)
		return
	end

	self.hint = { place, subplace }
	self:updateHint()
end

function GUI:updateHint()
	if not self.hint then
		return
	end

	if self.infoPanel:isShown() and self.infoPanel:getContentType() == self.hint[1] then
		self.infoPanel:setHint(self.hint[2])
	else
		local button = assert(self.buttons[self.hint[1]], tostring(self.hint[1]).." is unknown")
		local x, y = button:getPosition()

		hint:rotateAround(x + button:getWidth() / 2, y + button:getHeight() / 2 + 5, button:getWidth() * 0.4)
		self.infoPanel:setHint(nil)
	end
end

function GUI:changeAvailibility(type)
	if not self.infoPanel:isShown() then
		return
	end

	if self.infoPanel:getContentType() == type then
		-- FIXME: This will remove selections and other things.
		self.infoPanel:setContent(self.infoPanel:getContentType())
	end
end

function GUI:showYearPanel(instant)
	local y = 0
	if instant then
		self.yearPanel.y = y
	else
		Timer.tween(0.5, self.yearPanel, { y = y }, "in-back")
	end
end

function GUI:hideYearPanel(instant)
	local y = -self.yearPanel:getHeight()
	if instant then
		self.yearPanel.y = y
	else
		Timer.tween(0.5, self.yearPanel, { y = y }, "in-back")
	end
end

--
-- Events
--

function GUI:onAssigned(event)
	-- To avoid caching problems and other oddities, we simply update the resource panel every time.
	local workers = {}

	for resource in pairs(WorkComponent.RESOURCE_TO_WORK) do
		workers[resource] = 0
	end

	for _,entity in pairs(self.engine:getEntitiesWithComponent("AdultComponent")) do
		local resource = WorkComponent.WORK_TO_RESOURCE[entity:get("AdultComponent"):getOccupation()]
		if resource then
			workers[resource] = workers[resource] + 1
		end
	end

	for resource,numWorkers in pairs(workers) do
		self.resourcePanel:setWorkers(resource, numWorkers)
	end
end

function GUI:onUnassigned(event)
	self:onAssigned(event)
end

function GUI:onSelectionChanged(event)
	self.infoPanel:onSelectionChanged(event)
end

--
-- Pseudo events, eh
--

function GUI:onEventsChanged()
	soundManager:playEffect("new_event")

	if self.infoPanel:getContentType() == InfoPanel.CONTENT.LIST_EVENTS then
		self.infoPanel:refresh()
	end
end

--
-- Internal functions
--

function GUI:_closeInfoPanel()
	soundManager:playEffect("drawer_closed")
	self.infoPanel:hide()

	self:updateHint()

	state:showBuildingHeaders(false)
	state:showVillagerHeaders(false)
end

return GUI
