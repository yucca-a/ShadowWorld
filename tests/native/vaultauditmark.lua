local Mark=Class(function(self,inst)self.inst=inst end)
function Mark:OnSave()return self.token and {token=self.token,padding=self.padding} or nil end
function Mark:OnLoad(data)if data then self.token=data.token;self.padding=data.padding end end
return Mark
