# Hand testing

## UI

1. Simple Demo View
- 3D View is black
- print road segments coordinatates to a file with metadata (date, time, version number)

2. Road Genertion View
- Validate loaded map and print reason if it is not valid (wrong format, missing data for example there's no city districts specified and if there isn't use it whithout it')
- If user had pressed 'Generate Roads' button and no roads has been generater, print the reason (or potential reason)
- Too many options, prepare few presents with reccommendation on what size of type of map to use them
- it does not work now (no roads are being generated), see if it is connected to too restrict parameters in CityState and Generation Rules and if it will be resolved when more verbose algorithm output will be implemented and better presets
                                            
3. Combined view - maybe different app entry point dependent on debug / prod configuration

## Alghorithm
- RGA package doesn't build in tests (it used to work i think, but i'm not sure)
- Return status messages like 'N roads have been generated', 'No roads have been generated. It might be caused by ...'
- add a file containing a flat map with field and parameter map, so we can be sure that some roads would be generated and make tests.

## Documentation
- Write code challanges and solutions to particular problems in polish
- Why package architecture was chosen (it is slower, but less coupled to xcode development and more flexible)

