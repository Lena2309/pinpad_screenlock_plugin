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
            text = _("Advanced Settings"),
            sub_item_table = {
                {
                    text = _("Activate correct PIN pop-up"),
                    checked_func = function()
                        return PinPadMenuEntry:correctPinMessageEnabled()
                    end,
                    callback = function()
                        G_reader_settings:toggle("pinpadlock_correct_pin_message_activated")
                    end,
                },
                {
                    text = _("Display entered digit before hiding it"),
                    checked_func = function()
                        return PinPadMenuEntry:displayDigitEnabled()
                    end,
                    callback = function()
                        G_reader_settings:toggle("pinpadlock_display_digit_activated")
                    end,
                },
                {
                    text = _("Set Timeout time"),
                    sub_item_table = {
                        PinPadMenuEntry:genRadioMenuItem(_("10 seconds"), "pinpadlock_timeout_time", "10"),
                        PinPadMenuEntry:genRadioMenuItem(_("30 seconds"), "pinpadlock_timeout_time", "30"),
                        PinPadMenuEntry:genRadioMenuItem(_("60 seconds"), "pinpadlock_timeout_time", "60"),
                    },
                },
                {
                    text = _("Set max tries before timeout"),
                    sub_item_table = {
                        PinPadMenuEntry:genRadioMenuItem(_("1"), "pinpadlock_max_tries", "1"),
                        PinPadMenuEntry:genRadioMenuItem(_("3"), "pinpadlock_max_tries", "3"),
                        PinPadMenuEntry:genRadioMenuItem(_("6"), "pinpadlock_max_tries", "6"),
                    },
                },
            },
        },
        {
            text = _("Check for updates"),
            callback = function()
                PinPadMenuEntry:checkForUpdates()
            end,
        }
    }
}
