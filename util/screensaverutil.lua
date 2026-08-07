--[[
Author: Lena2309, oleasteo (original inspiration)
Inspiration and original skeleton from `https://github.com/oleasteo/koreader-screenlockpin`
Description: Utility to prevent screensaver from closing and manage z-order
]]

local Device = require("device")
local Screensaver = require("ui/screensaver")

local ScreensaverUtil = {}

local _original_setup = nil
local _original_close = nil
local _frozen = false

-- Prevent screensaver from closing
function ScreensaverUtil.freeze()
    if _frozen then return end
    Device.screen_saver_lock = false
    Device.screen_saver_mode = false
    if not _original_setup then
        _original_setup = Screensaver.setup
    end
    _original_close = Screensaver.close
    Screensaver.setup = function() end
    Screensaver.close = function() end
    _frozen = true
end

-- Restore screensaver normal behavior
function ScreensaverUtil.unfreeze(callback)
    if callback and _original_setup then
        Screensaver.setup = function()
            callback()
            _original_setup(Screensaver)
        end
    elseif _original_setup then
        Screensaver.setup = _original_setup
        _original_setup = nil
    end
    if _original_close then
        Screensaver.close = _original_close
        _original_close = nil
    end
    _frozen = false
end

function ScreensaverUtil.forceClose(callback)
    ScreensaverUtil.unfreeze(callback)
    Screensaver:close_widget()
end

return ScreensaverUtil
