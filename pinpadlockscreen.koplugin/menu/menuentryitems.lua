--[[
Author: Lena2309
Description: Displays items in the Screen Menu Entry to manage the plugin
]]

local PinPadMenuEntry = require("menu/pinpadmenuentry")
local _ = require("gettext")

return {
    text = _("PIN Pad Lock"),
    sorting_hint = "screen",
    sub_item_table = {
        {
            text = _("Activated"),
            checked_func = function()
                return PinPadMenuEntry:pinPadEnabled()
            end,
            callback = function()
                G_reader_settings:toggle("pinpadlock_activated")
            end,
            separator = true,
        },
        {
            text = _("Manage PIN Code"),
            keep_menu_open = true,
            sub_item_table = {
                {
                    text = _("Change PIN Code"),
                    callback = function()
                        PinPadMenuEntry:changePinCode()
                    end
                },
                {
                    text = _("Reset PIN Code"),
                    callback = function()
                        PinPadMenuEntry:resetPinCode()
                    end,
                },
            }
        },
        {
            text = _("PIN pad lock message"),
            separator = true,
            sub_item_table = {
                {
                    text = _("Add custom message to lock"),
                    checked_func = function()
                        return PinPadMenuEntry:showMessageEnabled()
                    end,
                    callback = function()
                        G_reader_settings:toggle("pinpadlock_show_message")
                    end,
                    separator = true,
                },
                {
                    text = _("Edit PIN pad lock message"),
                    enabled_func = function()
                        return PinPadMenuEntry:showMessageEnabled()
                    end,
                    keep_menu_open = true,
                    callback = function()
                        PinPadMenuEntry:setMessage()
                    end,
                },
                {
                    text = _("Message position"),
                    enabled_func = function()
                        return PinPadMenuEntry:showMessageEnabled()
                    end,
                    sub_item_table = {
                        PinPadMenuEntry:genRadioMenuItem(_("Top"), "pinpadlock_message_position", "top"),
                        PinPadMenuEntry:genRadioMenuItem(_("Middle"), "pinpadlock_message_position", "middle"),
                        PinPadMenuEntry:genRadioMenuItem(_("Bottom"), "pinpadlock_message_position", "bottom"),
                    },
                },
                {
                    text = _("Message alignment"),
                    enabled_func = function()
                        return PinPadMenuEntry:showMessageEnabled()
                    end,
                    sub_item_table = {
                        PinPadMenuEntry:genRadioMenuItem(_("Left"), "pinpadlock_message_alignment", "left"),
                        PinPadMenuEntry:genRadioMenuItem(_("Center"), "pinpadlock_message_alignment", "center"),
                        PinPadMenuEntry:genRadioMenuItem(_("Right"), "pinpadlock_message_alignment", "right"),
                    },
                },
            }
        },
        {
            text = _("Check for updates"),
            callback = function()
                PinPadMenuEntry:checkForUpdates()
            end,
        }
    }
}
