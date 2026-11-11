"""Export only the inventory/portrait icons used by the Wiki from installed game assets.
KTEX metadata reference: https://github.com/oblivioncth/Stexatlaser#klei-tex-format
Decoding uses Pillow's built-in BCn decoder; no third-party game artwork is generated.
"""
from pathlib import Path
from zipfile import ZipFile
import json
import re
import xml.etree.ElementTree as ET
from PIL import Image
from klei_texture import decode, web_crop

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'wiki/assets/icons'
OUT.mkdir(parents=True, exist_ok=True)
GAME = Path("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles")

def save(image, name):
    image = web_crop(image)
    image.thumbnail((96,96), Image.Resampling.LANCZOS)
    image.save(OUT / (name + '.png'))

names = '''spear hambat nightsword armorwood armorgrass armormarble armorruins ruinshat ruins_bat axe pickaxe multitool_axe_pickaxe glasscutter glassaxe tophat icestaff firestaff yellowstaff orangeamulet yellowamulet greenamulet orangegem yellowgem greengem bluegem redgem purplegem thulecite thulecite_pieces nightmarefuel livinglog log rocks cutgrass twigs gears papyrus boards cutstone silk spidergland reviver lifeinjector minotaurhorn deerclops_eyeball eyeturret_item eyeturret rainhat eyebrellahat umbrella slurtlehat shieldofterror mask_of_terror shadowthurible skeletonhat armorskeleton dragon_scales armordragonfly alterguardianhat lunarplant_husk purebrilliance horrorfuel dreadstone sword_lunarplant armor_lunarplant armor_voidcloth voidcloth_scythe voidclothhat pickaxe_lunarplant staff_lunarplant beargerfur_sack townportaltalisman beef_bell saddle_basic chestupgrade_stacksize gelblob_storage_kit trap trap_teeth trap_bramble tacklecontainer supertacklecontainer tackle_station boat_item boat_bumper_crabking_kit shadowheart shadowheart_infused bootleg oceanfish_small_6_inv oceanfish_small_7_inv oceanfish_small_8_inv oceanfish_medium_8_inv carrot onion onion_seeds monstermeat meat fish smallmeat honey royal_jelly forgetmelots glommerfuel goldenpitchfork turfcraftingstation researchlab researchlab2 researchlab3 researchlab4 cartographydesk townportal dragonflyfurnace mushroom_light mushroom_light2 cookpot meatrack tent siestahut bedroll_straw bedroll_furry portablecookpot portableblender lightninggoathorn moonglass moonrocknugget moonbutterflywings sewing_tape pocketwatch_heal pocketwatch_weapon pocketwatch_warp pocketwatch_portal pocketwatch_recall pocketwatch_revive book_brimstone book_tentacles book_horticulture_upgrade book_silviculture book_temperature book_fish spiderhat spiderden chester_eyebone hutch_fishbowl abigail_flower bernie_inactive torch lantern malbatross_beak mast_malbatross_item trident skeleton_player panflute flint lunar_seed opalpreciousgem spore_small spore_medium spore_tall beargervest icepack blueprint waxpaper bundlewrap fishingrod oceanfishingrod lightbulb batbat cave_banana wormlight pepper garlic chili carrotcake tropicalbouillabaisse smallcandy'''.split()
aliases = {
    '草': 'cutgrass',
    '割下的草': 'cutgrass',
    '干草': 'cutgrass',
    '龙鳞皮': 'dragon_scales',
    '龙鳞': 'dragon_scales',
    '西瓜帽': 'watermelonhat',
    '胡萝卜鼠': 'carrat',
    '胡萝卜鼠诱饵甲': 'armor_carrotlure',
    '胡萝卜外套': 'armor_carrotlure',
    '矿工帽': 'minerhat',
    '养蜂帽': 'beehat',
    '夏季背心': 'trunkvest_summer',
    '寒冬背心': 'trunkvest_winter',
    '浆果丛帽': 'bushhat',
    '花衬衫': 'hawaiianshirt',
    '鱼人帽': 'mermhat',
    '羽毛帽': 'featherhat',
    '海花冠': 'kelphat',
    '荆棘甲': 'armor_bramble',
    '雨衣': 'raincoat',
    '海带': 'kelp',
    '海带干': 'kelp_dried',
    '种子干': 'seeds',
    '睡袋炸弹': 'sleepbomb',
    '中毒金丝雀': 'canary_poisoned',
    '红蘑菇': 'red_cap',
    '绿蘑菇': 'green_cap',
    '蓝蘑菇': 'blue_cap',
    '烤肉': 'cookedmeat',
    '烤蝙蝠翅膀': 'batwing_cooked',
    '烤怪物肉': 'cookedmonstermeat',
    '电羊奶': 'goatmilk',
    '晨星': 'nightstick',
    '烤土豆': 'potato_cooked',
    '烤火龙果': 'dragonfruit_cooked',
    '烤仙人掌肉': 'cactus_meat_cooked',
    '烤蛙腿': 'froglegs_cooked',
    '烤红蘑菇': 'red_cap_cooked',
    '烤绿蘑菇': 'green_cap_cooked',
    '烤蓝蘑菇': 'blue_cap_cooked',
    '烤月亮蘑菇': 'moon_cap_cooked',
    '铥矿甲': 'armorruins',
    '远古铥矿盔甲': 'armorruins',
    '远古铥矿甲': 'armorruins',
    '铥矿盔甲': 'armorruins',
    '远古铥矿棒': 'ruins_bat',
    '远古铥矿皇冠': 'ruinshat',
    '懒人法杖': 'orangestaff',
    '解构魔杖': 'greenstaff',
    '解构法杖': 'greenstaff',
    '拆解法杖': 'greenstaff',
    '暗影盔甲': 'armor_sanity',
    '小发光浆果': 'wormlight_lesser',
    '黄金鹤嘴锄': 'goldenpickaxe',
    '黄金斧头': 'goldenaxe',
    '破损的帝王蟹保险杠套装': 'crabking_kit2hm',
    '飞翼风帆': 'mast_malbatross_item',
    '泰拉箱子': 'treasurechest',
    '闪冻冰杖': 'icestaff2',
    '深冻冰杖': 'icestaff3',
    '冰霜核心冰杖': 'icestaff',
    '暗影香炉': 'thurible',
    '蜗牛壳护甲': 'armorsnurtleshell',
    '活木': 'livinglog',
    '火把': 'torch',
    '携带式调味站': 'portableblender_item',
    '便携调味站': 'portableblender_item',
    '洋葱': 'quagmire_onion',
    '伏特羊奶': 'goatmilk',
    '羊奶': 'goatmilk',
    '树果酱': 'treegrowthsolution',
    '火龙果种子': 'dragonfruit_seeds',
    '公牛海带茎': 'bullkelp_root',
    '石果灌木苗': 'rock_avocado_fruit_sprout',
    '藤壶种子': 'waterplant_planter',
    '大肉': 'meat',
    '洋葱种子': 'onion_seeds',
    '大蒜种子': 'garlic_seeds',
    '辣椒种子': 'pepper_seeds',
    '食人花种子': 'lureplantbulb',
    '海象牙': 'walrus_tusk',
    '蜗牛黏液': 'slurtleslime',
    '骨头盔甲': 'armorskeleton',
    '防滑·出逃腿靴': 'bootleg',
    '防滑出逃腿靴': 'bootleg',
    '恶液存储套件': 'gelblob_storage_kit',
    '普通出逃腿靴': 'bootleg',
    '剃刀': 'razor',
    '堆肥': 'compost',
    '食人花叶肉': 'plantmeat',
    '天体洋葱': 'quagmire_onion',
    '远古铥矿护甲': 'armorruins',
    '暗夜甲': 'armor_sanity',
    '暗影铠甲': 'armor_sanity',
}
names.extend('''
antlionhat antliontrinket archive_resonator_item armor_sanity armorruins armorskeleton armorsnurtleshell asparagus
backpack balloonhat batnosehat battlesong_instant_revive battlesong_instant_taunt beardhair bearger_fur beebox
beefalofeed beefalowool beeswax berries_juicy blowdart_pipe blueamulet boneshard book_research_station
book_sleep boomerang bootleg bugnet bunnystew butter butterflywings cactus_meat
cane cannonball_rock_item carpentry_station charcoal compost cookedmeat corn crabking_kit2hm
deerclopseyeball_sentryward deerclopseyeball_sentryward_kit dragonflychest dragonfruit dragonfruit_seeds dug_rock_avocado_bush dumbbell_heat durian
eggplant elixir_container eyemaskhat fig fishmeat_small flowerhat footballhat fossil_piece
froglegs garlic_seeds gelblob_storage_kit ghostflower ghostlyelixir_fastregen ghostlyelixir_retaliation ghostlyelixir_shield ghostlyelixir_slowregen
ghostlyelixir_speed giftwrap goatmilk goldenaxe goldenpickaxe goldnugget greenstaff gunpowder
hammer healingsalve heatrock hivehat horn houndstooth houndstooth_blowpipe ice
icebox icehat icestaff icestaff2 icestaff3 kelp krampus_sack livinglog
lureplantbulb malbatross_feather malbatross_feathered_weave marble mast_malbatross_item mastupgrade_lamp_item meat_dried mermwatchtower
messagebottle messagebottleempty milkywhites molehat moonglass_charged moonglassaxe moonrockidol moonstorm_static_item
nightstick nutrientsgoggleshat onion_seeds orangestaff pepper_seeds petals pigskin plantmeat
plantregistryhat pocketwatch_parts pomegranate portableblender_item portablecookpot_item pumpkin quagmire_onion razor
refined_dust reskin_tool rock_avocado_fruit_ripe rock_avocado_fruit_ripe_cooked rope ruins_bat ruinshat saltrock
scandata scrap_monoclehat scraphat seafaring_prototyper sewing_mannequin shroom_skin slurtleslime snowball_item
spear_wathgrithr_lightning spear_wathgrithr_lightning_charged spicepack spoiled_food stash_map tacklestation tentaclespike tentaclespots
thurible tillweed torch transistor treasurechest treegrowthsolution trunk_summer voidcloth
wagpunk_bits wall_stone_item walrus_tusk watermelon waxwelljournal wormlight_lesser wx78_moduleremover wx78module_bee
wx78module_cold wx78module_heat wx78module_maxhealth wx78module_maxhealth2 wx78module_maxhunger wx78module_maxhunger1 wx78module_maxsanity1 wx78module_movespeed
wx78module_movespeed2 wx78module_nightvision wx78module_taser
'''.split())
names.extend(aliases.values())
names.extend('blue_mushroomhat green_mushroomhat red_mushroomhat moon_mushroomhat'.split())
# Inventory items found in Wiki recipes, drop tables and equipment tables.
names.extend('''
ancientfruit_nightvision armordreadstone barnacle batnose battlesong_instant_panic bee beefalohat berries
berries_cooked berries_juicy_cooked bird_egg birdtrap bonesoup book_light book_moon butterfly cactus_flower
canary chesspiece_crabking_sketch chesspiece_malbatross_sketch chesspiece_wagboss_lunar_sketch compass crow
cutlichen deserthat dragonpie dreadstonehat drumstick dug_bananabush fertilizer fishmeat_small_cooked flowerhat
footballhat frogfishbowl gazpacho gelblob_bottle ghostlyelixir_attack ghostlyelixir_lunar ghostlyelixir_revive
ghostlyelixir_shadow guacamole killerbee klaussackkey lunarplanthat manrabbit_tail molehat monstermeat_dried
moon_cap moon_tree_blossom nightmarepie nitre nutrientsgoggleshat oceanfish_medium_1_inv oceanfish_medium_2_inv
oceanfish_medium_3_inv oceanfish_medium_4_inv oceanfish_medium_5_inv oceanfish_medium_6_inv oceanfish_medium_7_inv
oceanfish_medium_9_inv oceanfish_small_1_inv oceanfish_small_2_inv oceanfish_small_3_inv oceanfish_small_4_inv
oceanfish_small_5_inv oceanfish_small_9_inv orangemooneye palmcone_scale petals phlegm pinecone rabbit robin
robin_winter saddle_shadow sculptingtable security_pulse_cage_full seeds seeds_cooked sleepbomb slurper_pelt
slurtle_shellpieces spice_garlic spider_healer spider_hider spider_warrior spidereggsack steelwool trinket_1
trinket_6 trinket_25 trunk_winter turf_marsh walrushat wetgoop woodcarvedhat wx78_shadowdrone_debuffer wx78module_light2
'''.split())
# dryplants2hm uses the raw produce art, with two Quagmire sprite overrides.
dry_plants = 'carrot corn pumpkin eggplant durian pomegranate dragonfruit watermelon tomato potato asparagus onion garlic pepper fig cave_banana cactus_meat'.split()
dry_overrides = {'tomato': 'quagmire_tomato', 'onion': 'quagmire_onion'}
names.extend(dry_plants)
names.extend(dry_overrides.values())
manifest = {}
with ZipFile(GAME/'images.zip') as archive:
    for xmlname in ['images/inventoryimages1.xml','images/inventoryimages2.xml','images/inventoryimages3.xml','images/inventoryimages4.xml','images/avatars.xml']:
        tree = ET.fromstring(archive.read(xmlname))
        atlas = None
        texpath = 'images/' + tree.find('Texture').get('filename')
        for element in tree.findall('./Elements/Element'):
            name = element.get('name').removesuffix('.tex')
            if name not in names and not re.fullmatch(r'avatar_(wilson|willow|wolfgang|wendy|wx78|wickerbottom|woodie|wes|waxwell|wigfrid|webber|winona|warly|walter|wortox|wormwood|wurt|wanda|wonkey)',name): continue
            if atlas is None: atlas = decode(archive.read(texpath))
            w,h=atlas.size
            u1,u2,v1,v2=(float(element.get(k)) for k in ('u1','u2','v1','v2'))
            crop=atlas.crop((round(u1*w),round((1-v2)*h),round(u2*w),round((1-v1)*h)))
            name=name.removeprefix('avatar_')
            save(crop,name)
            manifest[name]={'path':'assets/icons/'+name+'.png','source':'DST images.zip/'+texpath}
    for character in 'wilson willow wolfgang wendy wx78 wickerbottom woodie wes waxwell wigfrid webber winona warly walter wortox wormwood wurt wanda wonkey'.split():
        target=f'images/avatars/avatar_{character}.tex'
        if target in archive.namelist():
            save(decode(archive.read(target)),character)
            manifest[character]={'path':'assets/icons/'+character+'.png','source':'DST images.zip/'+target}
