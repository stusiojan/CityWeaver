clean-build:
	rm -rf ./.build

build: clean-build
	xcodebuild  \
		-project CityWeaver.xcodeproj \
		-scheme "CityWeaver Debug" \
		-destination 'platform=macOS' \
		-derivedDataPath ./.build \
		build

run:
	open ./.build/Build/Products/Debug/*.app

test-core:
	cd Packages/Core/ && swift test | xcbeautify

test-rga:
	cd Packages/RGA/ && swift test | xcbeautify

test-terrain:
	cd Packages/Terrain/ && swift test | xcbeautify

lsp-bind:
	xcode-build-server config -project CityWeaver.xcodeproj -scheme "CityWeaver Debug"

generate-xcodeproj:
	xcodegen
	
