local share =
  require "https://raw.githubusercontent.com/expo/share.lua/316916ca8d488e659c53710bda377500702963a4/share.lua"

local classic =
  require "https://raw.githubusercontent.com/rxi/classic/e5610756c98ac2f8facd7ab90c94e1a097ecd2c6/classic.lua"
local enet = require "enet" -- Network
local marshal = require "marshal" -- Serialization
local serpent =
  require "https://raw.githubusercontent.com/pkulchenko/serpent/522a6239f25997b101c585c0daf6a15b7e37fad9/src/serpent.lua" -- Table printing

local Object = classic

-- Super basic example where you can press keys to show the key name on the screen, and click with
-- the mouse to change where it's displayed.
--
-- Press 0 to start the server. Click to connect the client (allows connecting by touch on mobile).
--
-- To try connecting as a client to a remote server, start the server there by pressing 0. Edit
-- the line that says "EDIT IP ADDRESS FOR REMOTE SERVER" below to contain the ip address of that
-- computer. Run the edited code on the client and click.

-- You could write server and client code each in separate files and that probably helps make it
-- clear what's visible to what. But to keep the repo clean and allow testing server-client
-- connection within the same game, I'm going to keep them in the same file. I hide their data
-- from each other by using separate `do .. end` blocks and not setting any globals.

-- Remember that in ENet, the 'host' represents yourself on the network, while a 'peer' represents
-- someone else. So the server has one host and many peers (the clients), and each client has one
-- host and one peer (the server).

----------------------------------------------------------------------------------------------------
-- Server
----------------------------------------------------------------------------------------------------

