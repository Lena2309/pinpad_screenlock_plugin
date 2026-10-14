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
    if _frozen then
        return
    end
    Device.screen_saver_lock = false
    Device.screen_saver_mode = false
    if not _original_setup then
        _original_setup = Screensaver.setup
    end
    _original_close = Screensaver.close
    Screensaver.setup = function()
    end
    Screensaver.close = function()
    end
    _frozen = true
end

-- Restore screensaver normal behavior
function ScreensaverUtil.unfreeze(callback)
    local orig_setup = _original_setup or (callback and Screensaver.setup) or nil
    if orig_setup then
        if callback then
            Screensaver.setup = function(...)
                Screensaver.setup = orig_setup
                callback()
                return orig_setup(...)
            end
        else
            Screensaver.setup = orig_setup
        end
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
