import { gemEffects, gemSourceRowId } from './gemology-tables.mjs';

export const gemSourceTitle='按宝石查获取地形';
export const geodeSourceTitle='按晶洞查采集方法';

const geodes=[
  ['red','红色菌类晶洞','红蘑菇林、混合菌类区域','用镐挖有晶体的红色石化蘑菇树。必掉 1 个，另有 10% 概率再掉 1 个。'],
  ['green','绿色菌类晶洞','绿蘑菇林、混合菌类区域','用镐挖有晶体的绿色石化蘑菇树。必掉 1 个，另有 10% 概率再掉 1 个。'],
  ['blue','蓝色菌类晶洞','蓝蘑菇林、混合菌类区域','用镐挖有晶体的蓝色石化蘑菇树。必掉 1 个，另有 10% 概率再掉 1 个。'],
  ['guano','粪便晶洞','蝙蝠洞','用镐挖带晶洞的粪化石矿簇。按初始高度，矮、中、高分别有 10%、50%、100% 概率掉落，高矿簇还可能放出蝙蝠。'],
  ['lobster','胚胎晶洞','岩石平原、石虾孵化区','用镐挖孕育中的岩石。必掉 1 个，另有 10% 概率再掉 1 个。采矿会惊动附近的石虾。'],
  ['glass','玻璃晶洞','地下月亮洞窟','找月玻璃钟乳石。地震开始后，未掉过晶洞或已经重新长满的钟乳石有 25% 概率在 4–10 秒后掉落 1 个，避开落点。'],
  ['slime','黏液晶洞','遗迹入口苔藓区、洞穴猴区','用镐挖带晶洞的滑石灰岩。附近的洞穴猴可能被激怒。'],
  ['ruins','垃圾晶洞','远古遗迹','用锤子拆损坏的发条装置。三种残骸各有 30% 概率掉 1 个。'],
  ['sink','苔藓晶洞','洞穴入口落水洞、兔人聚落、部分绿蘑菇林','用镐挖带晶洞的「不起眼的洞穴」。挖开可能跑出住在里面的生物。'],
  ['vent','浮石晶洞','洞穴的喷气孔区域','击杀身上带晶洞的地热螨，必掉 1 个。地热螨生成时有 50% 概率变成这种外观。'],
  ['magma','熔火晶洞','熔岩洞穴的活动熔岩区','用镐挖已经结晶的熔火巨岩，必掉 1 个。冒火的巨石还要等 1 个游戏日结晶。熔火巨岩和熔火晶洞沿用当前社区汉化名称。'],
];

const geodePrefab=id=>'um_gemology_geode_'+id;
const geodeRowId=id=>'geode-source-'+id;

export const geodeSources={
  style:'guide-geode-sources',
  headers:['晶洞','常见地形','怎么拿到晶洞'],
  rows:geodes.map(([,name,terrain,method])=>[name,terrain,method]),
  prefabs:geodes.map(([id])=>geodePrefab(id)),
  rowAnchors:geodes.map(([id])=>geodeRowId(id)),
  rowLinks:geodes.map(([id])=>({
    lobster:{href:'rock-lobster.html',label:'石虾习性'},
    vent:{href:'geothermite.html',label:'地热螨打法'},
  })[id]),
};

export const gemSources={
  style:'guide-gem-sources',
  headers:['附魔宝石','可掉落的晶洞与地形'],
  prefabs:gemEffects.map(gem=>gem.prefab),
  rowAnchors:gemEffects.map(gem=>gemSourceRowId(gem.prefab)),
  rowLinks:gemEffects.map(({prefab})=>({href:'#gem-'+prefab.replace(/^um_gemology/,''),label:'三级效果'})),
  makeRows(pools){
    const sources=geodes.map(([id,name,terrain])=>{
      const pool=pools[geodePrefab(id)];
      if(!pool)throw Error('Missing geode pool '+id);
      return {id,name,terrain,pool,total:Object.values(pool).reduce((sum,weight)=>sum+weight,0)};
    });
    return gemEffects.map(({prefab,name})=>{
      const matching=sources.filter(s=>s.pool[prefab]).sort((a,b)=>b.pool[prefab]/b.total-a.pool[prefab]/a.total);
      if(!matching.length)throw Error('Missing geode for '+prefab);
      const locations=matching.map(s=>({
        href:'#'+geodeRowId(s.id),
        label:`${s.name} ${Number((s.pool[prefab]/s.total*100).toFixed(1))}%`,
        detail:s.terrain,
      }));
      return [name,locations];
    });
  },
};

export const sourceJumps=[
  {section:gemSourceTitle,terms:['宝石获取','附魔宝石获取','附魔宝石获取方式','附魔宝石怎么获得','附魔宝石哪里获得','宝石地形','宝石掉落','宝石来源','附魔宝石来源']},
  {section:geodeSourceTitle,terms:['晶洞','晶洞地形','晶洞获取','晶洞掉落','晶洞位置']},
  ...gemEffects.map(gem=>({section:gemSourceTitle,prefab:gem.prefab,anchor:gemSourceRowId(gem.prefab),title:gem.name+' · 获取方式',
    terms:['获取','获取方式','来源','在哪','在哪里','哪里找','哪里掉','怎么获得',' 获取'].map(suffix=>gem.name+suffix),summary:'查看会掉落这颗宝石的晶洞、地形和概率。'})),
  ...geodes.map(([id,name,terrain])=>({section:geodeSourceTitle,prefab:geodePrefab(id),anchor:geodeRowId(id),title:name+' · 获取方式',
    terms:[name,name+'获取',name+'在哪'],summary:terrain})),
];
