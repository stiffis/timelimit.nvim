-- timelimit.lua : barra de progreso basada en fechas para Neovim
-- Coloca este archivo en ~/.config/nvim/plugin/ y Neovim lo cargará automáticamente.

local ns = vim.api.nvim_create_namespace("timelimit")

-- Configuración visual
local INNER_LEN = 26 -- caracteres internos "━" o espacio
local FILL_CHAR = "━" -- carácter lleno
local EMPTY_CHAR = " " -- carácter vacío
local LEFT_MARK = '"' -- comilla inicial
local RIGHT_MARK = '"' -- comilla final
local UPDATE_MS = 60 * 1000 -- refresco cada 60 s (ms)
local HLGROUP = "TimelimitBar"

-- Crea el grupo de resaltado si no existe
if vim.fn.hlID(HLGROUP) == 0 then
	-- verde claro por defecto; respeta colorescheme si ya lo define
	vim.api.nvim_set_hl(0, HLGROUP, { fg = "#7CFF7C" })
end

---------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------
local function parse_date(s)
	local y, m, d = s:match("(%d+)%-(%d+)%-(%d+)")
	if not (y and m and d) then
		return nil
	end
	return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 0 })
end

local function make_inner_bar(p)
	if p < 0 then
		p = 0
	end
	if p > 1 then
		p = 1
	end
	local fill = math.floor(p * INNER_LEN + 0.5)
	return string.rep(FILL_CHAR, fill) .. string.rep(EMPTY_CHAR, INNER_LEN - fill)
end

local function make_full_bar(p)
	return LEFT_MARK .. make_inner_bar(p) .. RIGHT_MARK
end

---------------------------------------------------------------------
-- Dibujar la barra
---------------------------------------------------------------------
local function refresh(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
	local now = os.time()

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	for i, line in ipairs(lines) do
		local s_date, e_date = line:match("TIMELIMIT%s*%[(%d%d%d%d%-%d%d%-%d%d)%]%s*%[(%d%d%d%d%-%d%d%-%d%d)%]")
		if s_date and e_date then
			local ts, te = parse_date(s_date), parse_date(e_date)
			if ts and te and te > ts then
				local pct = (now - ts) / (te - ts)
				local bar = make_full_bar(pct)
				vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
					virt_text = { { bar, HLGROUP } },
					virt_text_pos = "right_align",
					hl_mode = "combine",
				})
			end
		end
	end
end

---------------------------------------------------------------------
-- Auto‑comandos y temporizador
---------------------------------------------------------------------
vim.api.nvim_create_autocmd({
	"BufReadPost",
	"BufWritePost",
	"BufEnter",
	"TextChanged",
	"TextChangedI",
}, {
	callback = function(args)
		refresh(args.buf)
	end,
})

local timer = vim.loop.new_timer()
if timer then
	timer:start(
		UPDATE_MS,
		UPDATE_MS,
		vim.schedule_wrap(function()
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_loaded(buf) then
					refresh(buf)
				end
			end
		end)
	)
end

return { refresh = refresh }