local server = {}
do
  local colors = {
    {"red", 0.9296875, 0.25, 0.20703125},
    {"orange", 0.94921875, 0.46484375, 0.2109375},
    {"yellow", 0.98828125, 0.953125, 0.59375},
    {"green", 0.48046875, 0.75, 0.26171875},
    {"blue", 0.01171875, 0.5703125, 0.80859375}
  }
  local clientIdSequence = 0

  server.started = false -- Export started state for use below

  -- The shared state. This will be synced to all clients.
  local state = share.new("state")
  state:__autoSync(true)

  -- Initial state
  state.mice = {}

  -- Network stuff
  local host  -- The host
  local peers = {} -- Clients

  -- Start server
  function server.start()
    host = enet.host_create("*:22122")
    server.started = true
  end

  function server.update(dt)
    -- Send state updates to everyone
    for peer in pairs(peers) do
      local diff = state:__diff(peer)
      if diff ~= nil then -- `nil` if nothing changed
        peer:send(marshal.encode({type = "diff", diff = diff}))
      end
    end
    state:__flush() -- Make sure to reset diff state after sending!

    -- Process network events
    if host then
      while true do
        local event = host:service(0)
        if not event then
          break
        end

        -- Someone connected?
        if event.type == "connect" then
          local clientId = clientIdSequence
          local color = colors[(clientId % #colors) + 1]
          clientIdSequence = clientIdSequence + 1
          peers[event.peer] = clientId
          state.mice[clientId] = {x = 0, y = 0, color = color}
          event.peer:send(marshal.encode({type = "clientId", clientId = clientId}))
          -- `true` below is for 'exact' -- send full state on connect, not just a diff
          event.peer:send(marshal.encode({type = "diff", diff = state:__diff(event.peer, true)}))
        end

        -- Someone disconnected?
        if event.type == "disconnect" then
          state.mice[peers[event.peer]] = nil
          peers[event.peer] = nil
        end

        -- Received a request?
        if event.type == "receive" then
          local request = marshal.decode(event.data)

          if request.type == "mousemoved" then
            local mouse = state.mice[peers[event.peer]]
            mouse.x, mouse.y = request.x, request.y
          end
        end
      end
    end
  end
end

----------------------------------------------------------------------------------------------------
-- Client
----------------------------------------------------------------------------------------------------

local client = {}
do
  local Piece = Object:extend()
  function Piece:new(props, context)
    self.props = props
    self.context = context
  end

  function Piece:draw()
    local mouse = self.props.mouse
    love.graphics.push("all")
    love.graphics.setColor(mouse.color[2], mouse.color[3], mouse.color[4])
    local x, y = mouse.x, mouse.y
    love.graphics.circle("fill", x, y, 30)
    if self.props.outline then
      love.graphics.setColor(1, 1, 1)
      love.graphics.setLineWidth(5)
      love.graphics.circle("line", x, y, 35)
    end
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.print(mouse.color[1], x - 20, y - 5)
    love.graphics.pop()
  end

  local Board = Object:extend()
  function Board:new(props, context)
    props = props or {}
    local dimensions = props.dimensions or {}
    self.rows = dimensions[1] or 6
    self.columns = dimensions[2] or 7
    self.board = {}
    for row = 1, self.rows do
      self.board[row] = {}
      for col = 1, self.columns do
        self.board[row][column] = false
      end
    end
    self.x = 10
    self.y = 10
    self.size = 30
    self.padding = 4
    self.color = {r = 1.0, g = 0.8, b = 0.0}
  end

  function Board:draw()
    local squareSize = self.size * 2 + self.padding * 2
    love.graphics.push("all")
    love.graphics.setColor(self.color.r, self.color.g, self.color.b)
    love.graphics.rectangle("fill", self.x, self.y, squareSize * columns, squareSize * rows)
    love.graphics.pop()
  end

  client.connected = false -- Export connected state for use below

  -- View of server's shared state from this client. Initially `nil`.
  local state

  -- Network stuff
  local host  -- The host
  local peer  -- The server

  local myClientId

  -- Connect to server
  function client.connect()
    host = enet.host_create()
    -- host:connect("192.168.1.224:22122") -- EDIT IP ADDRESS FOR REMOTE SERVER
    host:connect("127.0.0.1:22122") -- EDIT IP ADDRESS FOR REMOTE SERVER
  end

  function client.update(dt)
    -- Process network events
    if host then
      while true do
        local event = host:service(0)
        if not event then
          break
        end

        -- Connected?
        if event.type == "connect" then
          peer = event.peer
          client.connected = true
        end

        -- Received state diff?
        if event.type == "receive" then
          local request = marshal.decode(event.data)
          -- print("received", serpent.block(request)) -- Print the diff, for debugging
          if request.type == "diff" then
            state = share.apply(state, request.diff)
          elseif request.type == "clientId" then
            myClientId = request.clientId
          end
        end
      end
    end
  end

  function client.draw()
    if state then -- `nil` till we receive first update, so guard for that
      -- Draw key name at position

      local myMouse = nil

      for clientId, mouse in pairs(state.mice) do
        local x, y = mouse.x, mouse.y
        local p = Piece({mouse = mouse, outline = (clientId == myClientId)})
        if clientId == myClientId then
          myMouse = p
          myMouse.props.mouse.x, myMouse.props.mouse.y = love.mouse.getPosition()
        else
          m:draw()
        end
      end
      myMouse:draw()
    end
  end

  function client.mousemoved(x, y, dx, dy, istouch)
    if peer then
      peer:send(marshal.encode({type = "mousemoved", x = x, y = y}))
    end
  end
end

----------------------------------------------------------------------------------------------------
-- Forwarding Love events to Server and Client
----------------------------------------------------------------------------------------------------

function love.update(dt)
  server.update(dt)
  client.update(dt)
end

function love.draw()
  client.draw()
end

function love.keypressed(key)
  if not server.started and key == "0" then
    server.start()
  end
end

function love.mousepressed(x, y, button)
  if not client.connected then
    client.connect()
  end
end

function love.mousemoved(x, y, dx, dy, istouch)
  client.mousemoved(x, y, dx, dy, istouch)
end
