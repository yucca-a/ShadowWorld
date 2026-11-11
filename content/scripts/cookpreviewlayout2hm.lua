local M = {}
local GAP, MARGIN = 16, 12

local function Clamp(value, low, high) return math.max(low, math.min(high, value)) end
local function Union(a, b)
    if not a then return b end
    if not b then return a end
    return {l=math.min(a.l,b.l), r=math.max(a.r,b.r), b=math.min(a.b,b.b), t=math.max(a.t,b.t)}
end

-- Screen-space rectangles allow different widget parents and HUD scales.
function M.Rect(node)
    if not node or type(node.GetWorldPosition) ~= "function" then return end
    local x1,y1,x2,y2
    if node.GetAnimState then
        x1,y1,x2,y2 = node:GetAnimState():GetVisualBB()
    else
        local w,h
        if node.GetSize then w,h=node:GetSize()
        elseif node.GetRegionSize then w,h=node:GetRegionSize() end
        if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then return end
        x1,y1,x2,y2 = -w/2,-h/2,w/2,h/2
    end
    if not x1 or not y1 or not x2 or not y2 then return end
    local p,s = node:GetWorldPosition(),node:GetScale()
    x1,x2,y1,y2 = p.x+x1*s.x,p.x+x2*s.x,p.y+y1*s.y,p.y+y2*s.y
    return {l=math.min(x1,x2),r=math.max(x1,x2),b=math.min(y1,y2),t=math.max(y1,y2)}
end

function M.ContainerBounds(widget)
    local bounds=Union(M.Rect(widget.bganim),M.Rect(widget.bgimage))
    for _,slot in ipairs(widget.inv or {}) do bounds=Union(bounds,M.Rect(slot.bgimage)) end
    local function Button(button)
        if button and button.shown ~= false then
            bounds=Union(bounds,M.Rect(button.image))
            bounds=Union(bounds,M.Rect(button.text))
            bounds=Union(bounds,M.Rect(button.icon))
            bounds=Union(bounds,M.Rect(button.bg))
        end
    end
    Button(widget.button)
    for _,button in pairs(widget.btns_legion or {}) do Button(button) end
    -- Include sorting/locking buttons added by other container extensions.
    for child in pairs(widget.children or {}) do if child.image then Button(child) end end
    return bounds
end

local function BarBounds(preview)
    local bounds=M.Rect(preview.bg)
    for _,button in ipairs({preview.upbutton,preview.downbutton}) do
        bounds=Union(bounds,M.Rect(button and button.image))
    end
    return bounds
end

local function PopupBounds(popup)
    local bounds=M.Rect(popup.bg)
    local function Visit(node)
        if node.shown == false then return end
        bounds=Union(bounds,M.Rect(node))
        for child in pairs(node.children or {}) do Visit(child) end
    end
    -- Stat icons can protrude above the recipe card's background.
    for child in pairs(popup.children or {}) do Visit(child) end
    return bounds
end

-- Choose a free side of the blocking rectangle. Prefer full size; only shrink
-- when no side fits the available viewport. No cooker position is changed.
function M.Place(block, width, height, screenw, screenh, preferred)
    local regions={
        {side="left",l=MARGIN,r=math.min(screenw-MARGIN,block.l-GAP),b=MARGIN,t=screenh-MARGIN},
        {side="right",l=math.max(MARGIN,block.r+GAP),r=screenw-MARGIN,b=MARGIN,t=screenh-MARGIN},
        {side="above",l=MARGIN,r=screenw-MARGIN,b=math.max(MARGIN,block.t+GAP),t=screenh-MARGIN},
        {side="below",l=MARGIN,r=screenw-MARGIN,b=MARGIN,t=math.min(screenh-MARGIN,block.b-GAP)},
    }
    local best, score
    for _,region in ipairs(regions) do
        local w,h=region.r-region.l,region.t-region.b
        if w>0 and h>0 and width>0 and height>0 then
            local scale=math.min(1,w/width,h/height)
            local rank=region.side==preferred and 3 or (region.side=="left" or region.side=="right") and 2 or 1
            if not best or scale>best.scale+.000001 or math.abs(scale-best.scale)<=.000001 and rank>score then
                local bw,bh=width*scale,height*scale
                local x=Clamp((block.l+block.r)/2,region.l+bw/2,region.r-bw/2)
                local y=Clamp((block.b+block.t)/2,region.b+bh/2,region.t-bh/2)
                if region.side=="left" then x=region.r-bw/2
                elseif region.side=="right" then x=region.l+bw/2
                elseif region.side=="above" then y=region.b+bh/2
                else y=region.t-bh/2 end
                best={l=x-bw/2,r=x+bw/2,b=y-bh/2,t=y+bh/2,scale=scale,side=region.side}
                score=rank
            end
        end
    end
    return best
