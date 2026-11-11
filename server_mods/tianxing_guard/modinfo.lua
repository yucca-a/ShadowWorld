name = "天行卫（服务端防护）"
description = "服务器防护：阻止观察动作叠加移动校正及伪造地图投递解控。持续检测到异常后，全服5条倒计时提示；5秒后仍继续才踢出。无需玩家安装。"
author = "Yucca"
version = "0.1.1"
api_version = 10
dst_compatible = true
server_only_mod = true
client_only_mod = false
all_clients_require_mod = false
configuration_options = {
    {name="auto_kick",label="异常持续时自动踢出",hover="默认开启。确认异常后播报5条倒计时；5秒内停止不踢出。关闭后仍拦截和播报，但不踢出。",
     options={{description="开启",data=true},{description="关闭",data=false}},default=true},
}
