#!/bin/bash
# Usage: this_script ~/Downloads/test_IPAs/*.ipa

OUT_DIR=gen_output

ql() {
	# QL_dir=$HOME/Library/QuickLook
	QL_dir=$(dirname "$HOME/Library/Developer/Xcode/DerivedData/ProvisionQL-"*"/Build/Products/Debug/.")
	QL_generator="$QL_dir/ProvisionQL.qlgenerator"
	QL_type=$(mdls -raw -name kMDItemContentType "$1")
	qlmanage -g "$QL_generator" -c "$QL_type" "$@" 1> /dev/null
}

thumb() {
	echo
	echo "=== Thumbnail: $1 ==="
	ql "$1" -t -i -s 1024 -o "$OUT_DIR"
	bn=$(basename "$1")
	mv "$OUT_DIR/$bn.png" "$OUT_DIR/t_$bn.png"
}

preview() {
	echo
	echo "=== Preview: $1 ==="
	ql "$1" -p -o "$OUT_DIR"
	bn=$(basename "$1")
	mv "$OUT_DIR/$bn.qlpreview/Preview.html" "$OUT_DIR/p_$bn.html"
	rm -rf "$OUT_DIR/$bn.qlpreview"
}

fn() {
	thumb "$1"
	preview "$1"
}



mkdir -p "$OUT_DIR"

for file in "$@"; do
	if [ -e "$file" ]; then
		fn "$file"
	fi
done

echo 'done.'

# fn 'a.appex'
# fn 'a.xcarchive'
# fn 'a.mobileprovision'

# for x in *.ipa; do
# 	fn "$x"
# done
# fn 'a.ipa'
# fn 'aa.ipa'
# fn 'at.ipa'
# fn '10.Flight.Control-v1.9.ipa'
# fn 'Labyrinth 2 HD.ipa'
# fn 'Plague Inc. 1.10.1.ipa'
# fn 'iTunes U 1.3.1.ipa'
