local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local PinPadDialog = require("ui/pinpaddialog")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("dkjson")

local PinPadMenuEntry = {}

function PinPadMenuEntry:setMessage()
    local lock_message = G_reader_settings:readSetting("pinpadlock_message")
    local input_dialog
    input_dialog = InputDialog:new {
        title = _("PIN pad lock message"),
        description = _("Enter a custom message to be displayed on the PIN pad lock."),
        input = lock_message,
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = _("Set message"),
                    is_enter_default = true,
                    callback = function()
                        G_reader_settings:saveSetting("pinpadlock_message", input_dialog:getInputText())
                        UIManager:close(input_dialog)
                    end,
                },
            },
        },
    }
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function PinPadMenuEntry:showMessageEnabled()
    return G_reader_settings:isTrue("pinpadlock_show_message")
end

function PinPadMenuEntry:genRadioMenuItem(text, setting, value)
    return {
        text = text,
        checked_func = function()
            return G_reader_settings:readSetting(setting) == value
        end,
        callback = function()
            G_reader_settings:saveSetting(setting, value)
        end,
        radio = true,
    }
end

function PinPadMenuEntry:changePinCode()
    local confirmCurrentCode = PinPadDialog:new { stage = "confirm_current_code" }
    confirmCurrentCode:showPinPad()
end

function PinPadMenuEntry:resetPinCode()
    local confirmBox
    confirmBox = ConfirmBox:new {
        text = _("Do you really want to reset the PIN code to \"1234\" ?"),
        ok_text = _("Yes"),
        ok_callback = function()
            G_reader_settings:saveSetting("pinpadlock_pin_code", "1234")
            UIManager:close(confirmBox)
            UIManager:show(InfoMessage:new { text = _("PIN Code resetted successfully."), timeout = 1 })
        end,
        cancel_callback = function()
            UIManager:close(confirmBox)
        end
    }
    UIManager:show(confirmBox)
end

-- Parse a version string like "v1.2.3"
local function parseVersion(version)
    local major, minor, patch = version:match("^v(%d+)%.(%d+)%.(%d+)$")
    return {
        major = tonumber(major) or 0,
        minor = tonumber(minor) or 0,
        patch = tonumber(patch) or 0
    }
end

-- Returns -1 if a < b, 0 if equal, 1 if a > b
local function compareVersions(local_version, remote_version)
    if local_version.major ~= remote_version.major then
        if local_version.major > remote_version.major then
            return 1
        else
            return -1
        end
    elseif local_version.minor ~= remote_version.minor then
        if local_version.minor > remote_version.minor then
            return 1
        else
            return -1
        end
    elseif local_version.patch ~= remote_version.patch then
        if local_version.patch > remote_version.patch then
            return 1
        else
            return -1
        end
    end
    return 0
end

function PinPadMenuEntry:checkForUpdates()
    local meta = dofile("plugins/pinpadlockscreen.koplugin/_meta.lua")
    local local_version = meta.version or "unknown"

    local response_body = {}
    local ok, status = http.request {
        url = "https://api.github.com/repos/Lena2309/pinpad_screenlock_plugin/releases/latest",
        sink = ltn12.sink.table(response_body),
        redirect = true
    }

    if not ok or status ~= 200 then
        UIManager:show(InfoMessage:new {
            text = _("Unable to check for updates. Make sure your device is connected to the Internet."),
            timeout = 3,
        })
        return
    end

    local body = table.concat(response_body)
    local data, pos, err = json.decode(body, 1, nil)

    if not data or not data.tag_name then
        UIManager:show(InfoMessage:new {
            text = _("Error parsing GitHub release info."),
            timeout = 3,
        })
        return
    end

    local remote_version = data.tag_name
    local cmp = compareVersions(parseVersion(local_version), parseVersion(remote_version))
    if cmp < 0 then
        UIManager:show(InfoMessage:new {
            text = _("New version available: ") .. remote_version ..
                _("\nYou are running: ") .. local_version,
            timeout = 5,
        })
    else
        if cmp > 0 then
            UIManager:show(InfoMessage:new {
                text = _("You’re ahead of the official release.\nLatest official version: " .. remote_version),
                timeout = 5,
            })
        else
            UIManager:show(InfoMessage:new {
                text = _("You are up to date!"),
                timeout = 3,
            })
        end
    end
end

return PinPadMenuEntry
