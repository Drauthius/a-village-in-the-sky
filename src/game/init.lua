-- Directive:
--  - Get the game play in, taking time to fix other things around when the need or fancy arises.
-- TODO:
--  - Bugs:
--    * Villagers can get stuck in a four-grid gridlock.
--    * Villagers heading the exact opposite direction can get stuck in a two-grid gridlock.
--    * Removing a villager from a production job can leave resources "locked in limbo".
--      The same goes for building jobs.
--    * Display bug with the bottom panel???
--    * Villagers standing on a reserved grid can rotate around spastically trying to find a way to move.
--    * Freeing of dead villagers is not handled properly.
--  - Next:
--    * Scale work time based on year (faster early on, slower later)
--    * Proper fonts and font creation.
--      Convert TTF to BMFont for crisp pixel graphics.
--      Fallback fonts.
--    * Unselect things (in the GUI/detailspanel) that disappear (e.g. villager dies, building destroyed).
--    * Tutorial mode.
--      Show objectives panel.
--      Options:
--        - Passage of time
--          Year count increasing
--          Year panel shown
--        - Homeless indicator
--          Hide icon
--        - Tile selection
--          Limit to grass tile initially
--        - Building selection
--          Limit to dwelling initially
--      Different buttons/things need to "glow" to show what needs to be pressed to achieve the objective.
--    * Indicator for building cost
--      Either populate the details panel when hovering/selecting, or add small indicators next to the choices.
--      - Small indicators might be hard to read/see on mobile.
--      + Small indicators avoid having to click on the different things to see what they require.
--    * Selecting a runestone:
--      Shows the increased area of influence if upgraded/during upgrade?
--    * Construction header
--      Show needed/committed resources in the header and/or details panel.
--    * Cancelling/destroying buildings.
--      Refund some resources.
--      Handle assigned villagers.
--    * Building header
--      Show icon for the type of building?
--      Show stored resources in the header and/or details panel?
--      Show completion in the header and/or details panel?
--        This can probably be done by using a circle thingy around the assigned villagers in the header.
--    * Level stuff
--      Runestones can appear at certain positions.
--      Trees can appear on grass tiles.
--  - Refactoring:
--    * There is little reason to have the VillagerComponent be called "VillagerComponent", other than symmetry.
--    * Either consolidate production/construction components (wrt input), or maybe add an "input" component?
--    * Calling variables for "entity" in different contexts begs for trouble.
--    * Definition/specification for buildings is split into multiple files, making it hard to add new ones.
--  - Particles:
--    * "Button is next" for the tutorial.
--  - More sprites:
--    * Event button has a new event (maybe just want to add a text number?).
--    * Pressed/down layer.
--    * New blacksmith building.
--    * More villager fixes
--      - Shading when walking is off (for children at least).
--      - Shadows for when villagers are carrying stuff.
--  - Controls:
--    * Assigning/selecting through double tap or hold?
--      The details panel must have a "Deselect/Cancel/Close" button/icon so
--      that villagers can be easily deselected.
--  - Placing:
--    * Indicators of valid positions (blue)
--    * Placing runestones
--  - Info panel updates:
--    * Make the info panel title bar thicker, and put the name there + a button to
--      minimize/maximize.
--    * Building selection
--    * Villager selection
--    * Events
--  - Details panel:
--    * Fill up details panel with correct information
--      Villager stuff, wait with other things.
--    * Runestone
--      Cost to upgrade.
--      Refund if cancelled.
--      Confirmation dialogue when cancelling.
--  - Localization:
--    * Font support
--    * Details panel
--  - Nice to have:
--    * Don't increase opacity for overlapping shadows.
--    * Quads are created on demand. Problem?
--    * Villagers pushing another villager that is pushing another villager will end up with the first villager
--      abandoning the attempt.
--    * Clouds are a bit rough (sprites and particle system can remove sprites instantly).
--    * Draw placing tile behind other tiles?
--    * Villagers going diagonally are sometimes drawn behind.
--      They're too wide for the grids.
--    * Dedicated ghost/phantom sprite for death animation.

local Camera = require "lib.hump.camera"
local Timer = require "lib.hump.timer"
local lovetoys = require "lib.lovetoys.lovetoys"
local fpsGraph = require "lib.FPSGraph"

