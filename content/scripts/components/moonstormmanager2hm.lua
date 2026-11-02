return Class(function(self, inst)
    assert(TheWorld.ismastersim, "Moon Storm Manager should not exist on client")
    local SPARKLIMIT = 3
    self.inst = inst

    -- Private
    local _activeplayers = {}
    local _currentbasenodeindex = nil
    local _currentnodes = nil
    local _nummoonstormpropagationsteps = 3
    local _basenodemindistancefromprevious = 50

    local function isnormalmoonstorm() return TheWorld.components.moonstormmanager and TheWorld.components.moonstormmanager.moonstorm_spark_task end

    --------------------------------------------------------------------------
    --[[ Private member functions ]]
    --------------------------------------------------------------------------
    local function getlightningtime() return math.random() * 90 + 30 end

    local SPAWNDIST = 40
    local SCREENDIST = 30
    local MIN_NODES = 0
    local MAX_NODES = 3
    local _lastmoonphase = "new"
    local _currentmoonphase = "new"

    local BIRDBLOCKER_TAGS = {"birdblocker"}
    local function customcheckfn(pt)
        return #(TheSim:FindEntities(pt.x, 0, pt.z, 4, BIRDBLOCKER_TAGS)) == 0 and TheWorld.net.components.moonstorms2hm ~= nil and
                   TheWorld.net.components.moonstorms2hm:IsPointInMoonstorm(pt) or false
    end

    local function NodeCanHaveMoonstorm(node) return table.contains(node.tags, "lunacyarea") end

    local function AltarAngleTest(altar, other_altar1, other_altar2)
        local x, _, z = altar.Transform:GetWorldPosition()
        local x1, _, z1 = other_altar1.Transform:GetWorldPosition()
        local x2, _, z2 = other_altar2.Transform:GetWorldPosition()

        local delta_normalized_this_to_other1_x, delta_normalized_this_to_other1_z = VecUtil_Normalize(x1 - x, z1 - z)
        local delta_normalized_this_to_other2_x, delta_normalized_this_to_other2_z = VecUtil_Normalize(x2 - x, z2 - z)
        local dot_this_to_other1_other2 = VecUtil_Dot(delta_normalized_this_to_other1_x, delta_normalized_this_to_other1_z, delta_normalized_this_to_other2_x,
                                                      delta_normalized_this_to_other2_z)
        return math.abs(dot_this_to_other1_other2) <= TUNING.MOON_ALTAR_LINK_MAX_ABS_DOT
    end

    --------------------------------------------------------------------------
    --[[ Private event handlers ]]
    --------------------------------------------------------------------------

    local function OnPlayerJoined(src, player)
        for i, v in ipairs(_activeplayers) do if v == player then return end end
        table.insert(_activeplayers, player)

        if TheWorld.net.components.moonstorms2hm and next(TheWorld.net.components.moonstorms2hm._moonstorm_nodes:value()) ~= nil then
            player.components.moonstormwatcher:ToggleMoonstorms({setting = true})
        end
    end

    local function OnPlayerLeft(src, player)
        for i, v in ipairs(_activeplayers) do
            if v == player then
                table.remove(_activeplayers, i)
                return
            end
        end
    end
    --------------------------------------------------------------------------
    --[[ Initialization ]]
    --------------------------------------------------------------------------
    local function OnMoonPhaseChange(inst)
        if TheWorld.state.moonphase ~= _currentmoonphase then
            _lastmoonphase = _currentmoonphase
            _currentmoonphase = TheWorld.state.moonphase
        end
        if _lastmoonphase == "half" and _currentmoonphase == "threequarter" then
            MIN_NODES = math.max(MIN_NODES + 1, 1)
            MAX_NODES = math.max(MAX_NODES + 1, 4)
        elseif _currentmoonphase == "full" then
            MIN_NODES = 4
            MAX_NODES = 10
        elseif _lastmoonphase == "full" and _currentmoonphase == "threequarter" then
            MIN_NODES = math.max(MIN_NODES - 1, 1)
            MAX_NODES = math.max(MAX_NODES - 1, 4)
        end
        if _currentmoonphase == "full" or _currentmoonphase == "threequarter" then
            self:StartMoonstorm()
        else
            MIN_NODES = 0
            MAX_NODES = 3
            self:StopCurrentMoonstorm()
        end
    end
    -- Initialize variables
    for i, v in ipairs(AllPlayers) do table.insert(_activeplayers, v) end
    inst:ListenForEvent("ms_playerjoined", OnPlayerJoined)
    inst:WatchWorldState("moonphase", OnMoonPhaseChange)
    inst:WatchWorldState("cycles", OnMoonPhaseChange)
    -- Register events
    inst:ListenForEvent("ms_playerleft", OnPlayerLeft)
    --------------------------------------------------------------------------
    --[[ Public getters and setters ]]
    --------------------------------------------------------------------------

    --------------------------------------------------------------------------
    --[[ Public member functions ]]
    --------------------------------------------------------------------------

    -- STORM FUNCTIONS

    function self:CalcNewMoonstormBaseNodeIndex()
        local num_nodes = #TheWorld.topology.nodes
        local index_offset = math.random(1, num_nodes)
        local mindistsq = _basenodemindistancefromprevious * _basenodemindistancefromprevious

        for i = 1, num_nodes do
            local ind = math.fmod(i + index_offset, num_nodes) + 1
            local new_node = TheWorld.topology.nodes[ind]

            if ind ~= _currentbasenodeindex then
                local current_node = TheWorld.topology.nodes[_currentbasenodeindex]

                if _currentbasenodeindex ~= nil then
                    local new_x, new_z = new_node.cent[1], new_node.cent[2]
                    local current_x, current_z = current_node.cent[1], current_node.cent[2]

                    if NodeCanHaveMoonstorm(new_node) and VecUtil_LengthSq(new_x - current_x, new_z - current_z) > mindistsq then return ind end
                else
                    if NodeCanHaveMoonstorm(new_node) then return ind end
                end
            end
        end
    end

    function self:StartMoonstorm(set_first_node_index, nodes)
        self:StopCurrentMoonstorm()

        if not TheWorld.net or not TheWorld.net.components.moonstorms2hm == nil then return end

        local checked_nodes = {}
        local new_storm_nodes = nodes or {}
        local first_node_index = set_first_node_index or nil

        local function propagatestorm(node, steps, nodelist)
            if not checked_nodes[node] and NodeCanHaveMoonstorm(TheWorld.topology.nodes[node]) then
                checked_nodes[node] = true

                table.insert(nodelist, node)

                local node_edges = TheWorld.topology.nodes[node].validedges
                for _, edge_index in ipairs(node_edges) do
                    local edge_nodes = TheWorld.topology.edgeToNodes[edge_index]
                    local other_node_index = edge_nodes[1] ~= node and edge_nodes[1] or edge_nodes[2]

                    if steps > 0 and #nodelist < MAX_NODES then propagatestorm(other_node_index, steps - 1, nodelist) end
                end
            else
                return
            end
        end
        local trial = 0
        if not new_storm_nodes or #new_storm_nodes < MIN_NODES then
            while #new_storm_nodes < MIN_NODES do
                new_storm_nodes = {}
                if set_first_node_index and trial < 1 then
                    trial = trial + 1
                else
                    first_node_index = self:CalcNewMoonstormBaseNodeIndex()
                end
                if first_node_index == nil then return end
                -- end
                propagatestorm(first_node_index, _nummoonstormpropagationsteps, new_storm_nodes)
            end
        end

        _currentbasenodeindex = first_node_index
        _currentnodes = new_storm_nodes

        if TheWorld.net.components.moonstorms2hm then
            TheWorld.net.components.moonstorms2hm:ClearMoonstormNodes()
            TheWorld.net.components.moonstorms2hm:AddMoonstormNodes(new_storm_nodes, _currentbasenodeindex)
        end
        self.moonstorm_spark_task = self.inst:DoPeriodicTask(180, function() self:DoTestForSparks() end)
        self.moonstorm_lightning_task = self.inst:DoTaskInTime(getlightningtime(), function() self:DoTestForLightning() end)
    end

    function self:StopCurrentMoonstorm()
        if self.moonstorm_spark_task then
            self.moonstorm_spark_task:Cancel()
            self.moonstorm_spark_task = nil
        end
        if self.moonstorm_lightning_task then
            self.moonstorm_lightning_task:Cancel()
            self.moonstorm_lightning_task = nil
        end

        if TheWorld.net.components.moonstorms2hm ~= nil then TheWorld.net.components.moonstorms2hm:StopMoonstorm() end
        _currentbasenodeindex = nil
        _currentnodes = nil
        self.MoonStorm_Ending = true
    end

    local MOONSTORM_SPARKS_MUST_HAVE = {"moonstorm_spark"}
    local MOONSTORM_SPARKS_CANT_HAVE = {"INLIMBO"}

    function self:DoTestForSparks()
        for i, v in ipairs(_activeplayers) do
            local pt = Vector3(v.Transform:GetWorldPosition())
            if TheWorld.net.components.moonstorms2hm and TheWorld.net.components.moonstorms2hm:IsPointInMoonstorm(pt) then
                local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 30, MOONSTORM_SPARKS_MUST_HAVE, MOONSTORM_SPARKS_CANT_HAVE)
                if #ents < SPARKLIMIT then
                    local pos = FindWalkableOffset(pt, math.random() * 2 * PI, 5 + math.random() * 20, 16, nil, nil, customcheckfn, nil, nil)
                    if pos then
                        local spark = SpawnPrefab("moonstorm_spark")
                        spark.Transform:SetPosition(pt.x + pos.x, 0, pt.z + pos.z)
                    end
                end
            end
        end
    end

    function self:DoTestForLightning()
        local candidates = {}
        for i, v in ipairs(_activeplayers) do
            local pt = Vector3(v.Transform:GetWorldPosition())
            if TheWorld.net.components.moonstorms2hm and TheWorld.net.components.moonstorms2hm:IsPointInMoonstorm(pt) then
                table.insert(candidates, v)
            end
        end

        if #candidates > 0 then
            local candidate = candidates[math.random(1, #candidates)]
            local pt = Vector3(candidate.Transform:GetWorldPosition())
            local pos = FindWalkableOffset(pt, math.random() * 2 * PI, 5 + math.random() * 10, 16, nil, nil, customcheckfn, nil, nil)
            if pos then
                local spark = SpawnPrefab("moonstorm_lightning")
                spark.Transform:SetPosition(pt.x + pos.x, 0, pt.z + pos.z)
            end
        end
        self.moonstorm_lightning_task = self.inst:DoTaskInTime(getlightningtime(), function() self:DoTestForLightning() end)
    end

    self.LongUpdate = self.OnUpdate

    --------------------------------------------------------------------------
    --[[ Save/Load ]]
    --------------------------------------------------------------------------

    function self:OnSave()
        local data = {}
        data.currentbasenodeindex = self.currentbasenodeindextemp or _currentbasenodeindex
        data.currentnodes = _currentnodes
        data._lastmoonphase = _lastmoonphase
        data._currentmoonphase = _currentmoonphase
        data.MIN_NODES = MIN_NODES
        data.MAX_NODES = MAX_NODES
        return data
    end

    function self:OnLoad(data)
        if data ~= nil then
            _lastmoonphase = data._lastmoonphase or "new"
            _currentmoonphase = data._currentmoonphase or "new"
            MIN_NODES = data.MIN_NODES or 0
            MAX_NODES = data.MAX_NODES or 3
            if data.currentbasenodeindex ~= nil then
                self.currentbasenodeindextemp = data.currentbasenodeindex
                self.inst:DoTaskInTime(1, function()
                    self:StartMoonstorm(data.currentbasenodeindex, data.currentnodes)
                    self.currentbasenodeindextemp = nil
                end)
            end
        end
    end
end)
