---------------------------------------------------------------------------
-- @author Grigory Mishchenko
-- @copyright 2014 Grigory Mishchenko
-- @release awesome-git
---------------------------------------------------------------------------
local setmetatable = setmetatable
local type = type
local widget = require("wibox.widget.base")
local color = require("gears.color")
local round = require('kindness.helpers').round
local cap = require('kindness.helpers').cap
local capi = { 
    mouse = mouse,
    mousegrabber = mousegrabber
}

-- kindness.widget.slider
local slider = { mt = {} }


local function getValueFromPosition(pos, step, maxp, minv, maxv)
    local percentage = pos / (maxp or 1)
    local value = step * round(percentage * (maxv - minv) / step) + minv
    return cap(value, minv, maxv)
end

local function getPositionFromValue(val, minp, maxp, minv, maxv)
    local percentage = (val - minv) / (maxv - minv)
    local position = percentage * maxp
    return cap(position, 0, maxp)
end

function slider:draw(wibox, cr, width, height)
    local pointer, center
    local data = self.data
    local center = (data.vertical and width or height) / 2 - data.bar_line_width / 2
    local pointer_max = data.vertical and height - data.pointer_radius or width - data.pointer_radius
    local max_pos = data.vertical and height or width

    if self._update_pos then
        self._pos = getPositionFromValue(self._val, 0, max_pos, data.min, data.max)
    else
        self._val = getValueFromPosition(self._pos, data.step, max_pos, data.min, data.max)
        if data.snap then
            self._pos = getPositionFromValue(self._val, 0, max_pos, data.min, data.max)
        end
    end

    local pointer_pos = cap(self._pos, data.pointer_radius, pointer_max)

    cr:set_line_width(data.bar_line_width)
    if not data.vertical then
        pointer = {x=pointer_pos, y=center}
        cr:move_to(0, center)
        cr:line_to(self._pos, center)
        cr:set_source(color(data.bar_color_active))
        cr:stroke()
        cr:move_to(self._pos, center)
        cr:line_to(width, center)
        cr:set_source(color(data.bar_color))
        cr:stroke()
    else
        pointer = {x=center, y=pointer_pos}
        cr:move_to(center, 0)
        cr:line_to(center, self._pos)
        cr:set_source(color(data.bar_color))
        cr:stroke()
        cr:move_to(center, self._pos)
        cr:line_to(center, height)
        cr:set_source(color(data.bar_color_active))
        cr:stroke()
    end

    if data.with_pointer then
        cr:set_source(color(data.pointer_color))
        cr:arc(pointer.x, pointer.y, data.pointer_radius, 0, 2 * math.pi)
        cr:fill()
    end

    if self._val ~= self._cache_val and not self._silent and self._move_function then 
        self._move_function(self._val)
    end

    self._cache_val = self._val
    self._silent = false
    self._update_pos = false
end

function slider:set_vertical(vertical)
    self.data.vertical = vertical
    self._update_pos = true
    self._emit_updated()
end

function slider:set_value(val, silent)
    if val == self._val then return end
    self._val = val
    self._silent = silent or false
    self._update_pos = true
    self._emit_updated()
end

function slider:get_value()
    return self._val
end

--- Create a slider widget.
-- @return A slider widget.
local function new(move, args)
    local ret = widget.make_widget()
    local args = args or {}
    ret._pos = 0
    ret._val = 0
    ret._cache_val = 0
    ret._silent = false
    ret._move_function = move or nil
    ret._update_pos = true
    ret.data = {
        vertical = args.vertical or false,
        bar_color = args.bar_color or "#dddddd",
        bar_color_active = args.bar_color_active or bar_color,
        draggable = args.draggable == nil and true or args.draggable,
        with_pointer = args.with_pointer == nil and true or args.with_pointer,
        pointer_color = args.pointer_color or "#dddddd",
        bar_line_width = args.bar_line_width or 2,
        pointer_radius = args.pointer_radius or 5,
        min = args.min or 0,
        max = args.max or 100,
        step = args.step or 1,
        snap = args.snap or false
    }

    ret.fit = function(self, w, h) return w, h end
    
    for k, v in pairs(slider) do
        if type(v) == "function" then
            ret[k] = v
        end
    end

    ret._emit_updated = function()
        ret:emit_signal("widget::updated")
    end

    for k, v in pairs(ret.data) do
        ret['set_' .. k] = function(self, val)
            self.data[k] = val
            self._emit_updated()
        end
    end

    ret:connect_signal("button::press", function (v, x, y)
        ret._pos = ret.data.vertical and y or x
        if ret.data.draggable then
            local mc = mouse:coords()
            local minx = mc['x'] - x
            local miny = mc['y'] - y
            capi.mousegrabber.run(function (_mouse)
                for k, v in ipairs(_mouse.buttons) do
                    if k == 1 and v then
                        ret._pos = ret.data.vertical and _mouse.y - miny or _mouse.x - minx
                        ret._emit_updated()
                        return true
                    end
                end
                return false
            end, "fleur")
        else
            ret._emit_updated()
        end
    end)
    return ret
end

function slider.mt:__call(...)
    return new(...)
end

return setmetatable(slider, slider.mt)

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80