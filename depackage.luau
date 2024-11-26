--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

-- This type doesn't help much :\
type node = {
    ["$className"]: string?,
    ["$path"]: string?,
    ["$paths"]: {string}?,
    ["$properties"]: { [string]: any },
    ["$ignoreUnknownInstances"]: boolean?,
}

local repo_to_proj: { [{ string }]: string } = { }
local proj_to_repo: { [string]: { string } } = { }

local instance_descriptors = {
    ["$className"] = true,
    ["$path"] = true,
    ["$properties"] = true,
    ["$ignoreUnknownInstances"] = true,
}

-- proj_path represents the path to the LM project to merge into this repo
local function build_paths(node: node, proj_path: string)
    if node["$paths"] then
        local v = node["$paths"]
        proj_to_repo[proj_path] = v
        repo_to_proj[v] = proj_path
    elseif node["$path"] then
        local v = node["$path"]
        repo_to_proj[{v}] = proj_path
        proj_to_repo[proj_path] = { v }
    end

    for field, v in node do
        if typeof(v) == "table" and not instance_descriptors[field] then
            build_paths(v, proj_path .. "/" .. field)
        end
    end
end

local function main()
    local path = process.args[1]
    if not path then
        error("Expected path to LM project")
    end

    print(path .. "/src")
    if not fs.isDir(path) then
        error(`{path} is not a folder`)
    elseif not fs.isDir(path .. "/src") then
        error(`{path} doesn't have a \`src\` folder`)
    end

    path ..= "/src"

    local project = serde.decode("json", fs.readFile("full.project.json"))
    build_paths(project.tree, path)

    for lm_folders, proj_folder in repo_to_proj do
        for _, lm_folder in lm_folders do
            if fs.isDir(lm_folder) then
                for _,v in fs.readDir(lm_folder) do
                    local proj_file = proj_folder .. "/" .. v
                    if fs.isFile(proj_file) then
                        local dest = lm_folder .. "/" .. v
                        print(proj_file, "->", dest)
                        fs.writeFile(dest, fs.readFile(proj_file))
                    end
                end
            else
                -- TODO: Add support for single files
                -- Currently only applies to Config.luau which shouldn't be synced anyway
                -- So yeah,
--[[                 local proj_file = proj_folder .. "/" .. lm_folder
                if fs.isFile(proj_file) then
                    print("***", proj_file, "->", lm_folder .. "/" .. proj_folder)
                end ]]
            end
        end
    end
end

main()