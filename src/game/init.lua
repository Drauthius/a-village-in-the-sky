-- Directive:
--  - Get the game play in, taking time to fix other things around when the need or fancy arises.
-- TODO:
--  - Bugs:
--    * Map:reserve() is a bad name for something that doesn't use COLL_RESERVED
--      We could rename COLL_RESERVED to COLL_SPECIAL, and COLL_DYNAMIC to COLL_RESERVED,
--      but it needs to make sense if a spot to drop a resource is reserved, and the villager
--      assumes that there is a villager in the way and tries to tell it to move or something.
--      Maybe it would need to check "how" it is reserved, or we simply split it up further...
--      reserve() for resources, occupy() for villagers?
--    * Villagers always reserve two grids when walking. Problem?
--  - Next:
--    * Don't move building header with the sprite.
--    * Add indicator for homelessness.
--    * Don't allow homeless to work on non-building things.
--    * Make it possible to assign villagers a home.
--    * Show house header.
--    * Don't allow more than 1 worker on a resource.
--    * Bring resource back to home and place it on the ground (increasing resource counter).
--    * Allow changing profession without locking up resources, work grids, etc.
--  - Refactoring:
--    * Remove some logic in the components, and instead create more components?
--      Like Villager:isAdult() can be split into a Adult and Child component,
--      with the adult one handling things like occupation.
--      Pro:
--        Adult and Child can have different systems handling their behaviour.
--    * There is little reason to have the VillagerComponent be called "VillagerComponent", other than symmetry.
--  - Draw order:
--    * Update sprites to be square.
--  - Particles:
--    * "Button is next" for the tutorial.
--    * When villager hits tree/stone/building
--  - More sprites:
--    * Event button has a new event (maybe just want to add a text number?).
--    * Clouds
--    * Woman animations
--    * Investigate and fix (or work around) aseprite sprite sheet bug
--  - Controls
--    * Zoom (less smooth, to avoid uneven pixels)
--    * Drag (with min/max, to avoid getting lost in space)
--    * Camera stops abruptly when mouse is released (should keep going in the
--      same direction a bit)
--    * Assigning/selecting through double tap or hold?
--      The details panel must have a "Deselect/Cancel/Close" button/icon so
--      that villagers can be easily deselected.
--  - Placing:
--    * Indicators of valid positions (blue)
--    * Draw tiles behind other tiles? (Not really a requirement though)
--    * Effects ((small drop) + dust clouds + (screen shake))
--    * Limit placement depending on runestones
--    * Placing runestones
--    * Placing buildings
--  - Optimization:
--    * Quads are being (re)created each frame.
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

local Camera = require "lib.hump.camera"
local Timer = require "lib.hump.timer"
local lovetoys = require "lib.lovetoys.lovetoys"

local GUI = require "src.game.gui"
local Map = require "src.game.map"
-- Components
local AnimationComponent = require "src.game.animationcomponent"
local BlinkComponent = require "src.game.blinkcomponent"
local GroundComponent = require "src.game.groundcomponent"
local InteractiveComponent = require "src.game.interactivecomponent"
local PositionComponent = require "src.game.positioncomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local SpriteComponent = require "src.game.spritecomponent"
local TileComponent = require "src.game.tilecomponent"
local UnderConstructionComponent = require "src.game.underconstructioncomponent"
local VillagerComponent = require "src.game.villagercomponent"
-- Systems
local DebugSystem
local PlacingSystem
local PositionSystem
local RenderSystem
local SpriteSystem
local VillagerSystem
local WorkSystem

local blueprint = require "src.game.blueprint"
local screen = require "src.screen"
local soundManager = require "src.soundmanager"
local state = require "src.game.state"

local Game = {}

function Game:init()
	lovetoys.initialize({ debug = true, middleclassPath = "lib.middleclass" })

	-- Needs to be created after initialization.
	DebugSystem = require "src.game.debugsystem"
	PlacingSystem = require "src.game.placingsystem"
	PositionSystem = require "src.game.positionsystem"
	RenderSystem = require "src.game.rendersystem"
	SpriteSystem = require "src.game.spritesystem"
	VillagerSystem = require "src.game.villagersystem"
	WorkSystem = require "src.game.worksystem"
end

