#!/bin/sh
# Regenerate the Xcode project correctly. Run this, never gen_pbxproj.py alone.
#
# Why this script exists
# ----------------------
# There are TWO generators and they must run in this order:
#
#   1. gen_pbxproj.py      -- writes project.pbxproj from scratch, AND writes
#                             the scheme whose TestAction *references*
#                             PoopSocialTests and PoopSocialUITests.
#   2. add_uitest_target.py -- creates those two targets.
#
# gen_pbxproj.py does not create them. So running it alone leaves the scheme
# pointing at targets that do not exist, and the failure is badly misleading:
#
#   xcodebuild: error: Failed to build project PoopSocial with scheme
#   PoopSocial.: There are no test bundles available to test.
#
# That reads like a scheme problem. It is a missing-target problem, and it
# silently deletes the entire test suite from the build graph. This bit us once:
# a rebuild dropped both targets, so newly written tests could not run at all
# while the project still looked healthy.
#
# There is no way to notice from the outside -- the project opens fine, the app
# builds fine, only *testing* fails.
#
# Usage:  ./regen.sh
set -e

cd "$(dirname "$0")"

echo "1/2  gen_pbxproj.py (project + scheme)"
python3 gen_pbxproj.py

echo "2/2  add_uitest_target.py (unit + UI test targets)"
python3 add_uitest_target.py .

# Prove the fix took, rather than trusting it. A silent miss here is exactly the
# failure this script exists to prevent.
for target in PoopSocialTests PoopSocialUITests; do
    n=$(grep -c "$target" PoopSocial.xcodeproj/project.pbxproj)
    if [ "$n" -eq 0 ]; then
        echo "FAIL: $target is not in project.pbxproj -- tests would not run" >&2
        exit 1
    fi
    echo "     ok: $target present ($n references)"
done

# The UI target must pick up every file in the directory, including new ones.
want=$(ls PoopSocialUITests/*.swift | wc -l | tr -d ' ')
if ! grep -q "PoopSocialUITests" PoopSocial.xcodeproj/project.pbxproj; then
    echo "FAIL: UI target missing" >&2
    exit 1
fi
echo "     ok: UI suite has $want source file(s) on disk"

echo "done."
