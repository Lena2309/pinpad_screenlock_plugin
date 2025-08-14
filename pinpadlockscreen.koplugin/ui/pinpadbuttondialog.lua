--[[
Author: Lena2309
Description: customizes KOReader's existing ButtonDialog class solely
for aesthetic purposes (icon widget, vertical layout...),
with the primary modification in the `init` function.
]]

local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FocusManager = require("ui/widget/focusmanager")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local IconWidget = require("ui/widget/iconwidget")
local LineWidget = require("ui/widget/linewidget")
local MovableContainer = require("ui/widget/container/movablecontainer")
local ScrollTextWidget = require("ui/widget/scrolltextwidget")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Screen = Device.screen
local util = require("util")

local PinpadButtonDialog = FocusManager:extend {
    buttons = nil,
    width = nil,
    width_factor = nil,
    shrink_unneeded_width = false,
    shrink_min_width = nil,
    tap_close_callback = nil,
    alpha = nil,
    rows_per_page = nil,
    title = nil,
    title_align = "left",
    title_face = Font:getFace("x_smalltfont"),
    title_padding = Size.padding.large,
    title_margin = Size.margin.title,
    use_info_style = true,
    info_face = Font:getFace("infofont"),
    info_padding = Size.padding.default,
    info_margin = Size.margin.default,
    dismissable = true,
    override_show_message = false, -- will prevent showing custom lock message even if enabled (specific for changing PIN Code)
}

function PinpadButtonDialog:init()
    if not self.width_factor then
        self.width_factor = 2 / 3
    end
    self.width = math.floor(math.min(Screen:getWidth(), Screen:getHeight()) * self.width_factor)

    if self.dismissable then
        if Device:hasKeys() then
            local back_group = util.tableDeepCopy(Device.input.group.Back)
            if Device:hasFewKeys() then
                table.insert(back_group, "Left")
                self.key_events.Close = { { back_group } }
            else
                table.insert(back_group, "Menu")
                self.key_events.Close = { { back_group } }
            end
        end
        if Device:isTouchDevice() then
            self.ges_events.TapClose = {
                GestureRange:new {
                    ges = "tap",
                    range = Geom:new {
                        x = 0, y = 0,
                        w = Screen:getWidth(),
                        h = Screen:getHeight(),
                    }
                }
            }
        end
    end

    local title_face
    if self.use_info_style then
        title_face = self.info_face
    else
        title_face = self.title_face
    end

    local aesthetic_space = VerticalSpan:new { width = Size.margin.default + Size.padding.default }
    local text_pin_content = VerticalGroup:new {
        align = "center",
        IconWidget:new {
            icon = self.icon,
            alpha = true,
        },
        aesthetic_space,
        VerticalGroup:new {
            align = "center",
            TextBoxWidget:new {
                text = self.title,
                face = title_face,
                width = self.width,
                alignment = self.title_align,
            },
        },
    }

    self.buttontable = ButtonTable:new {
        buttons = self.buttons,
        width = text_pin_content:getSize().w,
        shrink_unneeded_width = self.shrink_unneeded_width,
        shrink_min_width = self.shrink_min_width,
        show_parent = self,
    }

    local separator = LineWidget:new {
        background = Blitbuffer.COLOR_GRAY,
        dimen = Geom:new {
            w = text_pin_content:getSize().w,
            h = Size.line.medium,
        },
    }

    local content
    if G_reader_settings:isTrue("pinpadlock_show_message") and not self.override_show_message then
        local lock_message = G_reader_settings:readSetting("pinpadlock_message")
        lock_message = lock_message:gsub("\\n", "\n") -- enabling jumping lines in the message

        local lock_message_alignment = G_reader_settings:readSetting("pinpadlock_message_alignment")
        local lock_message_position = G_reader_settings:readSetting("pinpadlock_message_position")

        local lock_message_widget = TextBoxWidget:new {
            text = lock_message,
            face = title_face,
            width = self.width,
            alignment = lock_message_alignment,
        }

        -- If the custom message ends up being too tall and makes the Pin Pad taller than the screen,
        -- wrap it inside a ScrollableContainer
        local max_height = self.buttontable:getSize().h + 3 * text_pin_content:getSize().h + Size.line.medium
        local height = self.buttontable:getSize().h + text_pin_content:getSize().h + Size.line.medium +
            lock_message_widget:getSize().h
        if height > max_height then
            local scroll_height = 3 * text_pin_content:getSize().h

            lock_message_widget = ScrollTextWidget:new {
                text = lock_message,
                face = title_face,
                width = self.width,
                alignment = lock_message_alignment,
                dialog = self,
                height = scroll_height,
            }
        end

        if lock_message_position == "top" then
            content = VerticalGroup:new {
                align = "center",
                aesthetic_space,
                lock_message_widget,
                aesthetic_space,
                separator,
                aesthetic_space,
                text_pin_content,
                aesthetic_space,
                separator,
                self.buttontable,
            }
        elseif lock_message_position == "middle" then
            content = VerticalGroup:new {
                align = "center",
                aesthetic_space,
                text_pin_content,
                aesthetic_space,
                separator,
                aesthetic_space,
                lock_message_widget,
                aesthetic_space,
                separator,
                self.buttontable,
            }
        else
            content = VerticalGroup:new {
                align = "center",
                aesthetic_space,
                text_pin_content,
                aesthetic_space,
                separator,
                self.buttontable,
                separator,
                aesthetic_space,
                lock_message_widget,
                aesthetic_space,
            }
        end
    else
        content = VerticalGroup:new {
            align = "center",
            aesthetic_space,
            text_pin_content,
            aesthetic_space,
            separator,
            self.buttontable,
        }
    end

    self.movable = MovableContainer:new {
        alpha = self.alpha,
        anchor = self.anchor,
        FrameContainer:new {
            background = Blitbuffer.COLOR_WHITE,
            bordersize = Size.border.window,
            radius = Size.radius.window,
            padding = Size.padding.default,
            padding_top = 0,
            padding_bottom = 0,
            content,
        },
        unmovable = true,
    }

    self.layout = self.buttontable.layout
    self.buttontable.layout = nil

    self[1] = CenterContainer:new {
        dimen = Screen:getSize(),
        self.movable,
    }