function Game:enter()
	love.graphics.setBackgroundColor(0.1, 0.5, 1)

	self.map = Map()

	-- Set up the camera.
	self.camera = Camera()
	self.camera:lookAt(0, 0)
	self.camera:zoom(6)

	self.eventManager = lovetoys.EventManager()

	self.engine = lovetoys.Engine()
	self.engine:addSystem(PlacingSystem(self.map), "update")
	self.engine:addSystem(SpriteSystem(self.eventManager), "update")
	self.engine:addSystem(VillagerSystem(self.engine, self.map), "update")
	local workSystem = WorkSystem(self.engine)
	self.engine:addSystem(workSystem, "update")
	self.engine:addSystem(PositionSystem(self.map), "update")
	self.engine:addSystem(RenderSystem(), "draw")
	self.engine:addSystem(DebugSystem(self.map), "draw")

	self.engine:toggleSystem("DebugSystem")

	-- Only currently listens to events.
	self.engine:stopSystem("PositionSystem")

	self.eventManager:addListener("WorkEvent", workSystem, workSystem.workEvent)

	self.gui = GUI(self.engine)

	local spriteSheet = require "src.game.spritesheet"

	do -- Initial tile.
		local tile = lovetoys.Entity()
		tile:add(TileComponent(TileComponent.GRASS, 0, 0))
		tile:add(SpriteComponent(spriteSheet:getSprite("grass-tile"), -self.map.halfTileWidth))
		self.engine:addEntity(tile)
		self.map:addTile(0, 0)
	end

	do -- Initial runestone.
		local runestone = blueprint:createRunestone()
		local x, y, grid = self.map:addObject(runestone, 0, 0)
		runestone:get("SpriteComponent"):setDrawPosition(x, y)
		runestone:get("PositionComponent"):setPosition(grid)
		InteractiveComponent:makeInteractive(runestone, x, y)
		self.engine:addEntity(runestone)
	end

	local startingResources = {
		[ResourceComponent.WOOD] = 30,
		[ResourceComponent.IRON] = 6,
		[ResourceComponent.TOOL] = 12,
		[ResourceComponent.BREAD] = 6
	}

	local startingVillagers = {
		maleVillagers = 3, -- 1, -- TODO
		femaleVillagers = 0, -- 2, -- TODO
		maleChild = 1,
		femaleChild = 1
	}
	startingVillagers = { maleVillagers = 2 }

	for type,num in pairs(startingResources) do
		while num > 0 do
			local name = ResourceComponent.RESOURCE_NAME[type]
			local resource = lovetoys.Entity()
			local pile = math.min(3, num)

			-- TODO: Sprite stuff could be handled by the SpriteSystem...
			local sprite = spriteSheet:getSprite(name.."-resource "..tostring(pile - 1))

			local gi, gj = self.map:getFreeGrid(0, 0, type)
			self.map:addResource(resource, self.map:getGrid(gi, gj))

			local ox, oy = self.map:gridToWorldCoords(gi, gj)
			ox = ox - self.map.halfGridWidth
			oy = oy - sprite:getHeight() + self.map.gridHeight

			resource:add(ResourceComponent(type, pile, true))
			resource:add(PositionComponent(self.map:getGrid(gi, gj)))
			resource:add(SpriteComponent(sprite, ox, oy))

			self.engine:addEntity(resource)
			state:increaseResource(type, pile)

			num = num - pile
		end
	end

	for type,num in pairs(startingVillagers) do
		for _=1,num do
			local villager = lovetoys.Entity()

			local gi, gj = self.map:getFreeGrid(0, 0, "villager")
			self.map:reserve(villager, self.map:getGrid(gi, gj))

			villager:add(PositionComponent(self.map:getGrid(gi, gj)))
			villager:add(GroundComponent(self.map:gridToGroundCoords(gi + 0.5, gj + 0.5)))
			villager:add(VillagerComponent({
				gender = type:match("^male") and "male" or "female",
				age = type:match("Child$") and 5 or 20 }))
			villager:add(SpriteComponent())
			villager:add(AnimationComponent())

			self.engine:addEntity(villager)

			-- XXX:
			state["increaseNum" .. type:gsub("^%l", string.upper):gsub("Child$", "Children")](state)
		end
	end

	--self:mousereleased(353, 420)
	--local mx, my = screen:getCoordinate(327, 253)
	--local drawArea = screen:getDrawArea()
	--state:setMousePosition(self.camera:worldCoords(mx, my, drawArea.x, drawArea.y, drawArea.width, drawArea.height))
	--self:mousereleased(327, 253)
end

function Game:update(dt)
	--dt = dt * 2

	Timer.update(dt)

	local mx, my = screen:getCoordinate(love.mouse.getPosition())
	local drawArea = screen:getDrawArea()
	state:setMousePosition(self.camera:worldCoords(mx, my, drawArea.x, drawArea.y, drawArea.width, drawArea.height))

	if self.dragging and self.dragging.dragged then
		--self.camera:lockWindow(
		self.camera:lockPosition(
				self.dragging.cx,
				self.dragging.cy,
				--0, 0,
				--0, 0,
				Camera.smooth.damped(15))
	end

	self.gui:update(dt)
	self.engine:update(dt)
end

function Game:draw()
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

	self.gui:draw()
end

function Game:keyreleased(key)
	if key == "d" then
		self.debug = not self.debug
	elseif key == "escape" then
		self.gui:back()
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
		dragged = false
	}
end

