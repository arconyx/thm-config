item modify entity @s weapon.offhand forever:tatter_charm

item modify entity @s hotbar.0 forever:tatter_charm
item modify entity @s hotbar.1 forever:tatter_charm
item modify entity @s hotbar.2 forever:tatter_charm
item modify entity @s hotbar.3 forever:tatter_charm
item modify entity @s hotbar.4 forever:tatter_charm
item modify entity @s hotbar.5 forever:tatter_charm
item modify entity @s hotbar.6 forever:tatter_charm
item modify entity @s hotbar.7 forever:tatter_charm
item modify entity @s hotbar.8 forever:tatter_charm

item modify entity @s inventory.0 forever:tatter_charm
item modify entity @s inventory.1 forever:tatter_charm
item modify entity @s inventory.2 forever:tatter_charm
item modify entity @s inventory.3 forever:tatter_charm
item modify entity @s inventory.4 forever:tatter_charm
item modify entity @s inventory.5 forever:tatter_charm
item modify entity @s inventory.6 forever:tatter_charm
item modify entity @s inventory.7 forever:tatter_charm
item modify entity @s inventory.8 forever:tatter_charm
item modify entity @s inventory.9 forever:tatter_charm
item modify entity @s inventory.10 forever:tatter_charm
item modify entity @s inventory.11 forever:tatter_charm
item modify entity @s inventory.12 forever:tatter_charm
item modify entity @s inventory.13 forever:tatter_charm
item modify entity @s inventory.14 forever:tatter_charm
item modify entity @s inventory.15 forever:tatter_charm
item modify entity @s inventory.16 forever:tatter_charm
item modify entity @s inventory.17 forever:tatter_charm
item modify entity @s inventory.18 forever:tatter_charm
item modify entity @s inventory.19 forever:tatter_charm
item modify entity @s inventory.20 forever:tatter_charm
item modify entity @s inventory.21 forever:tatter_charm
item modify entity @s inventory.22 forever:tatter_charm
item modify entity @s inventory.23 forever:tatter_charm
item modify entity @s inventory.24 forever:tatter_charm
item modify entity @s inventory.25 forever:tatter_charm
item modify entity @s inventory.26 forever:tatter_charm

execute store result score @s puckComment run random value 1..4
execute if score @s puckComment matches 1 run return run function forever:curse_of_greed/puck_say {text: "Teeheehee"}
execute if score @s puckComment matches 2 run return run function forever:curse_of_greed/puck_say {text: {text: "*giggles*", italic: true}}
execute if score @s puckComment matches 3 run return run function forever:curse_of_greed/puck_say {text: {text: "Repent! Repent! Repent!"}}
execute if score @s puckComment matches 4 run return run function forever:curse_of_greed/puck_say {text: {text: "You didn't need those, did you?"}}