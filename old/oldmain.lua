local sync = require "https://raw.githubusercontent.com/expo/sync.lua/master/sync.lua"

local Controller = sync.registerType("Controller")
local Game = sync.registerType("Game")

-- Board is 7 columns and 6 rows

local server, client

local function keyEvent(key)
  if client and client.controller then
    if key == "up" or key == "down" or key == "left" or key == "right" then
      client.controller:setWalkState(
        love.keyboard.isDown("up"),
        love.keyboard.isDown("down"),
        love.keyboard.isDown("left"),
        love.keyboard.isDown("right")
      )
    end
  end
end

function love.keypressed(key)
  if key == "1" then
    server = sync.newServer {address = "*:22122", controllerTypeName = "Controller"}
    server:spawn("Game")
  end
  if key == "2" then
    connectClient()
  end
  if key == "3" then
    if client then
      client.serverPeer:disconnect()
    end
  end
  keyEvent(key)
end

function connectClient()
  client = sync.newClient {address = "127.0.0.1:22122"}
  -- client = sync.newClient {address = "192.168.1.224:22122"}
end

function love.keyreleased(key)
  keyEvent(key)
end

function love.mousemoved(x, y, dx, dy, istouch)
  if client and client.controller then
    client.controller:setMouseState(x, y, dx, dy, istouch)
  end
end

function love.mousepressed()
  if client and client.controller then
    -- whatever
  else
    connectClient()
  end
end

function love.draw()
  if client and client.controller then
    for _, ent in pairs(client.all) do
      if ent.__typeName == "Player" then
        ent:draw(ent == client.controller.player)
      elseif ent.draw then
        ent:draw()
      end
    end
  else
    love.graphics.print("You are not connected. Press 1 to start a server, 2 to connect as a client.", 20, 20)
  end
end

function love.update(dt)
  if server then
    for _, ent in pairs(server.all) do
      if ent.update then
        ent:update(dt)
      end
    end
    server:process()
  end
  if client then
    client:process()
  end
end

local Player = sync.registerType("Player")

function Game:didSpawn()
  self:init()
end

function Game:init()
  self.board = {}
  for column = 1, 7 do
    self.board[column] = {}
    for row = 1, 6 do
      self.board[column][row] = "empty"
    end
  end
end

function Game:draw()
  local size = 40
  for column = 1, 7 do
    for row = 1, 6 do
      love.graphics.push("all")
      -- love.graphics.setBlendMode("subtract")
      local value = self.board[column][row]
      if value == "empty" then
        love.graphics.setColor(1, 1, 1)
      elseif value == "red" then
        love.graphics.setColor(1, 0, 0)
      elseif value == "black" then
        love.graphics.setColor(0.2, 0.2, 0.2)
      else
        love.graphics.setColor(0, 0, 1)
      end
      love.graphics.ellipse("fill", column * size * 2, row * size * 2, size, size)
      love.graphics.pop()
    end
  end
end

function Game:didSync()
end

function Player:didSpawn()
  self.x, self.y = love.graphics.getWidth() * math.random(), love.graphics.getHeight() * math.random()
  self.r, self.g, self.b = 0.2 + 0.8 * math.random(), 0.2 + 0.8 * math.random(), 0.2 + 0.8 * math.random()
  self.vx, self.vy = 0, 0
end

function Player:draw()
  love.graphics.push("all")
  love.graphics.setColor(self.r, self.g, self.b)
  love.graphics.ellipse("fill", self.x, self.y, 40, 40)
  love.graphics.pop()
end

function Controller:setMouseState(x, y, dx, dy, istouch)
  self.player.x = x
  self.player.y = y
  self.__mgr:sync(self)
end

function Controller:didSpawn()
  self.player = self.__mgr:spawn("Player")
end

function Controller:willDespawn()
  self.__mgr:despawn(self.player)
  self.player = nil
end

function Controller:setWalkState(up, down, left, right)
  self.player:setWalkState(up, down, left, right)
end

function Player:setWalkState(up, down, left, right)
  self.vx, self.vy = 0, 0
  if up then
    self.vy = self.vy - 40
  end
  if down then
    self.vy = self.vy + 40
  end
  if left then
    self.vx = self.vx - 40
  end
  if right then
    self.vx = self.vx + 40
  end
end

function Player:update(dt)
  self.x = self.x + self.vx * dt
  self.y = self.y + self.vy * dt
  self.__mgr:sync(self)
end

function Player:draw(isOwn)
  love.graphics.push("all")
  love.graphics.setColor(self.r, self.g, self.b)
  love.graphics.ellipse("fill", self.x, self.y, 40, 40)
  if isOwn then
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(5)
    love.graphics.ellipse("line", self.x, self.y, 48, 48)
  end
  love.graphics.pop()
end