function Game:mousemoved(x, y)
	if self.dragging then
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
	--print(x, y)
	x, y = screen:getCoordinate(x, y)

	if not self.dragging or not self.dragging.dragged then
		if not self.gui:handlePress(x, y) then
			if not state:isPlacing() then
				x, y = state:getMousePosition()
				--print(x, y)
				local clicked = nil
				for _,entity in pairs(self.engine:getEntitiesWithComponent("InteractiveComponent")) do
					if entity:get("InteractiveComponent"):isWithin(x, y) then
						clicked = entity
						break
					end
				end

				if clicked then
					--print(clicked)
					local selected = state:getSelection()
					if selected and selected:has("VillagerComponent") and selected:get("VillagerComponent"):isAdult() and
					   clicked:has("WorkComponent") then

					   -- Whether that there is room to work there.
					   -- FIXME: Reassignment not handled!
						local valid

						if clicked:has("UnderConstructionComponent") then
							if #clicked:get("UnderConstructionComponent"):getAssignedVillagers() >= 4 then
								valid = false
							else
								-- For things being built, update the places where builders can stand, so that rubbish can
								-- be cleared around the build site after placing the building.
								local adjacent = self.map:getAdjacentGrids(clicked)
								clicked:get("UnderConstructionComponent"):updateWorkGrids(adjacent)
								valid = true
							end
						else
							if #clicked:get("WorkComponent"):getAssignedVillagers() >= 1 then
								valid = false
							else
								clicked:get("WorkComponent"):assign(selected)
								valid = true
							end
						end

						if valid then
							-- TODO: Should probably be an event or similar.
							selected:get("VillagerComponent"):setWorkPlace(clicked)
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
				else
					soundManager:playEffect("clearSelection")
					state:clearSelection()
				end
			elseif state:getPlacing():has("TileComponent") then
				soundManager:playEffect("tilePlaced") -- TODO: Type?

				local placing = state:getPlacing()
				placing:remove("PlacingComponent")
				local ti, tj = placing:get("TileComponent"):getPosition()
				self.map:addTile(ti, tj)

				--local spec = Game.tileSpec[placing:get("TileComponent"):getType()]
				--local trees = #spec.trees > 0 and spec.trees[love.math.random(#spec.trees)] or 0
				--local iron = #spec.iron > 0 and spec.iron[love.math.random(#spec.iron)] or 0

				local trees, iron = self:_getResources(placing:get("TileComponent"):getType())

				--print("Will spawn "..tostring(trees).." trees and "..tostring(iron).." iron")

				local sgi, sgj = ti * self.map.gridsPerTile, tj * self.map.gridsPerTile
				local egi, egj = sgi + self.map.gridsPerTile, sgj + self.map.gridsPerTile

				local resources = {}

				-- TODO: Runestone logic
				--if love.math.random(1, 5) == 1 then
				if false then
					local runestone = blueprint:createRunestone()
					local ax, ay, grid = self.map:addObject(runestone, ti, tj)
					assert(ax and ay and grid, "Could not add runestone to empty tile.")
					runestone:get("SpriteComponent"):setDrawPosition(ax, ay)
					runestone:get("PositionComponent"):setPosition(grid)
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
						local ax, ay, grid = self.map:addObject(resource, gi, gj)
						if ax then
							resource:get("SpriteComponent"):setDrawPosition(ax, ay)
							resource:get("PositionComponent"):setPosition(grid)
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
			elseif state:getPlacing():has("BuildingComponent") then
				soundManager:playEffect("buildingPlaced") -- TODO: Type?

				local placing = state:getPlacing()
				placing:remove("PlacingComponent")

				local ax, ay, grid = self.map:addObject(placing, placing:get("BuildingComponent"):getPosition())
				assert(ax and ay and grid, "Could not add building with building component.")
				placing:get("SpriteComponent"):setDrawPosition(ax, ay)
				placing:get("SpriteComponent"):resetColor()
				placing:set(PositionComponent(grid))
				placing:add(UnderConstructionComponent(placing:get("BuildingComponent"):getType()))
				InteractiveComponent:makeInteractive(placing, ax, ay)

				--[[local adj = self.map:getAdjacentGrids(placing)
				for _,grid in ipairs(adj) do
					grid.collision = Map.COLL_DYNAMIC
				end]]

				-- Notify GUI to update its state.
				self.gui:placed()
			end
		end
	end

	self.dragging = nil
end

function Game:wheelmoved(_, y)
	if y < 0 then
		if self.camera.scale >= 0.2 then
			self.camera:zoom(0.9)
		end
	elseif y > 0 then
		if self.camera.scale <= 10.0 then
			self.camera:zoom(1.1)
		end
	end
end

function Game:_getResources(tile)
	if tile == TileComponent.GRASS then
		-- TODO: Would be nice with some trees, but not the early levels
		return 0, 0 --return math.max(0, math.floor((love.math.random(9) - 5) / 2)), 0
	elseif tile == TileComponent.FOREST then
		return love.math.random(2, 6), 0
	elseif tile == TileComponent.MOUNTAIN then
		return math.max(0, love.math.random(5) - 4), love.math.random(2, 4)
	end
end

return Game
