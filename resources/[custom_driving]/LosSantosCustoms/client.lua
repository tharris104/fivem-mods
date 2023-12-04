-------------------------------------------------------------------------------------
--- Add blips at Los Santos Customs to allow players to modify vehicles           ---
-------------------------------------------------------------------------------------
-- Global configurations
local config = {
    debug_enabled             = true,   -- Debug logging to local console
    openMenuKey               = 86,     -- default key bind (E), only works inside the marker
    markerDisplayDistance     = 25.0,   -- distance in which to draw markers
}
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Define where Los Santos Garages are located (coordinates)
local garageLocations = {
    { x = -339.7, y = -136.6, z = 38.57 },
}
local garageOptions = {
    ['Paint Job'] = {
        { name = 'Randomize', value = 'random' },
    },
    ['Engine Modifications'] = {
        { name = 'test', value = 'test' },
    },
    ['Body Modifications'] = {
        { name = 'test', value = 'test' },
    },
}
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

-- Initilize NativeUI menu
_menuPool = NativeUI.CreatePool()
customMenu = NativeUI.CreateMenu("Los Santos Customs", "~g~What would you like to modify?", 1430, 0)
_menuPool:Add(customMenu)
customMenu.SetMenuWidthOffset(50);
function initMenu(menu)
    table.sort(garageOptions)
    for Name, Options in pairs(garageOptions) do
        local garage_category = _menuPool:AddSubMenu(menu, Name, '', true)
        for _, Option in pairs(Options) do
            local option_name = NativeUI.CreateItem(Option.name, '')
            garage_category:AddItem(option_name)
            option_name.Activated = function(ParentMenu, SelectedItem)
                modifyVehicle(Option.name, Option.value)
            end
        end
    end
end
-- menu parameters
initMenu(customMenu)
_menuPool:RefreshIndex()
_menuPool:MouseControlsEnabled (false)
_menuPool:MouseEdgeEnabled (false)
_menuPool:ControlDisablingEnabled(false)

-- Function for modifying the current vehicle player is in
function modifyVehicle(mod_name, mod_value)
    local playerVehicle = GetVehiclePedIsIn(PlayerPedId(), true) -- return last vehicle even if they get out

    if DoesEntityExist(playerVehicle) and GetPedInVehicleSeat(playerVehicle, -1) == PlayerPedId() then
        if mod_value == 'random' then
            local randomPrimaryColor = math.random(0, 255) -- Adjust the range as needed
            local randomSecondaryColor = math.random(0, 255) -- Adjust the range as needed
            SetVehicleColours(playerVehicle, randomPrimaryColor, randomSecondaryColor)
            ShowNotification("~s~Vehicle colors randomized!")
        end
    else
        ShowNotification("~r~You must be inside a vehicle to modify it.")
    end
end

-- Function for displaying notifications to player
function ShowNotification(text)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(text)
    DrawNotification(false, false)
end

-- Function to check if a player is inside a marker area
function IsPlayerInMarkerArea(playerCoords)
    for _, location in pairs(garageLocations) do
        local distance = GetDistanceBetweenCoords(playerCoords.x, playerCoords.y, playerCoords.z, location.x, location.y, location.z, true)
        if distance <= 1.0 then
            return true, location
        end
    end
    return false, nil
end

-- Function to check if a player is near a marker area
function IsPlayerNearMarkerArea(playerCoords)
    for _, location in pairs(garageLocations) do
        local distance = GetDistanceBetweenCoords(playerCoords.x, playerCoords.y, playerCoords.z, location.x, location.y, location.z, true)
        if distance < config.markerDisplayDistance then
            return true, location
        end
    end
    return false, nil
end

-- Main thread checking if player is in a bounty area
Citizen.CreateThread(function()
    local isInsideMarker = false -- lock used so notifications are not spammed

    while true do
        Citizen.Wait(0)
        _menuPool:ProcessMenus()

        local playerCoords = GetEntityCoords(PlayerPedId())
        local isPlayerNearMarkerArea, location = IsPlayerNearMarkerArea(playerCoords)

        if isPlayerNearMarkerArea then
            DrawMarker(1, location.x, location.y, location.z - 1.0, 0, 0, 0, 0, 0, 0, 3.0, 3.0, 3.0, 255, 255, 0, 200, false, false, 2, nil, nil, false)

            if IsControlJustPressed(0, config.openMenuKey) then -- Replace with the desired control key
                customMenu:Visible(not customMenu:Visible())
            end

            if IsPlayerInMarkerArea(playerCoords) and isInsideMarker == false then
                isInsideMarker = true
                ShowNotification("~s~Press ~r~E ~s~to modify vehicle")
            elseif IsPlayerInMarkerArea(playerCoords) == false then
                isInsideMarker = false
            end
        else
            isInsideMarker = false
        end

    end
end)
