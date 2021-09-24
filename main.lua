local _dirname_ = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])")
package.path = _dirname_ .. "?.lua;" .. package.path
utils = require "utils"

-- load conky config tables including font definitions
if conky == nil then
	conky = {}
end
dofile(conky_config)

-- remove unavailable fonts
local function _check_fonts()
	for k, v in pairs(conky.fonts) do
		local font = conky.fonts[k]
		local p = font:find(":")
		if p then
			font = font:sub(1, p - 1)
		end
		font = utils.trim(font)
		if #font > 0 and font ~= "sans-serif" and font ~= "serif" and font ~= "courier" and font ~= "monospace" then
			local s = utils.sys_call('fc-list -f "%{family[0]}" "' .. font .. '"', true)
			if #s < 1 then
				conky.fonts[k] = nil
			end
		elseif not p then
			conky.fonts[k] = nil
		end
	end
end
_check_fonts()

-- render `text` with the specified `font` if it is available on the system.
-- if `font ` unavailable, render `alt_text` instead with `alt_font`.
-- if `alt_font` is unavailable or not specified, render `alt_text` with the
-- current font.
-- if no `alt_text` is provided, it is assumed to be the same as `text`.
function conky_font(font, text, alt_text, alt_font)
	text = utils.unbrace(text)
	if alt_text == nil then
		alt_text = text
	else
		alt_text = utils.unbrace(alt_text)
	end
	if font then
		font = conky.fonts[font]
	end
	if alt_font then
		alt_font = conky.fonts[alt_font]
	end
	if font then
		return conky_parse(string.format("${font %s}%s", font, text))
	elseif alt_font then
		return conky_parse(string.format("${font %s}%s", alt_font, alt_text))
	else
		return conky_parse(alt_text)
	end
end

conky_percent_ratio = utils.percent_ratio

-- unified shortcut to all top_x variables, with optional padding
function _top_val(ord, dev, type, max_len, align)
	if dev == "io" or dev == "mem" or dev == "time" then
		dev = "_" .. dev
	else
		dev = ""
	end
	local rendered = conky_parse(string.format("${top%s %s %d}", dev, type, ord))
	return utils.padding(utils.trim(rendered), max_len, align, " ")
	-- NOTE: the padding character here is FIGURE SPACE (U+2007)
	-- see https://en.wikipedia.org/wiki/Whitespace_character
end

-- render top (cpu) line
function conky_top_cpu_line(ord)
	local _H = "${color2}${lua font h3 {PID ${goto 48}PROCESS ${goto 220}MEM% ${alignr}CPU%}}${font}${color}"
	if ord == "header" then
		return conky_parse(_H)
	end

	local function _t(type, padding_len)
		return _top_val(ord, "cpu", type, padding_len, "right")
	end
	return conky_parse(
		string.format(
			"%s ${goto 48}%s${goto 220}%s${alignr}%s",
			_t("pid"),
			_t("name"),
			_t("mem"),
			_t("cpu")
		)
	)
end

-- render top_mem line
function conky_top_mem_line(ord)
	local _H = "${color2}${lua font h3 {PID ${goto 48}PROCESS ${goto 220}CPU%${alignr}MEM%}}${font}${color}"
	if ord == "header" then
		return conky_parse(_H)
	end

	local function _t(type, padding_len)
		return _top_val(ord, "mem", type, padding_len, "right")
	end
	return conky_parse(
		string.format(
			"%s ${goto 48}%s${goto 220}%s${alignr}%s",
			_t("pid"),
			_t("name"),
			_t("cpu"),
			_t("mem")
		)
	)
end

-- render top_io line
function conky_top_io_line(ord)
	local _H = "${color2}${lua font h3 {PID ${goto 48}PROCESS ${alignr}READ/WRITE}}${font}${color}"
	if ord == "header" then
		return conky_parse(_H)
	end

	local function _t(type)
		return _top_val(ord, "io", type)
	end
	return conky_parse(
		string.format("%s ${goto 48}%s ${alignr}%s / %s", _t("name"), _t("pid"), _t("io_read"), _t("io_write"))
	)
end

function conky_top_table(section, counts)
	local set_tables = {
		cpu = { 
			c0='mem',
			c1='cpu',
			tpl = "%s ${goto 48}%s${goto 220}%s${alignr}%s",
			header = "${color2}${lua font h3 {PID ${goto 48}PROCESS ${goto 220}MEM% ${alignr}CPU%}}${font}${color}"
		},
		mem = {
			c0 = 'cpu',
			c1 = 'mem',
			tpl = "%s ${goto 48}%s${goto 220}%s${alignr}%s",
			header = "${color2}${lua font h3 {PID ${goto 48}PROCESS ${goto 220}CPU%${alignr}MEM%}}${font}${color}"
		},
		io = {
			c0='io_read',
			c1='io_write',
			tpl = "%s ${goto 48}%s${alignr}%s / %s",
			header = "${color2}${lua font h3 {PID ${goto 48}PROCESS ${alignr}READ / WRITE}}${font}${color}"
		},
	}
	local function _t(ord, type, padding_len)
		return _top_val(ord, "mem", type, padding_len, "right")
	end
	local rendered = {}
	rendered[1] = conky_parse(set_tables[section].header)
	--print(section, set_tables[section].c0, set_tables[section].c1, counts)

	for i = 1,tonumber(counts) do 
		rendered[i+1] = conky_parse(
			string.format(
				set_tables[section].tpl,
				_t(i,"pid"),
				_t(i,"name"),
				_t(i,set_tables[section].c0),
				_t(i,set_tables[section].c1)
			)
		)
	end
	if tonumber(counts) > 0 then
		return table.concat(rendered, "\n")
	else
		rendered[1] = conky_parse("${color} .")
		return table.concat(rendered, "\n")
	end

