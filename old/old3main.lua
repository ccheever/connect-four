--[[
  name: Connect Four
  author: Charlie Cheever <ccheever@expo.io>
  description: An implementation of the classic game Connect Four
]]
local sync = require "https://raw.githubusercontent.com/expo/sync.lua/master/sync.lua"

local Controller = sync.registerType("Controller")
local Player = sync.registerType("Player")
local Board = sync.registerType("Board")
local server, client

local hasRedPlayer = false
local hasBlackPlayer = false
local hasBoard = false

local ROWS = 6
local COLUMNS = 7
local SIZE = 35
local MARGIN = 4
local BOX_SIZE = (SIZE + MARGIN) * 2
local RED = {r = 1.0, g = 0.0, b = 0.0}
local BLACK = {r = 0.0, g = 0.0, b = 0.0}

function love.load()
  love.mouse.setCursor(nil)
end

function love.draw()
  if client and client.controller then
    for _, ent in pairs(client:getAll()) do
      if ent.__typeName == "Player" then
        ent:draw(ent.__id == client.controller.playerId)
      elseif ent.draw then
        ent:draw()
      end
    end
  else
    love.graphics.print("not connected", 20, 20)
  end
end

function love.update(dt)
  if server then
    for _, ent in pairs(server:getAll()) do
      if ent.update then
        ent:update(dt)
      end
    end
  end

  if server then
    server:process()
  end
  if client then
    client:process()
  end

  if client and client.controller then
    local x, y = love.mouse.getPosition()
    client.controller:setPosition(x, y)
  end
end

function Controller:setPosition(x, y)
  self.__mgr:getById(self.playerId):setPosition(x, y)
  local board = self.__mgr:getById(self.boardId)
  local col = board:detectColumn(x, y)
  if col >= 1 and col <= COLUMNS then
    board:highlightColumn(col)
  else
    board:highlightColumn(nil)
  end
end

function Controller:didSpawn()
  self.playerId = self.__mgr:spawn("Player")
  if not hasBoard then
    self.boardId = self.__mgr:spawn("Board")
    hasBoard = true
  end
end

function Board:highlightColumn(col)
  self._highlightedColumn = col
end

function Controller:willDespawn()
  self.__mgr:despawn(self.playerId)
end

function Controller:setWalkState(up, down, left, right)
  self.__mgr:getById(self.playerId):setWalkState(up, down, left, right)
end

function Player:didSpawn()
  if not hasBlackPlayer then
    self.color = "black"
    self.r, self.g, self.b = 0.2, 0.2, 0.2
    hasBlackPlayer = true
  elseif not hasRedPlayer then
    self.color = "red"
    self.r, self.g, self.b = 1.0, 0.2, 0.2
    hasRedPlayer = true
  else
    self.color = "obs"
    self.r, self.g, self.b, self.a = 0.7, 0.7, 1.0, 0.5
  end

  print("Player:didSpawn", self.color)
  self.vx, self.vy = 0, 0
  self.x, self.y = love.graphics.getWidth() * math.random(), love.graphics.getHeight() * math.random()
  -- self.r, self.g, self.b = 0.2 + 0.8 * math.random(), 0.2 + 0.8 * math.random(), 0.2 + 0.8 * math.random()
end

function Player:draw(isOwn)
  love.graphics.push("all")
  love.graphics.setColor(self.r, self.g, self.b)
  -- love.graphics.ellipse("fill", self.x, self.y, 40, 40)
  love.graphics.circle("line", self.x, self.y, SIZE)
  if isOwn then
    -- love.graphics.setLineWidth(5)
    love.graphics.circle("fill", self.x, self.y, SIZE)
  -- love.graphics.ellipse("line", self.x, self.y, 48, 48)
  end
  love.graphics.pop()
end

function Player:setPosition(x, y)
  self.x = x
  self.y = y
end

function Player:setWalkState(up, down, left, right)
  self.vx, self.vy = 0, 0
  if up then
    self.vy = self.vy - 240
  end
  if down then
    self.vy = self.vy + 240
  end
  if left then
    self.vx = self.vx - 240
  end
  if right then
    self.vx = self.vx + 240
  end
end

function Player:update(dt)
  -- self.x, self.y = love.mouse.getPosition()
  -- self.x = self.x + self.vx * dt
  -- self.y = self.y + self.vy * dt
  self.__mgr:sync(self)
end

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
  end
  if key == "2" then
    client = sync.newClient {address = "127.0.0.1:22122"}
  end

  keyEvent(key)
end

function love.keyreleased(key)
  keyEvent(key)
end

function Board:didSpawn()
  self.board = {}
  self.x = 10
  self.y = 10
  for i = 1, ROWS do
    local row = {}
    for j = 1, COLUMNS do
      table.insert(row, false)
    end
    table.insert(self.board, row)
  end

  print("Board:didSpawn")
end

function Board:detectColumn(x, y)
  local column = math.floor((x - self.x) / BOX_SIZE)
  return column
end

function love.mousereleased(x, y, button)
  print("Mouse released at ", x, y)
  if client and client.controller then
    client.controller:click(x, y, button)
  end
end

function Controller:click(x, y, button)
  local board = self.__mgr:getById(self.boardId)
  local col = board:detectColumn(x, y)
  print("column = ", col)
end

function Board:draw()
  print("hc=", self._highlightedColumn)
  for i = 1, ROWS do
    for j = 1, COLUMNS do
      if j == self._highlightedColumn then
        love.graphics.setColor(0.5, 0.5, 1.0)
        love.graphics.rectangle("fill", self.x + j * BOX_SIZE, self.y + i * BOX_SIZE, BOX_SIZE, BOX_SIZE)
      else
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", self.x + j * BOX_SIZE, self.y + i * BOX_SIZE, BOX_SIZE, BOX_SIZE)
      end
      if self.board[i][j] == "red" then
        love.graphics.setColor(RED.r, RED.g, RED.b)
        love.graphics.circle("fill", self.x + j * BOX_SIZE + MARGIN + SIZE, self.y + i * BOX_SIZE + MARGIN + SIZE, SIZE)
      elseif self.board[i][j] == "black" then
        love.graphics.setColor(BLACK.r, BLACK.g, BLACK.b)
        love.graphics.circle("fill", self.x + j * BOX_SIZE + MARGIN + SIZE, self.y + i * BOX_SIZE + MARGIN + SIZE, SIZE)
      else
        love.graphics.circle("line", self.x + j * BOX_SIZE + MARGIN + SIZE, self.y + i * BOX_SIZE + MARGIN + SIZE, SIZE)
      end
    end
  end
end
