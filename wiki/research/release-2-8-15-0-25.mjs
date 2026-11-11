// Amend only the affected articles; retain older specialist audit versions.
const P=(title,...paragraphs)=>({title,paragraphs});
const version='2.8.15.0.25';
export function refreshRelease25(articles,notes){
 const updated=[];
 function revise(id,fn,sources=[]){
  const a=articles.find(a=>a.id===id);if(!a)throw Error('Unknown release article '+id);
  fn(a);a.source=[...new Set([...a.source,...sources])];a.auditedVersion=version;updated.push(id);
 }
 revise('getting-started',a=>{
  const section=a.sections.find(s=>s.title==='资料覆盖范围');
  section.paragraphs[0]='当前资料基线为淬炼之季 2.8.15.0.25。本轮补充角色右键技能、随机体型掉落与捕获、妥协战歌回复及穿越切换恢复；同时补齐 2.8.15.0.24 的深埋之下兼容说明。未重新核对的专题保留此前来源记录，历史更新日志保留当时规则。';
 });
 revise('configuration',a=>{
  const s=a.sections.find(s=>s.title==='旧档设置迁移');
  s.paragraphs[0]='旧穿越值统一转为“为爽原版”，旧暗影枢纽物品先恢复再送回所属分片原生空间。之后明确选择的新档位会保留。咸鱼版切回原版时会恢复咸鱼旧物品，原版已有库存保留；容量不足则保留剩余物品，腾位后继续恢复。原版与枢纽的手动切换仍保留各自库存。';
 },['content/scripts/components/exchangevariants2hm.lua','content/scripts/exchangexianyurecovery2hm.lua']);
 revise('world-exchange',a=>{
  a.summary='为爽原版、咸鱼版与暗影枢纽的使用规则，以及旧库存恢复。';
  a.sections.find(s=>s.title==='切换档位后的物品在哪里').paragraphs=[
   '由原版切到咸鱼版或枢纽，看到不同库存不代表原箱物品被清空。原版与枢纽的手动切换仍保留各自库存；旧枢纽首次升级另有自动回送流程。',
   '从咸鱼版切回原版后，帽子与钓具的第一、第二空间都会尝试恢复到原版空间。已有原版库存不会被覆盖，放不下的旧物品继续保留，腾出空格后自动恢复；此前已经切回原版而隐藏的咸鱼物品也适用。',
   '切换前未完成的咸鱼跨层存取继续恢复，离线玩家的待领取物品仍保留。再次保存和重启不会把已经恢复的物品重新发一份。地面、洞穴及额外分片需要采用一致版本和设置。',
  ];
  a.sections.push(P('关闭空间的按钮','使用为爽原版穿越时，关闭暗影空间会同步隐藏整理、穿越和暂停按钮，不再残留一秒的暂停按钮。'));
 },['content/easy_other/containersort.lua','content/scripts/components/shadowbank2hm.lua','content/scripts/exchangexianyurecovery2hm.lua','content/scripts/shadowvaultproxy2hm.lua']);
 for(const id of ['containers','tackle-station'])revise(id,a=>{
  a.sections.push({...P('咸鱼版切回原版','帽子和钓具旧物品会尝试恢复到原版空间，保留已有库存。容量不足时剩余物品继续保存，腾出位置后恢复；钓具入口会对应当前有效空间。'),links:['world-exchange']});
  if(id==='containers')a.sections.find(s=>s.title==='穿越与空间切换').paragraphs[1]='旧配置统一迁移为爽原版；地面和洞穴须同时更新且档位一致。原版／枢纽的手动切换保留各自库存，咸鱼版切回原版另有物品恢复。';
 },['content/scripts/exchangexianyurecovery2hm.lua','content/scripts/shadowvaultproxy2hm.lua']);
 revise('right-click-actions',a=>{
  a.summary='武器、角色和勋章技能保留普通右键；发生冲突时用 Ctrl＋右键选择淬炼技能。';
  a.sections[0]=P('技能冲突时的操作','装备、角色专属技能或勋章技能当前可用时，普通右键优先使用它们，Ctrl＋右键使用淬炼提供的角色技能。例如能奔雷冲刺时普通右键冲刺、Ctrl＋右键盈能；灵魂勋章可以跳跃时普通右键灵魂跳跃、Ctrl＋右键盈能。',
   '没有解锁、不能使用或处于不可用状态的装备技能，不应仅因物品带技能组件而阻止淬炼技能。只拿着奔雷矛但不能奔雷冲刺时，薇诺娜仍可使用盈能。',
   '同类兼容也适用于淬炼的角色冲刺、旺达前进／倒走、麦斯威尔突刺等右键地面动作。技能本身的装备、骑乘、冷却和可用条件仍需满足；相关 Ctrl 配置仍保留。');
  a.sections[2].paragraphs[0]='全员右键冲刺默认关闭；启用后同样协调当前可用的物品、角色与勋章技能。自伤避免默认开启，主要阻止玩家对自身的无武器攻击伤害，不代表对所有自身道具伤害免疫。';
 });
 revise('role-winona',a=>{
  a.sections.find(s=>s.title==='旋转武器').paragraphs=[
   '手部有装备且未骑乘时可使用盈能，不要求先连续攻击。奔雷矛等专武也适用；若当前还可以使用武器技能或灵魂勋章跳跃，普通右键保留该技能，Ctrl＋右键使用盈能。',
   '旋转动作可闪避攻击，结束后获得 2.5 秒的 25% 增伤、5 秒的 25% 移速加成；加速期间饥饿消耗为 1.75 倍，再次触发刷新加速时间。旋转冷却 2 秒。',
  ];
  a.sections.find(s=>s.title==='制作与拆除').paragraphs[0]='“薇诺娜制作不再受饥饿值影响”指普通制作不因饥饿而变慢，不代表制作免费或不扣饥饿。正常制作仍按原版规则处理饥饿消耗；永不妥协的砍树、挖矿、采集、工具损耗与工作扣饥饿另按对应设置处理。带专用动作的配方保留自身规则。';
  a.sections.push({title:'右键技能共存',links:['right-click-actions']});
 },['content/easy_role/rightaction.lua']);
 revise('role-wigfrid',a=>{
  a.sections.push(P('永不妥协测试版的乐谱回复','与已适配的永不妥协测试版同开、回血与回理智乐谱正在生效时，按实际命中的敌对目标结算回复。修复攻击蚁狮等 Boss、切换目标或附近存在拳击袋时偶尔无法回复的问题，不增加乐谱回复数值。',
   '月亮阵营可能按妥协规则关闭基础战斗回复，不能把没有乐谱生效时的不回复视为同一问题。猎物、建筑、友方和不符合条件的攻击仍不能用来获取乐谱回复。'));
 },['content/easy_other/um_patch.lua','content/scripts/umcompatprofiles2hm.lua']);
 revise('world-random-size',a=>{
  a.sections.push({title:'小体型的肉类掉落',table:{headers:['随机体型系数','普通肉类掉落调整'],rows:[
   ['0.9 及以上','不触发小体型减肉'],['大于 0.8 且小于 0.9','同类普通肉减少 1 份'],['0.8 及以下','同类普通肉减少 2 份'],
  ]},paragraphs:['按该生物随机得到的属性系数判断，不按画面中压缩后的视觉大小判断。每种普通肉至少保留 1 份，兔子和青蛙等本来只有 1 份肉的对象不再减少。牛角、象鼻、毛、皮等特殊材料不按这条规则削减，原有概率另行计算。']});
  a.sections.push({...P('捕获与宰杀','大体型青蛙等被陷阱直接结算为材料时，也按体型结算额外掉落。兔子、蜘蛛等不可堆叠的活物捕获后保留各自随机体型、最大生命与当前生命；放出、保存读档以及右键宰杀不会因此丢掉个体规则。',
   '若堆叠模组把捕获活物改为可堆叠物品，则沿用原版统一血量处理，不为一叠活物保存不同个体属性；青蛙等直接变成材料的捕获仍适用体型掉落。'),links:['trap']});
 });
 revise('trap',a=>{
  a.configKeys=[...new Set([...a.configKeys,'Random Sized'])];
  a.sections.find(s=>s.title==='使用').paragraphs[2]='捕获对象、范围和耐久沿用对应陷阱规则；“陷阱必中”需要同时开启简单模式。掉落及活物属性还可受独立的“随机大小”机制影响。';
  a.sections.push({...P('随机大小与捕获','开启随机大小后，大体型青蛙可直接产出额外蛙腿；不可堆叠的兔子、蜘蛛等活物保留个体体型、最大生命和当前生命，右键宰杀按个体体型结算掉落。',
   '被堆叠模组改为可堆叠的活物不保留逐个个体属性，沿用原版统一血量；直接变成材料的捕获仍可获得体型掉落。'),links:['world-random-size']});
 },['content/ray/suijishengwuapi.lua']);
 revise('world-autumn',a=>{
  a.sections.push({...P('与深埋之下同开','秋季复苏会同步地表和地下：地表进入秋季，深埋地下进入对应的稳定季，保留该阶段的天气与生态玩法。不会只改变地表而保留地下旧阶段。',
   '默认三宝石档的第一组三颗用于季节切换；两套季节时钟已经同步后，再插入宝石正常给档案馆供能，不重复消耗。旧存档若已有季节不同步，可在下一次满足条件的复苏触发时一起同步。'),links:['deeply-buried-compatibility']});
 });
 articles.push({id:'deeply-buried-compatibility',title:'深埋之下兼容',category:'mechanics',tag:'模组兼容',auditedVersion:version,
  summary:'死亡饥饿上限的显示与恢复，以及档案馆秋季复苏的地表／地下同步。',keywords:'深埋之下 饱食度 饥饿上限 死亡 恢复 秋季复苏 彩虹宝石 季节',
  source:['content/role/hunger.lua','content/weather/autumn.lua'],configKeys:['autumn_change'],sections:[
   P('死亡后的饥饿上限','与深埋之下同开时，淬炼造成的饥饿上限惩罚可以正常显示并按恢复道具的规则恢复，不必靠换角色或重置解除。深埋自身的惩罚仍独立保留；同一次恢复不会因兼容而重复计算。'),
   {...P('秋季复苏','档案馆触发秋季复苏时同步地表秋季和深埋地下对应的稳定季，保留深埋各季节阶段的玩法。宝石费用仍按所选档位处理，已经同步后再插入的宝石正常供能。'),links:['world-autumn']},
   {title:'适配范围',paragraphs:['本次兼容以深埋之下 0.4.16.6 核对。服务器各分片应同步更新；未来上游机制变化需重新核对。'],externalLinks:[{label:'深埋之下创意工坊',url:'https://steamcommunity.com/sharedfiles/filedetails/?id=3360553731'}]},
  ]});updated.push('deeply-buried-compatibility');
 notes['Random Sized']={...notes['Random Sized'],paragraphs:[...(notes['Random Sized']?.paragraphs??[]),'小于0.9倍的多份普通肉减少1份，0.8倍及以下减少2份，同类肉至少留1份。不可堆叠的捕获活物保留体型与血量，陷阱材料和右键宰杀也按体型结算。']};
 notes['Winona No Hungry Builder']={...notes['Winona No Hungry Builder'],paragraphs:['普通制作不因饥饿降低速度，不免除原版制作饥饿消耗。保留原有工作、采集、工具消耗与永不妥协工作能力；专用配方动作保留自身规则。']};
 return updated;
}
