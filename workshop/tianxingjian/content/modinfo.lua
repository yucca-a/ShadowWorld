name = "天行健"
description = "独立本地模组。默认F6循环切换关闭、温和、加速、极速，F7切换自动解控；按键可在设置中更换。用于自己的单人测试世界。"
author = "Yucca"
version = "0.2.6"
api_version = 10
dst_compatible = true
client_only_mod = true
all_clients_require_mod = false
local keys = {
    {description="F1", data="KEY_F1"},
    {description="F2", data="KEY_F2"},
    {description="F3", data="KEY_F3"},
    {description="F4", data="KEY_F4"},
    {description="F5", data="KEY_F5"},
    {description="F6", data="KEY_F6"},
    {description="F7", data="KEY_F7"},
    {description="F8", data="KEY_F8"},
    {description="F9", data="KEY_F9"},
    {description="F10", data="KEY_F10"},
    {description="F11", data="KEY_F11"},
    {description="F12", data="KEY_F12"},
    {description="A", data="KEY_A"},
    {description="B", data="KEY_B"},
    {description="C", data="KEY_C"},
    {description="D", data="KEY_D"},
    {description="E", data="KEY_E"},
    {description="F", data="KEY_F"},
    {description="G", data="KEY_G"},
    {description="H", data="KEY_H"},
    {description="I", data="KEY_I"},
    {description="J", data="KEY_J"},
    {description="K", data="KEY_K"},
    {description="L", data="KEY_L"},
    {description="M", data="KEY_M"},
    {description="N", data="KEY_N"},
    {description="O", data="KEY_O"},
    {description="P", data="KEY_P"},
    {description="Q", data="KEY_Q"},
    {description="R", data="KEY_R"},
    {description="S", data="KEY_S"},
    {description="T", data="KEY_T"},
    {description="U", data="KEY_U"},
    {description="V", data="KEY_V"},
    {description="W", data="KEY_W"},
    {description="X", data="KEY_X"},
    {description="Y", data="KEY_Y"},
    {description="Z", data="KEY_Z"},
    {description="0", data="KEY_0"},
    {description="1", data="KEY_1"},
    {description="2", data="KEY_2"},
    {description="3", data="KEY_3"},
    {description="4", data="KEY_4"},
    {description="5", data="KEY_5"},
    {description="6", data="KEY_6"},
    {description="7", data="KEY_7"},
    {description="8", data="KEY_8"},
    {description="9", data="KEY_9"},
}
configuration_options = {
    {name="speed_key",label="移动档位切换按键",hover="按下依次切换：关闭→温和→加速→极速→关闭。建议避开移动和聊天按键。",options=keys,default="KEY_F6"},
    {name="recover_key",label="自动解控开关按键",hover="开启后检测冻结、昏睡、受击、击退等控制动作；再次按下关闭。",options=keys,default="KEY_F7"},
}
