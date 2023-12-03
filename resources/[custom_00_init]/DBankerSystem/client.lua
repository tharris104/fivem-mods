-- Local array to store registered player IDs
local registeredPlayers = {}


-- Function to check if a player is already registered
local function isPlayerRegistered(playerId)
  return registeredPlayers[playerId]
end


-- Function to register a player
local function registerPlayer(playerId)
  local playerName = GetPlayerName(playerId)

  -- Use OxMySQL to insert a new user into the database
  MySQL.Async.insert(
    "INSERT INTO users (id, player_name) VALUES (?, ?)",
    {playerId, playerName},
    function(insertId)
      if insertId then
        print(('User %s (%s) registered automatically!'):format(playerId, playerName))
        registeredPlayers[playerId] = true -- Mark the player as registered in the local array
      else
        print(('Failed to register user %s (%s)'):format(playerId, playerName))
      end
    end
  )
end


-- Event handler for player joining the game
AddEventHandler('playerJoining', function()
  local playerId = source

  -- Check if the player is not already registered
  if not isPlayerRegistered(playerId) then
    registerPlayer(playerId)
  end
end)


-- Function to load all known user IDs from the database at the startup
local function loadKnownUserIDs()
  MySQL.Async.fetchAll(
    "SELECT id FROM users",
    {},
    function(result)
      if result then
        for _, entry in ipairs(result) do
          local userId = tonumber(entry.id)
          if userId then
            registeredPlayers[userId] = true
          end
        end
        print('Known user IDs loaded successfully.')
      else
        print('Failed to load known user IDs from the database.')
      end
    end
  )
end


-- Load known user IDs when the resource starts
AddEventHandler('onResourceStart', function(resourceName)
  if GetCurrentResourceName() == resourceName then
    loadKnownUserIDs()
  end
end)


-- Command to show all recorded users
RegisterCommand("showusers", function(source, args, rawCommand)
  print("Recorded Users:")
  for userId, _ in pairs(registeredPlayers) do
    print(userId)
  end
end, false)
