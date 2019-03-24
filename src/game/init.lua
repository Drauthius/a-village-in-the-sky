-- Directive:
--  - Get the game play in, taking time to fix other things around when the need or fancy arises.
-- TODO:
--  - Bugs:
--    * Villagers can get stuck in a four-grid gridlock.
--    * Villagers heading the exact opposite direction can get stuck in a two-grid gridlock.
--    * Removing a villager from a production job can leave resources "locked in limbo".
--      The same goes for building jobs.
--    * It is possible to starve a construction site by moving villagers at inopportune times.
--    * Villagers can be drawn behind e.g. the blacksmith shed, when there are a lot of things in the scene and they
--      are directly in front (to the right) of it.
--    * Display bug with the bottom panel???
--    * Villagers can stand in front of the bread delivery, causing it to be dropped where it stands.
--      Bread dropped outside door is not picked up. Is it reserved??
--      Problem seems to be that tile is owned by the building, but occupied by a villager.
--  - Next:
--    * Hunger and meals
--    * Birth and death
--  - Refactoring:
--    * There is little reason to have the VillagerComponent be called "VillagerComponent", other than symmetry.
--    * Map:reserve() is a bad name for something that doesn't use COLL_RESERVED
--      We could rename COLL_RESERVED to COLL_SPECIAL, and COLL_DYNAMIC to COLL_RESERVED,
--      but it needs to make sense if a spot to drop a resource is reserved, and the villager
--      assumes that there is a villager in the way and tries to tell it to move or something.
--      Maybe it would need to check "how" it is reserved, or we simply split it up further...
--      reserve() for resources, occupy() for villagers?
--    * Either consolidate production/construction components (wrt input), or maybe add an "input" component?
--    * Calling variables for "entity" in different contexts begs for trouble.
--    * Definition/specification for buildings is split into multiple files, making it hard to add new ones.
--  - Draw order:
--    * Update sprites to be square.
--    * Villagers going diagonally are sometimes draw behind.
--      Maybe because the position is updated fairly late?
--  - Particles:
--    * "Button is next" for the tutorial.
--    * When people die. (Probably easiest to do with a new sprite.)
--  - More sprites:
--    * Event button has a new event (maybe just want to add a text number?).
--    * Woman animations
--    * Investigate and fix (or work around) aseprite sprite sheet bug
--    * New blacksmith building.
--  - Controls:
--    * Zoom (less smooth, to avoid uneven pixels)
--    * Drag (with min/max, to avoid getting lost in space)
--    * Assigning/selecting through double tap or hold?
--      The details panel must have a "Deselect/Cancel/Close" button/icon so
--      that villagers can be easily deselected.
--  - Placing:
--    * Indicators of valid positions (blue)
--    * Limit placement depending on runestones
--    * Placing runestones
--  - Info panel updates:
--    * Make the info panel title bar thicker, and put the name there + a button to
--      minimize/maximize.
--  - Details panel:
--    * Fill up details panel with correct information
--      Villager stuff, Monolith, wait with other things.
--  - Localization:
--    * Refrain from using hardcoded strings, and consult a library instead.
--      https://github.com/martin-damien/babel
--  - Nice to have:
--    * Don't increase opacity for overlapping shadows.
--    * Villagers always reserve two grids when walking. Problem?
--    * Quads are created on demand. Problem?
--    * Villagers pushing another villager that is pushing another villager will end up with the first villager
--      abandoning the attempt.
--    * Clouds are a bit rough (sprites and particle system can remove sprites instantly).
--    * Draw placing tile behind other tiles?

local Camera = require "lib.hump.camera"
local Timer = require "lib.hump.timer"
local lovetoys = require "lib.lovetoys.lovetoys"

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
-- Events
local AssignedEvent = require "src.game.assignedevent"
-- Systems
local BuildingSystem
local DebugSystem
local FieldSystem
local ParticleSystem
local PlacingSystem
local PositionSystem
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

local Game = {}

Game.CAMERA_MIN_ZOOM = 0.5
Game.CAMERA_MAX_ZOOM = 10
Game.CAMERA_EPSILON = 0.025
-- Zoom level before the foreground is visible
Game.FOREGROUND_VISIBLE_ZOOM = 2
-- How transparent the foreground is based on the zoom level.
Game.FOREGROUND_VISIBLE_FACTOR = 1.0

