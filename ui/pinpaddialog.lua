--[[
Author: Lena2309
Description: represents a PIN pad interface and its behavior within KOReader.
It handles user input, PIN validation, and UI interactions.
]]

local Blitbuffer = require("ffi/blitbuffer")
local BookStatusWidget = require("ui/widget/bookstatuswidget")
local Button = require("ui/widget/button")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local InfoMessage = require("ui/widget/infomessage")
local ImageWidget = require("ui/widget/imagewidget")
local PinPadButtonDialog = require("ui/pinpadbuttondialog")
local RenderImage = require("ui/renderimage")
local Screensaver = require("ui/screensaver")
local ScreenSaverWidget = require("ui/widget/screensaverwidget")
local UIManager = require("ui/uimanager")
local ffiUtil = require("ffi/util")
local util = require("util")
local _ = require("gettext")
local Screen = Device.screen

local ScreensaverUtil = require("util/screensaverutil")

local DGENERIC_ICON_SIZE = G_defaults:readSetting("DGENERIC_ICON_SIZE")

local LOCKED_TEXT = _("Enter your PIN")
local CONFIRM_CURRENT_CODE_TEXT = _("Enter the current PIN Code")
local NEW_CODE_TEXT = _("Enter the new PIN Code")

local MAX_TRIES_LIMIT = tonumber(G_reader_settings:readSetting("pinpadlock_max_tries"))
local TIMEOUT_TIME = tonumber(G_reader_settings:readSetting("pinpadlock_timeout_time"))

if G_reader_settings:hasNot("current_tries_number") then
    G_reader_settings:saveSetting("current_tries_number", 0)
end
if G_reader_settings:hasNot("block_start_time") then
    G_reader_settings:saveSetting("block_start_time", 0)
end

local PinPadDialog = FrameContainer:extend {
    stage = "locked", -- "confirm_current_code" or "enter_new_code"
    icon_size = Screen:scaleBySize(DGENERIC_ICON_SIZE) * 1.25,
}

function PinPadDialog:init()
    self:setDialogText()
    self.pin = ""
    self.buttons = self:initializeButtons()
    return self
end

function PinPadDialog:setDialogText()
    if self.stage == "locked" then
        self.dialog_text = LOCKED_TEXT
    elseif self.stage == "confirm_current_code" then
        self.dialog_text = CONFIRM_CURRENT_CODE_TEXT
    else
        self.dialog_text = NEW_CODE_TEXT
    end
end

function PinPadDialog:createButton(text, callback, hold_callback)
    local button = Button:new {
        text = text,
        callback = callback,
        hold_callback = hold_callback,
    }
    return button
end

function PinPadDialog:initializeButtons()
    local ref_self = self
    local buttons = {
        {
            self:createButton("1", function() ref_self:onAppendToPin("1") end),
            self:createButton("2", function() ref_self:onAppendToPin("2") end),
            self:createButton("3", function() ref_self:onAppendToPin("3") end),
        },
        {
            self:createButton("4", function() ref_self:onAppendToPin("4") end),
            self:createButton("5", function() ref_self:onAppendToPin("5") end),
            self:createButton("6", function() ref_self:onAppendToPin("6") end),
        },
        {
            self:createButton("7", function() ref_self:onAppendToPin("7") end),
            self:createButton("8", function() ref_self:onAppendToPin("8") end),
            self:createButton("9", function() ref_self:onAppendToPin("9") end),
        },
        {
            self:createButton("Cancel", function() ref_self:onDelete() end, function() ref_self:onCancel() end),
            self:createButton("0", function() ref_self:onAppendToPin("0") end),
            self:createButton("OK", function() ref_self:onOk() end),
        }
    }
    return buttons
end

