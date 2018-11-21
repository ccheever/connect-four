--[[
  name: Connect Four
  author: Charlie Cheever <ccheever@expo.io>
  description: An implementation of the classic game Connect Four
]]

local classic = require "https://raw.githubusercontent.com/rxi/classic/e5610756c98ac2f8facd7ab90c94e1a097ecd2c6/classic.lua"
local share = require "https://raw.githubusercontent.com/expo/share.lua/master/share.lua"

local Object = classic

local root = share.new()

local Player = Object:extend()

function Player:new()

end


function love.draw()
  love.graphics.print("helo", 10, 10)
end