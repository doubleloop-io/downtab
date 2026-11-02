#!/usr/bin/env bash
# Fails if the Switcher core depends on anything but the allowed modules or loads private APIs.
set -euo pipefail
CORE_DIR=Sources/SwitcherCore

# Allowlist, not denylist: any import form (`import class X.Y`, `internal import X`, `@_exported import X`)
# of a module outside this list fails, so AppKit, AX (ApplicationServices, HIServices) and private frameworks stay out.
CORE_ALLOWED_MODULES="Foundation"

violations=$(grep -rnE '^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*((public|package|internal|fileprivate|private)[[:space:]]+)?import[[:space:]]' "$CORE_DIR" \
  | awk -v allowed=" $CORE_ALLOWED_MODULES " '{
      line = $0; sub(/^[^:]*:[0-9]+:/, "", line)
      n = split(line, w, /[[:space:]]+/)
      for (i = 1; i <= n; i++) if (w[i] == "import") break
      m = w[i + 1]
      if (m ~ /^(class|struct|enum|protocol|typealias|func|var|let)$/) m = w[i + 2]
      sub(/\..*/, "", m)
      if (index(allowed, " " m " ") == 0) print
    }' || true)
violations+=$(grep -rnE '@_silgen_name|dlopen|dlsym' "$CORE_DIR" || true)
if [ -n "$violations" ]; then
  echo "$violations"
  echo "Switcher core must stay pure (allowed imports: $CORE_ALLOWED_MODULES): remove the lines above"; exit 1
fi
echo "core boundary ok"