function PinPadDialog:initializeScreensaverBackground()
    if Screensaver.screensaver_type == "disable" and not Screensaver.show_message and not Screensaver.overlay_message then
        return
    end

    local rotation_mode = Screen:getRotationMode()

    if Screensaver:modeExpectsPortrait() then
        Device.orig_rotation_mode = rotation_mode
        if bit.band(Device.orig_rotation_mode, 1) == 1 then
            Screen:setRotationMode(Screen.DEVICE_ROTATED_UPRIGHT)
        else
            Device.orig_rotation_mode = nil
        end

        if Device:hasEinkScreen() and Screensaver:modeIsImage() then
            if Screensaver:withBackground() then
                Screen:clear()
            end
            Screen:refreshFull(0, 0, Screen:getWidth(), Screen:getHeight())

            if Device:isKobo() and Device:isSunxi() then
                ffiUtil.usleep(150 * 1000)
            end
        end
    else
        Device.orig_rotation_mode = nil
    end

    local widget = nil
    if Screensaver.screensaver_type == "cover" or Screensaver.screensaver_type == "random_image" then
        local widget_settings = {
            width = Screen:getWidth(),
            height = Screen:getHeight(),
            scale_factor = G_reader_settings:isFalse("screensaver_stretch_images") and 0 or nil,
            stretch_limit_percentage = G_reader_settings:readSetting("screensaver_stretch_limit_percentage"),
        }
        if Screensaver.image then
            widget_settings.image = Screensaver.image
            widget_settings.image_disposable = true
        elseif Screensaver.image_file then
            if G_reader_settings:isTrue("screensaver_rotate_auto_for_best_fit") then
                if util.getFileNameSuffix(Screensaver.image_file) == "svg" then
                    widget_settings.image = RenderImage:renderSVGImageFile(Screensaver.image_file, nil, nil, 1)
                else
                    widget_settings.image = RenderImage:renderImageFile(Screensaver.image_file, false, nil, nil)
                end
                if not widget_settings.image then
                    widget_settings.image = RenderImage:renderCheckerboard(Screen:getWidth(), Screen:getHeight(),
                        Screen.bb:getType())
                end
                widget_settings.image_disposable = true
            else
                widget_settings.file = Screensaver.image_file
                widget_settings.file_do_cache = false
            end
            widget_settings.alpha = true
        end
        if G_reader_settings:isTrue("screensaver_rotate_auto_for_best_fit") then
            local angle = rotation_mode == 3 and 180 or 0
            if (widget_settings.image:getWidth() < widget_settings.image:getHeight()) ~= (widget_settings.width < widget_settings.height) then
                angle = angle + (G_reader_settings:isTrue("imageviewer_rotation_landscape_invert") and -90 or 90)
            end
            widget_settings.rotation_angle = angle
        end
        widget = ImageWidget:new(widget_settings)
    elseif Screensaver.screensaver_type == "bookstatus" then
        local ReaderUI = require("apps/reader/readerui")
        widget = BookStatusWidget:new {
            ui = ReaderUI.instance,
            readonly = true,
        }
    elseif Screensaver.screensaver_type == "readingprogress" then
        widget = Screensaver.getReaderProgress()
    end

    local covers_fullscreen = true
    local background
    if Screensaver.screensaver_background == "white" then
        background = Blitbuffer.COLOR_WHITE
    elseif Screensaver.screensaver_background == "none" then
        background = nil
    else
        background = Blitbuffer.COLOR_BLACK
    end

    UIManager:setIgnoreTouchInput(false)

    if widget then
        self.screensaver_widget = ScreenSaverWidget:new {
            widget = widget,
            background = background,
            covers_fullscreen = covers_fullscreen,
        }
        self.screensaver_widget.dithered = true
    else
        local currentFileSource = debug.getinfo(1, "S").source
        local plugin_dir
        if currentFileSource:find("^@") then
            plugin_dir = currentFileSource:gsub("^@(.*)/[^/]*", "%1")
        end
        -- dummy widget
        widget = ImageWidget:new {
            file = plugin_dir .. "/icons/lock.svg",
            alpha = true,
            width = self.icon_size,
            height = self.icon_size,
            scale_factor = 0,
            original_in_nightmode = false,
        }
        self.screensaver_widget = ScreenSaverWidget:new {
            widget = widget,
            background = Blitbuffer.COLOR_BLACK,
            covers_fullscreen = covers_fullscreen,
        }
        self.screensaver_widget.dithered = true
    end
end

