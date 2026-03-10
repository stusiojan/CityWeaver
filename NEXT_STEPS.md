# Hand testing and future features ideas

## UI

1. Simple Demo View
- 3D View is black by default. My system appearience is light. I can change 3d view background color to white, but by default is black and it resets to black each time, I change something.

2. Road Genertion View
- only 1 to 3 roads are being generated, it should be whole city with dozens of roads. Start with flat map and create custom parameters that will allow to generate more accurate city

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

