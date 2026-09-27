.PHONY: run build app clean setup-update-signing package-release release

run:
	swift run MacTranslate

build:
	swift build

app:
	./Scripts/build-app.sh

clean:
	swift package clean
	rm -rf dist

setup-update-signing:
	./Scripts/setup-update-signing.sh

package-release:
	@test -n "$(VERSION)" || { echo "Usage: make package-release VERSION=1.0.0" >&2; exit 2; }
	./Scripts/package-release.sh "$(VERSION)"

release:
	@test -n "$(VERSION)" || { echo "Usage: make release VERSION=1.0.0 [RELEASE_ARGS=--publish]" >&2; exit 2; }
	./Scripts/release.sh "$(VERSION)" $(RELEASE_ARGS)
