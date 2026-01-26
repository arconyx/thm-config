execute store result score @s randomBlessing run random value 1..13

effect clear @s

execute if score @s randomBlessing matches 1 run return run effect give @s minecraft:absorption 360
execute if score @s randomBlessing matches 2 run return run effect give @s minecraft:fire_resistance 360
execute if score @s randomBlessing matches 3 run return run effect give @s minecraft:haste 360
execute if score @s randomBlessing matches 4 run return run effect give @s minecraft:health_boost 360
execute if score @s randomBlessing matches 5 run return run effect give @s minecraft:hero_of_the_village 360
execute if score @s randomBlessing matches 6 run return run effect give @s minecraft:jump_boost 360
execute if score @s randomBlessing matches 7 run return run effect give @s minecraft:luck 360
execute if score @s randomBlessing matches 8 run return run effect give @s minecraft:night_vision 360
execute if score @s randomBlessing matches 9 run return run effect give @s minecraft:regeneration 360
execute if score @s randomBlessing matches 10 run return run effect give @s minecraft:saturation 360
execute if score @s randomBlessing matches 11 run return run effect give @s minecraft:speed 360
execute if score @s randomBlessing matches 12 run return run effect give @s minecraft:strength 360
execute if score @s randomBlessing matches 13 run return run effect give @s minecraft:oozing 360