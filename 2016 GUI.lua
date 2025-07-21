if input ~= nil then
    return 
end

input = {
    input_state = {},
    prev_input_state = {}
}

input.keys = {
    toggle = ui.new_hotkey("LUA", "A", "Input manager - toggle menu", false),
    lmouse = ui.new_hotkey("LUA", "A", "Input manager - mouse left", false),
    rmouse = ui.new_hotkey("LUA", "A", "Input manager - mouse right", false)
}

input.update = function ()
    for key, handle in pairs(input.keys) do 
        input.prev_input_state[key] = input.input_state[key] or false
        input.input_state[key] = ui.get(handle)
    end
end

input.is_key_pressed = function (key)
    for _key, _ in pairs(input.input_state) do 
        if _key == key then
            return _ == true and input.prev_input_state[key] == false
        end
    end
    
    return false
end

input.is_key_down = function (key)
    for _key, _ in pairs(input.input_state) do 
        if _key == key then 
            return _
        end
    end
    
    return false
end

input.is_key_released = function (key)
    for _key, _ in pairs(input.input_state) do 
        if _key == key then 
            return _ == false and input.prev_input_state[key] == true
        end
    end
    
    return false
end

if gui ~= nil then 
    return
end

function string:split(sSeparator, nMax, bRegexp)
    assert(sSeparator ~= '')
    assert(nMax == nil or nMax >= 1)
 
    local aRecord = {}
 
    if self:len() > 0 then
        local bPlain = not bRegexp
        nMax = nMax or -1
 
        local nField, nStart = 1, 1
        local nFirst,nLast = self:find(sSeparator, nStart, bPlain)
        while nFirst and nMax ~= 0 do
            aRecord[nField] = self:sub(nStart, nFirst-1)
            nField = nField+1
            nStart = nLast+1
            nFirst,nLast = self:find(sSeparator, nStart, bPlain)
            nMax = nMax-1
        end
        aRecord[nField] = self:sub(nStart)
    end
 
    return aRecord
end

function string:starts_with(str)
    return self:sub(1, str:len()) == str
end

gui = {}

local function gs_line(x1, y1, x2, y2, r, g, b, a)
    renderer.line(x1, y1, x2, y2, math.min(r + 2, 255), math.min(g + 2, 255), math.min(b + 2, 255), a)
end

local function gs_outline(x, y, w, h, r, g, b, a)
    gs_line(x, y, x + w, y, r, g, b, a)
    gs_line(x + w, y, x + w, y + h, r, g, b, a)
    gs_line(x + w, y + h, x, y + h, r, g, b, a)
    gs_line(x, y + h, x, y, r, g, b, a)
end

local function gs_fill(x, y, w, h, r, g, b, a)
    renderer.rectangle(x, y, w, h, math.min(r + 2, 255), math.min(g + 2, 255), math.min(b + 2, 255), a)
end

local function gs_gradient(x, y, w, h, r1, g1, b1, a1, r2, g2, b2, a2, horizontal)
    renderer.gradient(x, y, w, h, math.min(r1 + 2, 255), math.min(g1 + 2, 255), math.min(b1 + 2, 255), a1,
        math.min(r2 + 2, 255), math.min(g2 + 2, 255), math.min(b2 + 2, 255), a2, horizontal)
end

local function gs_map_number(x, a, b, c, d)
    return (x - a) / (b - a) * (d - c) + c
end

local function gs_form_defaults()
    return {
        pos_x = 100,
        pos_y = 100,
        min_size_x = 660,
        min_size_y = 478
    }
end

local function gs_make_context(defaults)
    return {
        pos_x = defaults.pos_x,
        pos_y = defaults.pos_y,
        size_x = defaults.min_size_x,
        size_y = defaults.min_size_y,
        open = true,
        alpha = 255,
        tabs = {},
        active_tab = 1,
        blocking = nil,
        blocking_action = nil,
        dragging = false,
        mouse_pos_x = 0,
        mouse_pos_y = 0,
        mouse_delta_x = 0,
        mouse_delta_y = 0,
        cursor_pos_stack = {}
    }
end

local function gs_set_cursor_pos(ctx, x, y)
    table.insert(ctx.cursor_pos_stack, { x, y })
    return ctx
end

