--!strict
local mod = { }

local ApiExporter = { }
ApiExporter.__index = ApiExporter

type ApiExporter<T> = T & {
	LoadExports: <M, R>(M, R) -> R & T,
	ExposeTo: <M, H>(M, H) -> H & { ApiExporter: M }
}

function mod.ExportList<T>(list: T)
	setmetatable(list, ApiExporter)

	return (list :: any) :: ApiExporter<T>
end

function ApiExporter.ExposeTo<M, H>(self: M, host: H)
	host.ApiExporter = self

	return host
end

function ApiExporter.LoadExports<M, R>(self: M, target_mod: R)
	for i,v in self do
		if i == "ApiExporter" then
			continue
		end

		target_mod[i] = v
	end

	return target_mod
end

function mod.HasApiExports(module: { [any]: any })
	return module.ApiExporter ~= nil
end

return mod