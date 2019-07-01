if not DrGBase then return end -- return if DrGBase isn't installed
ENT.Base = "proj_drg_default"

-- Misc --
ENT.PrintName = "Plasma Ball"
ENT.Category = "DrGBase"
ENT.AdminOnly = true
ENT.Spawnable = true

-- Physics --
ENT.Gravity = false
ENT.Physgun = false
ENT.Gravgun = true
ENT.Collisions = true

-- Sounds --
ENT.LoopSounds = {}
ENT.OnContactSounds = {"weapons/stunstick/stunstick_fleshhit1.wav"}
ENT.OnRemoveSounds = {}

-- Effects --
ENT.AttachEffects = {"drg_plasma_ball"}
ENT.OnContactEffects = {}
ENT.OnRemoveEffects = {}

if SERVER then
  AddCSLuaFile()

  function ENT:CustomInitialize()
    self:DynamicLight(Color(150, 255, 0), 300, 0.1)
    self:FilterOwner(false)
  end

  function ENT:CustomThink()
    local velocity = self:GetVelocity()
    self:SetVelocity(velocity:GetNormalized()*500)
  end

  function ENT:OnContact(ent)
    if ent:GetClass() == self:GetClass() then
      -- nice explosion
    else self:DealDamage(ent, ent:Health(), DMG_SHOCK) end
  end

end