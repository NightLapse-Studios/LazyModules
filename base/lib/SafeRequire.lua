--!strict

local mod = { }



function mod.require<M>(_s: M)
	if not _s then
		error("No script passed to require")
	end

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

	return ret :: typeof(require(_s)), false, nil
end

return mod