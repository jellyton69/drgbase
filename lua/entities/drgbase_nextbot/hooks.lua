
if SERVER then

  -- Damage --

  function ENT:OnTakeDamage(dmg)
    self:SpotEntity(dmg:GetAttacker())
  end

  function ENT:OnFatalDamage() end
  function ENT:OnDowned() end

  function ENT:OnDealtDamage() end

  local function NextbotDeath(self, dmg)
    if self:HasWeapon() and self.DropWeaponOnDeath then
      self:DropWeapon()
    end
    if self.RagdollOnDeath then
      return self:BecomeRagdoll(dmg)
    else self:Remove() end
  end

  function ENT:OnInjured(dmg)
    for type, mult in pairs(self._DrGBaseDamageMultipliers) do
      if type == DMG_DIRECT then continue end
      if dmg:IsDamageType(type) then dmg:ScaleDamage(mult) end
    end
    if dmg:GetDamage() <= 0 then return end
    local res = self:OnTakeDamage(dmg)
    local attacker = dmg:GetAttacker()
    if IsValid(attacker) and DrGBase.IsTarget(attacker) then
      if self:IsAlly(attacker) then
        self._DrGBaseAllyDamageTolerance[attacker] = self._DrGBaseAllyDamageTolerance[attacker] or 0
        self._DrGBaseAllyDamageTolerance[attacker] = self._DrGBaseAllyDamageTolerance[attacker] + self.AllyDamageTolerance
        self:AddEntityRelationship(attacker, D_HT, self._DrGBaseAllyDamageTolerance[attacker])
      elseif self:IsAfraidOf(attacker) then
        self._DrGBaseAfraidOfDamageTolerance[attacker] = self._DrGBaseAfraidOfDamageTolerance[attacker] or 0
        self._DrGBaseAfraidOfDamageTolerance[attacker] = self._DrGBaseAfraidOfDamageTolerance[attacker] + self.AfraidOfDamageTolerance
        self:AddEntityRelationship(attacker, D_HT, self._DrGBaseAfraidOfDamageTolerance[attacker])
      elseif self:IsNeutral(attacker) then
        self._DrGBaseNeutralDamageTolerance[attacker] = self._DrGBaseNeutralDamageTolerance[attacker] or 0
        self._DrGBaseNeutralDamageTolerance[attacker] = self._DrGBaseNeutralDamageTolerance[attacker] + self.NeutralDamageTolerance
        self:AddEntityRelationship(attacker, D_HT, self._DrGBaseNeutralDamageTolerance[attacker])
      end
    end
    if res == true or self:IsDown() or self:IsDead() then
      return dmg:ScaleDamage(0)
    else
      if isnumber(res) then dmg:ScaleDamage(res) end
      if dmg:GetDamage() >= self:Health() then
        if #self.OnDeathSounds > 0 then
          self:EmitSound(self.OnDeathSounds[math.random(#self.OnDeathSounds)])
        end
        if self:OnFatalDamage(dmg) then
          self:SetNW2Bool("DrGBaseDown", true)
          self:SetHealth(1)
          local data = util.DrG_SaveDmg(dmg)
          self:CallInCoroutine(function(self, delay)
            self:OnDowned(util.DrG_LoadDmg(data), delay)
            if self:Health() <= 0 then self:SetHealth(1) end
            self:SetNW2Bool("DrGBaseDown", false)
          end)
          return dmg:ScaleDamage(0)
        end
      else
        if #self.OnDamageSounds > 0 then
          self:EmitSlotSound("DrGBaseDamageSounds", self.DamageSoundDelay, self.OnDamageSounds[math.random(#self.OnDamageSounds)])
        end
        if isfunction(self.AfterTakeDamage) then
          local data = util.DrG_SaveDmg(dmg)
          self:CallInCoroutine(function(self, delay)
            dmg = util.DrG_LoadDmg(data)
            self:AfterTakeDamage(dmg, delay)
          end)
        end
      end
    end
  end
  function ENT:OnKilled(dmg)
    if self:IsDead() then return end
    self:SetHealth(0)
    hook.Run("OnNPCKilled", self, dmg:GetAttacker(), dmg:GetInflictor())
    if isfunction(self.OnDeath) then
      local data = util.DrG_SaveDmg(dmg)
      self:SetNW2Bool("DrGBaseDying", true)
      self:CallInCoroutine(function(self, delay)
        self:SetNW2Bool("DrGBaseDying", false)
        self:SetHealth(0)
        self:SetNW2Bool("DrGBaseDead", true)
        local now = CurTime()
        dmg = util.DrG_LoadDmg(data)
        if dmg:IsDamageType(DMG_DISSOLVE) then self:DrG_Dissolve() end
        dmg = self:OnDeath(dmg, delay)
        if dmg == nil then
          dmg = util.DrG_LoadDmg(data)
          if CurTime() > now then
            dmg:SetDamageForce(Vector(0, 0, 1))
          end
        end
        NextbotDeath(self, dmg)
      end, true)
    else
      self:SetNW2Bool("DrGBaseDead", true)
      NextbotDeath(self, dmg)
    end
  end

  hook.Add("EntityTakeDamage", "DrGBaseNextbotDealtDamage", function(ent, dmg)
    local attacker = dmg:GetAttacker()
    if IsValid(attacker) and attacker.IsDrGNextbot then
      local res = attacker:OnDealtDamage(ent, dmg)
      if isnumber(res) then dmg:ScaleDamage(res)
      elseif res == true then return true end
    end
  end)

  -- Collisions --

  function ENT:OnCombineBall() end

  local COLLIDES_WITH = {
    ["prop_combine_ball"] = true,
    ["replicator_melon"] = true
  }
  local function OnCollide(self, ent)
    if self:GetNoDraw() then return end
    local class = ent:GetClass()
    if not COLLIDES_WITH[class] then return end
    if self:GetHullRangeSquaredTo(ent) > 0 then return end
    if class == "prop_combine_ball" then
      if self:IsFlagSet(FL_DISSOLVING) then return end
      if not self:OnCombineBall(ent) then
        local dmg = DamageInfo()
        local owner = ent:GetOwner()
        dmg:SetAttacker(IsValid(owner) and owner or ent)
        dmg:SetInflictor(ent)
        dmg:SetDamage(self:Health())
        dmg:SetDamageType(DMG_DISSOLVE)
        self:TakeDamageInfo(dmg)
        ent:EmitSound("NPC_CombineBall.KillImpact")
      end
    elseif class == "replicator_melon" then
      ent:Replicate(self)
      self:Remove()
    end
  end
  hook.Add("ShouldCollide", "DrGBaseShouldCollide", function(ent1, ent2)
    if ent1.IsDrGNextbot then OnCollide(ent1, ent2) end
    if ent2.IsDrGNextbot then OnCollide(ent2, ent1) end
  end)

  -- Misc --

  hook.Add("vFireEntityStartedBurning", "DrGBaseNextbotOnIgniteVFire", function(ent)
    if ent.IsDrGNextbot then ent:OnIgnite() end
  end)

end
