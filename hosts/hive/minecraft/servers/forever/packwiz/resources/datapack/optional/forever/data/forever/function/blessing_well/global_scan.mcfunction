# use distance to make it overworld only for performance
execute as @e[type=minecraft:marker,tag=magic_well,distance=0..] at @s run function forever:blessing_well/marker_scan
schedule function forever:blessing_well/global_scan 2s replace