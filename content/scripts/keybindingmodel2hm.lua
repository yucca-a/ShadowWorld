-- Local preferences and keyboard recording; no world save or server settings.
local M = {}
local aliases = {[KEY_LCTRL]=KEY_CTRL, [KEY_RCTRL]=KEY_CTRL,
    [KEY_LALT]=KEY_ALT, [KEY_RALT]=KEY_ALT, [KEY_LSHIFT]=KEY_SHIFT, [KEY_RSHIFT]=KEY_SHIFT}
local modifiers = {[KEY_CTRL]=1, [KEY_ALT]=2, [KEY_SHIFT]=3}
local names = {[KEY_CTRL]="Ctrl", [KEY_ALT]="Alt", [KEY_SHIFT]="Shift", [KEY_SPACE]="Space",
    [KEY_BACKSPACE]="Backspace", [KEY_DELETE]="Delete", [KEY_TAB]="Tab", [KEY_UP]="Up",
    [KEY_DOWN]="Down", [KEY_LEFT]="Left", [KEY_RIGHT]="Right", [KEY_HOME]="Home", [KEY_END]="End",
    [KEY_PAGEUP]="Page Up", [KEY_PAGEDOWN]="Page Down", [KEY_INSERT]="Insert"}
for key = KEY_F1, KEY_F12 do names[key] = "F" .. tostring(key - KEY_F1 + 1) end
for key = KEY_KP_0, KEY_KP_9 do names[key] = "Numpad " .. tostring(key - KEY_KP_0) end
for key,label in pairs({[KEY_KP_PERIOD]=".",[KEY_KP_DIVIDE]="/",[KEY_KP_MULTIPLY]="*",
    [KEY_KP_MINUS]="-",[KEY_KP_PLUS]="+",[KEY_KP_EQUALS]="="}) do names[key]="Numpad "..label end
for key = 32, 126 do names[key] = names[key] or string.upper(string.char(key)) end
function M.Key(key) return aliases[key] or key end
function M.IsModifier(key) return modifiers[M.Key(key)] ~= nil end
function M.Normalize(keys)
    if type(keys) ~= "table" then return nil, "invalid" end
    local result, seen, main = {}, {}, false
    for i, value in ipairs(keys) do
        if i > 4 or type(value) ~= "number" or value ~= math.floor(value) then return nil, "invalid" end
        local key = M.Key(value)
        if not names[key] or key == KEY_ESCAPE or key == KEY_ENTER or key == KEY_TILDE then return nil, "reserved" end
        if not seen[key] then result[#result+1] = key; seen[key] = true end
        if not modifiers[key] then main = true end
    end
    if not main then return nil, "modifier" end
    table.sort(result, function(a,b)
        local ma, mb = modifiers[a] or 10, modifiers[b] or 10
        return ma ~= mb and ma < mb or ma == mb and a < b
    end)
    return result
end
function M.Label(keys)
    local text = {}
    for _, key in ipairs(keys or {}) do text[#text+1] = names[M.Key(key)] or tostring(key) end
    return table.concat(text, " + ")
end
function M.Overlap(a,b)
    local function subset(x,y)
        local set = {}; for _,key in ipairs(y) do set[key] = true end
        for _,key in ipairs(x) do if not set[key] then return false end end
        return true
    end
    return subset(a,b) or subset(b,a)
end
function M.ModifiersMatch(keys,isdown)
    for key in pairs(modifiers) do
        local expected = false; for _,bound in ipairs(keys) do if bound==key then expected=true end end
        if not not isdown(key) ~= expected then return false end
    end
    return true
end
function M.Matches(keys, isdown)
    for _,key in ipairs(keys) do if not isdown(key) then return false end end
    return M.ModifiersMatch(keys,isdown)
end
function M.Recorder(isdown)
    local r = {pressed={}, keys={}, seen={}, done=false}
    function r:Feed(raw, down)
        local key = M.Key(raw)
        if key == KEY_ESCAPE and down then self.cancelled=true; return end
        if self.done or self.cancelled then return end
        local addedmodifier=false
        if isdown then
            for modifier in pairs(modifiers) do
                if isdown(modifier) then
                    self.pressed[modifier]=true
                    if not self.seen[modifier] then self.keys[#self.keys+1]=modifier;self.seen[modifier]=true;addedmodifier=true end
                else self.pressed[modifier]=nil end
            end
        end
        -- Some platforms emit KEY_UNKNOWN (0) alongside modifier events.
        -- Read the canonical modifier state instead of recording that noise.
        if key==0 and down and not addedmodifier then self.unknown=true end
        if key~=0 and down then
            self.pressed[key] = true
            if not self.seen[key] then self.keys[#self.keys+1]=key; self.seen[key]=true end
        elseif key~=0 then
            self.pressed[key] = nil
        end
        if not down then
            if #self.keys > 0 and next(self.pressed) == nil then
                if self.unknown then self.error="unknown" else self.result,self.error = M.Normalize(self.keys) end
                self.done = true
            end
        end
    end
    return r
end
local function empty() return {version=1, global={}, characters={}} end
function M.Sanitize(raw)
    local result=empty()
    if type(raw)~="table" or raw.version~=1 then return result end
    local function clean(source)
        local out = {}
        if type(source)=="table" then
            for id, keys in pairs(source) do
                if type(id)=="string" and #id<=160 then
                    local normalized=M.Normalize(keys); if normalized then out[id]=normalized end
                end
            end
        end
        return out
    end
    result.global=clean(raw.global)
    if type(raw.characters)=="table" then
        for role, binds in pairs(raw.characters) do
            if type(role)=="string" and #role<=80 then result.characters[role]=clean(binds) end
        end
    end
    return result
end
function M.Store(io, json)
    local s={data=empty(), loaded=false, saving=false, revision=0}
    function s:Load()
        io.read(function(ok, text)
            if ok and type(text)=="string" and #text>0 then
                local parsed, raw=pcall(json.decode,text)
                self.data=M.Sanitize(parsed and raw or nil)
                self.loaderror=not parsed or type(raw)~="table" or raw.version~=1
            end
            self.loaded=true; self.revision=self.revision+1
        end)
    end
    function s:Get(role,entry)
        local group=entry.global and self.data.global or self.data.characters[role]
        return group and group[entry.id]
    end
    function s:Conflict(role, entry, keys, entries)
        for _,other in ipairs(entries) do
            if other.id~=entry.id then
                local bound=self:Get(role,other)
                if bound and M.Overlap(bound,keys) then return other end
            end
        end
    end
    function s:Set(role,entry,keys,entries,cb)
        if not self.loaded or self.saving then cb(false,"busy"); return end
        local normalized,err
        if keys~=nil then
            normalized,err=M.Normalize(keys)
            if not normalized then cb(false,err); return end
            local conflict=self:Conflict(role,entry,normalized,entries)
            if conflict then cb(false,"conflict",conflict); return end
        end
        local nextdata=M.Sanitize(self.data)
        if not nextdata.characters[role] then nextdata.characters[role]={} end
        local group=entry.global and nextdata.global or nextdata.characters[role]
        group[entry.id]=normalized
        self.saving=true
        io.write(json.encode(nextdata),function(ok)
            self.saving=false
            if ok then self.data=nextdata; self.loaderror=false; self.revision=self.revision+1 end
            cb(ok,not ok and "save" or nil)
        end)
    end
    return s
end
return M