function Game:init()
	lovetoys.initialize({ debug = true, middleclassPath = "lib.middleclass" })

	-- Needs to be created after initialization.
	BuildingSystem = require "src.game.buildingsystem"
	DebugSystem = require "src.game.debugsystem"
	FieldSystem = require "src.game.fieldsystem"
	ParticleSystem = require "src.game.particlesystem"
	PlacingSystem = require "src.game.placingsystem"
	PositionSystem = require "src.game.positionsystem"
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
	self.backgrounds = {
		Background(self.camera, 0.05, 2),
		Background(self.camera, 0.2, 3)
	}
	self.backgrounds[1]:setColor({ 0.8, 0.8, 0.95, 1 })
	self.backgrounds[2]:setColor({ 0.9, 0.9, 1, 1 })
	self.foreground = Background(self.camera, 10, 2)

	self.engine = lovetoys.Engine()
	self.eventManager = lovetoys.EventManager()

	local buildingSystem = BuildingSystem(self.engine)
	local fieldSystem = FieldSystem(self.engine, self.eventManager, self.map)
	local villagerSystem = VillagerSystem(self.engine, self.eventManager, self.map)
	local workSystem = WorkSystem(self.engine, self.eventManager)

	self.engine:addSystem(fieldSystem, "update")
	self.engine:addSystem(PlacingSystem(self.map), "update")
	self.engine:addSystem(workSystem, "update") -- Must be before the sprite system
	self.engine:addSystem(villagerSystem, "update")
	self.engine:addSystem(WalkingSystem(self.engine, self.eventManager, self.map), "update")
	self.engine:addSystem(TimerSystem(), "update") -- Must be before the sprite system...
	self.engine:addSystem(SpriteSystem(self.eventManager), "update")
	self.engine:addSystem(ParticleSystem(self.engine), "update")
	self.engine:addSystem(RenderSystem(), "draw")
	self.engine:addSystem(DebugSystem(self.map), "draw")

	-- Not enabled by default.
	self.engine:toggleSystem("DebugSystem")

	-- Currently only listens to events.
	self.engine:addSystem(buildingSystem, "update")
	self.engine:addSystem(PositionSystem(self.map), "update")
	self.engine:stopSystem("BuildingSystem")
	self.engine:stopSystem("PositionSystem")

	self.eventManager:addListener("AssignedEvent", villagerSystem, villagerSystem.assignedEvent)
	self.eventManager:addListener("BuildingCompletedEvent", buildingSystem, buildingSystem.buildingCompletedEvent)
	self.eventManager:addListener("BuildingEnteredEvent", buildingSystem, buildingSystem.buildingEnteredEvent)
	self.eventManager:addListener("BuildingEnteredEvent", villagerSystem, villagerSystem.buildingEnteredEvent)
	self.eventManager:addListener("BuildingLeftEvent", buildingSystem, buildingSystem.buildingLeftEvent)
	self.eventManager:addListener("BuildingLeftEvent", villagerSystem, villagerSystem.buildingLeftEvent)
	self.eventManager:addListener("TargetReachedEvent", villagerSystem, villagerSystem.targetReachedEvent)
	self.eventManager:addListener("TargetUnreachableEvent", villagerSystem, villagerSystem.targetUnreachableEvent)
	self.eventManager:addListener("WorkEvent", fieldSystem, fieldSystem.workEvent)
	self.eventManager:addListener("WorkEvent", workSystem, workSystem.workEvent)
	self.eventManager:addListener("WorkCompletedEvent", villagerSystem, villagerSystem.workCompletedEvent)

	self.worldCanvas = love.graphics.newCanvas()
	self.gui = GUI(self.engine)

	self.level:initiate(self.engine, self.map)
end

