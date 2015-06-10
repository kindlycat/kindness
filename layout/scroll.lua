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
local max = math.max
local base = require("wibox.layout.base")
local widget_base = require("wibox.widget.base")
local table = table
local draw_widget = require('kindness.helpers').draw_widget
local cap = require('kindness.helpers').cap
local slider = require('kindness.widget.slider')
local join = require('awful.util').table.join
local color = require("gears.color")
local surface = require("gears.surface")
local cairo = require('lgi').cairo

local scroll = { mt = {} }

function scroll:_set_cache(width, height)
    local pos = 0
    local drawing = {}
    local widgets = self.widgets
    local sb_offset = 0
    local scrollbar_size

    if self.scrollbar then
        local ps = (self.dir == "y") and self.scrollbar:get_size()['w'] or self.scrollbar:get_size()['h']
        scrollbar_size = max(self.scrollbar.data.bar_line_width, ps * 2)
        sb_offset = self.data.scrollbar_ontop and 0 or scrollbar_size
    end

    for k, v in pairs(widgets) do
        local x, y, w, h, _

        if self.dir == "y" then
            x, y, w = 0, pos, width - sb_offset
            _, h = base.fit_widget(v, w, huge)
            h = (h == huge) and height or h
            if k == #widgets then
                self._max_offset = (y + h <= height) and 0 or y + h - height
            end
            pos = pos + h
        else
            x, y, h = pos, 0, height - sb_offset
            w, _ = base.fit_widget(v, huge, h)
            w = (w == huge) and width or w
            if k == #self.widgets then
                self._max_offset = (x + w <= width) and 0 or x + w - width 
            end
            pos = pos + w
        end
        drawing[k] = {widget = v, x = x, y = y, w = w, h = h, 
            rw = min(w - sb_offset, width - x - sb_offset),
            rh = min(h - sb_offset, height - y - sb_offset)
        }
    end

    if self.scrollbar then
        local x = (self.dir == "y") and width - scrollbar_size or 0
        local y = (self.dir == "y") and 0 or height - scrollbar_size
        local w = (self.dir == "y") and scrollbar_size or width
        local h = (self.dir == "y") and height or scrollbar_size
        self.scrollbar.data.max = self._max_offset
        if self.data.custom_pointer then
            local pw = (self.dir == "y") and w or max(w*w/(w+self._max_offset), 15)
            local ph = (self.dir == "y") and max(h*h/(h+self._max_offset), 15) or h
            local img = cairo.ImageSurface(cairo.Format.ARGB32, pw, ph)
            local cr = cairo.Context(img)
            cr.source = color(self.scrollbar.data.pointer_color)
            cr:paint()
            self.scrollbar.data.pointer = surface.load(img)
            self.scrollbar._pointer_size = {w=pw/2, h=ph/2}
        end
        self._cache_scrollbar = {x=x, y=y, w=w, h=h}
    end

    self._cache_drawing = drawing
end


--- Draw a scroll layout.
-- @param wibox The wibox that this widget is drawn to.
-- @param cr The cairo context to use.
-- @param width The available width.
-- @param height The available height.
function scroll:draw(wibox, cr, width, height)
    local cached = self._cache_drawing
    if not cached then
        self:_set_cache(width, height)
    end

    self._offset = cap(self._offset, 0, self._max_offset)

    for k, v in pairs(self._cache_drawing) do
        local x = v.x - (self.dir == "x" and self._offset or 0)
        local y = v.y - (self.dir == "y" and self._offset or 0)
        local widget, w, h, rw, rh = v.widget, v.w, v.h, v.rw, v.rh
        -- Draw only visible widgets
        if y + h > 0 and y < height and x + w > 0 and x < width then
            draw_widget(wibox, cr, widget, x, y, w, h, rw, rh)
        elseif y > height or x > width then
            break
        end
    end

    if self.scrollbar and self._show_scrollbar then
        draw_widget(wibox, cr, self.scrollbar, 
            self._cache_scrollbar.x, self._cache_scrollbar.y,
            self._cache_scrollbar.w, self._cache_scrollbar.h,
            self._cache_scrollbar.w, self._cache_scrollbar.h
        )
    end
    self._to_end = false
end

--- Add a widget to the given scroll layout.
-- @param widget
function scroll:add(widget)
    widget_base.check_widget(widget)
    table.insert(self.widgets, widget)
    widget:connect_signal("widget::updated", self._widget_update)
    self._cache_drawing = nil
    self._emit_updated()
end

--- Reset a scroll layout. This removes all widgets from the layout.
function scroll:reset()
    for k, v in pairs(self.widgets) do
        v:disconnect_signal("widget::updated", self._widget_update)
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
    if self.scrollbar then
        self.scrollbar:set_value(self._offset, true)
    end
    self._emit_updated()
end

function scroll:_set_offset(val)
    self._offset = val
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

local function get_layout(dir, args)
    local ret = widget_base.make_widget()
    local args = args or {}

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
    ret._show_scrollbar = (args.scrollbar and not args.scrollbar_hover)
    ret.data = args or {}
    ret.data['custom_pointer'] = (args.custom_pointer == nil) and true or args.custom_pointer

    ret._emit_updated = function()
        ret:emit_signal("widget::updated")
    end

    ret.fit = function(self, w, h) return w, h end

    ret._widget_update = function()
        ret._cache_drawing = nil
        ret._emit_updated()
    end

    if args.scrollbar then
        local sl_args = {
            bar_line_width = 8,
            pointer_radius = 4,
            pointer_color = '#222222',
            mode = 'stop_position',
            vertical=(dir == 'y')
        }
        ret.scrollbar = slider(function(v) ret:_set_offset(v) end, join(sl_args, args))

        if args.scrollbar_hover then
            if (ret.data.scrollbar_ontop == nil) then
                ret.data.scrollbar_ontop = true
            end
            ret:connect_signal("mouse::enter", function()
                ret._show_scrollbar = true
                ret._emit_updated()
            end)
            ret:connect_signal("mouse::leave", function()
                ret._show_scrollbar = false
                ret._emit_updated()
            end)
        end
        
        ret.scrollbar:connect_signal("widget::updated", ret._emit_updated)
        ret.scrollbar:connect_signal("slider::data_updated", function() ret._widget_update(ret) end)
    end

    return ret
end

--- Returns a new horizontal scroll layout. This layout can scroll content inside.
-- Widgets can be added via :add() and scrolled via :scroll().
function scroll.horizontal(args)
    return get_layout("x", args)
end

--- Returns a new vertical scroll layout. This layout can scroll content inside.
-- Widgets can be added via :add() and scrolled via :scroll().
function scroll.vertical(args)
    return get_layout("y", args)
end

return setmetatable(scroll, scroll.mt)

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
