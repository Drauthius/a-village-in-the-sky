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

local Camera = require "lib.hump.camera"
local Timer = require "lib.hump.timer"
local fpsGraph = require "lib.FPSGraph"
local lovetoys = require "lib.lovetoys.lovetoys"
local table = require "lib.table"
local math = require "lib.math"

local Cassette = require "src.game.cassette"
local Background = require "src.game.background"
local GUI = require "src.game.gui"
local Map = require "src.game.map"
local DefaultLevel = require "src.game.level.default"
-- Components
local AssignmentComponent = require "src.game.assignmentcomponent"
local BlinkComponent = require "src.game.blinkcomponent"
local BuildingComponent = require "src.game.buildingcomponent"
local ConstructionComponent = require "src.game.constructioncomponent"
local InteractiveComponent = require "src.game.interactivecomponent"
local PositionComponent = require "src.game.positioncomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local SpriteComponent = require "src.game.spritecomponent"
local TimerComponent = require "src.game.timercomponent"
local WorkComponent = require "src.game.workcomponent"
-- Events
local AssignedEvent = require "src.game.assignedevent"
local GameEvent = require "src.game.gameevent"
local SelectionChangedEvent = require "src.game.selectionchangedevent"
local TileDroppedEvent = require "src.game.tiledroppedevent"
local TilePlacedEvent = require "src.game.tileplacedevent"
local UnassignedEvent = require "src.game.unassignedevent"
local VillagerDeathEvent = require "src.game.villagerdeathevent"
-- Systems
local BuildingSystem
local DebugSystem
local FieldSystem
local ParticleSystem
local PlacingSystem
local PositionSystem
local PregnancySystem
local RenderSystem
local ResourceSystem
local SpriteSystem
local TimerSystem
local VillagerSystem
local WalkingSystem
local WorkSystem

local blueprint = require "src.game.blueprint"
local hint = require "src.game.hint"
local screen = require "src.screen"
local soundManager = require "src.soundmanager"
local state = require "src.game.state"

local Game = {
	-- Requirement to be allowed to listen to events.
	class = { name = "Game" }
}

-- How often to save the game automatically.
Game.AUTOSAVE_TIME = 60

-- Maximum minimisation.
Game.CAMERA_MIN_ZOOM = 0.5
-- Maximum maximisation.
Game.CAMERA_MAX_ZOOM = 10
-- Zoom level before the foreground is visible
Game.FOREGROUND_VISIBLE_ZOOM = 2
-- How transparent the foreground is based on the zoom level.
Game.FOREGROUND_VISIBLE_FACTOR = 1.0

-- Number of squared pixels (in camera space) before interpreting a movement as a drag instead of a click.
Game.CAMERA_DRAG_THRESHOLD = 20
-- Number of squared pixels (in camera space) before interpreting the camera movement as stopped.
Game.CAMERA_EPSILON = 0.05

-- How much each pixel in the world affects the sound volume.
Game.SOUND_POSITION_COEFFICIENT = 30.0
-- How much the camera scale affects the sound volume.
Game.SOUND_SCALE_COEFFICIENT = 3.0
-- How many pixels outside the screen before the sound effects can no longer be heard.
-- Will be multiplied by the camera's scale value.
Game.SOUND_CUTOFF_OFFSET_X = 10.0
Game.SOUND_CUTOFF_OFFSET_Y = 10.0

function Game:init()
	lovetoys.initialize({ debug = true, middleclassPath = "lib.middleclass" })

	-- Needs to be loaded after initialization.
	BuildingSystem = require "src.game.buildingsystem"
	DebugSystem = require "src.game.debugsystem"
	FieldSystem = require "src.game.fieldsystem"
	ParticleSystem = require "src.game.particlesystem"
	PlacingSystem = require "src.game.placingsystem"
	PositionSystem = require "src.game.positionsystem"
	PregnancySystem = require "src.game.pregnancysystem"
	RenderSystem = require "src.game.rendersystem"
	ResourceSystem = require "src.game.resourcesystem"
	SpriteSystem = require "src.game.spritesystem"
	TimerSystem = require "src.game.timersystem"
	VillagerSystem = require "src.game.villagersystem"
	WalkingSystem = require "src.game.walkingsystem"
	WorkSystem = require "src.game.worksystem"
end

