--!strict

local mod = { }

function mod.require(_s: Script)
	assert(_s, "No script passed to require")

	local co = coroutine.create(require)

	if _s.Name == "Effects" then
		print()
	end
	local succ, ret = coroutine.resume(co, _s)

	if not succ then
		local trace = ret .. ":\n" .. debug.info(co, 0, "sln") .. "\n" .. debug.traceback()
		warn("\n\nSafeRequire: Module `" .. _s.Name .. "` could not compile:\n" .. trace)
		return ret, true, trace
	end

	return ret, false, nil
end

return mod