end

function PinpadButtonDialog:getContentSize()
    return self.movable.dimen
end

function PinpadButtonDialog:getButtonById(id)
    return self.buttontable:getButtonById(id)
end

function PinpadButtonDialog:getScrolledOffset()
    if self.cropping_widget then
        return self.cropping_widget:getScrolledOffset()
    end
end

function PinpadButtonDialog:setScrolledOffset(offset_point)
    if offset_point and self.cropping_widget then
        return self.cropping_widget:setScrolledOffset(offset_point)
    end
end

function PinpadButtonDialog:setTitle(title)
    self.title = title
    self:free()
    self:init()
    UIManager:setDirty("all", "ui")
end

function PinpadButtonDialog:onShow()
    UIManager:setDirty(self, function()
        return "ui", self.movable.dimen
    end)
end

function PinpadButtonDialog:onCloseWidget()
    UIManager:setDirty(nil, function()
        return "flashui", self.movable.dimen
    end)
end

function PinpadButtonDialog:onClose()
    if self.tap_close_callback then
        self.tap_close_callback()
    end
    UIManager:close(self)
    return true
end

function PinpadButtonDialog:onTapClose(arg, ges)
    if ges.pos:notIntersectWith(self.movable.dimen) then
        self:onClose()
    end
    return true
end

function PinpadButtonDialog:paintTo(...)
    FocusManager.paintTo(self, ...)
    self.dimen = self.movable.dimen
end

function PinpadButtonDialog:onFocusMove(args)
    local ret = FocusManager.onFocusMove(self, args)

    if self.cropping_widget then
        local focus = self:getFocusItem()
        if self.dimen and focus and focus.dimen then
            local button_y_offset = focus.dimen.y - self.dimen.y - self.top_to_content_offset
            self.cropping_widget:_scrollBy(0, button_y_offset, true)
        end
    end

    return ret
end

function PinpadButtonDialog:_onPageScrollToRow(row)
    self:moveFocusTo(1, row)
end

return PinpadButtonDialog
