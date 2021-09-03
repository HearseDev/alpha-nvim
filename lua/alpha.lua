_G.alpha_redraw = function() end
_G.alpha_cursor_ix = 1
_G.alpha_cursor_jumps = {}
_G.alpha_cursor_jumps_press = {}
_G.alpha_keymaps = {}

local function from_nil(x, nil_case)
    if x == nil
        then return nil_case
        else return x
    end
end

function _G.alpha_press()
    _G.alpha_cursor_jumps_press[_G.alpha_cursor_ix]()
end

local function longest_line(tbl)
    local longest = 0
    for _, v in pairs(tbl) do
        if #v > longest then
            longest = #v
        end
    end
    return longest
end

local function center(tbl, state)
    -- longest line used to calculate the center.
    -- which doesn't quite give a 'justfieid' look, but w.e
    local longest = longest_line(tbl)
    local win_width = vim.api.nvim_win_get_width(state.window)
    local left = math.ceil((win_width / 2) - (longest / 2))
    local padding = string.rep(" ", left)
    local centered = {}
    for k, v in pairs(tbl) do
        centered[k] = padding .. v
    end
    return centered, left
end

local function pad_margin(tbl, state, margin, shrink)
    local longest = longest_line(tbl)
    local pot_width = margin + margin + longest
    local win_width = vim.api.nvim_win_get_width(state.window)
    local left
    if shrink and (pot_width > win_width) then
        left = (win_width - pot_width) + margin
    else
        left = margin
    end
    local padding = string.rep(" ", left)
    local padded = {}
    for k, v in pairs(tbl) do
        padded[k] = padding .. v .. padding
    end
    return padded
end

-- function trim(tbl, state)
--     local win_width = vim.api.nvim_win_get_width(state.window)
--     local trimmed = {}
--     for k,v in pairs(tbl) do
--         trimmed[k] = string.sub(v, 1, win_width)
--     end
--     return trimmed
-- end

