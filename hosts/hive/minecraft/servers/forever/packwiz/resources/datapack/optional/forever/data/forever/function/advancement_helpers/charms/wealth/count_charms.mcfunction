advancement revoke @s only forever:charms/wealth/charm_monitor

scoreboard players set @s charmsCount 0
execute store result score @s charmsCount run clear @s minecraft:written_book[minecraft:written_book_content={"pages": [{"raw": "This token has a value of 1 Imperial Charm, awarded for service to the Empire."}],"title": {"raw": "Imperial Charm"},"author": "ArcOnyx","generation": 2,"resolved": true}] 0

# we use this structure so we can bail early
execute unless score @s charmsCount matches 64.. run return fail
advancement grant @s until forever:charms/wealth/charm_64

execute unless score @s charmsCount matches 128.. run return fail
advancement grant @s until forever:charms/wealth/charm_128

execute unless score @s charmsCount matches 256.. run return fail
advancement grant @s until forever:charms/wealth/charm_256

execute unless score @s charmsCount matches 432.. run return fail
advancement grant @s until forever:charms/wealth/charm_432

execute unless score @s charmsCount matches 592.. run return fail
advancement grant @s until forever:charms/wealth/charm_592