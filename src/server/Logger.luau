--!strict
--[=[
	Logger.luau
	Log terstruktur untuk server (TECH_SPEC.md §10).
	Level: INFO, WARN, ERROR. Dapat dinyalakan/dimatikan melalui ENABLED.
]=]

local Logger = {
	ENABLED = true,
}

export type LogLevel = "INFO" | "WARN" | "ERROR"

function Logger.log(level: LogLevel, tag: string, message: string, data: any?): ()
	if not Logger.ENABLED then
		return
	end

	local formatted = string.format("[%s] [%s] %s", level, tag, message)
	if data ~= nil then
		formatted = formatted .. " | Data: " .. tostring(data)
	end

	if level == "WARN" then
		warn(formatted)
	elseif level == "ERROR" then
		warn("[ERROR] " .. formatted)
	else
		print(formatted)
	end
end

function Logger.info(tag: string, message: string, data: any?): ()
	Logger.log("INFO", tag, message, data)
end

function Logger.warn(tag: string, message: string, data: any?): ()
	Logger.log("WARN", tag, message, data)
end

function Logger.error(tag: string, message: string, data: any?): ()
	Logger.log("ERROR", tag, message, data)
end

return Logger
