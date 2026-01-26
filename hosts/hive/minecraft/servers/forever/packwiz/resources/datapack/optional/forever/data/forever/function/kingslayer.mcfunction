weather thunder

title @a[distance=..24] title TREASON

summon minecraft:lightning_bolt ~ ~ ~
summon minecraft:lightning_bolt ~2 ~ ~
summon minecraft:lightning_bolt ~2 ~ ~2
summon minecraft:lightning_bolt ~ ~ ~2
summon minecraft:lightning_bolt ~-2 ~ ~
summon minecraft:lightning_bolt ~-2 ~ ~-2
summon minecraft:lightning_bolt ~ ~ ~-2
summon minecraft:lightning_bolt ~2 ~ ~-2
summon minecraft:lightning_bolt ~-2 ~ ~2

effect give @s minecraft:wither 360
effect give @s minecraft:slowness 360
effect give @s minecraft:weakness 360
effect give @s minecraft:mining_fatigue 360
effect give @s minecraft:hunger 360

playsound entity.ender_dragon.death hostile @a[distance=..24] ~ ~ ~

attribute @s minecraft:scale modifier add forever:kingslayer -0.1 add_value

# other ideas
# - anvil
# - warden (excessive? yes. amusing? yes.)