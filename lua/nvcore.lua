--- A placeholder variable used to queue section names to be registered by which-key
---@type table?
local wk_queue = {}

local M = {
  config = {
    --- Whether to add <localleader> keymaps for all <leader> keymaps.
    --- @type boolean
    map_localleader = true,

    --- Default options for keymaps, autocmds and user commands.
    default_opts = {
      keymaps = {},
      commands = {},
      autocmds = {},
    },
  },
}

function M.get_config()
	return M.config
end

local function omit(tbl, keys_to_omit)
  local new_tbl = {}
  local keys_to_omit_set = {}

  for _, key in ipairs(keys_to_omit) do
    keys_to_omit_set[key] = true
  end

  for k, v in pairs(tbl) do
    if not keys_to_omit_set[k] then new_tbl[k] = v end
  end

  return new_tbl
end

local function deep_merge(t1, t2)
  for key, value in pairs(t2) do
    if type(value) == "table" and type(t1[key]) == "table" then
      deep_merge(t1[key], value)
    else
      t1[key] = value
    end
  end
end

function M.setup(opts)
  M.map_localleader = opts.map_localleader or M.map_localleader
  deep_merge(M.default_opts, opts.default_opts or {})

  -- set opts
  if opts.options then
    for scope, settings in pairs(opts.options) do
      for setting, value in pairs(settings) do
        vim[scope][setting] = value
      end
    end
  end

  -- autocmds
  if opts.autocmds then
    for augroup, autocmds in pairs(opts.autocmds) do
      if not autocmds then return end

      local augroup_id = vim.api.nvim_create_augroup(augroup, { clear = true })
      for _, autocmd in ipairs(autocmds) do
        local event = autocmd.event
        autocmd.event = nil
        autocmd.group = augroup_id
        vim.api.nvim_create_autocmd(event, autocmd)
        autocmd.event = event
      end
    end
  end

  -- user commands
  if opts.commands then
    for cmd, spec in pairs(opts.commands) do
      if not spec then return end

      local action = spec[1]
      spec[1] = nil
      vim.api.nvim_create_user_command(cmd, action, spec)
      spec[1] = action
    end
  end

  -- keymaps
  for _, keymap in ipairs(opts.keymaps or {}) do
    local keymap_table = keymap.keymaps or { keymap }

    if keymap.group and keymap.keymaps then table.insert(wk_queue, omit(keymap, { "keymaps" })) end
    table.insert(wk_queue, keymap_table)

    for _, keymap in ipairs(keymap_table) do
      local key, action = keymap[1], keymap[2]
      local mode = keymap.mode or "n"

      keymap[1] = nil
      keymap[2] = nil
      keymap.icon = nil
      keymap.group = nil

      vim.keymap.set(mode, key, action, vim.tbl_extend("force", M.default_opts.keymaps, keymap))
    end
  end

  vim.api.nvim_create_autocmd("User", {
    pattern = "LazyLoad",
    callback = function(args)
      if args.data ~= "which-key.nvim" or #wk_queue == 0 then return end

      local wk_avail, wk = pcall(require, "which-key")
      if wk_avail then
        wk.add(wk_queue)
        wk_queue = {}
      end
    end,
  })
end

return M
