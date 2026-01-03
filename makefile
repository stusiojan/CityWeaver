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
	cd Packages/Core/ && swift test

test-rga:
	cd Packages/RGA/ && swift test

lsp-bind:
	xcode-build-server config -project CityWeaver.xcodeproj -scheme "CityWeaver Debug"

generate-xcodeproj:
	xcodegen
	
