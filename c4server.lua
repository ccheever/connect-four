local cs = require "https://raw.githubusercontent.com/expo/share.lua/cfb3ed2b3a63355ed78aa5bbe691afdb33aac475/cs.lua"
local server = cs.server

local serpent = require "https://raw.githubusercontent.com/pkulchenko/serpent/master/src/serpent.lua"

server.enabled = true
server.start("22122") -- Port of server

-- Server has many clients connecting to it. Each client has a unique `id` to identify it.
--
-- `server.share` represents shared state that the server can write to and all clients can read
-- from. `server.homes[id]` each represents state that the server can read from and client with
-- that `id` can write to (clients can't see each other's homes). Thus the server gets data
-- from each client and combines them for all clients to see.
--
-- Server can also send or receive individual messages to or from any client.

local share = server.share -- Maps to `client.share` -- can write
local homes = server.homes -- `homes[id]` maps to `client.home` for that `id` -- can read

function server.connect(id) -- Called on connect from client with `id`
  share.colors[id] = {
    r = math.random(),
    g = math.random(),
    b = math.random()
  }
end

function server.disconnect(id) -- Called on disconnect from client with `id`
end

function server.receive(id, op, col) -- Called when client with `id` does `client.send(...)`
  print("op", id, op, col)
  if op == "place" then
    if share.win then
      print("game already over; can't place")
      return
    end
    if not col then
      return
    end
    if share.board[1][col] then
      -- can't place the thing
      print("can't place")
      goto placed
    else
      local row = 0
      while row <= share.rows do
        if (share.board[row + 1] and share.board[row + 1][col]) or (row == share.rows) then
          if row == 0 then
            -- can't place
            print "can't place"
          else
            share.board[row][col] = id
            print("place at row ", row)
          end
          goto placed
        end
        row = row + 1
      end
    end
    ::placed::
    share.win = checkForWin()
  elseif op == "restart" then
    initializeBoard()
  end
end

function initializeBoard()
  share.rows = 6
  share.columns = 7
  share.board = {}
  for i = 1, share.rows do
    share.board[i] = {}
    for j = 1, share.columns do
      share.board[i][j] = false
    end
  end
  share.win = nil
end

-- Server only gets `.load`, `.update`, `.quit` Love events (also `.lowmemory` and `.threaderror`
-- which are less commonly used)

function server.load()
  share.mice = {}
  share.colors = {}
  initializeBoard()
end

function server.update(dt)
  for id, home in pairs(server.homes) do -- Combine mouse info from clients into share
    share.mice[id] = home.mouse
  end
end

function checkForWin()
  print "check for win"
  local n = 4
  for i = 1, share.rows do
    for j = 1, share.columns do
      local c = share.board[i][j]
      print("checking ", c, " starting at ", i, ", ", j)
      if c then
        for _, dir in ipairs(
          {
            {-1, -1},
            {-1, 0},
            {-1, 1},
            {0, -1},
            {0, 1},
            {1, -1},
            {1, 0},
            {1, 1}
          }
        ) do
          local drow, dcol = dir[1], dir[2]
          for s = 0, n - 1 do
            print(" s=", s, " drow=", drow, " dcol=", dcol)
            local i2 = i + s * drow
            local j2 = j + s * dcol
            if i2 >= 1 and i2 <= share.rows and j2 >= 1 and j2 <= share.columns then
              local c2 = share.board[i2][j2]
              print("c2=", c2, "c=", c)
              if c2 ~= c then
                goto nowin
              end
            else
              goto nowin
            end
          end
          if true then
            local w = {
              winner = c,
              row = i,
              col = j,
              drow = drow,
              dcol = dcol
            }
            print("WIN", serpent.block(w))
            return w
          end
          ::nowin::
        end
      end
    end
  end
  return nil
end