function PinPadDialog:isBlocked()
    local block_start = G_reader_settings:readSetting("block_start_time") or 0
    if block_start == 0 then
        if self.blocking_dialog then
            UIManager:close(self.blocking_dialog, "ui")
            self.blocking_dialog = nil
        end
        return false
    end

    local elapsed = os.time() - block_start

    if elapsed < 0 then
        G_reader_settings:saveSetting("block_start_time", 0)
        G_reader_settings:saveSetting("current_tries_number", 0)
        if self.blocking_dialog then
            UIManager:close(self.blocking_dialog, "ui")
            self.blocking_dialog = nil
        end
        return false
    end

    if elapsed >= TIMEOUT_TIME then
        if self.blocking_dialog then
            UIManager:close(self.blocking_dialog, "ui")
            self.blocking_dialog = nil
        end
        return false
    else
        self.remaining_block_time = TIMEOUT_TIME - elapsed
        return true
    end
end

function PinPadDialog:showPinPad()
    local screensaver_visible = UIManager:isWidgetShown(Screensaver.screensaver_widget)

    if screensaver_visible then
        ScreensaverUtil.freeze()
        self.reused_screensaver = true
    else
        Screensaver:setup()
        self:initializeScreensaverBackground()
        if self.screensaver_widget then
            UIManager:show(self.screensaver_widget)
        end
        self.reused_screensaver = false
    end


    local currentFileSource = debug.getinfo(1, "S").source
    local plugin_dir
    if currentFileSource:find("^@") then
        plugin_dir = currentFileSource:gsub("^@(.*)/[^/]*", "%1")
    end

    if self.stage == "locked" then
        self.dialog = PinPadButtonDialog:new {
            title = self.dialog_text,
            title_align = "center",
            use_info_style = false,
            buttons = self.buttons,
            dismissable = false,
            ImageWidget:new {
                file = plugin_dir .. "/icons/lock.svg",
                alpha = true,
                width = self.icon_size,
                height = self.icon_size,
                scale_factor = 0,
                original_in_nightmode = false,
            }
        }
    else
        self.dialog = PinPadButtonDialog:new {
            title = self.dialog_text,
            title_align = "center",
            use_info_style = false,
            buttons = self.buttons,
            dismissable = true,
            override_show_message = true,
            ImageWidget:new {
                file = plugin_dir .. "/icons/lock.svg",
                alpha = true,
                width = self.icon_size,
                height = self.icon_size,
                scale_factor = 0,
                original_in_nightmode = false,
            }
        }
    end

    UIManager:show(self.dialog, "ui")
    UIManager:nextTick(function()
        for i = 1, #UIManager._window_stack do
            if UIManager._window_stack[i].widget == self.dialog then
                local dialog_entry = table.remove(UIManager._window_stack, i)
                table.insert(UIManager._window_stack, dialog_entry)
                UIManager:setDirty(self.dialog, "ui")
                break
            end
        end
    end)

    if self.stage == "locked" and self:isBlocked() then
        self:showBlockingDialog(self.remaining_block_time)
    end
end

function PinPadDialog:showBlockingDialog(remaining_time)
    self.blocking_dialog = InfoMessage:new {
        text = _("Too many failed attempts. Wait " .. remaining_time .. " seconds."),
        timeout = remaining_time,
        dismissable = false,
    }

    UIManager:show(self.blocking_dialog, "ui")
    UIManager:nextTick(function()
        if not self.blocking_dialog then return end
        for i = 1, #UIManager._window_stack do
            if UIManager._window_stack[i].widget == self.blocking_dialog then
                local blocking_entry = table.remove(UIManager._window_stack, i)
                table.insert(UIManager._window_stack, blocking_entry)
                UIManager:setDirty(self.blocking_dialog, "ui")
                break
            end
        end
    end)
end

function PinPadDialog:reset()
    self.pin = ""
    self:setDialogText()
end

function PinPadDialog:closeDialogs()
    if self.digit_display_timer then
        self.digit_display_timer:stop()
        self.digit_display_timer = nil
    end
    if self.blocking_dialog then
        UIManager:close(self.blocking_dialog, "ui")
    end
    if self.dialog then
        UIManager:close(self.dialog, "ui")
    end
end

