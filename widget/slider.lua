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
local notzero = require('kindness.helpers').notzero
local cap = require('kindness.helpers').cap
local surface = require("gears.surface")
local cairo = require('lgi').cairo
local capi = { 
    mouse = mouse,
    mousegrabber = mousegrabber
}

-- kindness.widget.slider
local slider = { mt = {} }


function slider:_get_value()
    local cache = self._cache
    local data = self.data
    local percentage = (self._pos - cache.pos.min) / notzero((cache.pos.max - cache.pos.min), 1)
    local value = data.step * round(percentage * (data.max - data.min) / data.step) + data.min
    return cap(value, data.min, data.max)
end

function slider:_get_position()
    local cache = self._cache
    local data = self.data
    local percentage = (self._val - data.min) / notzero((data.max - data.min), 1)
    local position = percentage * (cache.pos.max - cache.pos.min) + cache.pos.min
    return cap(position, cache.pos.min, cache.pos.max)
end

function slider:_set_cache(width, height)
    local center
    local data = self.data
    local orient = data.vertical and height or width
    local center = (data.vertical and width or height) / 2
    local pw, ph = self:get_pointer_size()
    local ps = data.vertical and ph / 2 or pw / 2
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

    if (center % 2 == 0 and data.bar_line_width % 2 ~= 0) or
        (center % 2 ~= 0 and data.bar_line_width % 2 == 0) then
        center = center + 0.5
    end

    self._cache = {
        center = center,
        pos = {
            min = min_pos,
            max = max_pos
        },
        bar = {
            min = min_bar,
            max = max_bar
        },
        pointer = {
            min = pointer_min,
            max = pointer_max,
            size = ps,
            width = pw / 2,
            height = ph / 2
        },
        w = width,
        h = height
    }
end

function slider:draw(wibox, cr, width, height)
    if not self._cache or self._cache.w ~= width or self._cache.h ~= height then
        self:_set_cache(width, height)
    end

    local pointer
    local data = self.data
    local cache = self._cache

    self._pos = cap(self._pos, cache.pos.min, cache.pos.max)
    self._val = cap(self._val, data.min, data.max)

    if self._update_pos then
        self._pos = self:_get_position()
        self._update_pos = false
    else
        self._val = self:_get_value()
        if data.snap then
            self._pos = self:_get_position()
        end
    end

    local pointer_pos = cap(self._pos, cache.pointer.min, cache.pointer.max)

    cr:set_line_width(data.bar_line_width)
    if not data.vertical then
        pointer = {x=pointer_pos, y=cache.center}
        cr:move_to(cache.bar.min, cache.center)
        cr:line_to(self._pos, cache.center)
        cr:set_source(color(data.bar_color_active))
        cr:stroke()
        cr:move_to(self._pos, cache.center)
        cr:line_to(cache.bar.max, cache.center)
        cr:set_source(color(data.bar_color))
        cr:stroke()
    else
        pointer = {x=cache.center, y=pointer_pos}
        cr:move_to(cache.center, cache.bar.min)
        cr:line_to(cache.center, self._pos)
        cr:set_source(color(data.bar_color))
        cr:stroke()
        cr:move_to(cache.center, self._pos)
        cr:line_to(cache.center, cache.bar.max)
        cr:set_source(color(data.bar_color_active))
        cr:stroke()
    end

    if data.with_pointer then
        cr:set_source_surface(
            data.pointer,
            round(pointer.x - cache.pointer.width),
            round(pointer.y - cache.pointer.height)
        )
        cr:paint()
    end

    if self._val ~= self._cache_val then 
        self:emit_signal("slider::value_updated")
    end
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

function slider:set_pointer(val, redraw)
    if not val then
        local pr = self.data.pointer_radius
        val = cairo.ImageSurface(cairo.Format.ARGB32, pr*2, pr*2)
        local cr = cairo.Context(val)
        cr:set_source(color(self.data.pointer_color))
        cr:arc(pr, pr, pr, 0, 2 * pi)
        cr:fill()
    end
    self.data.pointer = surface.load(val)
    if redraw then
        self._emit_redraw()
    else
        self._emit_updated()
    end
    self:emit_signal("slider::data_updated")
end

function slider:set_pointer_radius(val)
    self.data.pointer_radius = val
    self:set_pointer()
end

function slider:set_pointer_color(val)
    self.data.pointer_color = val
    self:set_pointer(nil, true)
end

function slider:set_value(val, silent)
    if val == self._val or self._is_dragging then return end
    self._val = val
    self._silent = silent or false
    self._update_pos = true
    self._emit_redraw()
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
    ret._silent = false
    ret._update_pos = true
    ret._is_dragging = false
    ret._cache = nil
    ret._move_function = type(move) == 'function' and move or nil
    ret._before_function = type(args.before) == 'function' and args.before or nil
    ret._after_function = type(args.after) == 'function' and args.after or nil
    ret.data = {
        vertical = args.vertical or false,
        bar_color = args.bar_color or "#dddddd",
        bar_color_active = args.bar_color_active or "#dddddd",
        draggable = args.draggable == nil and true or args.draggable,
        with_pointer = args.with_pointer == nil and true or args.with_pointer,
        pointer_color = args.pointer_color or "#dddddd",
        pointer_color_active = args.pointer_color_active or '#dddddd',
        bar_line_width = args.bar_line_width or 2,
        pointer_radius = args.pointer_radius or 5,
        min = args.min or 0,
        max = args.max or 100,
        step = args.step or 1,
        snap = args.snap or false,
        mode = args.mode or 'stop',
        cursor = args.cursor or 'fleur'
    }

    ret:add_signal('slider::data_updated')
    ret:add_signal('slider::value_updated')
    
    ret._emit_updated = function()
        ret._cache = nil
        ret:emit_signal("widget::updated")
    end

    ret._emit_redraw = function()
        ret:emit_signal("widget::updated")
    end
    
    for k, v in pairs(slider) do
        if type(v) == "function" then
            ret[k] = v
        end
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

    ret._val = cap(args.initial or ret.data.min, ret.data.min, ret.data.max)
    ret._cache_val = ret._val
    ret:set_pointer(args.pointer)

    ret:connect_signal("slider::value_updated", function()
        if not ret._silent then
            ret._move_function(ret._val)
            ret._cache_val = ret._val
        else
            ret._silent = false
        end
    end)

    ret:connect_signal("button::press", function (v, x, y)
        if ret._before_function then ret._before_function(ret._val) end
        ret._pos = ret.data.vertical and y or x
        ret._emit_redraw()

        if ret.data.draggable then
            local mc = mouse.coords()
            local minx = mc['x'] - x
            local miny = mc['y'] - y
            ret._is_dragging = true
            capi.mousegrabber.run(function (_mouse)
                -- todo: use _mouse.buttons[1]
                if not mouse.coords()['buttons'][1] then
                    if ret._after_function then ret._after_function(ret._val) end
                    ret._is_dragging = false
                    return false
                end

                local new_pos = ret.data.vertical and _mouse.y - miny or _mouse.x - minx
                if new_pos ~= ret._pos then
                    ret._pos = new_pos
                    ret._emit_redraw()
                end
                return true
            end, ret.data.cursor or "fleur")
        end
    end)
    return ret
end

function slider.mt:__call(...)
    return new(...)
end

return setmetatable(slider, slider.mt)

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80