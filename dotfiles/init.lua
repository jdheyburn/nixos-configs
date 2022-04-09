-- Inspiration from https://framagit.org/vegaelle/nix-nvim/-/blob/main/init.lua

local cmd = vim.cmd
local g = vim.g

g.mapleader = " "


-- misc utils
local scopes = {o = vim.o, b = vim.bo, w = vim.wo, g = vim.g}

local function opt(scope, key, value)
    scopes[scope][key] = value
    if scope ~= "o" then
        scopes["o"][key] = value
    end
end

local function map(mode, lhs, rhs, opts)
    local options = {noremap = true}
    if opts then
        options = vim.tbl_extend("force", options, opts)
    end
    vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

-- allow undos to persist sessions
opt("b", "undofile", true)
-- highlight the line with the cursor
opt("w", "cursorline", false)
-- show line numbers
opt("w", "number", true)
-- keep cursor from top/bottom
opt("w", "scrolloff", 10)
-- fix tabs on paste
opt("g", "paste", true)
-- tabs
opt("b", "expandtab", true)
opt("b", "tabstop", 4)