function Game:enter(_, profile)
	love.graphics.setBackgroundColor(0.1, 0.5, 1)
	love.filesystem.write("latest", profile)

	self.speed = 1

	-- Flush the state, in case we're jumping between profiles.
	state:initialize()

	-- Set up the map.
	self.map = Map()

	-- Set up the camera.
	self.camera = Camera()
	self.camera:lookAt(0, self.map.halfTileHeight / 2)
	self.camera:zoom(3)

	-- Set up cloud layers.
	self.backgrounds = {
		Background(self.camera, 0.05, 2),
		Background(self.camera, 0.2, 3)
	}
	self.backgrounds[1]:setColor({ 0.8, 0.8, 0.95, 1 })
	self.backgrounds[2]:setColor({ 0.9, 0.9, 1, 1 })
	self.foreground = Background(self.camera, 2, 2)

	self.engine = lovetoys.Engine()
	self.eventManager = lovetoys.EventManager()

	self.worldCanvas = love.graphics.newCanvas(screen:getDrawDimensions())
	self.gui = GUI(self.engine, self.eventManager, self.map)

	-- Systems that listen to events
	local buildingSystem = BuildingSystem(self.engine, self.eventManager)
	local fieldSystem = FieldSystem(self.engine, self.eventManager, self.map)
	local placingSystem = PlacingSystem(self.map)
	local pregnancySystem = PregnancySystem(self.eventManager)
	local renderSystem = RenderSystem()
	local villagerSystem = VillagerSystem(self.engine, self.eventManager, self.map)
	local workSystem = WorkSystem(self.engine, self.eventManager)

	-- Updates
	self.engine:addSystem(fieldSystem, "update")
	self.engine:addSystem(placingSystem, "update")
	self.engine:addSystem(workSystem, "update") -- Must be before the sprite system
	self.engine:addSystem(villagerSystem, "update")
	self.engine:addSystem(pregnancySystem, "update")
	self.engine:addSystem(WalkingSystem(self.engine, self.eventManager, self.map), "update")
	self.engine:addSystem(TimerSystem(), "update") -- Must be before the sprite system...
	self.engine:addSystem(SpriteSystem(self.eventManager), "update")
	self.engine:addSystem(ParticleSystem(self.engine), "update")
	self.engine:addSystem(renderSystem, "update")

	-- Draws
	self.engine:addSystem(renderSystem, "draw")
	self.engine:addSystem(placingSystem, "draw")
	self.engine:addSystem(DebugSystem(self.map), "draw")

	-- Not enabled by default.
	self.engine:toggleSystem("DebugSystem")

	-- Currently only listens to events.
	self.engine:addSystem(buildingSystem, "update")
	self.engine:addSystem(PositionSystem(self.map), "update")
	self.engine:addSystem(ResourceSystem(self.map), "update")
	self.engine:stopSystem("BuildingSystem")
	self.engine:stopSystem("PositionSystem")
	self.engine:stopSystem("ResourceSystem")

	-- Event handling for logging/the player, state handling, and stuff that didn't fit anywhere else.
	self.eventManager:addListener("BuildingCompletedEvent", self, self.onBuildingCompleted)
	self.eventManager:addListener("BuildingRazedEvent", self, self.onBuildingRazed)
	self.eventManager:addListener("ChildbirthEndedEvent", self, self.childbirthEndedEvent)
	self.eventManager:addListener("ChildbirthStartedEvent", self, self.childbirthStartedEvent)
	self.eventManager:addListener("ConstructionCancelledEvent", self, self.onConstructionCancelled)
	self.eventManager:addListener("ResourceDepletedEvent", self, self.onResourceDepleted)
	self.eventManager:addListener("RunestoneUpgradingEvent", self, self.onRunestoneUpgrading)
	self.eventManager:addListener("SelectionChangedEvent", self, self.onSelectionChanged)
	self.eventManager:addListener("VillagerDeathEvent", self, self.onVillagerDeath)

	-- Events between the systems.
	self.eventManager:addListener("AssignedEvent", villagerSystem, villagerSystem.assignedEvent)
	self.eventManager:addListener("BuildingCompletedEvent", buildingSystem, buildingSystem.buildingCompletedEvent)
	self.eventManager:addListener("BuildingEnteredEvent", buildingSystem, buildingSystem.buildingEnteredEvent)
	self.eventManager:addListener("BuildingEnteredEvent", pregnancySystem, pregnancySystem.buildingEnteredEvent)
	self.eventManager:addListener("BuildingEnteredEvent", villagerSystem, villagerSystem.buildingEnteredEvent)
	self.eventManager:addListener("BuildingLeftEvent", buildingSystem, buildingSystem.buildingLeftEvent)
	self.eventManager:addListener("BuildingLeftEvent", villagerSystem, villagerSystem.buildingLeftEvent)
	self.eventManager:addListener("ChildbirthEndedEvent", villagerSystem, villagerSystem.childbirthEndedEvent)
	self.eventManager:addListener("ChildbirthStartedEvent", villagerSystem, villagerSystem.childbirthStartedEvent)
	self.eventManager:addListener("EntityMovedEvent", renderSystem, renderSystem.onEntityMoved)
	self.eventManager:addListener("RunestoneUpgradedEvent", placingSystem, placingSystem.onRunestoneUpgraded)
	self.eventManager:addListener("SelectionChangedEvent", placingSystem, placingSystem.onSelectionChanged)
	self.eventManager:addListener("TargetReachedEvent", villagerSystem, villagerSystem.targetReachedEvent)
	self.eventManager:addListener("TargetUnreachableEvent", villagerSystem, villagerSystem.targetUnreachableEvent)
	self.eventManager:addListener("TileDroppedEvent", renderSystem, renderSystem.onTileDropped)
	self.eventManager:addListener("TilePlacedEvent", renderSystem, renderSystem.onTilePlaced)
	self.eventManager:addListener("UnassignedEvent", villagerSystem, villagerSystem.unassignedEvent)
	self.eventManager:addListener("VillagerAgedEvent", pregnancySystem, pregnancySystem.villagerAgedEvent)
	self.eventManager:addListener("VillagerAgedEvent", villagerSystem, villagerSystem.villagerAgedEvent)
	self.eventManager:addListener("WorkCompletedEvent", villagerSystem, villagerSystem.workCompletedEvent)
	self.eventManager:addListener("WorkEvent", fieldSystem, fieldSystem.workEvent)
	self.eventManager:addListener("WorkEvent", workSystem, workSystem.workEvent)

	-- Event handling by the GUI (after other processing has completed).
	self.eventManager:addListener("AssignedEvent", self.gui, self.gui.onAssigned)
	self.eventManager:addListener("SelectionChangedEvent", self.gui, self.gui.onSelectionChanged)
	self.eventManager:addListener("UnassignedEvent", self.gui, self.gui.onUnassigned)
	-- Other events that can influence/move the tutorial hints
	self.eventManager:addListener("BuildingCompletedEvent", self.gui, self.gui.updateHint)
	--self.eventManager:addListener("SelectionChangedEvent", self.gui, self.gui.updateHint)
	self.eventManager:addListener("VillagerDeathEvent", self.gui, self.gui.updateHint)

	-- This "event" has been hacked in.
	self.engine.onRemoveEntity = function(_, entity)
		self:onRemoveEntity(entity)
	end

	-- Load the game, or create an initial save.
	self.cassette = Cassette(profile)
	if self.cassette:isValid() then
		self.level = self.cassette:load(self.engine, self.map, self.gui)
	else
		-- Set up the level.
		self.level = DefaultLevel(self.engine, self.map, self.gui)
		--self.level = require("src.game.level.hallway")(self.engine, self.map, self.gui)
		--self.level = require("src.game.level.runestone")(self.engine, self.map, self.gui)

		self.level:initial()
		self:_save()
	end
	Timer.every(Game.AUTOSAVE_TIME, function()
		self:_save()
	end)

	self:_updateCameraBoundingBox()
	self.numTouches = 0

	soundManager:setPositionFunction(function(gi, gj)
		local x, y = self.map:gridToWorldCoords(gi + 0.5, gj + 0.5)
		local vpsx, vpsy, vpex, vpey = state:getViewport()
		local ox = Game.SOUND_CUTOFF_OFFSET_X * self.camera.scale
		local oy = Game.SOUND_CUTOFF_OFFSET_Y * self.camera.scale

		local inRange = x >= vpsx - ox and x <= vpex + ox and
						y >= vpsy - oy and y <= vpey + oy
		return inRange, x / Game.SOUND_POSITION_COEFFICIENT, y / Game.SOUND_POSITION_COEFFICIENT
	end)
	self:_updateListenerPosition()

	self.debug = false
	self.fpsGraph = fpsGraph.createGraph()
	self.memGraph = fpsGraph.createGraph(0, 30)