end

local function Scale(node, base, factor) node:SetScale(base[1]*factor,base[2]*factor,base[3]*factor) end
local function Move(node, bounds, target)
    local p=node:GetPosition()
    local scale=node.parent and node.parent:GetScale() or {x=1,y=1}
    local dx=(target.l+target.r-bounds.l-bounds.r)/2
    local dy=(target.b+target.t-bounds.b-bounds.t)/2
    if math.abs(scale.x)>.0001 and math.abs(scale.y)>.0001 then
        node:SetPosition(p.x+dx/scale.x,p.y+dy/scale.y,p.z)
    end
end

function M.Attach(widget, preview)
    if not widget.GetWorldPosition or not preview.GetLooseScale then return end
    if preview.cookpreviewlayout2hm then preview.cookpreviewlayout2hm:Detach() end
    local layout={widget=widget,preview=preview,popups={},basepos=preview:GetPosition(),basescale={preview:GetLooseScale()}}
    preview.cookpreviewlayout2hm=layout
    local function AddPopup(popup)
        if not popup then return end
        local entry={popup=popup,show=popup.Show,pos=popup:GetPosition(),scale={popup:GetLooseScale()}}
        layout.popups[#layout.popups+1]=entry
        entry.wrapper=function(self,...)
            local function Finish(...)
                layout.current=entry
                layout:Update()
                return ...
            end
            return Finish(entry.show(self,...))
        end
        popup.Show=entry.wrapper
        if popup:IsVisible() then layout.current=entry end
    end
    AddPopup(preview.popup)
    for _,food in ipairs(preview.allfoods or {}) do AddPopup(food.recipepopup) end

    function layout:Update()
        if self.busy or preview.cookpreviewlayout2hm~=self or not widget.isopen then return end
        self.busy=true
        local block=M.ContainerBounds(widget)
        Scale(preview,self.basescale,1)
        local bar=BarBounds(preview)
        local screenw,screenh=TheSim:GetScreenSize()
        if block and bar then
            local width,height=bar.r-bar.l,bar.t-bar.b
            local popupwidth=0
            local example=self.current or self.popups[1]
            if example then
                Scale(example.popup,example.scale,1)
                local bounds=PopupBounds(example.popup)
                if bounds then popupwidth=bounds.r-bounds.l end
            end
            local preferred="right"
            if screenw-MARGIN-block.r < width+GAP*2+popupwidth and block.l-MARGIN >= width+GAP*2+popupwidth then preferred="left" end
            local target=M.Place(block,width,height,screenw,screenh,preferred)
            if target then
                Scale(preview,self.basescale,target.scale)
                bar=BarBounds(preview)
                Move(preview,bar,target)
                bar=BarBounds(preview)
            end
            self.last={container=block,bar=bar,screenw=screenw,screenh=screenh,side=target and target.side}
            local entry=self.current
            if entry and entry.popup:IsVisible() then
                Scale(entry.popup,entry.scale,1)
                local bounds=PopupBounds(entry.popup)
                if bounds then
                    local placement=M.Place(Union(block,bar),bounds.r-bounds.l,bounds.t-bounds.b,
                        screenw,screenh,target and target.side or "right")
                    if placement then
                        Scale(entry.popup,entry.scale,placement.scale)
                        Move(entry.popup,PopupBounds(entry.popup),placement)
                        self.last.popup=PopupBounds(entry.popup)
                    end
                end
            end
        end
        self.busy=false
    end
    function layout:Detach()
        if self.detached then return end
        self.detached=true
        if self.task then self.task:Cancel();self.task=nil end
        for _,entry in ipairs(self.popups) do
            if entry.popup.Show==entry.wrapper then entry.popup.Show=entry.show end
            entry.popup:SetPosition(entry.pos)
            Scale(entry.popup,entry.scale,1)
        end
        if preview.cookpreviewlayout2hm==self then
            preview.cookpreviewlayout2hm=nil
            preview:SetPosition(self.basepos)
            Scale(preview,self.basescale,1)
        end
    end
    layout:Update()
    if widget.inst.DoStaticPeriodicTask then
        layout.task=widget.inst:DoStaticPeriodicTask(.25,function()layout:Update()end)
    end
    return layout
end

return M