end

local function _interval_call(interv, ...)
	return conky_parse(utils.interval_call(tonumber(interv or 0), ...))
end

-- dynamically show active ifaces
-- see https://matthiaslee.com/dynamically-changing-conky-network-interface/
local TPL_IFACE =
	[[${if_existing /sys/class/net/<IFACE>/operstate up}#
${voffset 5}${color6}${lua font icon_l {}}${color} ${voffset -3} ${lua font h3 {<IFACE>:}}${font}#
${alignr}${voffset -5}${color4} ${upspeed <IFACE>}  ${lua font icon_x }${font}${color}
${alignr}${color5}${downspeed <IFACE>}  ${lua font icon_x }${font}
${voffset -3}${color9}${hr 1}${color}${voffset -4}${endif}]]

local TPL_IFACEWIFI =
	[[${if_existing /sys/class/net/<IFACE>/operstate up}#
${voffset 5}${color6}${lua font icon_l {}}${color} ${voffset -3} ${lua font h3 {<IFACE>:}}${font}${voffset -5}#
${alignc -46}${color1}${wireless_essid <IFACE>}${font}#
${alignr}${color4} ${upspeed <IFACE>}  ${lua font icon_x }${font}${color}
${alignc -46} ${wireless_link_qual_perc <IFACE>} % / ${wireless_bitrate <IFACE>}#
${alignr}${color5}${downspeed <IFACE>}  ${lua font icon_x }${font}
${voffset -3}${color9}${hr 1}${color}${voffset -4}${endif}]]

local function _conky_ifaces()
	local rendered = {}
	for i, iface in ipairs(utils.enum_ifaces_full()) do
		if iface[2] ~= "wifi" then
			rendered[i] = TPL_IFACE:gsub("<IFACE>", iface[1])
		else
			rendered[i] = TPL_IFACEWIFI:gsub("<IFACE>", iface[1])
		end
	end
	if #rendered > 0 then
		return table.concat(rendered, "\n")
	else
		return "${font}(no active network interface found)"
	end
end

function conky_ifaces(interv)
	return _interval_call(interv, _conky_ifaces)
end

-- dynamically show mounted disks
local TPL_DISK =
	[[${lua font icon_l { ${voffset -3}} {}} ${lua font h2 {%s}}${font} ${alignc -80}%s / %s [ ${lua font h5bold {%s}}${font} ] ${alignr}${color0}%s%%${color}
	${lua font h6 {${voffset 3} %s}}${font}
${color3}${lua_bar 4 percent_ratio %s %s}${color}]]
local TPL_DISKmini =
	[[${lua font icon_x {} {}} ${lua font h4 {%s}}${font} ( ${lua font h6 {%s}}${font}${voffset -1} ) ${alignc -80}%s / %s [ ${lua font h5bold {%s}}${font} ] ${alignr}${color0}%s%%${color}]]
local type_disk = "full"

local function _conky_disks()
	local rendered = {}
	for i, disk in ipairs(utils.enum_disks()) do
		-- human friendly size strings
		local size_h = utils.filesize(disk.size)
		local used_h = utils.filesize(disk.used)

		-- get succinct name for the mount
		local name = disk.mnt
		local media = name:match("^/media/" .. utils.env.USER .. "/(.+)$")
		local label = disk.label
		if media then
			name = media
		elseif name == utils.env.HOME then
			name = "${lua font icon_s ⌂}"
		end
		if type_disk == "full" then
			rendered[i] =
				string.format(
				TPL_DISK,
				label,
				used_h,
				size_h,
				disk.type,
				utils.percent_ratio(disk.used, disk.size),
				name,
				disk.used,
				disk.size
			)
		else
			rendered[i] =
				string.format(
				TPL_DISKmini,
				label,
				name,
				used_h,
				size_h,
				disk.type,
				utils.percent_ratio(disk.used, disk.size),
				disk.used,
				disk.size
			)
		end
	end
	if #rendered > 0 then
		return table.concat(rendered, "\n")
	else
		return "${font}(no mounted disk found)"
	end
end

function conky_disks(interv, parms)
	type_disk = parms
	return _interval_call(interv, _conky_disks)
end

local TPL_core =
[[${lua font h3 {${color}CPU<cores>:${alignc} ${color2}${freq_g <cores>} Ghz ${alignr}${color0}${cpu cpu<cores>}% ${color}${cpubar cpu<cores> 5,100}}}${color}]]
local function _conky_cpus_cores(x)
	local rendered = {}
	local cores = 1
	cores = tonumber(sys_call("lscpu | grep 'CPU(s):' | awk  '{print $2}'", true))
	for i = 1,cores do 
		rendered[i] = TPL_core:gsub("<cores>", i-1)
	end
	return table.concat(rendered, "\n")
end

function conky_cpus_cores(interv)
	return _interval_call(interv, _conky_cpus_cores)
end
