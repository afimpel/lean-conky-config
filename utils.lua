-- utility functions and variables

-- dump object, see https://stackoverflow.com/a/27028488/707516
function dump_object(o)
	if type(o) == "table" then
		local s = "{ "
		for k, v in pairs(o) do
			if type(k) ~= "number" then
				k = '"' .. k .. '"'
			end
			s = s .. "[" .. k .. "] = " .. dump_object(v) .. ","
		end
		return s .. "} "
	else
		return tostring(o)
	end
end
local function split(str, sep)
	local result = {}
	local regex = ("([^%s]+)"):format(sep)
	for each in str:gmatch(regex) do
	   table.insert(result, each)
	end
	return result
 end
 
-- enumerate network interfaces, see https://superuser.com/a/1173532/95569
function enum_ifaces_full()
	local _in_docker = in_docker()
	local ifaces = {}
	for i, device in ipairs(sys_call("bash ./script/netlist.sh")) do
		local lines = split(device, ":")
		table.insert(ifaces, lines)
	end
	return ifaces
end

function enum_ifaces()
	local _in_docker = in_docker()
	local ifaces = {}
	for i, l in ipairs(sys_call("basename -a /sys/class/net/*")) do
		local p = sys_call("realpath /sys/class/net/" .. l, true)
		-- for regular host, skip virtual interfaces (including lo)
		-- in container, return all interfaces except lo
		if not p:match("^/sys/devices/virtual/") or (_in_docker and l ~= "lo") then
			table.insert(ifaces, l)
		end
	end
	return ifaces
end

-- enumerate mounted disks
-- NOTE: only list most relevant mounts, e.g. boot partitions are ignored
function enum_disks()
	local fs_types = "fuseblk,ext2,ext3,ext4,ecryptfs,vfat"
	if in_docker() then
		fs_types = fs_types .. ",overlay"
	end
	local cmd = "findmnt -bPUno TARGET,FSTYPE,SIZE,USED,LABEL,SOURCE,AVAIL -t " .. fs_types
	local entry_pattern = '^TARGET="(.+)"%s+FSTYPE="(.+)"%s+SIZE="(.+)"%s+USED="(.+)"%s+LABEL="(.+)"%s+SOURCE="(.+)"%s+AVAIL="(.+)"$'
	local mnt_fs = sys_call(cmd)
	local mnts = {}

	for i, l in ipairs(mnt_fs) do
		local mnt, fstype, size, used, label, source, avail = l:match(entry_pattern)
		if mnt and is_dir(mnt) and is_readable(mnt) and not mnt:match("^/boot/") and not mnt:match("^/run/live/") then
			table.insert(
				mnts,
				{
					mnt = mnt,
					type = fstype,
					size = tonumber(size),
					used = tonumber(used),
					avail = tonumber(avail),
					label = label,
					source = source
				}
			)
		end
	end
	return mnts
end

-- some environment variables
local env = {}
for i, k in ipairs({"HOME", "USER"}) do
	env[k] = os.getenv(k)
end

-- human friendly file size
local _filesize = require "filesize"
function filesize(size)
	return _filesize(size, {round = 0, spacer = "", base = 2})
end

-- call at interval, similar to Conky's `execi` but for functions
local _interval_call_cache = {}
function interval_call(interv, func, ...)
	if _interval_call_cache[func] == nil then
		_interval_call_cache[func] = {}
	end
	local cache = _interval_call_cache[func]
	local now = os.time()
	if cache.last == nil or (now - cache.last) >= interv then
		cache.result = func(...)
		cache.last = now
	end
	return cache.result
end

-- pad string to `max_len`, `align` mode can be 'left', 'right' or 'center'
function padding(str, max_len, align, char)
	if not max_len then
		return str
	end
	local n = max_len - utf8_len(str)
	if n <= 0 then
		return str
	end

	if not align then
		align = "left"
	end
	if not char then
		char = " "
	end
	assert(utf8_len(char) == 1, "padding `char` must be a single character.")

	local srep = string.rep
	if align == "center" then
		local m = math.floor(n / 2)
		return srep(char, m) .. str .. srep(char, n - m)
	elseif align == "left" then
		return str .. srep(char, n)
	elseif align == "right" then
		return srep(char, n) .. str
	end
end

-- strip surrounding whitespaces
function trim(str)
	return str:match("^%s*(.-)%s*$")
end

-- strip surrounding braces
function unbrace(str)
	if not str then
		return str
	end
	while true do
		local u = str:match("^{(.-)}$")
		if u then
			str = u
		else
			return str
		end
	end
end

-- count characters in a utf-8 encoded string
function utf8_len(str)
	local _, count = string.gsub(str, "[^\128-\193]", "")
	return count
end

-- calculate ratio as percentage
function percent_ratio(x, y)
	return math.floor(100.0 * tonumber(x) / tonumber(y))
end

-- run system command and return stdout as lines or a string
function sys_call(cmd, as_string)
	local pipe = io.popen(cmd)
	local lines = {}
	for l in pipe:lines() do
		table.insert(lines, l)
	end
	pipe:close()
	if as_string then
		return table.concat(lines, "\n")
	else
		return lines
	end
end

-- eval string as system call and check if result is true
function is_true(expr)
	local s = sys_call(expr .. ' && echo "true"', true)
	return (#s > 3)
end

-- is dir or file
function is_dir(p)
	return is_true('[ -d "' .. p .. '" ]')
end

-- is path readable
function is_readable(p)
	return is_true('[ -r "' .. p .. '" ]')
end

-- is running in a docker container
function in_docker()
	return is_true('[ -f /.dockerenv ] || grep -Eq "(lxc|docker)" /proc/1/cgroup')
end


return {
	dump_object = dump_object,
	enum_ifaces_full = enum_ifaces_full,
	enum_ifaces = enum_ifaces,
	enum_disks = enum_disks,
	env = env,
	filesize = filesize,
	interval_call = interval_call,
	padding = padding,
	percent_ratio = percent_ratio,
	sys_call = sys_call,
	trim = trim,
	unbrace = unbrace
}
