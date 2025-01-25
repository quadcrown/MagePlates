## REQUIRES SUPERWOW AND UNITXP

### Test build -- Based on using UnitXP new AOE function, see opened issue below:
https://github.com/allfoxwy/UnitXP_SP3/issues/8

## Mageplates v1
- Adds Arcane Explosion icon to enemy nameplates that are within distance of arcane explosion around you

### Known issues
- There is a range issue whenever mobs are not perfectly vertically distanced from you (i.e X = 2.6, Y = 9.7). AOE distances are not straight forward and this is a limitation of UNITXP more than myself. Will provide updates as these new functions are updated.

### Added Features
- Added Frost Nova and Cone of Cold support with cooldown tracking. Will display frost nova and cone of cold icons when within 12 yards and if they are off cooldown. If not off cooldown, they will not show. When they are within 3 seconds of coming off cooldown, they will display with a counter.

### Commands
/mageplates or /mp will display commands for toggling Arcane Explosion, Frost Nova, and Cone of Cold tracking.
