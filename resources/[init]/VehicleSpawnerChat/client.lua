-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Vehicle mod refrence:
-- https://docs.fivem.net/natives/?_0x6AF0636DDEDCB6DD
local config = {
  keybind               = 170,            -- Default 170: F3
  maxVehicleLimit       = 3,              -- Set your desired vehicle limit here
  vehicleEngineUpgrades = true,           -- Enable vehicle engine related upgrades
  vehicleBodyUpgrades   = true,           -- Enable vehicle body related upgrades
  vehicleNeonKit        = false,          -- Enable Neon kits
  vehicleNeonColorRed   = 255,            -- Red color value (0 - 255)
  vehicleNeonColorGreen = 0,              -- Green color value (0 - 255)
  vehicleNeonColorBlue  = 0,              -- Blue color value (0 - 255)
}
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

-- Function for displaying a notification on the players screen
function ShowNotification(text)
  SetNotificationTextEntry("STRING")
  AddTextComponentString(text)
  DrawNotification(false, false)
end

-- Adding chat command 'spawn' to allow spawning any vehicle by name (restricted with permissions)
RegisterCommand('spawn', function(source, args)
  -- account for the argument not being passed
  local vehicleName = args[1] or 'adder'

  -- check if the vehicle actually exists
  if not IsModelInCdimage(vehicleName) or not IsModelAVehicle(vehicleName) then
    ShowNotification('~r~Error: ~s~Cannot spawn ' .. vehicleName .. '!')
    return
  end

  -- delete vehicle player is or was previously using
  if IsPedInAnyVehicle(GetPlayerPed(-1), true) then
    local delvehin = GetVehiclePedIsIn(GetPlayerPed(-1), true)
    local delvehtrying = GetVehiclePedIsTryingToEnter(GetPlayerPed(-1))
    local delvehenter = GetVehiclePedIsEntering(GetPlayerPed(-1))
    local delvehusing = GetVehiclePedIsUsing(GetPlayerPed(-1))
    DeleteVehicle(delvehin)
    DeleteVehicle(delvehtrying)
    DeleteVehicle(delvehenter)
    DeleteVehicle(delvehusing)
  end

  -- get player coordinates
  local coords = GetEntityCoords(GetPlayerPed(-1))

  -- load the model
  RequestModel(vehicleName)

  -- wait for the model to load
  while not HasModelLoaded(vehicleName) do
    Wait(500)
  end

  -- create the car instance based on player location
  local veh = CreateVehicle(car, coords.x, coords.y, coords.z, GetEntityHeading(GetPlayerPed(-1)), true, false)

  -- Add the spawned vehicle to the player's list with a timestamp
  local timestamp = GetGameTimer()
  table.insert(playerVehicles, {vehicle = veh, timestamp = timestamp})

  -- move ped into car
  SetPedIntoVehicle(playerPed, vehicle, -1)

  -- Check if the player has exceeded their vehicle limit
  if #playerVehicles > config.maxVehicleLimit then
    -- Sort the playerVehicles table based on timestamps (oldest first)
    table.sort(playerVehicles, function(a, b)
      return a.timestamp < b.timestamp
    end)

    -- Get the oldest vehicle in the list
    local oldestVehicle = table.remove(playerVehicles, 1).vehicle

    -- Delete the oldest vehicle
    if DoesEntityExist(oldestVehicle) then
      DeleteVehicle(oldestVehicle)
    end
  end

  -- release the model
  SetModelAsNoLongerNeeded(vehicleName)

  -- enable vehicle mods
  SetVehicleModKit(veh, 0)

  -- install body upgrades
  if config.vehicleBodyUpgrades then
    local bestspoiler = GetNumVehicleMods(veh, 0)-1
    local bestFrontBumper = GetNumVehicleMods(veh, 1) - 1
    local bestRearBumper = GetNumVehicleMods(veh, 2) - 1
    local bestSideSkirts = GetNumVehicleMods(veh, 3) - 1
    local bestHood = GetNumVehicleMods(veh, 7) - 1
    if bestspoiler then
      SetVehicleMod(veh, 0, bestspoiler, false)
    end
    if bestFrontBumper then
      SetVehicleMod(veh, 1, bestFrontBumper, false)
    end
    if bestRearBumper then
      SetVehicleMod(veh, 2, bestRearBumper, false)
    end
    if bestSideSkirts then
      SetVehicleMod(veh, 3, bestSideSkirts, false)
    end
    if bestHood then
      SetVehicleMod(veh, 7, bestHood, false)
    end
  end

  -- install engine upgrades
  if config.vehicleEngineUpgrades then
    local bestengine = GetNumVehicleMods(veh, 11)-1
    local bestbrakes = GetNumVehicleMods(veh, 12)-1
    local bestgearbox = GetNumVehicleMods(veh, 13)-1
    local bestsuspension = GetNumVehicleMods(veh, 15)-1
    local bestarmor = GetNumVehicleMods(veh, 16)-1
    if bestengine then
      SetVehicleMod(veh, 11, bestengine, false)
    end
    if bestbrakes then
      SetVehicleMod(veh, 12, bestbrakes, false)
    end
    if bestgearbox then
      SetVehicleMod(veh, 13, bestgearbox, false)
    end
    if bestsuspension then
      SetVehicleMod(veh, 15, bestsuspension, false)
    end
    if bestarmor then
      SetVehicleMod(veh, 16, bestarmor, false)
    end
  end

  -- everyone gets a turbo
  ToggleVehicleMod(veh, 18, true)

  -- install neon kits
  if config.vehicleNeonKit then
    -- default as all turned on... 0=left, 1=right, 2=front, 3=back
    SetVehicleNeonLightEnabled(veh, 0, true)
    SetVehicleNeonLightEnabled(veh, 1, true)
    SetVehicleNeonLightEnabled(veh, 2, true)
    SetVehicleNeonLightEnabled(veh, 3, true)
    SetVehicleNeonLightsColour(veh, config.vehicleNeonColorRed, config.vehicleNeonColorGreen, config.vehicleNeonColorBlue)
  end

  -- add white HID headlights (stock is -1, white is 0)
  ToggleVehicleMod(veh, 22, true)
  SetVehicleXenonLightsColour(veh, 0)

  -- fresh car wash, nobody wants to spawn a dirty car
  SetVehicleDirtLevel(veh, 0.0)

  -- tell the player
  ShowNotification('~g~Enjoy your shiny new ^*' .. vehicleName .. '!')

end, false)
