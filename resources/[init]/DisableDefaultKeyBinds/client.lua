-- Unset default built-in controls for FiveM --
local controlCleared = false

-- Unset the control hash 116 (currently used by simpleCarHUD)
-- Main thread checking if player is in a bounty area
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(0)
    if not controlCleared then
      N_0x06462a961e94b67c(GetHashKey("INPUT_VEH_SELECT_PREV_WEAPON")) -- https://docs.fivem.net/natives/?_0x06462A961E94B67C
      print('cleared keybind for INPUT_VEH_SELECT_PREV_WEAPON')
      controlCleared = true
    end
  end
end)