local function layout(opts, state)
    -- this is my way of hacking pattern matching
    -- you index the table by its "type"
    local layout_element = {}

    layout_element.text = function(el)
        if type(el.val) == "table" then
            local end_ln = state.line + #el.val
            local val = el.val
            if opts.opts and opts.opts.margin and el.opts and (el.opts.position ~= "center") then
                val = pad_margin(val, state, opts.opts.margin, from_nil(el.opts.shrink_margin, true))
            end
            if el.opts then
                if el.opts.position == "center" then
                    val, _ = center(val, state)
                end
            -- if el.opts.wrap == "overflow" then
            --     val = trim(val, state)
            -- end
            end
            vim.api.nvim_buf_set_lines(state.buffer, state.line, state.line, true, val)
            if el.opts and el.opts.hl then
                for i = state.line, end_ln do
                    vim.api.nvim_buf_add_highlight(state.buffer, -1, el.opts.hl, i, 0, -1)
                end
            end
            state.line = end_ln
        end
        if type(el.val) == "string" then
            local val = {el.val}
            if opts.opts and opts.opts.margin and el.opts and (el.opts.position ~= "center") then
                val = pad_margin(val, state, opts.opts.margin, from_nil(el.opts.shrink_margin, true))
            end
            if el.opts then
                if el.opts.position == "center" then
                    val, _ = center(val, state)
                end
            end
            vim.api.nvim_buf_set_lines(state.buffer, state.line, state.line, true, val)
            if el.opts and el.opts.hl then
                vim.api.nvim_buf_add_highlight(state.buffer, -1, el.opts.hl, state.line, 0, -1)
            end
            state.line = state.line + 1
        end
    end

    layout_element.padding = function(el)
        local end_ln = state.line + el.val
        local val = {}
        for i = 1, el.val + 1 do
            val[i] = ""
        end
        vim.api.nvim_buf_set_lines(state.buffer, state.line, state.line, true, val)
        state.line = end_ln
    end

    layout_element.button = function(el)
        local val
        local padding = {
            left   = 0,
            center = 0,
            right  = 0,
        }
        if el.opts and el.opts.shortcut then
            local win_width = vim.api.nvim_win_get_width(state.window)
            -- this min lets the padding resize when the window gets smaller
            if el.opts.width then
                local max_width = math.min(el.opts.width , win_width)
                if el.opts.align_shortcut == "right"
                    then padding.center = max_width - (#el.val + #el.opts.shortcut)
                    else padding.right = max_width - (#el.val + #el.opts.shortcut)
                end
            end
            if el.opts.align_shortcut == "right"
                then val = {el.val .. string.rep(" ", padding.center) .. el.opts.shortcut}
                else val = {el.opts.shortcut .. " " .. el.val .. string.rep(" ", padding.right)}
            end
        else
            val = {el.val}
        end

        -- margin
        if opts.opts and opts.opts.margin and el.opts and (el.opts.position ~= "center") then
            val = pad_margin(val, state, opts.opts.margin, from_nil(el.opts.shrink_margin, true))
            if el.opts.align_shortcut == "right"
                then padding.center = padding.center + opts.opts.margin
                else padding.left = padding.left + opts.opts.margin
            end
        end

        -- center
        if el.opts then
            if el.opts.position == "center" then
                local left
                val, left = center(val, state)
                if el.opts.align_shortcut == "right"
                    then padding.center = padding.center + left
                    else padding.left = padding.left + left
                end
            end
        end

        local row = state.line + 1
        local _, count_spaces = string.find(val[1], "%s*")
        local col = ((el.opts and el.opts.cursor) or 0) + count_spaces
        table.insert(_G.alpha_cursor_jumps, {row, col})
        table.insert(_G.alpha_cursor_jumps_press, el.on_press)
        vim.api.nvim_buf_set_lines(state.buffer, state.line, state.line, true, val)
        if el.opts and el.opts.hl_shortcut then
            if el.opts.align_shortcut == "right"
                then vim.api.nvim_buf_add_highlight(state.buffer, -1, el.opts.hl_shortcut, state.line, #el.val + padding.center, -1)
                else vim.api.nvim_buf_add_highlight(state.buffer, -1, el.opts.hl_shortcut, state.line, padding.left, padding.left + #el.opts.shortcut)
            end
        end

        if el.opts and el.opts.hl then
            local left = padding.left
            if el.opts.align_shortcut == "left" then left = left + #el.opts.shortcut + 3 end
            for _, hl in pairs(el.opts.hl) do
                vim.api.nvim_buf_add_highlight(
                    state.buffer,
                    -1,
                    hl[1],
                    state.line,
                    left + hl[2],
                    left + hl[3]
                )
            end
        end
        state.line = state.line + 1
    end

    layout_element.button_group = function(el)
        for _, v in pairs(el.val) do
            layout_element[v.type](v)
            if el.opts and el.opts.spacing then
                local padding_el = {type = "padding", val = el.opts.spacing}
                layout_element[padding_el.type](padding_el)
            end
        end
    end

    for _, el in pairs(opts.layout) do
        layout_element[el.type](el, state)
    end
end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

-- dragons
local function closest_cursor_jump(cursor, cursors, prev_cursor)
    local direction = prev_cursor[1] > cursor[1] -- true = UP, false = DOWN
    -- minimum distance key from jump point
    -- excluding jumps in opposite direction
    local min
    for k, v in pairs(cursors) do
        local distance = v[1] - cursor[1] -- new cursor distance from old cursor
        if direction and (distance <= 0) then
            distance = math.abs(distance)
            local res = {distance, k}
            if not min then min = res end
            if min[1] > res[1] then min = res end
        end
        if (not direction) and (distance >= 0) then
            local res = {distance, k}
            if not min then min = res end
            if min[1] > res[1] then min = res end
        end
    end
    if not min -- top or bottom
        then
            if direction
                then return 1, cursors[1]
                else return #cursors, cursors[#cursors]
            end
        else
            -- returns the key (stored in a jank way so we can sort the table)
            -- and the {row, col} tuple
            return min[2], cursors[min[2]]
    end
end

_G.alpha_set_cursor = function ()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local closest_ix, closest_pt = closest_cursor_jump(cursor, _G.alpha_cursor_jumps, _G.alpha_cursor_jumps[_G.alpha_cursor_ix])
    _G.alpha_cursor_ix = closest_ix
    vim.api.nvim_win_set_cursor(0, closest_pt)
end

local function enable_alpha()
    -- vim.opt_local behaves inconsistently for window options, it seems.
    -- I don't have the patience to sort out a better way to do this
    -- or seperate out the buffer local options.
    vim.cmd(
        [[silent! setlocal bufhidden=wipe colorcolumn= foldcolumn=0 matchpairs= nocursorcolumn nocursorline nolist nonumber norelativenumber nospell noswapfile signcolumn=no synmaxcol& buftype=nofile filetype=alpha nowrap]]
    )

    vim.cmd("autocmd alpha CursorMoved <buffer> call v:lua.alpha_set_cursor()")
end

local options = {}

local function start(on_vimenter, opts)
    if on_vimenter then
        if     vim.opt.insertmode:get()       -- Handle vim -y
            or (not vim.opt.modifiable:get()) -- Handle vim -M
            or vim.fn.argc() ~= 0 -- should probably figure out
                                  -- how to be smarter than this
        then return end
     end

    if not vim.opt.hidden:get() and vim.opt_local.modified:get() then
        vim.api.nvim_err_writeln("Save your changes first.")
        return
    end

    opts = opts or options

    local buffer = vim.api.nvim_create_buf(false, true)
    local window = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(window, buffer)
    enable_alpha()

    local state = {
        line = 0,
        buffer = buffer,
        window = window
    }
    local draw = function()
        _G.alpha_cursor_jumps = {}
        _G.alpha_cursor_jumps_press = {}
        _G.alpha_keymaps = {}
        -- this is for redraws. i guess the cursor 'moves'
        -- when the screen is cleared and then redrawn
        -- so we save the index before that happens
        local ix = _G.alpha_cursor_ix
        vim.api.nvim_buf_set_option(state.buffer, "modifiable", true)
        vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, {})
        state.line = 0
        layout(opts, state)
        vim.api.nvim_buf_set_option(state.buffer, "modifiable", false)
        vim.api.nvim_buf_set_keymap(
            state.buffer,
            "n",
            "<CR>",
            ":call v:lua.alpha_press()<CR>",
            {noremap = false, silent = true}
        )
        vim.api.nvim_win_set_cursor(0, _G.alpha_cursor_jumps[ix])
    end
    _G.alpha_redraw = draw
    for _, map in pairs(_G.alpha_keymaps) do
        vim.api.nvim_buf_set_keymap(state.buffer, map[1], map[2], map[3], map[4])
    end
    draw()
end

local function setup(opts)
    vim.cmd("command! Alpha lua require'alpha'.start(false)")
    vim.cmd([[augroup alpha]])
    vim.cmd([[au!]])
    vim.cmd([[autocmd VimResized * if &filetype ==# 'alpha' | call v:lua.alpha_redraw() | endif]])
    vim.cmd([[autocmd VimEnter * nested lua require'alpha'.start(true) ]])
    vim.cmd([[augroup END]])
    if type(opts) == "table" then
        options = opts
    end
end

return {
    setup = setup,
    start = start,
}