function Game:update(dt)
	local mx, my = screen:getCoordinate(love.mouse.getPosition())
	local drawArea = screen:getDrawArea()
	state:setMousePosition(self.camera:worldCoords(mx, my, drawArea.x, drawArea.y, drawArea.width, drawArea.height))

	if self.dragging and self.dragging.dragged then
		self.camera:lockPosition(
				self.dragging.cx,
				self.dragging.cy,
				Camera.smooth.damped(15))
		if self.dragging.released and
		   math.abs(self.dragging.cx - self.camera.x) <= Game.CAMERA_EPSILON and
		   math.abs(self.dragging.cy - self.camera.y) <= Game.CAMERA_EPSILON then
			-- Clear and release the dragging table, to avoid subpixel camera movement which looks choppy.
			self.dragging = nil
		end
	end

	self.foreground:setZoom(self.camera.scale)
	self.foreground:setColor({
		1, 1, 1,
		math.max(0.0, math.min(0.9, (Game.FOREGROUND_VISIBLE_ZOOM - self.camera.scale) / Game.FOREGROUND_VISIBLE_FACTOR))
	})

	for _=1,self.speed do
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
	love.graphics.setColor(255, 255, 255)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(self.worldCanvas)
	love.graphics.setBlendMode("alpha")

	self.foreground:draw()

	self.gui:draw()
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
		self.speed = 0
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
	elseif scancode == "a" then
		local particle = blueprint:createDeathParticle()
		particle:set(PositionComponent(self.map:getGrid(13, 9)))
		particle:get("SpriteComponent"):setDrawPosition(self.map:gridToWorldCoords(13, 9))
		particle:get("ParticleComponent"):getParticleSystem():start()
		self.engine:addEntity(particle)
	end
end

function Game:mousepressed(x, y)
	local origx, origy = self.camera:position()
	local sx, sy = screen:getCoordinate(x, y)

	-- Don't allow dragging the camera when it starts on a GUI element.
	if self.gui:handlePress(sx, sy, true) then
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

		local tolerance = 20
		if not self.dragging.dragged and
		   (self.dragging.sx - ex)^2 + (self.dragging.sy - ey)^2 >= tolerance then
			self.dragging.dragged = true
		end

		self.dragging.cx = self.dragging.ox + newx
		self.dragging.cy = self.dragging.oy + newy
	end
end

function Game:mousereleased(x, y)
	x, y = screen:getCoordinate(x, y)

	if not self.dragging or not self.dragging.dragged or self.dragging.released then
		if not self.gui:handlePress(x, y) then
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
		self.camera:move(diffx / newScale * (newScale / oldScale - 1), diffy / newScale * (newScale / oldScale - 1))
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

		if clicked:has("FieldEnclosureComponent") then
			-- Never work the enclosure, only the fields.
			skipWorkPlace = true
		elseif not valid and clicked:has("WorkComponent") then
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

			self.eventManager:fireEvent(AssignedEvent(clicked, selected))

			soundManager:playEffect("successfulAssignment") -- TODO: Different sounds per assigned occupation?
			BlinkComponent:makeBlinking(clicked, { 0.15, 0.70, 0.15, 1.0 }) -- TODO: Colour value
		else
			soundManager:playEffect("failedAssignment")
			BlinkComponent:makeBlinking(clicked, { 0.70, 0.15, 0.15, 1.0 }) -- TODO: Colour value
		end
	else
		soundManager:playEffect("selecting") -- TODO: Different sounds depending on what is selected.
		state:setSelection(clicked)
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

		dust:set(PositionComponent(self.map:getGrid(gi, gj)))
		dust:get("SpriteComponent"):setDrawPosition(self.map:gridToWorldCoords(gi + dx * 2, gj + dy * 2))
		self.engine:addEntity(dust)
	end

	local sprite = placing:get("SpriteComponent")
	sprite:resetColor()
	local dest = sprite.y
	sprite.y = sprite.y - 10

	Timer.tween(0.15, sprite, { y = dest }, "in-bounce", function()
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
end

function Game:_placeBuilding(placing)
	soundManager:playEffect("buildingPlaced") -- TODO: Type?

	local ax, ay, minGrid, maxGrid = self.map:addObject(placing, placing:get("BuildingComponent"):getPosition())
	assert(ax and ay and minGrid and maxGrid, "Could not add building with building component.")
	placing:get("SpriteComponent"):setDrawPosition(ax, ay)
	placing:get("SpriteComponent"):resetColor()
	placing:add(PositionComponent(minGrid, maxGrid, self.map:gridToTileCoords(minGrid.gi, minGrid.gj)))
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

		dust:set(PositionComponent((assert(self.map:getGrid(gi, gj), ("(%d,%d) is outside of the map"):format(gi, gj)))))
		dust:get("SpriteComponent"):setDrawPosition(self.map:gridToWorldCoords(gi, gj))
		self.engine:addEntity(dust)
	end

	-- Notify GUI to update its state.
	self.gui:placed()
end

return Game