local Background = require "src.game.background"
local GUI = require "src.game.gui"
local Map = require "src.game.map"
local DefaultLevel = require "src.game.level.default"
-- Components
local AssignmentComponent = require "src.game.assignmentcomponent"
local BlinkComponent = require "src.game.blinkcomponent"
local ConstructionComponent = require "src.game.constructioncomponent"
local InteractiveComponent = require "src.game.interactivecomponent"
local PositionComponent = require "src.game.positioncomponent"
local TimerComponent = require "src.game.timercomponent"
-- Events
local AssignedEvent = require "src.game.assignedevent"
local SelectionChangedEvent = require "src.game.selectionchangedevent"
local TileDroppedEvent = require "src.game.tiledroppedevent"
local TilePlacedEvent = require "src.game.tileplacedevent"
-- Systems
local BuildingSystem
local DebugSystem
local FieldSystem
local ParticleSystem
local PlacingSystem
local PositionSystem
local PregnancySystem
local RenderSystem
local SpriteSystem
local TimerSystem
local VillagerSystem
local WalkingSystem
local WorkSystem

local blueprint = require "src.game.blueprint"
local screen = require "src.screen"
local soundManager = require "src.soundmanager"
local state = require "src.game.state"

local Game = {
	-- Requirement to be allowed to listen to events.
	class = { name = "Game" }
}

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

function Game:init()
	lovetoys.initialize({ debug = true, middleclassPath = "lib.middleclass" })

	-- Needs to be created after initialization.
	BuildingSystem = require "src.game.buildingsystem"
	DebugSystem = require "src.game.debugsystem"
	FieldSystem = require "src.game.fieldsystem"
	ParticleSystem = require "src.game.particlesystem"
	PlacingSystem = require "src.game.placingsystem"
	PositionSystem = require "src.game.positionsystem"
	PregnancySystem = require "src.game.pregnancysystem"
	RenderSystem = require "src.game.rendersystem"
	SpriteSystem = require "src.game.spritesystem"
	TimerSystem = require "src.game.timersystem"
	VillagerSystem = require "src.game.villagersystem"
	WalkingSystem = require "src.game.walkingsystem"
	WorkSystem = require "src.game.worksystem"
end

function Game:enter()
	love.graphics.setBackgroundColor(0.1, 0.5, 1)

	self.speed = 1

	-- Set up the camera.
	self.camera = Camera()
	self.camera:lookAt(0, 0)
	self.camera:zoom(3)

	self.map = Map()
	self.level = DefaultLevel()
	--self.level = require("src.game.level.hallway")()
	--self.level = require("src.game.level.runestones")()
	self.backgrounds = {
		Background(self.camera, 0.05, 2),
		Background(self.camera, 0.2, 3)
	}
	self.backgrounds[1]:setColor({ 0.8, 0.8, 0.95, 1 })
	self.backgrounds[2]:setColor({ 0.9, 0.9, 1, 1 })
	self.foreground = Background(self.camera, 2, 2)

	self.engine = lovetoys.Engine()
	self.eventManager = lovetoys.EventManager()

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
	self.engine:stopSystem("BuildingSystem")
	self.engine:stopSystem("PositionSystem")

	-- Event handling for logging/the player.
	self.eventManager:addListener("ChildbirthStartedEvent", self, self.childbirthStartedEvent)
	self.eventManager:addListener("ChildbirthEndedEvent", self, self.childbirthEndedEvent)

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

	self.worldCanvas = love.graphics.newCanvas()
	self.gui = GUI(self.engine, self.eventManager, self.map)

	self.level:initiate(self.engine, self.map)

	self:_updateCameraBoundingBox()

	self.fpsGraph = fpsGraph.createGraph()
	self.memGraph = fpsGraph.createGraph(0, 30)
end

function Game:update(dt)
	fpsGraph.updateFPS(self.fpsGraph, dt)
	fpsGraph.updateMem(self.memGraph, dt)

	local mx, my = screen:getCoordinate(love.mouse.getPosition())
	local drawArea = screen:getDrawArea()
	state:setMousePosition(self.camera:worldCoords(mx, my, drawArea.x, drawArea.y, drawArea.width, drawArea.height))

	local left, top = self.camera:worldCoords(0, 0,
	                                          drawArea.x, drawArea.y, drawArea.width, drawArea.height)
	local right, bottom = self.camera:worldCoords(drawArea.width, drawArea.height,
	                                              drawArea.x, drawArea.y, drawArea.width, drawArea.height)
	state:setViewport(left, top, right, bottom)

	if self.dragging and self.dragging.dragged then
		self.camera:lockPosition(
				self.dragging.cx,
				self.dragging.cy,
				Camera.smooth.damped(10))
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
		state:increaseYear(TimerComponent.YEARS_PER_SECOND * dt)

		Timer.update(dt)
		for _,background in ipairs(self.backgrounds) do
			background:update(dt)
		end
		self.foreground:update(dt)
		self.gui:update(dt)
		self.engine:update(dt)
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

	local drawArea = screen:getDrawArea()
	self.camera:draw(drawArea.x, drawArea.y, drawArea.width, drawArea.height, function()
		self.engine:draw()

		if self.debug then
			self.map:drawDebug()

			love.graphics.setPointSize(4)
			love.graphics.setColor(1, 0, 0, 1)
			love.graphics.points(0, 0)
			love.graphics.setColor(1, 1, 1, 1)
		end
	end)

	love.graphics.setCanvas(oldCanvas)
	love.graphics.setColor(1, 1, 1)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(self.worldCanvas)
	love.graphics.setBlendMode("alpha")

	self.foreground:draw()

	self.gui:draw(self.camera)

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
	elseif scancode == "escape" then
		self.gui:back()
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
	end
