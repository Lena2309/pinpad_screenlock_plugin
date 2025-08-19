local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local PinPadDialog = require("ui/pinpaddialog")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

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

return PinPadMenuEntry
