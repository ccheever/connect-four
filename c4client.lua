local cs = require "https://raw.githubusercontent.com/expo/share.lua/cfb3ed2b3a63355ed78aa5bbe691afdb33aac475/cs.lua"
local client = cs.client

local classic =
  require "https://raw.githubusercontent.com/rxi/classic/e5610756c98ac2f8facd7ab90c94e1a097ecd2c6/classic.lua"
local Object = classic

local brighten = require "./brighten"

client.enabled = true
client.start("192.168.1.224:22122") -- IP address ('127.0.0.1' is same computer) and port of server
-- client.start("127.0.0.1:22122") -- IP address ('127.0.0.1' is same computer) and port of server

-- Client connects to server. It gets a unique `id` to identify it.
--
-- `client.share` represents the shared state that server can write to and any client can read from.
-- `client.home` represents the home for this client that only it can write to and only server can
-- read from. `client.id` is the `id` for this client (set once it connects).
--
-- Client can also send or receive individual messages to or from server.

local share = client.share -- Maps to `server.share` -- can read
local home = client.home -- Maps to `server.homes[id]` with our `id` -- can write

function client.connect() -- Called on connect from server
end

function client.disconnect() -- Called on disconnect from server
end

function client.receive(...) -- Called when server does `server.send(id, ...)` with our `id`
end

-- Client gets all Love events

function client.load()
  home.mouse = {}
  home.mouse.x, home.mouse.y = love.mouse.getPosition()
  love.mouse.setVisible(false)
end

function client.update(dt)
  home.mouse.x, home.mouse.y = love.mouse.getPosition()
end

local Board = Object:extend()

function Board:new(data, rows, columns)
  self.size = 80
  self.rows = rows
  self.columns = columns
  self.data = data
  self.x = 10
  self.y = 10
end

function Board:whichColumn(x, y)
  local col = math.floor(0.5 + (x - self.x) / self.size)
  if col < 1 or col > self.columns then
    return nil
  else
    return col
  end
end

function Board:draw()
  local x, y = self.x, self.y
  local mouseX, mouseY = love.mouse.getPosition() -- get the position of the mouse
  local col = self:whichColumn(mouseX, mouseY)
  if col then
    -- love.graphics.print("column " .. col, 10, 300)
    love.graphics.setColor(1.0, 1.0, 0.0, 0.25)
    love.graphics.rectangle(
      "fill",
      self.x + self.size * col - self.size / 2,
      self.y,
      self.size,
      self.size * (self.rows + 1)
    )
  end

  love.graphics.push("all")
  for i = 1, self.rows do
    for j = 1, self.columns do
      if j == col then
        love.graphics.setColor(1.0, 1.0, 0)
      else
        love.graphics.setColor(1.0, 1.0, 1.0)
      end
      if self.data[i][j] ~= false then
        local c = share.colors[self.data[i][j]]
        -- print(c)
        love.graphics.setColor(c.r, c.g, c.b)
        love.graphics.circle("fill", x + self.size * j, y + self.size * i, self.size / 2)
      else
        love.graphics.circle("line", x + self.size * j, y + self.size * i, self.size / 2)
      end
    end
  end
  love.graphics.pop()
end

function client.draw()
  -- love.graphics.translate(0.5 * (love.graphics.getWidth() - 600), 0.5 * (love.graphics.getHeight() - 650))

  if client.connected then
    -- Draw board first so its on bottom
    local board = Board(share.board, share.rows, share.columns)
    board:draw()

    -- Draw our own mouse in a special way (bigger radius)
    local c = share.colors[client.id]
    if c then
      local c2 = brighten(c)
      love.graphics.setColor(c2.r, c2.g, c2.b, 0.5)
    end
    -- love.graphics.circle("fill", home.mouse.x, home.mouse.y, 40, 40)
    local mouseX, mouseY = love.mouse.getPosition()
    love.graphics.circle("fill", mouseX, mouseY, 40, 40)

    -- Draw other mice
    for id, mouse in pairs(share.mice) do
      local c = share.colors[id]
      if c then
        local c2 = brighten(c)
        love.graphics.setColor(c2.r, c2.g, c2.b, 0.5)
      -- love.graphics.setColor(c.r, c.g, c.b)
      end

      if id ~= client.id then -- Only draw others' mice this way
        love.graphics.circle("fill", mouse.x, mouse.y, 30, 30)
      end
    end

    love.graphics.setColor(0.8, 0.8, 0.8)

    -- Draw our ping
    love.graphics.print("ping: " .. client.getPing(), 20, 20)

    -- Draw winner if nec
    if share.win then
      love.graphics.setFont(love.graphics.newFont(85))
      local winner = share.win.winner
      local c = share.colors[winner]
      love.graphics.setColor(c.r, c.g, c.b)
      love.graphics.print("WINNER!!!", 100, 530)
    end
  else
    love.graphics.print("not connected", 20, 20)
  end
end

function love.mousepressed(x, y, button, istouch)
  if button == 1 then -- Versions prior to 0.10.0 use the MouseConstant 'l'
    local board = Board(share.board, share.rows, share.columns)
    local col = board:whichColumn(x, y)
    client.send("place", col)
  end
end

function love.keypressed(key, scancode, isrepeat)
  if scancode == "q" then
    client.send("restart")
  end
end
