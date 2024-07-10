--!optimize 2

-- made by: kineticwallet
-- current version: 2.0.1
-- last edited: 06/05/2024

local fs = require("@lune/fs")
local process = require("@lune/process")
local regex = require("@lune/regex")
local stdio = require("@lune/stdio")

local DEFAULT_PRINT_COLOR: stdio.Color = "blue"
local DEFAULT_DEBUG_COLOR: stdio.Color = "yellow"
local LUA_FILE_REGEX_PATTERN = regex.new(".lua$")

local function stdWriteConsole(color, ...)
	stdio.write(stdio.style("bold"))
	stdio.write(stdio.color(color))
	stdio.write(...)
	stdio.write(stdio.color("reset"))
end

local function isParameterATrueBoolean(parameter)
	return typeof(parameter) == "string" and parameter:lower():match("true") == "true"
end

stdWriteConsole(DEFAULT_PRINT_COLOR, "Welcome to the convert .lua files to .luau files process!\n")

local readPath, writePath, deleteOldFile, enableDebugPrinting = table.unpack(process.args, 1, 4)

local amountOfConvertedFiles = 0
local shouldDeleteOldFile = isParameterATrueBoolean(deleteOldFile)
local shouldDebugPrint = isParameterATrueBoolean(enableDebugPrinting)

local function createMissingPath(path)
	local pathParts = path:split("/")
	local createdPath = ""

	for _, pathPart in pathParts do
		if LUA_FILE_REGEX_PATTERN:isMatch(pathPart) then
			break
		end

		createdPath ..= `{pathPart}/`

		if not fs.isFile(createdPath) and not fs.isDir(createdPath) then
			fs.writeDir(createdPath)
		end
	end
end

local function convertFiles(convertReadPath, convertWritePath)
	if fs.isFile(convertReadPath) and LUA_FILE_REGEX_PATTERN:isMatch(convertReadPath) then
		createMissingPath(convertWritePath)
		fs.copy(convertReadPath, convertWritePath .. "u", true)
		if shouldDeleteOldFile then
			fs.removeFile(convertReadPath)
		end
		amountOfConvertedFiles += 1
	elseif fs.isDir(convertReadPath) then
		for _, path in fs.readDir(convertReadPath) do
			convertFiles(convertReadPath .. "/" .. path, convertWritePath .. "/" .. path)
		end
	elseif shouldDebugPrint then
		stdWriteConsole(
			DEFAULT_DEBUG_COLOR,
			`Invalid path or file extension received "{convertReadPath}", converted files may not be complete!\n`
		)
	end
end

local startTime = os.clock()

convertFiles(readPath, writePath)

local finishTime = os.clock() - startTime
local formattedFinishTime = string.format("%.2f", finishTime)

stdWriteConsole(
	DEFAULT_PRINT_COLOR,
	`Converted {amountOfConvertedFiles} .lua files in {formattedFinishTime}s to .luau files!`
)