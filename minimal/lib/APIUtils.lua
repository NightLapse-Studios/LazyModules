local mod = { }

local API_EXPORTER = { }
local mt_API_EXPORTER = { __index = API_EXPORTER }

function mod.EXPORT_LIST(module)
	local t = {
		module = module
	}

	module.API_EXPORTS = { }

	setmetatable(t, mt_API_EXPORTER)
	return t
end

function API_EXPORTER:ADD(name, opt_value: any?)
	local thing = if opt_value ~= nil then opt_value else self.module[name]
	assert(thing ~= nil, "API_EXPORTER:ADD: `" .. name .. "` not found in `" .. debug.info(2, "s"))

	self.module.API_EXPORTS[name] = thing

	return self
end

function API_EXPORTER:Unpack()
	return table.unpack(self.module.API_EXPORTS)
end

function mod.LOAD_EXPORTS(source_mod, target_mod)
	local exports = source_mod.API_EXPORTS
	assert(exports, "API_EXPORTER:LOAD: " .. tostring(source_mod) .. " has no API exports")

	for i,v in exports do
		target_mod[i] = v
	end
end

function mod.HAS_API_EXPORTS(module: table)
	return module.API_EXPORTS ~= nil
end

return mod