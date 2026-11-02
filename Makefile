# One entry point for people, CI and AI agents. `make help` lists targets.
PROJECT      := Catalog.xcodeproj
SCHEME       := Catalog
IPHONE       ?= iPhone 17
IPAD         ?= iPad Pro 11-inch (M5)
DERIVED_DATA := build/DerivedData
XCODEBUILD   := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED_DATA)
# A hung UI test fails after a minute instead of blocking the run.
TEST_LIMITS  := -test-timeouts-enabled YES -maximum-test-execution-time-allowance 60
APP          := $(DERIVED_DATA)/Build/Products/Debug-iphonesimulator/Catalog.app

.PHONY: help project build test ui-test ui-test-ipad ui-test-all logs maestro maestro-live format lint run clean

help: ## List targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

project: ## Regenerate Catalog.xcodeproj from project.yml (needs XcodeGen; the project is committed)
	xcodegen generate

build: ## Build the app for the iPhone simulator
	$(XCODEBUILD) -destination 'platform=iOS Simulator,name=$(IPHONE)' build

test: ## Unit tests (Swift Testing), no network
	$(XCODEBUILD) -destination 'platform=iOS Simulator,name=$(IPHONE)' test -only-testing:CatalogTests

ui-test: ## XCUITest on iPhone against the stubbed backend, includes the accessibility audit
	$(XCODEBUILD) -destination 'platform=iOS Simulator,name=$(IPHONE)' $(TEST_LIMITS) test -only-testing:CatalogUITests

ui-test-ipad: ## The same UI tests on iPad (split view)
	$(XCODEBUILD) -destination 'platform=iOS Simulator,name=$(IPAD)' $(TEST_LIMITS) test -only-testing:CatalogUITests

ui-test-all: ## UI tests on iPhone and iPad at once, test classes spread over simulator clones
	$(XCODEBUILD) -destination 'platform=iOS Simulator,name=$(IPHONE)' -destination 'platform=iOS Simulator,name=$(IPAD)' \
		-parallel-testing-enabled YES -parallel-testing-worker-count 3 $(TEST_LIMITS) test -only-testing:CatalogUITests

maestro: build ## Maestro flows against the stubbed backend (needs a booted simulator)
	xcrun simctl install booted $(APP)
	maestro test --exclude-tags live maestro/flows

maestro-live: build ## Maestro smoke test against the real DummyJSON API
	xcrun simctl install booted $(APP)
	maestro test --include-tags live maestro/flows

run: build ## Build, install and launch on the booted simulator (SCENARIO=catalog for stubs)
	xcrun simctl install booted $(APP)
	xcrun simctl launch --terminate-running-process booted com.tinyprocessing.catalog $(if $(SCENARIO),-uiTestScenario $(SCENARIO))

logs: ## Stream the app's logs from the booted simulator
	xcrun simctl spawn booted log stream --level debug --predicate 'subsystem == "com.tinyprocessing.catalog"'

format: ## Format Swift sources with the swift-format bundled in Xcode
	xcrun swift-format format --in-place --recursive App Packages/CatalogKit/Sources Tests

lint: ## Check formatting without changing files
	xcrun swift-format lint --strict --recursive App Packages/CatalogKit/Sources Tests

clean: ## Remove build output
	rm -rf build
