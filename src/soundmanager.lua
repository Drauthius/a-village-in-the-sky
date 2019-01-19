local class = require "lib.middleclass"

local SoundManager = class("SoundManager")

function SoundManager:initialize()
end

function SoundManager:playEffect(effect)
	print("Playing "..tostring(effect))
end

function SoundManager:playMusic(section)
end

return SoundManager()