end

function Game:leave()
	self:_save()
	Timer.clear()
end

function Game:quit()
	self:_save()
end

function Game:update(dt)
	fpsGraph.updateFPS(self.fpsGraph, dt)
	fpsGraph.updateMem(self.memGraph, dt)

	local mx, my = screen:getCoordinate(love.mouse.getPosition())
	local dx, dy, dw, dh = screen:getDrawArea()
	state:setMousePosition(self.camera:worldCoords(mx, my, dx, dy, dw, dh))

	local left, top = self.camera:worldCoords(0, 0, dx, dy, dw, dh)
	local right, bottom = self.camera:worldCoords(dw, dh, dx, dy, dw, dh)
	state:setViewport(left, top, right, bottom)

	if self.dragging and self.dragging.dragged then
		self.camera:lockPosition(
				self.dragging.cx,
				self.dragging.cy,
				Camera.smooth.damped(10))
		self:_updateListenerPosition()

		if self.dragging.released and
		   math.abs(self.dragging.cx - self.camera.x)^2 +
		   math.abs(self.dragging.cy - self.camera.y)^2 <= Game.CAMERA_EPSILON then
			-- Clear and release the dragging table, to avoid subpixel camera movement which looks choppy.
			self.dragging = nil
		end
	end

	self.foreground:setZoom(self.camera.scale)
	self.foreground:setColor({
		1, 1, 1,
		math.max(0.0, math.min(0.9, (Game.FOREGROUND_VISIBLE_ZOOM - self.camera.scale) / Game.FOREGROUND_VISIBLE_FACTOR))
	})

	-- Game behaves weirdly when the speed is too great, so better to loop the relevant parts.
	local loops = self.speed
	if loops < 1 then
		dt = dt * loops
		loops = 1
	end
	for _=1,loops do
		if not state:isTimeStopped() then
			state:increaseYear(TimerComponent.YEARS_PER_SECOND * dt)
			state:setYearModifier(math.max(1.0, 6.0 - state:getYear()/15.0))
		end

		Timer.update(dt)
		for _,background in ipairs(self.backgrounds) do
			background:update(dt)
		end
		self.foreground:update(dt)
		self.gui:update(dt)
		self.level:update(dt)
		self.engine:update(dt)
		hint:update(dt)
	end
end

function Game:draw()
	for _,background in ipairs(self.backgrounds) do
		background:draw()
	end

	-- This canvas helps us to differentiate between the backgrounds and the world, making certain alpha tests easier.
	local oldCanvas = love.graphics.getCanvas()
	love.graphics.setCanvas({self.worldCanvas, stencil = true})
	love.graphics.clear(0, 0, 0, 0, true)

	local dx, dy, dw, dh = screen:getDrawArea()
	self.camera:draw(dx, dy, dw, dh, true, function()
		self.engine:draw()

		if hint:isInWorld() then
			hint:draw()
		end

		if self.debug then
			self.map:drawDebug()

			love.graphics.setPointSize(4)
			love.graphics.setColor(1, 0, 0, 1)
			love.graphics.points(0, 0)
			love.graphics.setColor(1, 1, 1, 1)
		end
	end)

	love.graphics.setCanvas({oldCanvas, stencil = true})
	love.graphics.setColor(1, 1, 1)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(self.worldCanvas)
	love.graphics.setBlendMode("alpha")

	self.foreground:draw()

	self.gui:draw(self.camera)
	if not hint:isInWorld() then
		hint:draw()
	end

	if self.debug then
		love.graphics.setLineWidth(1)
		fpsGraph.drawGraphs({ self.fpsGraph, self.memGraph })
	end
end

--
-- Input handling
--