local function gs_get_cursor_pos(ctx)
    return table.remove(ctx.cursor_pos_stack, #ctx.cursor_pos_stack), ctx
end

local function gs_generate_id(ctx, name)
    return (ctx.parent or "root") .. "." .. name
end

local function gs_form(ctx, defaults)
    if defaults == nil then
        defaults = gs_form_defaults()
    end
    
    if ctx == nil then
        ctx = gs_make_context(defaults)
    end

    local mouse_pos_x, mouse_pos_y = ui.mouse_position()

    ctx.mouse_delta_x, ctx.mouse_delta_y = mouse_pos_x - ctx.mouse_pos_x, mouse_pos_y - ctx.mouse_pos_y
    ctx.mouse_pos_x, ctx.mouse_pos_y = mouse_pos_x, mouse_pos_y

    local fade_factor = ((1 / (135 / 1000)) * globals.frametime()) * 255

    if input.is_key_pressed("toggle") then
        ctx.open = not ctx.open
    end

    if ctx.open and ctx.alpha < 255 then
        ctx.alpha = math.min(ctx.alpha + fade_factor, 255)
    elseif not ctx.open and ctx.alpha > 0 then
        ctx.alpha = math.max(ctx.alpha - fade_factor, 0)
    end

    if ctx.open or ctx.alpha > 0 then
        local title_bar_hovered = mouse_pos_x > ctx.pos_x and mouse_pos_y > ctx.pos_y - 6 and
            mouse_pos_x < ctx.pos_x + ctx.size_x and mouse_pos_y < ctx.pos_y + 6

        if not ctx.dragging and input.is_key_pressed("lmouse") and title_bar_hovered then
            ctx.dragging = true
        elseif ctx.dragging and input.is_key_down("lmouse") then
            ctx.pos_x = ctx.pos_x + ctx.mouse_delta_x
            ctx.pos_y = ctx.pos_y + ctx.mouse_delta_y
        elseif ctx.dragging and not input.is_key_down("lmouse") then
            ctx.dragging = false
        end

        gs_fill(ctx.pos_x, ctx.pos_y, ctx.size_x, ctx.size_y, 22, 22, 22, ctx.alpha)
    
        gs_outline(ctx.pos_x, ctx.pos_y, ctx.size_x, ctx.size_y, 22, 22, 22, ctx.alpha)
        gs_outline(ctx.pos_x - 1, ctx.pos_y - 1, ctx.size_x + 2, ctx.size_y + 2, 60, 60, 60, ctx.alpha)
        gs_outline(ctx.pos_x - 2, ctx.pos_y - 2, ctx.size_x + 4, ctx.size_y + 4, 40, 40, 40, ctx.alpha)
        gs_outline(ctx.pos_x - 3, ctx.pos_y - 3, ctx.size_x + 6, ctx.size_y + 6, 40, 40, 40, ctx.alpha)
        gs_outline(ctx.pos_x - 4, ctx.pos_y - 4, ctx.size_x + 8, ctx.size_y + 8, 40, 40, 40, ctx.alpha)
        gs_outline(ctx.pos_x - 5, ctx.pos_y - 5, ctx.size_x + 10, ctx.size_y + 10, 60, 60, 60, ctx.alpha)
        gs_outline(ctx.pos_x - 6, ctx.pos_y - 6, ctx.size_x + 12, ctx.size_y + 12, 22, 22, 22, ctx.alpha)

        gs_gradient(ctx.pos_x + 1, ctx.pos_y + 1, (ctx.size_x / 2) - 2, 2, 59, 175, 222, ctx.alpha, 202, 70, 205, ctx.alpha, true)
        gs_gradient(ctx.pos_x + (ctx.size_x / 2) - 1, ctx.pos_y + 1, (ctx.size_x / 2) + 1, 2, 202, 70, 205, ctx.alpha, 221, 227, 78, ctx.alpha, true)
        gs_line(ctx.pos_x + 1, ctx.pos_y + 2, ctx.pos_x + ctx.size_x, ctx.pos_y + 2, 0, 0, 0, 150)

        for i = 1, #ctx.tabs do
            local tab = ctx.tabs[i]
            local tab_w, tab_h = renderer.measure_text("+", tab)
        
            if ctx.active_tab == i then
                renderer.text(ctx.pos_x + 12, ctx.pos_y + 24 + ((i - 1) * (tab_h - 4)), 255, 255, 255, ctx.alpha, "+", 0, tab)
            else 
                local hovered_min = ctx.mouse_pos_x > ctx.pos_x + 12 and ctx.mouse_pos_y > ctx.pos_y + 24 + ((i - 1) * (tab_h - 4))
                local hovered_max = ctx.mouse_pos_x < ctx.pos_x + 12 + tab_w and ctx.mouse_pos_y < ctx.pos_y + 24 + ((i - 1) * (tab_h - 4)) + (tab_h - 4)

                if hovered_min and hovered_max then
                    if input.is_key_pressed("lmouse") then
                        ctx.active_tab = i 
                    else
                        renderer.text(ctx.pos_x + 12, ctx.pos_y + 24 + ((i - 1) * (tab_h - 4)), 150, 150, 150, ctx.alpha, "+", 0, tab)
                    end
                else
                    renderer.text(ctx.pos_x + 12, ctx.pos_y + 24 + ((i - 1) * (tab_h - 4)), 80, 80, 80, ctx.alpha, "+", 0, tab)
                end
            end
        end
    end
    
    ctx.tabs = {}
    ctx.cursor_pos_stack = {}

    ctx = gs_set_cursor_pos(ctx, 148, 24)

    return ctx
end

local function gs_tab(ctx, name, callback)
    if ctx == nil then
        return
    end

    if callback == nil then
        callback = function () end
    end

    table.insert(ctx.tabs, name)

    if ctx.active_tab == #ctx.tabs then
        callback()

        if ctx.blocking_action ~= nil then
            ctx.blocking_action()
            ctx.blocking_action = nil
        end
    end

    return ctx
end

local function gs_group(ctx, name, size_x, size_y)
    local cursor = gs_get_cursor_pos(ctx)

    if (cursor[2] - 24) + size_y > ctx.size_y - 32 then
        cursor[1] = cursor[1] + size_x + 16
        cursor[2] = 24
    end

    local pos_x = ctx.pos_x + cursor[1]
    local pos_y = ctx.pos_y + cursor[2]

    local label_width, label_height = renderer.measure_text("b", name:split("#")[1])

    -- dark outline
    gs_line(pos_x, pos_y, pos_x + 12, pos_y, 0, 0, 0, ctx.alpha)
    gs_line(pos_x + 14 + label_width + 2, pos_y, pos_x + size_x, pos_y, 0, 0, 0, ctx.alpha)

    gs_line(pos_x + size_x, pos_y, pos_x + size_x, pos_y + size_y, 0, 0, 0, ctx.alpha)
    gs_line(pos_x + size_x, pos_y + size_y, pos_x, pos_y + size_y, 0, 0, 0, ctx.alpha)
    gs_line(pos_x, pos_y + size_y, pos_x, pos_y, 0, 0, 0, ctx.alpha)

    -- light outline
    gs_line(pos_x + 1, pos_y + 1, pos_x + 12, pos_y + 1, 48, 48, 48, ctx.alpha)
    gs_line(pos_x + 14 + label_width + 2, pos_y + 1, pos_x + size_x - 1, pos_y + 1, 48, 48, 48, ctx.alpha)
    
    gs_line(pos_x + size_x - 1, pos_y + 1, pos_x + size_x - 1, pos_y + size_y - 1, 48, 48, 48, ctx.alpha)
    gs_line(pos_x + size_x - 1, pos_y + size_y - 1, pos_x + 1, pos_y + size_y - 1, 48, 48, 48, ctx.alpha)
    gs_line(pos_x + 1, pos_y + size_y - 1, pos_x + 1, pos_y + 1, 48, 48, 48, ctx.alpha)

    -- label
    renderer.text(pos_x + 14, pos_y - 6, 203, 203, 203, ctx.alpha, "b", 0, name:split("#")[1])

    ctx = gs_set_cursor_pos(ctx, cursor[1] + 2 + 20, cursor[2] + 2 + 20)
    ctx.parent = "root." .. ctx.tabs[ctx.active_tab] .. "." .. name
    ctx.parent_width = size_x

    return ctx, {
        cursor_pos_x = cursor[1],
        cursor_pos_y = cursor[2] + size_y + 10
    }
end

local function gs_checkbox(ctx, name, reference)
    local cursor = gs_get_cursor_pos(ctx)

    local pos_x = ctx.pos_x + cursor[1]
    local pos_y = ctx.pos_y + cursor[2]

    local label_width, label_height = renderer.measure_text("b", name:split("#")[1])

    local alt_label = name:starts_with("!")
    if alt_label then name = name:split("!", 1)[2] end

    local hovered_min = ctx.mouse_pos_x > pos_x - 1 and ctx.mouse_pos_y > pos_y - 1
    local hovered_max = ctx.mouse_pos_x < pos_x + 8 and ctx.mouse_pos_y < pos_y + 8

    local hovered_text_min = ctx.mouse_pos_x > pos_x + 18 and ctx.mouse_pos_y > pos_y - 4
    local hovered_text_max = ctx.mouse_pos_x < pos_x + 18 + label_width and ctx.mouse_pos_y < pos_y - 4 + label_height

    gs_outline(pos_x - 1, pos_y - 1, 7, 7, 0, 0, 0, ctx.alpha)

    if ui.get(reference) == true then
        gs_gradient(pos_x, pos_y, 6, 6, ctx.accent_color[1], ctx.accent_color[2], ctx.accent_color[3], ctx.accent_color[4] * (ctx.alpha / 255),
            ctx.accent_color[1] * 0.55, ctx.accent_color[2] * 0.55, ctx.accent_color[3] * 0.55, ctx.accent_color[4] * (ctx.alpha / 255), false)
    else
        if hovered_min and hovered_max then
            gs_gradient(pos_x, pos_y, 6, 6, 83, 83, 83, ctx.alpha, 58, 58, 58, ctx.alpha, false)
        else
            gs_gradient(pos_x, pos_y, 6, 6, 75, 75, 75, ctx.alpha, 51, 51, 51, ctx.alpha, false)
        end
    end

    if alt_label then
        renderer.text(pos_x + 18, pos_y - 4, 166, 166, 93, ctx.alpha, nil, 0, name:split("#")[1])
    else
        renderer.text(pos_x + 18, pos_y - 4, 203, 203, 203, ctx.alpha, nil, 0, name:split("#")[1])
    end
    ctx = gs_set_cursor_pos(ctx, cursor[1], cursor[2] + 18)

    if ctx.blocking == gs_generate_id(ctx, name) then
        if not input.is_key_down("lmouse") then
            ctx.blocking = nil

            if ((hovered_min and hovered_max) or (hovered_text_min and hovered_text_max)) then
                ui.set(reference, not ui.get(reference))
            end
        end
    elseif ctx.blocking == nil then
        if input.is_key_pressed("lmouse") and ((hovered_min and hovered_max) or (hovered_text_min and hovered_text_max)) then
            ctx.blocking = gs_generate_id(ctx, name)
        end
    end

    return ctx
end

local function gs_slider(ctx, name, reference, min, max, display, inline)
    if display == nil then
        display = "%.0f"
    end

    local cursor = gs_get_cursor_pos(ctx)

    local pos_x = ctx.pos_x + cursor[1]
    local pos_y = ctx.pos_y + cursor[2]

    local bar_position = pos_y
    
    if not inline then
        bar_position = bar_position + 13
    end

    local bar_max_width = ctx.parent_width - 40 - 38
    local bar_width = gs_map_number(ui.get(reference), min, max, 0, bar_max_width)

    local hovered_min = ctx.mouse_pos_x > pos_x + 17 and ctx.mouse_pos_y > bar_position - 1
    local hovered_max = ctx.mouse_pos_x < pos_x + 18 + bar_max_width and ctx.mouse_pos_y < bar_position + 7

    local alt_label = name:starts_with("!")
    if alt_label then name = name:split("!", 1)[2] end

    if bar_width < 0 then bar_width = 0 end
    if bar_width > bar_max_width then bar_width = bar_max_width end

    gs_outline(pos_x + 17, bar_position - 1, bar_max_width + 1, 7, 0, 0, 0, ctx.alpha)

    gs_gradient(pos_x + 18, bar_position, bar_max_width, 6, 52, 52, 52, ctx.alpha, 68, 68, 68, ctx.alpha, false)

    gs_gradient(pos_x + 18, bar_position, bar_width, 6, ctx.accent_color[1], ctx.accent_color[2], ctx.accent_color[3], ctx.accent_color[4] * (ctx.alpha / 255),
        ctx.accent_color[1] * 0.55, ctx.accent_color[2] * 0.55, ctx.accent_color[3] * 0.55, ctx.accent_color[4] * (ctx.alpha / 255), false)

    for i = -1, 0 do
        for j = -1, 0 do
            renderer.text(pos_x + 18 + bar_width + 1 + i, bar_position + 5 + j, 0, 0, 0, ctx.alpha, "cb", 0,
                string.format(display, ui.get(reference)))
        end
    end

    renderer.text(pos_x + 18 + bar_width + 1, bar_position + 5, 203, 203, 203, ctx.alpha, "cb", 0,
        string.format(display, ui.get(reference)))

    if not inline then
        if alt_label then
            renderer.text(pos_x + 18, pos_y - 4, 166, 166, 93, ctx.alpha, nil, 0, name:split("#")[1])
        else
            renderer.text(pos_x + 18, pos_y - 4, 203, 203, 203, ctx.alpha, nil, 0, name:split("#")[1])
        end
        
        ctx = gs_set_cursor_pos(ctx, cursor[1], cursor[2] + 29)
    else
        ctx = gs_set_cursor_pos(ctx, cursor[1], cursor[2] + 16)
    end

    if ctx.blocking == gs_generate_id(ctx, name) then
        if input.is_key_down("lmouse") then
            local offset = ctx.mouse_pos_x - (pos_x + 18)

            if offset < 0 then offset = 0 end
            if offset > bar_max_width then offset = bar_max_width end

            ui.set(reference, gs_map_number(offset, 0, bar_max_width, min, max))
        else
            ctx.blocking = nil
        end
    elseif ctx.blocking == nil then
        if input.is_key_pressed("lmouse") and hovered_min and hovered_max then
            ctx.blocking = gs_generate_id(ctx, name)
        end
    end

    return ctx
end

local function gs_button(ctx, name, width, action)
    if type(action) == "number" then
        local handle = action
        action = function () ui.set(handle, true) end
    end

    local cursor = gs_get_cursor_pos(ctx)

    local pos_x = ctx.pos_x + cursor[1]
    local pos_y = ctx.pos_y + cursor[2]

    local alt_label = name:starts_with("!")
    if alt_label then name = name:split("!", 1)[2] end

    if ctx.parent_width ~= nil then
        if width == 0 then width = ctx.parent_width - 40 - 38 end
        if width > ctx.parent_width - 40 - 38 then width = ctx.parent_width - 40 - 38 end
    end

    local hovered_min = ctx.mouse_pos_x > pos_x + 16 and ctx.mouse_pos_y > pos_y - 2
    local hovered_max = ctx.mouse_pos_x < pos_x + 17 + width and ctx.mouse_pos_y < pos_y + 26

    local name_width, name_height = renderer.measure_text("b", name:split("#")[1])
    if width < name_width + 20 then width = name_width + 20 end

    if hovered_min and hovered_max and ctx.blocking ~= gs_generate_id(ctx, name) then
        gs_gradient(pos_x + 18, pos_y, width, 24, 40, 40, 40, ctx.alpha, 30, 30, 30, ctx.alpha, false)
    elseif hovered_min and hovered_max and ctx.blocking == gs_generate_id(ctx, name) then
        gs_gradient(pos_x + 18, pos_y, width, 24, 30, 30, 30, ctx.alpha, 15, 15, 15, ctx.alpha, false)
    else
        gs_gradient(pos_x + 18, pos_y, width, 24, 35, 35, 35, ctx.alpha, 25, 25, 25, ctx.alpha, false)
    end

    gs_outline(pos_x + 17, pos_y - 1, width + 1, 26, 0, 0, 0, ctx.alpha)
    gs_outline(pos_x + 18, pos_y, width - 1, 24, 50, 50, 50, ctx.alpha)

    if alt_label then
        renderer.text(pos_x + 18 + (width / 2) - (name_width / 2), pos_y + 12 - (name_height / 2),
            166, 166, 93, ctx.alpha, "b", 0, name:split("#")[1])
    else
        renderer.text(pos_x + 18 + (width / 2) - (name_width / 2), pos_y + 12 - (name_height / 2),
            203, 203, 203, ctx.alpha, "b", 0, name:split("#")[1])
    end
    
    ctx = gs_set_cursor_pos(ctx, cursor[1], cursor[2] + 32)

    if ctx.blocking == gs_generate_id(ctx, name) then
        if not input.is_key_down("lmouse") then
            ctx.blocking = nil

            if hovered_min and hovered_max then
                action()
            end
        end
    elseif ctx.blocking == nil then
        if input.is_key_pressed("lmouse") and hovered_min and hovered_max then
            ctx.blocking = gs_generate_id(ctx, name)
        end
    end

    return ctx
end

local function gs_dropdown(ctx, name, reference, width, inline, options)
    local cursor = gs_get_cursor_pos(ctx)

    local pos_x = ctx.pos_x + cursor[1]
    local pos_y = ctx.pos_y + cursor[2]

    local bar_position = pos_y
    
    if not inline then
        bar_position = bar_position + 13
    end

    if ctx.parent_width ~= nil then
        if width == 0 then width = ctx.parent_width - 40 - 38 end
        if width > ctx.parent_width - 40 - 38 then width = ctx.parent_width - 40 - 38 end
    end

    local name_width, name_height = renderer.measure_text("b", ui.get(reference))
    local widest_item = name_width

    for i = 1, #options do
        local selected = options[i] == ui.get(reference)

        local item_min_x = pos_x + 18
        local item_max_x = item_min_x + width
        local item_min_y = bar_position + 21 + (18 * (i - 1))
        local item_max_y = item_min_y + 18

        local item_hovered_min = ctx.mouse_pos_x > item_min_x and ctx.mouse_pos_y > item_min_y
        local item_hovered_max = ctx.mouse_pos_x < item_max_x and ctx.mouse_pos_y < item_max_y
        local flags = nil

        if item_hovered_min and item_hovered_max then
            flags = "b"
        end

        local option_width, option_height = renderer.measure_text(flags, options[i])
        if option_width > widest_item then widest_item = option_width end
    end

    if width < widest_item + 20 then width = widest_item + 20 end

    local hovered_min = ctx.mouse_pos_x > pos_x + 17 and ctx.mouse_pos_y > bar_position - 1
    local hovered_max = ctx.mouse_pos_x < pos_x + 18 + width and ctx.mouse_pos_y < bar_position + 19
    local hovered_min_expanded = ctx.mouse_pos_x > pos_x + 17 and ctx.mouse_pos_y > bar_position + 20
    local hovered_max_expanded = ctx.mouse_pos_x < pos_x + 18 + width and ctx.mouse_pos_y < bar_position + 22 + (#options * 18) + 1

    local alt_label = name:starts_with("!")
    if alt_label then name = name:split("!", 1)[2] end

    gs_outline(pos_x + 17, bar_position - 1, width + 1, 19, 0, 0, 0, ctx.alpha)

    if (hovered_min and hovered_max) or ctx.blocking == gs_generate_id(ctx, name) then
        gs_fill(pos_x + 18, bar_position, width, 18, 40, 40, 40, ctx.alpha)
    else
        gs_fill(pos_x + 18, bar_position, width, 18, 35, 35, 35, ctx.alpha)
    end

    for i = 1, 3 do
        local arrow_width = { 5, 3, 1 }
        gs_fill(pos_x + 18 + width - 10 + i, bar_position + 6 + i, arrow_width[i], 1, 152, 152, 152, ctx.alpha)
    end

    renderer.text(pos_x + 27, bar_position + 9 - (name_height / 2), 203, 203, 203, ctx.alpha, nil, 0, ui.get(reference))
    
    if not inline then
        if alt_label then
            renderer.text(pos_x + 18, pos_y - 4, 166, 166, 93, ctx.alpha, nil, 0, name:split("#")[1])
        else
            renderer.text(pos_x + 18, pos_y - 4, 203, 203, 203, ctx.alpha, nil, 0, name:split("#")[1])
        end
        
        ctx = gs_set_cursor_pos(ctx, cursor[1], cursor[2] + 41)
    else
        ctx = gs_set_cursor_pos(ctx, cursor[1], cursor[2] + 25)
    end

    -- draw overlay for combobox
    local blocking_action = function ()
        gs_outline(pos_x + 17, bar_position + 20, width + 1, (18 * #options) + 1, 0, 0, 0, ctx.alpha)
        gs_fill(pos_x + 18, bar_position + 21, width, 18 * #options, 35, 35, 35, ctx.alpha)

        for i = 1, #options do
            local selected = options[i] == ui.get(reference)

            local item_min_x = pos_x + 18
            local item_max_x = item_min_x + width
            local item_min_y = bar_position + 21 + (18 * (i - 1))
            local item_max_y = item_min_y + 18

            local item_hovered_min = ctx.mouse_pos_x > item_min_x and ctx.mouse_pos_y > item_min_y
            local item_hovered_max = ctx.mouse_pos_x < item_max_x and ctx.mouse_pos_y < item_max_y

            if item_hovered_min and item_hovered_max then
                gs_fill(item_min_x, item_min_y, width, 18, 25, 25, 25, ctx.alpha)
            end

            if selected then
                renderer.text(item_min_x + 9, item_min_y + 9 - (name_height / 2),
                    ctx.accent_color[1], ctx.accent_color[2], ctx.accent_color[3], ctx.accent_color[4] * (ctx.alpha / 255),
                    "b", 0, options[i])
            elseif item_hovered_min and item_hovered_max then
                renderer.text(item_min_x + 9, item_min_y + 9 - (name_height / 2), 203, 203, 203, ctx.alpha, "b", 0, options[i])

                if input.is_key_pressed("lmouse") then
                    ui.set(reference, options[i])
                    ctx.blocking = nil
                end
            else
                renderer.text(item_min_x + 9, item_min_y + 9 - (name_height / 2), 203, 203, 203, ctx.alpha, nil, 0, options[i])
            end
        end
    end

    if ctx.blocking == gs_generate_id(ctx, name) then
        ctx.blocking_action = blocking_action

        if input.is_key_pressed("lmouse") and ((hovered_min and hovered_max) or not (hovered_min_expanded and hovered_max_expanded)) then
            ctx.blocking = nil
            ctx.blocking_action = nil
        end
    elseif ctx.blocking == nil then
        if input.is_key_pressed("lmouse") and hovered_min and hovered_max then
            ctx.blocking = gs_generate_id(ctx, name)
            ctx.blocking_action = blocking_action
        end
    end

    return ctx
end

local function gs_multi_dropdown(ctx, name, reference, width, inline, options)
    local cursor = gs_get_cursor_pos(ctx)

    local pos_x = ctx.pos_x + cursor[1]
    local pos_y = ctx.pos_y + cursor[2]

    local bar_position = pos_y
    
    if not inline then
        bar_position = bar_position + 13
    end

    if width == 0 then width = ctx.parent_width - 40 - 38 end
    if width > ctx.parent_width - 40 - 38 then width = ctx.parent_width - 40 - 38 end

    local name_width, name_height = 0, 0
    local widest_item = 0
    local label = ""

    if #ui.get(reference) == 0 then
        label = "-"
        name_width, name_height = renderer.measure_text(nil, label)
    else
        local selected = ui.get(reference)
        label = selected[1]

        for i = 2, #selected do
            label = label .. ", " .. selected[i]
        end

        name_width, name_height = renderer.measure_text(nil, label)

        if name_width > ctx.parent_width - 40 - 38 - 20 then
            while name_width > ctx.parent_width - 40 - 38 - 36 do
                label = string.sub(label, 0, -3)
                name_width, name_height = renderer.measure_text(nil, label)
            end

            label = label .. "..."
        end
    end

    for i = 1, #options do
        local selected = options[i] == ui.get(reference)

        local item_min_x = pos_x + 18
        local item_max_x = item_min_x + width
        local item_min_y = bar_position + 21 + (18 * (i - 1))
        local item_max_y = item_min_y + 18

        local item_hovered_min = ctx.mouse_pos_x > item_min_x and ctx.mouse_pos_y > item_min_y
        local item_hovered_max = ctx.mouse_pos_x < item_max_x and ctx.mouse_pos_y < item_max_y
        local flags = nil

        if item_hovered_min and item_hovered_max then
            flags = "b"
        end

        local option_width, option_height = renderer.measure_text(flags, options[i])
        if option_width > widest_item then widest_item = option_width end
    end

    if width < widest_item + 20 then width = widest_item + 20 end

    local hovered_min = ctx.mouse_pos_x > pos_x + 17 and ctx.mouse_pos_y > bar_position - 1
    local hovered_max = ctx.mouse_pos_x < pos_x + 18 + width and ctx.mouse_pos_y < bar_position + 19
    local hovered_min_expanded = ctx.mouse_pos_x > pos_x + 17 and ctx.mouse_pos_y > bar_position + 20
    local hovered_max_expanded = ctx.mouse_pos_x < pos_x + 18 + width and ctx.mouse_pos_y < bar_position + 22 + (#options * 18) + 1

    local alt_label = name:starts_with("!")
    if alt_label then name = name:split("!", 1)[2] end

    gs_outline(pos_x + 17, bar_position - 1, width + 1, 19, 0, 0, 0, ctx.alpha)

    if (hovered_min and hovered_max) or ctx.blocking == gs_generate_id(ctx, name) then
        gs_fill(pos_x + 18, bar_position, width, 18, 40, 40, 40, ctx.alpha)
    else
        gs_fill(pos_x + 18, bar_position, width, 18, 35, 35, 35, ctx.alpha)
    end

    for i = 1, 3 do
        local arrow_width = { 5, 3, 1 }
        gs_fill(pos_x + 18 + width - 10 + i, bar_position + 6 + i, arrow_width[i], 1, 152, 152, 152, ctx.alpha)
    end

    renderer.text(pos_x + 27, bar_position + 9 - (name_height / 2), 203, 203, 203, ctx.alpha, nil, 0, label)
    
    if not inline then
        if alt_label then
            renderer.text(pos_x + 18, pos_y - 4, 166, 166, 93, ctx.alpha, nil, 0, name:split("#")[1])
        else
            renderer.text(pos_x + 18, pos_y - 4, 203, 203, 203, ctx.alpha, nil, 0, name:split("#")[1])
        end
        
        ctx = gs_set_cursor_pos(ctx, cursor[1], cursor[2] + 41)
    else
        ctx = gs_set_cursor_pos(ctx, cursor[1], cursor[2] + 25)
    end

    -- draw overlay for combobox
    local blocking_action = function ()
        gs_outline(pos_x + 17, bar_position + 20, width + 1, (18 * #options) + 1, 0, 0, 0, ctx.alpha)
        gs_fill(pos_x + 18, bar_position + 21, width, 18 * #options, 35, 35, 35, ctx.alpha)

        local result = ui.get(reference)

        for i = 1, #options do
            local selected = false

            for j = 1, #result do
                if result[j] == options[i] then
                    selected = true
                end
            end

            local item_min_x = pos_x + 18
            local item_max_x = item_min_x + width
            local item_min_y = bar_position + 21 + (18 * (i - 1))
            local item_max_y = item_min_y + 18

            local item_hovered_min = ctx.mouse_pos_x > item_min_x and ctx.mouse_pos_y > item_min_y
            local item_hovered_max = ctx.mouse_pos_x < item_max_x and ctx.mouse_pos_y < item_max_y

            if item_hovered_min and item_hovered_max then
                gs_fill(item_min_x, item_min_y, width, 18, 25, 25, 25, ctx.alpha)
            end

            if selected then
                renderer.text(item_min_x + 9, item_min_y + 9 - (name_height / 2),
                    ctx.accent_color[1], ctx.accent_color[2], ctx.accent_color[3], ctx.accent_color[4] * (ctx.alpha / 255),
                    "b", 0, options[i])
            elseif item_hovered_min and item_hovered_max then
                renderer.text(item_min_x + 9, item_min_y + 9 - (name_height / 2), 203, 203, 203, ctx.alpha, "b", 0, options[i])
            else
                renderer.text(item_min_x + 9, item_min_y + 9 - (name_height / 2), 203, 203, 203, ctx.alpha, nil, 0, options[i])
            end

            if item_hovered_min and item_hovered_max and input.is_key_pressed("lmouse") then
                if selected then
                    for j = 1, #result do
                        if result[j] == options[i] then
                            table.remove(result, j)
                        end
                    end
                else
                    table.insert(result, options[i])
                end
            end
        end

        ui.set(reference, result)
    end

    if ctx.blocking == gs_generate_id(ctx, name) then
        ctx.blocking_action = blocking_action

        if input.is_key_pressed("lmouse") and ((hovered_min and hovered_max) or not (hovered_min_expanded and hovered_max_expanded)) then
            ctx.blocking = nil
            ctx.blocking_action = nil
        end
    elseif ctx.blocking == nil then
        if input.is_key_pressed("lmouse") and hovered_min and hovered_max then
            ctx.blocking = gs_generate_id(ctx, name)
            ctx.blocking_action = blocking_action
        end
    end

    return ctx
end

gui.set_cursor_pos = gs_set_cursor_pos
gui.get_cursor_pos = gs_get_cursor_pos

gui.form = gs_form
gui.tab = gs_tab
gui.group = gs_group
gui.checkbox = gs_checkbox
gui.slider = gs_slider
gui.button = gs_button
gui.dropdown = gs_dropdown
gui.multi_dropdown = gs_multi_dropdown

local ctx = nil

--[[

    ctx = gui.dropdown(ctx, "Pick a preset", ui.reference("Misc", "Other", "Presets"), ui.get(test_slider), false,
    { "Legit", "Rage", "HvH", "Secret", "Headshot", "Alpha", "Bravo" })

    ctx = gui.button(ctx, "!Now you can either save it", ui.get(test_slider), ui.reference("Misc", "Other", "Save config"))
    ctx = gui.slider(ctx, "And here you can adjust controls width", test_slider, 0, 300)

--]]

function rage_tab()
    ctx, data = gui.group(ctx, "Aimbot", 239, 437)
        ctx = gui.checkbox(ctx, "Enabled", ui.reference("Rage", "Aimbot", "Enabled"))

        ctx = gui.dropdown(ctx, "Target selection", ui.reference("Rage", "Aimbot", "Target selection"), 0, false,
            { "Cycle", "Cycle (2x)", "Near crosshair", "Highest damage", "Lowest ping", "Best K/D ratio", "Best hit chance" })
        ctx = gui.multi_dropdown(ctx, "Hitbox", ui.reference("Rage", "Aimbot", "Target hitbox"), 0, false,
            { "Head", "Chest", "Stomach", "Arms", "Legs", "Feet" })

        ctx = gui.multi_dropdown(ctx, "Multi-point", ui.reference("Rage", "Aimbot", "Multi-point"), 0, false,
            { "Head", "Chest", "Stomach", "Arms", "Legs", "Feet" })

        if #ui.get(ui.reference("Rage", "Aimbot", "Multi-point")) > 0 then
            ctx = gui.slider(ctx, "Multi-point scale", ui.reference("Rage", "Aimbot", "Multi-point scale"), 24, 100, "%.0f", false)
        end

        ctx = gui.checkbox(ctx, "Automatic penetration", ui.reference("Rage", "Aimbot", "Automatic penetration"))
        ctx = gui.checkbox(ctx, "Automatic fire", ui.reference("Rage", "Aimbot", "Automatic fire"))
        ctx = gui.checkbox(ctx, "Silent aim", ui.reference("Rage", "Aimbot", "Silent aim"))

        ctx = gui.slider(ctx, "Minimum hit chance", ui.reference("Rage", "Aimbot", "Minimum hit chance"), 0, 100, "%.0f", false)

        ctx = gui.slider(ctx, "Maximum FOV", ui.reference("Rage", "Aimbot", "Maximum FOV"), 0, 180, "%.0f", false)
        ctx = gui.slider(ctx, "Minimum damage", ui.reference("Rage", "Aimbot", "Minimum damage"), 1, 100, "%.0f", false)

        ctx = gui.checkbox(ctx, "Automatic scope", ui.reference("Rage", "Aimbot", "Automatic scope"))
        ctx = gui.checkbox(ctx, "Reduce aim step", ui.reference("Rage", "Aimbot", "Reduce aim step"))
    ctx = gui.set_cursor_pos(ctx, data.cursor_pos_x, data.cursor_pos_y)

    ctx, data = gui.group(ctx, "Other", 239, 437)
        ctx = gui.checkbox(ctx, "Remove recoil", ui.reference("Rage", "Other", "Remove recoil"))

        ctx = gui.dropdown(ctx, "Accuracy boost", ui.reference("Rage", "Other", "Accuracy boost"), 0, false,
            { "Off", "Low", "Medium", "High", "Maximum" })
        ctx = gui.checkbox(ctx, "Quick stop", ui.reference("Rage", "Other", "Quick stop"))
        ctx = gui.multi_dropdown(ctx, "Quick stop options", ui.reference("Rage", "Other", "Quick stop options"), 0, false,
            { "Early", "Slow motion", "Duck", "Fakeduck", "Move between shots", "Ignore molotov" })

        ctx = gui.checkbox(ctx, "Quick peek assist", ui.reference("Rage", "Other", "Quick peek assist"))
        ctx = gui.checkbox(ctx, "Anti-aim correction", ui.reference("Rage", "Other", "Anti-aim correction"))

        ctx = gui.checkbox(ctx, "Prefer body aim", ui.reference("Rage", "Other", "Prefer body aim"))
        ctx = gui.multi_dropdown(ctx, "Prefer body aim disablers", ui.reference("Rage", "Other", "Prefer body aim disablers"), 0, false,
            { "Low Inaccuracy", "Target shot fired", "Target resolved", "Safe point headshot", "Low damage" })

    ctx = gui.set_cursor_pos(ctx, data.cursor_pos_x, data.cursor_pos_y)
end


client.set_event_callback("paint", function (_)
    input.update()

    ctx = gui.form(ctx)
    ctx = gui.set_cursor_pos(ctx, 0, ctx.size_y - 16 - 147)

    ctx = gui.button(ctx, "Save", 112, ui.reference("CONFIG", "Presets", "Save"))
    ctx = gui.button(ctx, "Load", 112, ui.reference("CONFIG", "Presets", "Load"))
    ctx = gui.button(ctx, "Reset", 112, ui.reference("CONFIG", "Presets", "Reset"))
    ctx = gui.button(ctx, "Unload", 112, ui.reference("MISC", "Settings", "Unload"))

    _, ctx = gui.get_cursor_pos(ctx) -- pop the cursor pos

    local r, g, b, a = ui.get(ui.reference("MISC", "Settings", "Menu color"))
    ctx.accent_color = { r, g, b, a }

    if ctx.open or ctx.alpha > 0 then
        ctx = gui.tab(ctx, "RAGE", rage_tab)
        ctx = gui.tab(ctx, "VISUALS")
    end
end)