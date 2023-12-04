-------------------------------------------------------------------------------------
--- Add blips at Los Santos Customs to allow players to modify vehicles           ---
-------------------------------------------------------------------------------------
-- Global configurations
local config = {
    debug_enabled             = true,   -- Debug logging to local console
    openMenuKey               = 29,     -- default key bind (E), only works inside the marker
    markerDisplayDistance     = 16.0,   -- distance in which to draw markers
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
        { name = 'test', value = 'test' },
    },
    ['Vehicle Modifications'] = {
        { name = 'test', value = 'test' },
    },
}
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

-- Initilize NativeUI menu
_menuPool = NativeUI.CreatePool()
customMenu = NativeUI.CreateMenu("Los Santos Customs", "~g~What do you want to modify?", 1430, 0)
_menuPool:Add(customMenu)
customMenu.SetMenuWidthOffset(50);
function initMenu(menu)
    table.sort(garageOptions)
    for Name, Options in pairs(garageOptions) do
        print('Name: ' .. Name)
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
    print("mod name: " .. mod_name .. " mod value: " .. mod_value )
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
            DrawMarker(1, location.x, location.y, location.z - 1.0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 255, 255, 0, 200, false, false, 2, nil, nil, false)

            if IsControlJustPressed(0, config.openMenuKey) then -- Replace with the desired control key
                customMenu:Visible(not customMenu:Visible())
            end

            if IsPlayerInMarkerArea(playerCoords) and isInsideMarker == false then
                isInsideMarker = true
                ShowNotification("~s~Press ~r~E ~s~to modify vehicle")
            end
        else
            isInsideMarker = false
        end

    end
end)