for file in (ROOT/'content/images/inventoryimages').glob('*.tex'):
    save(decode(file.read_bytes()),file.stem)
    manifest[file.stem]={'path':'assets/icons/'+file.stem+'.png','source':str(file.relative_to(ROOT)).replace('\\','/')}
for name in ['frostshrine2hm', 'tomb_repair']:
    file=ROOT/'content/images'/f'{name}.tex'
    save(decode(file.read_bytes()),name)
    manifest[name]={'path':'assets/icons/'+name+'.png','source':str(file.relative_to(ROOT)).replace('\\','/')}
save(decode((ROOT/'content/modicon.tex').read_bytes()),'modicon')
manifest['modicon']={'path':'assets/icons/modicon.png','source':'content/modicon.tex'}
um = GAME.parents[3] / 'workshop/content/322330/2039181790'
for name in ['zaspberry', 'viperfruit']:
    asset = f'images/inventoryimages/{name}.tex'
    file = um / asset
    if file.is_file():
        save(decode(file.read_bytes()), name)
        manifest[name] = {'path': f'assets/icons/{name}.png', 'source': f'Uncompromising Mode Workshop 2039181790/{asset}'}
labels={}
localized_names=set()
localized_by_prefab={}
with ZipFile(GAME/'scripts.zip') as archive:
    po=archive.read('scripts/languages/chinese_s.po').decode('utf-8-sig')
    for prefab, english, chinese in re.findall(r'msgctxt "STRINGS.NAMES\.([A-Z0-9_]+)"\s+msgid "([^"\n]*)"\s+msgstr "([^"\n]*)"',po):
        prefab=prefab.lower()
        if len(chinese) > 1:
            localized_names.add(chinese)
            localized_by_prefab[prefab]=chinese
        if prefab in manifest and chinese: labels[chinese]=prefab
