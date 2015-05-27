---------------------------------------------------------------------------
-- @author Grigory Mishchenko
-- @copyright 2014 Grigory Mishchenko
-- @release awesome-git
---------------------------------------------------------------------------
local type = type
local pairs = pairs
local setmetatable = setmetatable
local huge = math.huge
local min = math.min
local base = require("wibox.layout.base")
local widget_base = require("wibox.widget.base")
local table = table
local draw_widget = require('kindness.helpers').draw_widget

local scroll = { mt = {} }

function scroll:set_cache(width, height)
    local pos = 0
    local drawing = {}
    local widgets = self.widgets

    for k, v in pairs(widgets) do
        local x, y, w, h, _

        if self.dir == "y" then
            x, y, w = 0, pos, width
            _, h = base.fit_widget(v, w, huge)
            h = (h == huge) and height or h
            if k == #widgets then
                self._max_offset = (y + h <= height) and 0 or y + h - height
            end
            pos = pos + h
        else
            x, y, h = pos, 0, height
            w, _ = base.fit_widget(v, huge, h)
            w = (w == huge) and width or w
            if k == #self.widgets then
                self._max_offset = (x + w <= width) and 0 or x + w - width 
            end
            pos = pos + w
        end
        drawing[k] = {widget = v, w = w, h = h, x = x, y = y}
    end
    self._cache_drawing = drawing
end


--- Draw a scroll layout.
-- @param wibox The wibox that this widget is drawn to.
-- @param cr The cairo context to use.
-- @param width The available width.
-- @param height The available height.
function scroll:draw(wibox, cr, width, height)
    if not self._cache_drawing then
        self:set_cache(width, height)
    end

    if self._offset > self._max_offset or self._to_end then
        self._offset = self._max_offset
        self._to_end = false
    elseif self._offset < 0 then
        self._offset = 0
    end

    for k, v in pairs(self._cache_drawing) do
        local x = v.x - (self.dir == "x" and self._offset or 0)
        local y = v.y - (self.dir == "y" and self._offset or 0)
        local widget, w, h = v.widget, v.w, v.h
        -- Draw only visible widgets
        if y + h > 0 and y < height and x + w > 0 and x < width then
            draw_widget(wibox, cr, widget, x, y, w, h, min(w, width - x), min(h, height - y))
        elseif y > height or x > width then
            break
        end
    end
end

function scroll:widget_update()
    self._cache_drawing = nil
    self._emit_updated()
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
    widget:connect_signal("widget::updated", self.widget_update)
    self._cache_drawing = nil
    self._emit_updated()
end

--- Reset a scroll layout. This removes all widgets from the layout.
function scroll:reset()
    for k, v in pairs(self.widgets) do
        v:disconnect_signal("widget::updated", self.widget_update)
    end
    self.widgets = {}
    self._offset = 0
    self._max_offset = 0
    self._to_end = false
    self._cache_drawing = nil
    self._emit_updated()
end

--- Scroll layout content by val.
-- @param val The value in pixels to scroll.
function scroll:scroll(val)
    self._offset = self._offset + val
    self._emit_updated()
end

--- Get offsets.
-- @return Current and maximum offsets.
function scroll:get_offsets()
    return self._offset, self._max_offset
end

--- Scroll to begin of layout.
function scroll:to_begin()
    self._offset = 0
    self._emit_updated()
end

--- Scroll to end of layout.
function scroll:to_end()
    self._to_end = true
    self._emit_updated()
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
    ret._cache_drawing = nil
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
