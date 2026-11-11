local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local function run(source, env)
    -- Native modinfo loading supplies locale/folder helpers, not ordinary Lua globals.
    setfenv(assert(loadstring(source)), env)()
    return env
end
ANCHOR_MIDDLE, ANCHOR_RIGHT = 0, 2
CHATFONT, UICOLOURS = "chat", {GOLD = {1, 1, 1, 1}}
local function widget()
    local w = {position = {x = 0, y = 0, z = 0}}
    function w:AddChild(child) return child end
    function w:Show() self.hidden = false end
    function w:Hide() self.hidden = true end
    function w:SetPosition(x, y, z)
        self.position = type(x) == "table" and {x = x.x, y = x.y, z = x.z} or {x = x, y = y or 0, z = z or 0}
    end
    function w:GetPosition() return self.position end
    return w
end
Widget = widget
function Text()
    local w = widget()
    function w:SetRegionSize(width, height) self.width, self.height = width, height end
    function w:GetRegionSize() return self.width, self.height end
    function w:SetHAlign(align) self.align = align end
    function w:SetColour() end
    function w:SetSize(size) self.size = size end
    function w:SetString(text) self.text = text end
    return w
end
TEMPLATES = {StandardSpinner = function()
    local w = widget()
    function w:SetOptions(options) self.options = options end
    function w:SetSelected(value) self.selected = value end
    function w:SetHasModification(value) self.modified = value end
    return w
end}
assert(loadstring(native_label_spinner))()
local make_apply = assert(loadstring(native_apply))()
local make_data = assert(loadstring(native_option_data))()
local current_options
local index = {GetModsToLoad = function() return {} end,
    LoadModConfigurationOptions = function() return current_options end}
local class = {_ctor = function(self, name)
    self.options, self.optionwidgets = {}, {}
    for _, option in ipairs(index:LoadModConfigurationOptions(name)) do
        self.options[#self.options + 1] = {name = option.name, label = option.label,
            hover = option.hover, options = option.options, default = option.default, value = option.saved}
    end
    make_data(self)
    local row = {bg = widget(), opt = TEMPLATES.LabelSpinner("", {}, 300, 300, 40)}
    local scroll = {update_fn = make_apply(self), current = 1, row = row}
    function scroll:GetScrollRegionSize() return 630, 450 end
    function scroll:RefreshView() self.update_fn({}, row, self.owner.optionwidgets[self.current], self.current) end
    scroll.owner = self
    self.options_scroll_list = scroll
    self.native_update = scroll.update_fn
    scroll:RefreshView()
end}
local config = assert(loadstring(config_patch))()
config.Install({KnownModIndex = index, require = function() return class end,
    ANCHOR_MIDDLE = ANCHOR_MIDDLE, ANCHOR_RIGHT = ANCHOR_RIGHT}, "ours")
for _, locale in ipairs({"zh", "en", "zhr", "zht"}) do
    local info = run(modinfo_source, {locale = locale})
    current_options = info.configuration_options
    check(current_options[1].name == "Language In Game", "No oversized query heading at the start")
    local rating, ratingindex, hardindex
    for i, option in ipairs(current_options) do
        check(option.label == option.label:match("^%s*(.-)%s*$"), "Unpadded label: " .. option.name)
        for _, choice in ipairs(option.options) do
            check(type(choice.description) == "string", "Spinner description is text: " .. option.name)
            check(choice.description == choice.description:match("^%s*(.-)%s*$"), "Unpadded choice: " .. option.name)
        end
        if option.name == "difficulty_rating" then rating, ratingindex = option, i end
        if option.name == "enable hard mode" then hardindex = i end
        if option.name == "" then check(not option.label:find("/nd", 1, true), "Query hint is not a heading") end
    end
    check(rating and rating.default == true and ratingindex == hardindex + 1, "Rating switch follows the difficulty masters")
    check(rating.label == (locale == "en" and "Difficulty Rating" or "难度评级"), "Requested rating label")
    local enabled, disabled
    for _, choice in ipairs(rating.options) do
        if choice.data then enabled = choice else disabled = choice end
    end
    check(enabled.hover:find("/nd", 1, true) and disabled.hover ~= enabled.hover, "Query hint belongs to enabled choice")
    local screen = {}
    class._ctor(screen, "ours")
    local scroll = screen.options_scroll_list
    local label, original_x = scroll.row.opt.label, -152.5
    local headers = 0
    for i, data in ipairs(screen.optionwidgets) do
        scroll.current = i; scroll:RefreshView()
        if data.is_header then
            headers = headers + 1
            check(label.align == ANCHOR_MIDDLE and label.position.x == 0 and label.width == 630, "Heading centered across the full row")
            check(scroll.row.opt.spinner.hidden and label.size == 30, "Native heading presentation retained")
        else
            check(label.align == ANCHOR_RIGHT and label.position.x == original_x and label.width == 300,
                "Reused ordinary row restores native label alignment")
            check(not scroll.row.opt.spinner.hidden and label.size == 25, "Ordinary row retains native spinner")
        end
    end
    check(headers >= 20, "All subsection headings covered")
    -- Explicitly reuse a header widget as a normal row and then as a header again.
    for i, data in ipairs(screen.optionwidgets) do
        if data.is_header then
            scroll.current = i; scroll:RefreshView()
            scroll.current = 1; scroll:RefreshView()
            check(label.align == ANCHOR_RIGHT and label.position.x == original_x, "Header scrolling does not shift settings")
            break
        end
    end
    local other = {}
    class._ctor(other, "another_mod")
    check(other.options_scroll_list.update_fn == other.native_update, "Other mod screens are untouched")
end
print("MOD_CONFIG_LAYOUT_PASS " .. checks .. " checks")
