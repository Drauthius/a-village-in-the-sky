-- Set the default filter before loading anything.
love.graphics.setDefaultFilter("linear", "nearest")

local GameState = require "lib.hump.gamestate"

local Game = require "src.game"

local screen = require "src.screen"

function love.load()
	-- WTF. Default error handle apparently doesn't work.
	love.errorhandler = love.errhand

	--local Bound = require "lib.gui.bound"
	--Bound.static.debug = true

	GameState.registerEvents()

	screen:setUp()

	GameState.switch(Game)
end
