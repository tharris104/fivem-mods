-- Unset default built-in controls for FiveM --
local controlCleared = false

-- Unset the control hash 116 (currently used by simpleCarHUD)
if not controlCleared then
  N_0x06462a961e94b67c(GetHashKey("INPUT_VEH_SELECT_PREV_WEAPON")) -- https://docs.fivem.net/natives/?_0x06462A961E94B67C
  controlCleared = true
end
