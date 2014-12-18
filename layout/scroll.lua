---------------------------------------------------------------------------
-- @author Grigory Mishchenko
-- @copyright 2014 Grigory Mishchenko
-- @release @AWESOME_VERSION@
---------------------------------------------------------------------------

local type = type
local pairs = pairs
local setmetatable = setmetatable
local huge = math.huge
local base = require("wibox.layout.base")
local widget_base = require("wibox.widget.base")
local table = table

-- wibox.layout.scroll
local scroll = { mt = {} }


-- Patched version of base.draw_widget. Register only wisible part of widget.
local function draw_widget(wibox, cr, widget, x, y, width, height, reg_w, reg_h)
    -- Use save() / restore() so that our modifications aren't permanent
    cr:save()

    -- Move (0, 0) to the place where the widget should show up
    cr:translate(x, y)

    -- Make sure the widget cannot draw outside of the allowed area
    cr:rectangle(0, 0, width, height)
    cr:clip()

    -- Let the widget draw itself
    local success, msg = pcall(widget.draw, widget, wibox, cr, width, height)
    if not success then
        print("Error while drawing widget: " .. msg)
    end

    -- Register the widget for input handling
    wibox:widget_at(widget, base.rect_to_device_geometry(cr, 0, 0, reg_w, reg_h))

    cr:restore()
end


--- Draw a scroll layout.
-- @param wibox The wibox that this widget is drawn to.
-- @param cr The cairo context to use.
-- @param width The available width.
-- @param height The available height.
function scroll:draw(wibox, cr, width, height)
    local pos = 0
    local current_offset = {x = 0, y = 0}
    local drawing = {}

    for k, v in pairs(self.widgets) do
        local x, y, w, h, _

        if self.dir == "y" then
            x, y, w = 0, pos, width
            _, h = base.fit_widget(v, w, huge)
            h = (h == huge) and height or h
            if k == #self.widgets then
                self._max_offset = y + h - height 
                if y + h <= height then
                    self._max_offset = 0
                    self._offset = 0
                elseif self._offset > self._max_offset or self._to_end then
                    self._offset = self._max_offset
                    self._to_end = false
                end
                current_offset.y = self._offset 
            end
            pos = pos + h 
        else
            x, y, h = pos, 0, height
            w, _ = base.fit_widget(v, huge, h)
            w = (w == huge) and width or w
            if k == #self.widgets then
                self._max_offset = x + w - width 
                if x + w <= width then
                    self._max_offset = 0
                    self._offset = 0
                elseif self._offset > self._max_offset or self._to_end then
                    self._offset = self._max_offset
                    self._to_end = false
                end
                current_offset.x = self._offset 
            end
            pos = pos + w
        end
        drawing[k] = {widget = v, w = w, h = h, x = x, y = y}
    end
    for k, v in pairs(drawing) do
        v.x = v.x - current_offset.x
        v.y = v.y - current_offset.y
        -- Draw only visible widgets
        if (self.dir == "y" and v.y + v.h > 0 and v.y < height) or
            (self.dir ~= "y" and v.x + v.w > 0 and v.x < width) then
            if (self.dir == "y" and v.y + v.h > height) then
                draw_widget(wibox, cr, v.widget, v.x, v.y, v.w, v.h, v.w, v.h - (v.y + v.h - height))
            elseif (self.dir ~= "y" and v.x + v.w > width) then
                draw_widget(wibox, cr, v.widget, v.x, v.y, v.w, v.h, v.w - (v.x + v.w - width), v.h)
            else
                base.draw_widget(wibox, cr, v.widget, v.x, v.y , v.w, v.h)
            end
        elseif (self.dir == "y" and v.y > height) or
            (self.dir ~= "y" and v.x > width) then
            break
        end
    end
end


--- Fit the scroll layout into the given area.
-- @param w The available width.
-- @param h The available height.
-- @return The width and height that the widget wants to use.
function scroll:fit(w, h)
    return w, h
end

--- Add a widget to the given scroll layout.
-- @param widget
function scroll:add(widget)
    widget_base.check_widget(widget)
    table.insert(self.widgets, widget)
    widget:connect_signal("widget::updated", self._emit_updated)
    self:emit_signal("widget::updated")
end

--- Reset a scroll layout. This removes all widgets from the layout.
function scroll:reset()
    for k, v in pairs(self.widgets) do
        v:disconnect_signal("widget::updated", self._emit_updated)
    end
    self.widgets = {}
    self._offset = 0
    self._max_offset = 0
    self._to_end = false
    self:emit_signal("widget::updated")
end

--- Scroll layout content by val.
-- @param val The value in pixels to scroll.
function scroll:scroll(val)
    self._offset = self._offset + val
    if self._offset < 0 then
        self._offset = 0
    end
    self:emit_signal("widget::updated")
end

--- Get offsets.
-- @return Current and maximum offsets.
function scroll:get_offsets()
    return self._offset, self._max_offset
end

--- Scroll to begin of layout.
function scroll:to_begin()
    self._offset = 0
    self:emit_signal("widget::updated")
end

--- Scroll to end of layout.
function scroll:to_end()
    self._to_end = true
    self:emit_signal("widget::updated")
end

local function get_layout(dir)
    local ret = widget_base.make_widget()

    for k, v in pairs(scroll) do
        if type(v) == "function" then
            ret[k] = v
        end
    end

    ret.dir = dir
    ret.widgets = {}
    ret._offset = 0
    ret._max_offset = 0 
    ret._to_end = false
    ret._emit_updated = function()
        ret:emit_signal("widget::updated")
    end

    return ret
end

--- Returns a new horizontal scroll layout. This layout can scroll content inside.
-- Widgets can be added via :add() and scrolled via :scroll().
function scroll.horizontal()
    return get_layout("x")
end

--- Returns a new vertical scroll layout. This layout can scroll content inside.
-- Widgets can be added via :add() and scrolled via :scroll().
function scroll.vertical()
    return get_layout("y")
end

return setmetatable(scroll, scroll.mt)

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
