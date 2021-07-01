![Release](https://github.com/ahakola/iLevel/actions/workflows/release.yml/badge.svg)

# iLevel

Shows equiped items itemlevel on Paperdoll frame view, nothing more, nothing less. ~~No other features~~, ~~no bloat~~, these days the addon can show you missing enchants, gems and upgrades and also supports Inspect frame and has only little bit of fancy stuff (Average itemlevel on InspectFrame is extra fancy).

I know there are 13 of these addons in a dozen, but this is my version. While leveling I wanted a quick and easy way to see what itemslot I had the item with lowest itemlevel equiped so I wrote this small addon without any extra features to keep it simple and light and added features along the way while trying to keep the original vision.

---

```
/ilevel ( 0 | 1 | 2 | inside | color | tooltip | enchants [#] | resetenchants )

0 - Only show item levels.
1 - Show item levels and upgrades.
2 - Show item levels, upgrades and enchants and gems.
inside - Change anchoring of the item levels between INSIDE and OUTSIDE of the slot icons.
color - Change the coloring of the itemlevel texts between DEFAULT and RARITY coloring.
tooltip - ENABLE/DISABLE show Enchant/Gem-tooltips.
   - Works only when setting is 2 and anchor is set to OUTSIDE.
enchants [#] - ENABLE/DISABLE show missing Enchants for slot number #.
   - Ommit # to list slot numbers and their current settings.
resetenchants - reset "Show missing Enchants for slots" -settings back to defaults.
```

---

* NEW v2.3: Added option to show tooltips for Enchants and Gems when hovering over the itemlevel text (N.B.: This feature is **OFF** by default). Also added option to enable/disable the missing enchant warning per itemslot. These are only warnings of missing enchants, the addon will still show all applied enchants for all itemslots like before. By default the addon will show warnings for BfA enchantable itemslots.
* NEW v2.0: Rewrote the addon. The addon should detect all sockets (except Azerite Essences) without hardcoding and the addon should also detect all enchants, but only shows missing enchants for the slots with BfA enchants.
* NEW v1.18: Fixed Offhand Artifacts. Added Average itemlevel text for InspectFrame. Added option to color itemlevel texts with the color of itemrarity instead of default color.
* NEW v1.15: Added option to anchor item levels inside the slot icons. Fixed few bugs and the addon should now update missing texts and socketed gems more often if the data wasn't available right away when PaperDollFrame was first opened.
* NEW v1.13: Fixed the non-persistent setting bug and added support for Inspect-frame.
* NEW v1.7: Added slash command /ilevel to give you control on how much addons shows information.
* NEW v1.5: Added indicators for missing Enchants and empty Gem sockets. Please report to me if you know any missing bonusIDs for sockets in gear.
* NEW v1.3: Now shows also small green arrow next to items with unused itemlevel upgrades. Added this feature just to make my life easier with tracking item level upgrades between different item sets.

---