for plant in dry_plants:
    art=dry_overrides.get(plant,plant)
    if plant in localized_by_prefab and art in manifest:
        labels[localized_by_prefab[plant]+'干']=art
labels.update({'霜冻核心':'frostcore2hm','寒霜之祠':'frostshrine2hm','灵魂瓶':'bottle_soul','涡流':'sword_vortex2hm','裂开的不老表':'pocketwatch_heal2hm','永恒-出逃腿靴':'bootleg2hm','小糖豆':'smallcandy2hm','猪鼻胡萝卜蛋糕':'carrotcake2hm','四季鱼汤':'tropicalbouillabaisse2hm','哀悼之穴':'tomb_repair','眼球炮塔':'eyeturret_item','沃特':'wurt'})
labels.update(aliases)
for label, name in {'闪电蓝莓': 'zaspberry', '暗影蓝莓': 'viperfruit'}.items():
    if name in manifest:
        labels[label] = name
(ROOT/'wiki/data/icon-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(ROOT/'wiki/data/icon-labels.json').write_text(json.dumps(labels,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
# Keep compound names intact even when only a shorter ingredient has an icon.
protected_names = sorted(name for name in localized_names - labels.keys()
                         if any(label in name for label in labels if len(label) > 1))
(ROOT/'wiki/data/icon-protected-names.json').write_text(json.dumps(protected_names,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'Exported {len(manifest)} local game/mod icons.')
