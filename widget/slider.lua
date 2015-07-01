---------------------------------------------------------------------------
-- @author Grigory Mishchenko
-- @copyright 2014 Grigory Mishchenko
-- @release awesome-git
---------------------------------------------------------------------------
local setmetatable = setmetatable
local type = type
local max = math.max
local pi = math.pi
local widget = require("wibox.widget.base")
local color = require("gears.color")
local round = require('kindness.helpers').round
local cap = require('kindness.helpers').cap
local surface = require("gears.surface")
local cairo = require('lgi').cairo
local capi = { 
    mouse = mouse,
    mousegrabber = mousegrabber
}

-- kindness.widget.slider
local slider = { mt = {} }


local function getValueFromPosition(pos, step, minp, maxp, minv, maxv)
    local percentage = (pos - minp) / ((maxp - minp) or 1)
    local value = step * round(percentage * (maxv - minv) / (step or 1)) + minv
    return cap(value, minv, maxv)
end

local function getPositionFromValue(val, step, minp, maxp, minv, maxv)
    local percentage = (val - minv) / ((maxv - minv) or 1)
    local position = step * round(percentage * (maxp - minp) / (step or 1)) + minp
    return cap(position, minp, maxp)
end


function slider:draw(wibox, cr, width, height)
    local pointer, center
    local data = self.data
    local orient = data.vertical and height or width
    local center = (data.vertical and width or height) / 2
    local pw, ph = self:get_pointer_size()
    local ps = data.vertical and ph/2 or pw/2
    local min_pos = 0
    local max_pos = orient
    local min_bar = 0
    local max_bar = orient
    local pointer_min = ps
    local pointer_max = orient - ps

    if data.mode == 'stop_position' then
        min_pos = ps
        max_pos = orient - ps
    elseif data.mode == 'over' then
        pointer_min = 0
        pointer_max = orient
    elseif data.mode == 'over_margin' then
        min_pos = ps
        max_pos = orient - ps
        min_bar = ps
        max_bar = orient - ps
    end

    self._pos = cap(self._pos, min_pos, max_pos)
    self._val = cap(round(self._val / data.step) * data.step, data.min, data.max)

    if self._update_pos then
        self._pos = getPositionFromValue(self._val, data.step, min_pos, max_pos, data.min, data.max)
    else
        self._val = getValueFromPosition(self._pos, data.step, min_pos, max_pos, data.min, data.max)
        if data.snap then
            self._pos = getPositionFromValue(self._val, data.step, min_pos, max_pos, data.min, data.max)
        end
    end

    local pointer_pos = cap(self._pos, pointer_min, pointer_max)

    cr:set_line_width(data.bar_line_width)
    if not data.vertical then
        pointer = {x=pointer_pos, y=center}
        cr:move_to(min_bar, center)
        cr:line_to(self._pos, center)
        cr:set_source(color(data.bar_color_active))
        cr:stroke()
        cr:move_to(self._pos, center)
        cr:line_to(max_bar, center)
        cr:set_source(color(data.bar_color))
        cr:stroke()
    else
        pointer = {x=center, y=pointer_pos}
        cr:move_to(center, min_bar)
        cr:line_to(center, self._pos)
        cr:set_source(color(data.bar_color))
        cr:stroke()
        cr:move_to(center, self._pos)
        cr:line_to(center, max_bar)
        cr:set_source(color(data.bar_color_active))
        cr:stroke()
    end

    if data.with_pointer then
        cr:set_source_surface(data.pointer, round(pointer.x - pw/2), round(pointer.y - ph/2))
        cr:paint()
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
    self:emit_signal("slider::data_updated")
end

function slider:fit(width, height)
    local pw, ph = self:get_pointer_size()
    local ps = (self.data.vertical) and pw or ph
    local max_size = max(self.data.bar_line_width, ps)
    local w = (self.data.vertical) and max_size or width
    local h = (self.data.vertical) and height or max_size
    return w, h
end

function slider:get_pointer_size()
    return surface.get_size(self.data.pointer)
end

function slider:set_pointer(val)
    if not val then
        local pr = self.data.pointer_radius
        val = cairo.ImageSurface(cairo.Format.ARGB32, pr*2, pr*2)
        local cr = cairo.Context(val)
        cr:set_source(color(self.data.pointer_color))
        cr:arc(pr, pr, pr, 0, 2 * pi)
        cr:fill()
    end
    self.data.pointer = surface.load(val)
    self._emit_updated()
    self:emit_signal("slider::data_updated")
end

function slider:set_pointer_radius(val)
    self.data.pointer_radius = val
    self:set_pointer()
end

function slider:set_pointer_color(val)
    self.data.pointer_color = val
    self:set_pointer()
end

function slider:set_value(val, silent)
    if val == self._val then return end
    self._val = val
    self._silent = silent or false
    self._update_pos = true
    self._emit_updated()
end

function slider:set_mode(mode)
    self.data.mode = mode
    self._update_pos = true
    self._emit_updated()
    self:emit_signal("slider::data_updated")
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
        bar_color_active = args.bar_color_active or "#dddddd",
        draggable = args.draggable == nil and true or args.draggable,
        with_pointer = args.with_pointer == nil and true or args.with_pointer,
        pointer_color = args.pointer_color or "#dddddd",
        bar_line_width = args.bar_line_width or 2,
        pointer_radius = args.pointer_radius or 5,
        min = args.min or 0,
        max = args.max or 100,
        step = args.step or 1,
        snap = args.snap or false,
        mode = args.mode or 'stop'
    }
    ret:add_signal('slider::data_updated')
    
    for k, v in pairs(slider) do
        if type(v) == "function" then
            ret[k] = v
        end
    end

    ret._emit_updated = function()
        ret:emit_signal("widget::updated")
    end

    for k, v in pairs(ret.data) do
        if not ret['set_' .. k] then 
            ret['set_' .. k] = function(self, val)
                self.data[k] = val
                self._emit_updated()
                self:emit_signal("slider::data_updated")
            end
        end
    end

    ret:set_pointer(args.pointer)

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