-- 定义一个名为 SavedData 的类，使用 Class 函数创建
-- 该类用于处理游戏中数据的保存和加载操作
-- 传入的 inst 参数通常是一个游戏实例对象，代表某个实体
local SavedData = Class(function(self, inst)
    -- 将传入的游戏实例对象赋值给类的 inst 属性
    -- 这样在类的其他方法中可以使用这个实例对象
    self.inst = inst
end)

-- 定义类的 OnSave 方法，用于将类的属性数据保存到一个表中
-- 当游戏需要保存数据时，会调用这个方法获取需要保存的数据
function SavedData:OnSave()
    -- 创建一个空表 toSave，用于存储需要保存的属性数据
    local toSave = {}
    -- 遍历类的所有属性
    for k,v in pairs(self) do
        -- 排除 inst 属性，因为 inst 是游戏实例对象，通常不需要保存
        if k ~= "inst" then
            -- 将除 inst 之外的属性及其值存储到 toSave 表中
            toSave[k] = v
        end
    end
    -- 返回存储了需要保存的数据的表
    return toSave
end

-- 定义类的 OnLoad 方法，用于从保存的数据中恢复类的属性
-- 当游戏加载数据时，会调用这个方法将保存的数据重新赋值给类的属性
function SavedData:OnLoad(data)
    -- 遍历传入的保存数据的表
    for k,v in pairs(data) do
        -- 将保存的数据中的属性及其值赋值给类的相应属性
        self[k] = v
    end
end

-- 返回 SavedData 类，以便其他模块可以使用这个类来创建处理数据保存和加载的对象
return SavedData