function Game:keyreleased(key, scancode)
	if scancode == "d" then
		self.engine:toggleSystem("DebugSystem")
	elseif scancode == "g" then
		self.debug = not self.debug
	elseif key == "escape" then
		if state:isPlacing() or state:hasSelection() then
			self.eventManager:fireEvent(SelectionChangedEvent(nil))
		else
			self.gui:back()
		end
	elseif scancode == "`" then
		self.speed = 0.5
	elseif scancode == "1" then
		self.speed = 1
	elseif scancode == "2" then
		self.speed = 2
	elseif scancode == "3" then
		self.speed = 5
	elseif scancode == "4" then
		self.speed = 10
	elseif scancode == "5" then
		self.speed = 50
	elseif scancode == "s" then
		print("Saving game...")
		self:_save()
	end
end

function Game:mousepressed(x, y, _, istouch)
	-- If there is already a finger down. This generally shouldn't happen (only one press event for the first finger),
	-- but it might if fingers are moving on and off quickly.
	if istouch and self.dragging and not self.dragging.released then
		return
	end

	local origx, origy = self.camera:position()
	local sx, sy = screen:getCoordinate(x, y)

	-- Don't allow dragging the camera when it starts on a GUI element.
	if self.gui:handlePress(sx, sy, false) then
		return
	end

	self.dragging = {
		-- Original camera coordinates where mouse was pressed (don't change).
		ox = origx, oy = origy,
		-- Original coordinates in screen space.
		sx = sx, sy = sy,
		-- Current camera coordinates.
		cx = origx, cy = origy,
		-- Whether dragging or simply pressing.
		dragged = false,
		-- Whether the mouse has been released.
		released = false
	}
end

function Game:mousemoved(x, y, _, istouch)
	if istouch then
		-- Two fingers down does not count as a drag/move, but as a zoom.
		if self.numTouches > 1 then
			local touches = love.touch.getTouches()
			if not self.pinchDistance or #touches ~= 2 then
				return
			elseif not self.dragging then
				-- This indicates that the first press was on a UI element.
				return
			end

			local x1, y1 = love.touch.getPosition(touches[1])
			local x2, y2 = love.touch.getPosition(touches[2])
			local pinchDistance = math.distance(x1, y1, x2, y2)
			local delta = (pinchDistance - self.pinchDistance) / 200
			if math.abs(delta) > 0.001 then
				self:_zoom(delta, (x1 + x2) / 2, (y1 + y2) / 2)
				self.dragging.dragged = true
			end
			self.pinchDistance = pinchDistance
			return
		end
	end

	if self.dragging and not self.dragging.released then
		local ex, ey = screen:getCoordinate(x, y)
		local newx, newy = self.dragging.sx - ex, self.dragging.sy - ey
		newx, newy = newx / self.camera.scale, newy / self.camera.scale

		local tolerance = Game.CAMERA_DRAG_THRESHOLD
		if not self.dragging.dragged and
		   (self.dragging.sx - ex)^2 + (self.dragging.sy - ey)^2 >= tolerance then
			self.dragging.dragged = true
		end

		local bb = self.cameraBoundingBox
		self.dragging.cx = math.max(bb.xMin, math.min(bb.xMax, self.dragging.ox + newx))
		self.dragging.cy = math.max(bb.yMin, math.min(bb.yMax, self.dragging.oy + newy))
	end
end

function Game:mousereleased(x, y, _, istouch)
	-- This generally shouldn't happen, but it can, if all the touches are released, retouched, and then released
	-- again during the same frame.
	if istouch and #love.touch.getTouches() > 0 then
		return
	end

	x, y = screen:getCoordinate(x, y)

	if not self.dragging or not self.dragging.dragged or self.dragging.released then
		if not self.gui:handlePress(x, y, true) then
			if state:isPlacing() then
				local placing = state:getPlacing()
				if placing:has("TileComponent") then
					self:_placeTile(placing)
				elseif placing:has("BuildingComponent") then
					self:_placeBuilding(placing)
				end
			else
				self:_handleClick(state:getMousePosition())
			end
		end
	end

	if self.dragging then
		self.dragging.released = true
	end
end

function Game:wheelmoved(_, y)
	if y < 0 then
		return self:_zoom(-0.1)
	else
		return self:_zoom(0.1)
	end
end

function Game:touchpressed()
	local touches = love.touch.getTouches()
	self.numTouches = #touches

	if self.numTouches == 2 then
		local x1, y1 = love.touch.getPosition(touches[1])
		local x2, y2 = love.touch.getPosition(touches[2])
		self.pinchDistance = math.distance(x1, y1, x2, y2)
	else
		self.pinchDistance = nil
	end
end

function Game:touchreleased()
	if self.numTouches > 1 and self.dragging and not self.dragging.released then
		self.dragging.ox, self.dragging.oy = self.camera:position()
		self.dragging.cx, self.dragging.cy = self.camera:position()

		-- There can be no touches left if multiple fingers are released the same frame.
		local touches = love.touch.getTouches()
		if next(touches) then
			self.dragging.sx, self.dragging.sy = screen:getCoordinate(love.touch.getPosition(touches[1]))
		else
			self.dragging.released = true
		end
	end

	-- Update the pinch distance.
	self:touchpressed()
end

function Game:resize()
	self.gui:resize(screen:getDrawDimensions())

	self:_updateCameraBoundingBox()

	local bb = self.cameraBoundingBox
	self.camera.x = math.max(bb.xMin, math.min(bb.xMax, self.camera.x))
	self.camera.y = math.max(bb.yMin, math.min(bb.yMax, self.camera.y))
	self.dragging = nil

	-- The world canvas needs to be recreated.
	self.worldCanvas = love.graphics.newCanvas(screen:getDrawDimensions())

	-- TODO: Clouds depend on draw area.
end

function Game:focus(focused)
	-- Focus is lost on mobile when switching out of the app.
	if not focused then
		self:_save()
	end
end

function Game:fastforward(fastforward)
	self.speed = fastforward and 3 or 1
end

--
-- Internal functions
--

function Game:_handleClick(x, y)
	--print(self.map:worldToGridCoords(x, y))

	local clicked, clickedIndex = nil, 0
	for _,entity in pairs(self.engine:getEntitiesWithComponent("InteractiveComponent")) do
		local index = assert(entity:get("SpriteComponent"):getDrawIndex(),
		                     "Draw index missing for entity "..tostring(entity).."with sprite component.")
		if index > clickedIndex and entity:get("InteractiveComponent"):isWithin(x, y) then
			local dx, dy = entity:get("SpriteComponent"):getDrawPosition()
			-- Cast a bit wider net than single pixel.
			for ox in ipairs({ 0, 1, -1 }) do
				for oy in ipairs({0, 1, -1}) do
					if select(4, entity:get("SpriteComponent"):getSprite():getPixel(x - dx + ox, y - dy + oy)) > 0.1 then
						clicked = entity
						clickedIndex = index
						break
					end
				end

				if clicked == entity then
					break
				end
			end
		end
	end

	if not clicked then
		if state:hasSelection() then
			return self.eventManager:fireEvent(SelectionChangedEvent(nil))
		end
		return
	end

	local selected = state:getSelection()
	if selected and selected:has("AdultComponent") and clicked:has("AssignmentComponent") then
		if clicked:has("FieldComponent") then
			print("Managed to click the field, eh?")
			clicked = clicked:get("FieldComponent"):getEnclosure()
		end

		local assignment = clicked:get("AssignmentComponent")
		local alreadyAdded = assignment:isAssigned(selected)
		local valid = alreadyAdded or assignment:getNumAssignees() < assignment:getMaxAssignees()
		local skipWorkPlace = false

		if not valid and clicked:has("WorkComponent") then
			-- Assign to work the grid instead of to the specific resource.
			valid = true
			skipWorkPlace = true
		end

		if valid and
		   not selected:get("VillagerComponent"):getHome() and
		   not clicked:has("DwellingComponent") and
		   not clicked:has("ConstructionComponent") then
			-- Only allowed to build or be assigned a home while homeless.
			valid = false
		end

		if valid then
			if not skipWorkPlace then
				assignment:assign(selected)
			end

			if not alreadyAdded then
				self.eventManager:fireEvent(AssignedEvent(clicked, selected))
			end

			soundManager:playEffect("successful_assignment") -- TODO: Different sounds per assigned occupation?
			BlinkComponent:makeBlinking(clicked, { 0.15, 0.70, 0.15, 1.0 }) -- TODO: Colour value
		else
			soundManager:playEffect("failed_assignment")
			BlinkComponent:makeBlinking(clicked, { 0.70, 0.15, 0.15, 1.0 }) -- TODO: Colour value
		end
	else
		self.eventManager:fireEvent(SelectionChangedEvent(clicked))
	end
end

function Game:_zoom(dz, mx, my)
	local oldScale = self.camera.scale

	if dz < 0 and oldScale <= Game.CAMERA_MIN_ZOOM then
		return
	elseif dz > 0 and oldScale >= Game.CAMERA_MAX_ZOOM then
		return
	end

	self.camera:zoomTo(self.camera.scale * (1 + dz))
	self.camera.scale = math.min(Game.CAMERA_MAX_ZOOM, math.max(Game.CAMERA_MIN_ZOOM, self.camera.scale))

	if self.camera.scale ~= oldScale then
		if not mx or not my then
			mx, my = screen:getCoordinate(love.mouse.getPosition())
		end
		local w, h = screen:getDrawDimensions()
		local diffx, diffy = mx - w/2, my - h/2
		local newScale = self.camera.scale

		self:_updateCameraBoundingBox()
		local bb = self.cameraBoundingBox

		local dx, dy = diffx / newScale * (newScale / oldScale - 1), diffy / newScale * (newScale / oldScale - 1)

		if self.dragging then
			-- Change the position to where the camera is going, to avoid jumps
			self.dragging.cx = math.max(bb.xMin, math.min(bb.xMax, self.dragging.cx + dx))
			self.dragging.cy = math.max(bb.yMin, math.min(bb.yMax, self.dragging.cy + dy))
		end

		self.camera.x = math.max(bb.xMin, math.min(bb.xMax, self.camera.x + dx))
		self.camera.y = math.max(bb.yMin, math.min(bb.yMax, self.camera.y + dy))

		self:_updateListenerPosition()
	end
end

function Game:_placeTile(placing)
	placing:remove("PlacingComponent")
	local ti, tj = placing:get("TileComponent"):getPosition()
	self.map:addTile(placing:get("TileComponent"):getType(), ti, tj)

	local trees, iron = self.level:getResources(placing:get("TileComponent"):getType())

	--print("Will spawn "..tostring(trees).." trees and "..tostring(iron).." iron")

	local sgi, sgj = ti * self.map.gridsPerTile, tj * self.map.gridsPerTile
	local egi, egj = sgi + self.map.gridsPerTile, sgj + self.map.gridsPerTile

	local resources = {}

	if self.level:shouldPlaceRunestone(ti, tj) then
		local runestone = blueprint:createRunestone()
		local ax, ay, minGrid, maxGrid = self.map:addObject(runestone, ti, tj)
		assert(ax and ay and minGrid and maxGrid, "Could not add runestone to empty tile.")
		runestone:get("SpriteComponent"):setDrawPosition(ax, ay)
		runestone:add(PositionComponent(minGrid, maxGrid, ti, tj))
		InteractiveComponent:makeInteractive(runestone, ax, ay)
		self.engine:addEntity(runestone)
		table.insert(resources, runestone)
	end

	-- Resources
	for i=1,trees+iron do
		local resource
		if i <= trees then
			resource = blueprint:createTree()
		else
			resource = blueprint:createIron()
		end
		for _=1,1000 do -- lol
			local gi, gj = love.math.random(sgi + 1, egi - 1), love.math.random(sgj + 1, egj - 1)
			local ax, ay, minGrid, maxGrid = self.map:addObject(resource, gi, gj)
			if ax then
				resource:get("SpriteComponent"):setDrawPosition(ax, ay)
				resource:add(PositionComponent(minGrid, maxGrid, ti, tj))
				resource:add(AssignmentComponent(1))
				InteractiveComponent:makeInteractive(resource, ax, ay)
				self.engine:addEntity(resource)
				table.insert(resources, resource)
				resource = nil
				break
			end
		end

		if resource then
			print("Could not add object.")
		end
	end

	-- DROP
	for _,resource in ipairs(resources) do
		local sprite = resource:get("SpriteComponent")
		local dest = sprite.y
		sprite.y = sprite.y - 10
		Timer.tween(0.15, sprite, { y = dest }, "in-bounce")
	end

	-- DUST
	local halfgi, halfgj = sgi + self.map.gridsPerTile/2, sgj + self.map.gridsPerTile/2
	for _,dir in ipairs({ "SE", "SW", "NE", "NW" }) do
		local dust = blueprint:createDustParticle(dir)

		local gi, gj, dx, dy
		if dir == "SE" then
			gi, gj = egi - 1, halfgj
			dx, dy = 1, 1
		elseif dir == "SW" then
			gi, gj = halfgi, egj - 1
			dx, dy = -1, 1
		elseif dir == "NE" then
			gi, gj = halfgi, sgj
			dx, dy = 1, -1
		elseif dir == "NW" then
			gi, gj = sgi, halfgj
			dx, dy = -1, -1
		end

		dust:set(PositionComponent(self.map:getGrid(gi, gj), nil, self.map:gridToTileCoords(gi, gj)))
		dust:get("SpriteComponent"):setDrawPosition(self.map:gridToWorldCoords(gi + dx * 2, gj + dy * 2))
		self.engine:addEntity(dust)
	end

	local sprite = placing:get("SpriteComponent")
	sprite:resetColor()
	local dest = sprite.y
	sprite.y = sprite.y - 10

	Timer.tween(0.15, sprite, { y = dest }, "in-bounce", function()
		-- Tile has come to rest.
		soundManager:playEffect("tile_placed", sgi + self.map.gridsPerTile / 2, sgj + self.map.gridsPerTile / 2)
		self.eventManager:fireEvent(TilePlacedEvent(placing))

		-- Screen shake
		local orig_x, orig_y = self.camera:position()
		Timer.during(0.10, function()
			self.camera:lookAt(orig_x + math.random(-2,2), orig_y + math.random(-4,4))
		end, function()
			-- reset camera position
			self.camera:lookAt(orig_x, orig_y)
		end)
	end)

	-- Clear the state.
	state:clearPlacing()

	-- Update camera bounds.
	self:_updateCameraBoundingBox()

	-- Notify other parties.
	self.eventManager:fireEvent(SelectionChangedEvent(nil, true))
	self.eventManager:fireEvent(TileDroppedEvent(placing))
end

function Game:_placeBuilding(placing)
	local ax, ay, minGrid, maxGrid = self.map:addObject(placing, placing:get("BuildingComponent"):getPosition())
	assert(ax and ay and minGrid and maxGrid, "Could not add building with building component.")

	local ti, tj = self.map:gridToTileCoords(minGrid.gi, minGrid.gj)
	placing:get("SpriteComponent"):setDrawPosition(ax, ay)
	placing:get("SpriteComponent"):resetColor()
	placing:add(PositionComponent(minGrid, maxGrid, ti, tj))
	placing:add(ConstructionComponent(placing:get("PlacingComponent"):getType()))
	placing:add(AssignmentComponent(4))
	InteractiveComponent:makeInteractive(placing, ax, ay)

	placing:remove("PlacingComponent")

	-- DROP
	local sprite = placing:get("SpriteComponent")
	sprite:resetColor()
	local dest = sprite.y
	sprite.y = sprite.y - 4
	Timer.tween(0.11, sprite, { y = dest }, "in-back", function()
		-- Building has come to rest.
		soundManager:playEffect(
			"building_placed",
			minGrid.gi + (maxGrid.gi - minGrid.gi) / 2,
			minGrid.gj + (maxGrid.gj - minGrid.gj) / 2)
	end)

	-- DUST
	local halfgi = minGrid.gi + math.floor((maxGrid.gi - minGrid.gi)/2)
	local halfgj = minGrid.gj + math.floor((maxGrid.gj - minGrid.gj)/2)
	for _,dir in ipairs({ "SE", "SW", "NE", "NW" }) do
		local dust = blueprint:createDustParticle(dir, true)

		local gi, gj
		if dir == "SE" then
			gi, gj = maxGrid.gi, halfgj
		elseif dir == "SW" then
			gi, gj = halfgi, maxGrid.gj
		elseif dir == "NE" then
			gi, gj = halfgi, minGrid.gj
		elseif dir == "NW" then
			gi, gj = minGrid.gi, halfgj
		end

		dust:set(PositionComponent((assert(self.map:getGrid(gi, gj), ("(%d,%d) is outside of the map"):format(gi, gj))), nil,
		                           ti, tj))
		dust:get("SpriteComponent"):setDrawPosition(self.map:gridToWorldCoords(gi, gj))
		self.engine:addEntity(dust)
	end

	-- Clear the state.
	state:clearPlacing()

	-- Notify other parties.
	self.eventManager:fireEvent(SelectionChangedEvent(nil, true))
end

--- Update `self.cameraBoundingBox` with the minimum and maximum position of the camera, in world coords,
-- based on the placed tiles.
function Game:_updateCameraBoundingBox()
	-- The tip of every corner, sort of.
	local _, yMin = self.map:tileToWorldCoords(self.map.firstTile[1], self.map.firstTile[2])
	local xMin, _ = self.map:tileToWorldCoords(self.map.firstTile[1], self.map.lastTile[2] + 1)
	local _, yMax = self.map:tileToWorldCoords(self.map.lastTile[1] + 1, self.map.lastTile[2] + 1)
	local xMax, _ = self.map:tileToWorldCoords(self.map.lastTile[1] + 1, self.map.firstTile[2])

	local scale = self.camera.scale
	-- Offset, so a little bit of the tile can be seen.
	local ox = -5 * scale
	local oy = ox
	local _, _, dw, dh = screen:getDrawArea()
	-- Allow the camera (centre of the screen) to be half a screen away.
	local w2, h2 = dw / 2 + ox, dh / 2 + oy
	xMin, yMin = xMin - w2 / scale, yMin - h2 / scale
	xMax, yMax = xMax + w2 / scale, yMax + h2 / scale

	self.cameraBoundingBox = {
		xMin = xMin,
		xMax = xMax,
		yMin = yMin,
		yMax = yMax
	}
end

-- Handles both the razing and cancellations of buildings and runestones.
function Game:_removeBuilding(building)
	local isUnderConstruction = building:has("ConstructionComponent")
	local isRunestone = building:has("RunestoneComponent")

	local grids
	if isRunestone then
		-- Runestones drop the refunded resources on adjacent grids.
		-- The adjacent grids needs a bit of massaging, since they include a rotation.
		grids = {}
		for _,grid in ipairs(self.map:getAdjacentGrids(building, true)) do
			table.insert(grids, grid[1])
		end
	else
		-- Buildings are blown up, and the resources dropped where it stood.
		grids = self.map:getOwnedGrids(building)
		-- The building has to be removed before resources are placed in its stead.
		self.map:remove(building)
	end

	-- Refund any materials.
	local refund
	if isUnderConstruction then
		refund = building:get("ConstructionComponent"):getRefundedResources()
	else
		refund = ConstructionComponent:getRefundedResources(building:get("BuildingComponent"):getType())
	end
	for resource,amount in pairs(refund) do
		while amount > 0 do
			local grid

			if next(grids) then
				grid = table.remove(grids, love.math.random(1, #grids))
			else
				-- Fall back to the normal placement of resources in case there is no room adjacent.
				local ti, tj = building:get("PositionComponent"):getTile()
				grid = self.map:getFreeGrid(ti, tj, resource)
			end

			if grid then
				local resourceEntity = blueprint:createResourcePile(resource, math.min(3, amount))
				self.map:addResource(resourceEntity, grid, true)
				resourceEntity:add(PositionComponent(grid, nil, self.map:gridToTileCoords(grid.gi, grid.gj)))
				self.engine:addEntity(resourceEntity)

				amount = amount - resourceEntity:get("ResourceComponent"):getResourceAmount()
			else
				print("Resource thrown off the side due to space constraints")
				break
			end
		end
	end

	for _,villager in ipairs(building:get("BuildingComponent"):getInside()) do
		assert(not isRunestone)

		local grid
		if next(grids) then
			grid = table.remove(grids, love.math.random(1, #grids))
		else
			-- Fall back to the normal placement of "resources" in case there is no room adjacent.
			local ti, tj = building:get("PositionComponent"):getTile()
			grid = self.map:getFreeGrid(ti, tj, "villager")
		end

		if grid then
			-- XXX: A bit too much logic here
			villager:get("VillagerComponent"):setIsHome(false) -- Most likely
			-- Place the villager on the grid.
			villager:add(PositionComponent(grid, nil, self.map:gridToTileCoords(grid.gi, grid.gj)))
			villager:get("GroundComponent"):setPosition(self.map:gridToGroundCoords(grid.gi + 0.5, grid.gj + 0.5))
			villager:add(SpriteComponent()) -- Must be added after the position component.
		else
			print("Villager thrown off the side due to space constraints")
			self.engine:removeEntity(villager, true)
		end
	end

	-- Unassign all the affected villagers.
	-- (After kicking them out.)
	-- NOTE: The assignee list is modified by the villager system.
	for _,assignee in ipairs(table.clone(building:get("AssignmentComponent"):getAssignees())) do
		self.eventManager:fireEvent(UnassignedEvent(building, assignee))
	end
	-- Unassign all the children.
	if building:has("DwellingComponent") then
		-- NOTE: The children list is modified by the villager system.
		for _,child in ipairs(table.clone(building:get("DwellingComponent"):getChildren())) do
			self.eventManager:fireEvent(UnassignedEvent(building, child))
		end
	end

	local from, to = building:get("PositionComponent"):getFromGrid(), building:get("PositionComponent"):getToGrid()
	soundManager:playEffect(
		"building_razed",
		from.gi + (to.gi - from.gi) / 2,
		from.gj + (to.gj - from.gj) / 2)

	if isRunestone then
		building:remove("ConstructionComponent")
		building:remove("AssignmentComponent")
		building:get("SpriteComponent"):setNeedsRefresh(true)
	else
		self.engine:removeEntity(building, true)
	end
end

function Game:_save()
	self.cassette:save(self.engine, self.map, self.level)
end

function Game:_updateListenerPosition()
	love.audio.setPosition(self.camera.x / Game.SOUND_POSITION_COEFFICIENT,
	                       self.camera.y / Game.SOUND_POSITION_COEFFICIENT,
	                       Game.SOUND_SCALE_COEFFICIENT / self.camera.scale)
end

--
-- Events
--

function Game:childbirthStartedEvent(event)
	print("Childbirth started")
end

function Game:childbirthEndedEvent(event)
	local villager = event:getMother():get("VillagerComponent")
	local mother = villager:getName()
	local father = event:getFather() and event:getFather():get("VillagerComponent"):getName()

	local ti, tj
	if villager:getHome() then
		ti, tj = villager:getHome():get("PositionComponent"):getTile()
	else
		ti, tj = event:getMother():get("PositionComponent"):getTile()
	end

	if event:didChildSurvive() then
		state:addEvent(GameEvent(GameEvent.TYPES.CHILD_BORN, ti, tj, ("%s%s has had a child."):format(
			father and (father.." and ") or "", mother)))

		local numVillagers = state:getNumMaleVillagers() + state:getNumFemaleVillager() +
		                     state:getNumMaleChildren() + state:getNumFemaleChildren()
		if numVillagers % 50 == 0 and state:getLastPopulationEvent() < numVillagers then
			state:setLastPopulationEvent(numVillagers)
			state:addEvent(GameEvent(GameEvent.TYPES.POPULATION, 0, 0, ("%d villagers now call your village their home."):format(
				numVillagers)))
		end
	else
		state:addEvent(GameEvent(GameEvent.TYPES.CHILD_DEATH, ti, tj, ("%s%s's baby died in childbirth."):format(
			father and (father.."'s and ") or "", mother)))
	end

	-- Mother death is handled elsewhere.

	self.gui:onEventsChanged()
end

function Game:onBuildingCompleted(event)
	local ti, tj = event:getBuilding():get("PositionComponent"):getTile()
	state:addEvent(GameEvent(GameEvent.TYPES.BUILDING_COMPLETE, ti, tj, ("A %s has been %s."):format(
		BuildingComponent.BUILDING_NAME[event:getBuilding():get("BuildingComponent"):getType()],
		event:getBuilding():get("BuildingComponent"):getType() == BuildingComponent.RUNESTONE and "upgraded" or "built")))

	self.gui:onEventsChanged()
end

function Game:onBuildingRazed(event)
	self:_removeBuilding(event:getBuilding())
end

function Game:onConstructionCancelled(event)
	self:_removeBuilding(event:getBuilding())
end

function Game:onResourceDepleted(event)
	local ti, tj = event:getTile()
	local resource = event:getResource()

	state:addEvent(GameEvent(
		resource == ResourceComponent.WOOD and GameEvent.TYPES.WOOD_DEPLETED or GameEvent.TYPES.IRON_DEPLETED,
		ti, tj, ("A %s resource has been depleted."):format(ResourceComponent.RESOURCE_NAME[resource])))

	self.gui:onEventsChanged()
end

function Game:onRunestoneUpgrading(event)
	local runestone = event:getRunestone()

	runestone:add(ConstructionComponent(BuildingComponent.RUNESTONE, runestone:get("RunestoneComponent"):getLevel()))
	runestone:add(AssignmentComponent(4))
	runestone:get("SpriteComponent"):setNeedsRefresh(true)
end

function Game:onSelectionChanged(event)
	local selection = event:getSelection()
	local isPlacing = event:isPlacing()

	-- If selecting an event, move the camera there.
	if selection and selection:isInstanceOf(GameEvent) then
		local ti, tj = selection:getTile()
		if ti and tj then
			local x, y = self.map:tileToWorldCoords(ti + 0.5, tj + 0.5)
			-- Mimic a drag event, so that the camera moves to the desired position smoothly.
			self.dragging = {
				cx = x,
				cy = y,
				released = true,
				dragged = true
			}
		end
		return
	end

	-- Make sure that to clear any potential placing piece before adding another one, or selecting something else.
	if state:isPlacing() then
		soundManager:playEffect("placing_cleared")
		self.engine:removeEntity(state:getPlacing(), true)
		state:clearPlacing()
	end

	if selection then
		if isPlacing then
			self.engine:addEntity(selection)
			state:setPlacing(selection)
			state:clearSelection()
		else
			soundManager:playEffect("selecting") -- TODO: Different sounds depending on what is selected.
			state:setSelection(selection)
		end
	elseif state:hasSelection() then
		soundManager:playEffect("clear_selection")
		state:clearSelection()
	end
end

local _deathReasons
function Game:onVillagerDeath(event)
	local entity = event:getVillager()
	local villager = entity:get("VillagerComponent")
	local occupation = entity:has("AdultComponent") and
	                   WorkComponent.WORK_NAME[entity:get("AdultComponent"):getOccupation()] or
	                   "child"

	local ti, tj
	if villager:getHome() then
		ti, tj = villager:getHome():get("PositionComponent"):getTile()
	else
		ti, tj = entity:get("PositionComponent"):getTile()
	end

	_deathReasons = _deathReasons or {
		[VillagerDeathEvent.REASONS.AGE] = "due to old age",
		[VillagerDeathEvent.REASONS.STARVATION] = "due to starvation",
		[VillagerDeathEvent.REASONS.CHILDBIRTH] = "in childbirth"
	}

	state:addEvent(GameEvent(GameEvent.TYPES.VILLAGER_DEATH, ti, tj, ("%s the %s died at the age of %d %s."):format(
		villager:getName(),
		occupation,
		villager:getAge(),
		_deathReasons[event:getReason()])))

	self.gui:onEventsChanged()
end

function Game:onRemoveEntity(entity)
	if state:getSelection() == entity and not state:isPlacing() then
		self.eventManager:fireEvent(SelectionChangedEvent(nil))
	end
end

return Game
