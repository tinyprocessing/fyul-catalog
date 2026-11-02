#!/bin/sh
# Scaffolds a feature module: package target, model, view, strings and a test.
# Usage: scripts/new-feature.sh Favorites   →   FavoritesFeature
set -eu

name="${1:?Usage: scripts/new-feature.sh <Name>}"
module="${name}Feature"
root="$(cd "$(dirname "$0")/.." && pwd)"
sources="$root/Packages/CatalogKit/Sources/$module"
tests="$root/Tests/CatalogTests/$name"

[ -d "$sources" ] && { echo "$module already exists" >&2; exit 1; }
mkdir -p "$sources/Resources" "$tests"

cat > "$sources/${name}Model.swift" <<EOF
import CatalogCore
import Foundation
import Observation

@MainActor
@Observable
public final class ${name}Model {
    public init() {}
}
EOF

cat > "$sources/${name}View.swift" <<EOF
import CatalogAccessibility
import DesignSystem
import SwiftUI

public struct ${name}View: View {
    @State private var model: ${name}Model

    public init(model: ${name}Model) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.s) {}
                .padding(.horizontal, Spacing.l)
        }
        .scrollIndicators(.hidden)
        .background(Palette.screenBackground)
        .navigationTitle(String(localized: "${name}.title", bundle: .module))
    }
}
EOF

cat > "$sources/Resources/Localizable.xcstrings" <<EOF
{
  "sourceLanguage" : "en",
  "strings" : {
    "${name}.title" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "${name}" } },
        "es" : { "stringUnit" : { "state" : "needs_review", "value" : "${name}" } }
      }
    }
  },
  "version" : "1.0"
}
EOF

cat > "$tests/${name}ModelTests.swift" <<EOF
import ${module}
import Testing

@MainActor
@Suite("${name}")
struct ${name}ModelTests {
    @Test func starts() {
        _ = ${name}Model()
    }
}
EOF

# Register the module: Package.swift lists features in one array, project.yml links them into the app and tests.
sed -i '' "s/^let features = \[\(.*\)\]$/let features = [\1, \"$module\"]/" "$root/Packages/CatalogKit/Package.swift"
for target in Catalog CatalogTests; do
    sed -i '' "/^  $target:$/,/^    dependencies:$/{
        /^    dependencies:$/a\\
\      - package: CatalogKit\\
\        product: $module
    }" "$root/project.yml"
done
(cd "$root" && xcodegen generate --quiet)

echo "Created $module. Next: add an AccessibilityID namespace, Spanish strings, and route to ${name}View."
