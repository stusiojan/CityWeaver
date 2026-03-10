# Hand testing and future features ideas

## UI

1. Simple Demo View
- 3D View is black by default. My system appearience is light. I can change 3d view background color to white, but by default is black and it resets to black each time, I change something.

2. Road Genertion View
- only 1 to 3 roads are being generated, it should be whole city with dozens of roads. See logs/* - there is downsampling in loading an asc file. It might affect how many roads are created (see next point). Check with flat map and create custom parameters that will allow to generate more accurate city.

3. Terrain Editor
- see terrain loading logic. We are downsampling 4 times the map, so user can edit it whithout lags. When we will export map it stays downsampled (see 'Data/80052_1526701_M-34-51-C-d-4-1.asc' and  'Data/terrain_map_no_changes.json', which is the same file as .asc but exported with no modification and it seems to be 4 times smaller). This has effect on road generation (see UI point 2.).

# Future features

## UI

1. Simple Demo View
- add export button that will export only roads to format that is editable in blender (and good for editing roads)

2. Road Genertion View
- add export button (same as in simple demo view)
- add 3d view (make it share view logic with simple demo view)

## Backend

1. Terrain generator
- add parametric .asc terrain generator for generating simple terrains
- add populating .asc terrains with zones for mocking .json terrain maps with basic city zones
- use it in tests and simple demo view

