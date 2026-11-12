local M = {}

-- A new key distinguishes an explicit choice from old boolean defaults.
-- Legacy retains both old switches and their original global gates.
function M.Resolve(get, tuning)
    local mode = get("WX-78 Mode") or "legacy"
    local legacy = mode ~= "easy" and mode ~= "hard" and mode ~= "draft" and mode ~= "off"
    return {
        mode = legacy and "legacy" or mode,
        easy = mode == "easy" or mode == "hard" or
            (legacy and tuning.easymode2hm and get("role_easy") and get("wx78_easy")) or false,
        hard = mode == "hard" or
            (legacy and tuning.hardmode2hm and get("role_nerf") and get("wx-78")) or false,
        -- The old easy implementation used role_nerf even when wx-78 was off.
        easyhard = mode == "hard" or (legacy and tuning.hardmode2hm and get("role_nerf")) or false,
        draft = mode == "draft",
    }
end

return M
