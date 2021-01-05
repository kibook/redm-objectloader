# RedM Object Loader

Loads map XML files exported from the RDR2 Map Editor by Lambdarevolution: https://allmods.net/red-dead-redemption-2/tools-red-dead-redemption-2/rdr2-map-editor-v0-10/

[![Butter Bridge](https://i.imgur.com/qlmvzwdm.jpg)](https://imgur.com/qlmvzwd)

## Installing

Place the files inside a subfolder in the resources directory, for example:

```
resources/[local]/[objectloader]
resources/[local]/[objectloader]/[maps]
resources/[local]/[objectloader]/objectloader
```

The `[ ]` in the names are important: only folders with names like `[this]` will be searched by the server for resources.

You do not need to add `ensure objectloader` to `server.cfg`. Each map should include `objectloader` as a dependency, which will automatically start it if it is not already running.

## Adding a map

1. Create a new resource for the map:

   `resources/[local]/[objectloader]/[maps]/mymap`.

2. Copy the map editor XML file into the resource folder:

   `resources/[local]/[objectloader]/[maps]/mymap/mymap.xml`
   
3. Create a resource manifest (`fxmanifest.lua`), and enter the following inside it:

   For a single map editor XML file:
   ```
   fx_version 'adamant'
   game 'rdr3'
   rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
   
   dependency 'objectloader'
   
   file 'mymap.xml'
   
   objectloader_map 'mymap.xml'
   ```
   
   For multiple map editor XML files:
   ```
   fx_version 'adamant'
   game 'rdr3'
   rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
   
   dependency 'objectloader'
   
   files {
      'mymap1.xml',
      'mymap2.xml'
   }
   
   objectloader_maps {
      'mymap1.xml',
      'mymap2.xml'
   }
   ```
   
4. Add `ensure mymap` inside `server.cfg`.

5. To enable the map immediately without restarting the server, do the following in the console:

   ```
   refresh
   ensure mymap
   ```