end

function Game:mousepressed(x, y)
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

function Game:mousemoved(x, y)
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

function Game:mousereleased(x, y)
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
	local oldScale = self.camera.scale

	if y < 0 then
		if oldScale >= Game.CAMERA_MIN_ZOOM then
			self.camera:zoom(0.9)
		end
	elseif y > 0 then
		if oldScale <= Game.CAMERA_MAX_ZOOM then
			self.camera:zoom(1.1)
		end
	end

	if self.camera.scale ~= oldScale then
		local mx, my = screen:getCoordinate(love.mouse.getPosition())
		local w, h = screen:getDimensions()
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
	end
end

--
-- Internal functions
--

function Game:_handleClick(x, y)
	--print(self.map:worldToGridCoords(x, y))

	local clicked, clickedIndex = nil, 0
	for _,entity in pairs(self.engine:getEntitiesWithComponent("InteractiveComponent")) do
		local index = entity:get("SpriteComponent"):getDrawIndex()
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
		soundManager:playEffect("clearSelection")
		state:clearSelection()
		self.eventManager:fireEvent(SelectionChangedEvent(nil))
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

			soundManager:playEffect("successfulAssignment") -- TODO: Different sounds per assigned occupation?
			BlinkComponent:makeBlinking(clicked, { 0.15, 0.70, 0.15, 1.0 }) -- TODO: Colour value
		else
			soundManager:playEffect("failedAssignment")
			BlinkComponent:makeBlinking(clicked, { 0.70, 0.15, 0.15, 1.0 }) -- TODO: Colour value
		end
	else
		soundManager:playEffect("selecting") -- TODO: Different sounds depending on what is selected.
		state:setSelection(clicked)
		self.eventManager:fireEvent(SelectionChangedEvent(clicked))
	end
end

function Game:_placeTile(placing)
	soundManager:playEffect("tilePlaced") -- TODO: Type?

	placing:remove("PlacingComponent")
	local ti, tj = placing:get("TileComponent"):getPosition()
	self.map:addTile(placing:get("TileComponent"):getType(), ti, tj)

	local trees, iron = self.level:getResources(placing:get("TileComponent"):getType())

	--print("Will spawn "..tostring(trees).." trees and "..tostring(iron).." iron")

	local sgi, sgj = ti * self.map.gridsPerTile, tj * self.map.gridsPerTile
	local egi, egj = sgi + self.map.gridsPerTile, sgj + self.map.gridsPerTile

	local resources = {}

	if self.level:shouldPlaceRunestone() then
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

	-- Notify GUI to update its state.
	self.gui:placed()
	-- Update camera bounds.
	self:_updateCameraBoundingBox()

	-- Notify other parties.
	self.eventManager:fireEvent(TileDroppedEvent(placing))
end

function Game:_placeBuilding(placing)
	soundManager:playEffect("buildingPlaced") -- TODO: Type?

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
	Timer.tween(0.11, sprite, { y = dest }, "in-back")

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

	-- Notify GUI to update its state.
	self.gui:placed()
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
	local drawArea = screen:getDrawArea()
	-- Allow the camera (centre of the screen) to be half a screen away.
	local w2, h2 = drawArea.width / 2 + ox, drawArea.height / 2 + oy
	xMin, yMin = xMin - w2 / scale, yMin - h2 / scale
	xMax, yMax = xMax + w2 / scale, yMax + h2 / scale

	self.cameraBoundingBox = {
		xMin = xMin,
		xMax = xMax,
		yMin = yMin,
		yMax = yMax
	}
end

--
-- Events
--

function Game:childbirthStartedEvent(event)
	print("Childbirth started")
end

function Game:childbirthEndedEvent(event)
	print("Childbirth ended. Mother "..
		(event:didMotherSurvive() and "survived" or "died").." and child "..
		(event:didChildSurvive() and "survived" or "died"))
end

return Game