function PinPadDialog:close(callback_function)
    self:reset()
    if not callback_function then
        self:closeDialogs()
    end
    if self.reused_screensaver then
        ScreensaverUtil.forceClose(function()
            if callback_function then
                self:closeDialogs()
                callback_function()
            end
        end)
    else
        if self.screensaver_widget then
            ScreensaverUtil.forceClose(function()
                if callback_function then
                    self:closeDialogs()
                    callback_function()
                end
            end)
            UIManager:close(self.screensaver_widget)
            self.screensaver_widget = nil
        end
    end
end

function PinPadDialog:onAppendToPin(digit)
    if self.digit_display_timer then
        self.digit_display_timer:stop()
        self.digit_display_timer = nil
    end
    if self.dialog_text == LOCKED_TEXT or self.dialog_text == CONFIRM_CURRENT_CODE_TEXT or self.dialog_text == NEW_CODE_TEXT then
        self.dialog_text = ""
    end
    self.pin = self.pin .. digit

    if G_reader_settings:isTrue("pinpadlock_display_digit_activated") then
        local temp_display_text = self.dialog_text .. digit
        self.dialog:updateTitle(temp_display_text)

        self.dialog_text = self.dialog_text .. "*"

        self.digit_display_timer = UIManager:scheduleIn(1, function()
            self.dialog:updateTitle(self.dialog_text)
            self.digit_display_timer = nil
        end)
    else
        self.dialog_text = self.dialog_text .. "*"
        self.dialog:updateTitle(self.dialog_text)
    end
end

function PinPadDialog:onOk()
    if self.stage == "locked" then
        if self.pin == G_reader_settings:readSetting("pinpadlock_pin_code") then
            self:close()
            if G_reader_settings:isTrue("pinpadlock_correct_pin_message_activated") then
                UIManager:show(InfoMessage:new { text = _("Correct PIN, have fun !"), timeout = 2 })
            end
            G_reader_settings:saveSetting("current_tries_number", 0)
            G_reader_settings:saveSetting("block_start_time", 0)
            G_reader_settings:makeFalse("suspended_device")
        else
            if self.pin == "" then
                return
            end
            local current_tries = G_reader_settings:readSetting("current_tries_number")
            if (current_tries + 1) >= MAX_TRIES_LIMIT then
                G_reader_settings:saveSetting("block_start_time", os.time())
                self:showBlockingDialog(TIMEOUT_TIME)
            else
                G_reader_settings:saveSetting("current_tries_number", current_tries + 1)
                UIManager:show(InfoMessage:new { text = _("Wrong PIN, try again."), timeout = 2 })
            end
            self:onCancel()
        end
    elseif self.stage == "confirm_current_code" then
        if self.pin == G_reader_settings:readSetting("pinpadlock_pin_code") then
            self:close()
            UIManager:show(InfoMessage:new { text = _("Correct PIN, you may change your PIN Code !"), timeout = 2 })
            local enterNewCode = PinPadDialog:new { stage = "enter_new_code" }
            enterNewCode:showPinPad()
        else
            UIManager:show(InfoMessage:new { text = _("Wrong PIN, try again."), timeout = 2 })
            self:onCancel()
        end
    else
        G_reader_settings:saveSetting("pinpadlock_pin_code", self.pin)
        self:close()
        UIManager:show(InfoMessage:new { text = _("PIN Code changed successfully !"), timeout = 2 })
    end
end

function PinPadDialog:onDelete()
    if self.pin == "" then
        return
    elseif #self.pin == 1 then
        self.pin = ""
    else
        self.pin = self.pin:sub(1, #self.pin - 1)
    end

    if #self.dialog_text == 1 then
        self:setDialogText()
    elseif not (self.dialog_text == LOCKED_TEXT or self.dialog_text == CONFIRM_CURRENT_CODE_TEXT or self.dialog_text == NEW_CODE_TEXT) then
        self.dialog_text = self.dialog_text:sub(1, #self.dialog_text - 1)
    end
    self.dialog:updateTitle(self.dialog_text)
end

function PinPadDialog:onCancel()
    if self.pin == "" then
        return
    end
    self:reset()
    self.dialog:updateTitle(self.dialog_text)
end

return PinPadDialog
