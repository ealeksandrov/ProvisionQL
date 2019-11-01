#!/bin/sh
# autoupdate-revision.sh

git=`sh /etc/profile; which git`
branch=`${git} rev-parse --abbrev-ref HEAD`
commits_count=`${git} rev-list ${branch} | wc -l  | tr -d ' '`

filepath="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"

echo "Updating ${filepath}"
echo "Current version build ${commits_count}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${commits_count}" "${filepath}"
