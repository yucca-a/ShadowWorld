local Widget = require "widgets/widget"
local ImageButton = require "widgets/imagebutton"

local MAPSCALE = .8
AddClassPostConstruct("screens/redux/lobbyscreen", function(self)
    local _bottomright_root = self:AddChild(Widget("bottomright"))
    _bottomright_root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    _bottomright_root:SetHAnchor(ANCHOR_RIGHT)
    _bottomright_root:SetVAnchor(ANCHOR_BOTTOM)
    _bottomright_root:SetMaxPropUpscale(MAX_HUD_SCALE)
    _bottomright_root:MoveToFront()
    local mapcontrols = _bottomright_root:AddChild(Widget())
    mapcontrols:SetPosition(-60, 70, 0)
    local tex = "moonrockidol.tex"
    local crossgamebtn = mapcontrols:AddChild(ImageButton(GetInventoryItemAtlas(tex), tex, nil, nil, nil, nil, {1, 1}, {0, 0}))
    crossgamebtn:SetScale(MAPSCALE, MAPSCALE, MAPSCALE)
    crossgamebtn:SetOnClick(nilfn)
end)
