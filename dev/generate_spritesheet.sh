#!/bin/bash -eu

declare -r aseprite='aseprite --batch'
declare -ri start=$(date +%s%3N)
declare -r dir="$(dirname "$0")"
declare -r output='../asset/gfx/spritesheet'

# Files with a "Grid information" layer containing collision information.
grid_info_layer='Grid information'
buildings=(
bakery.aseprite
blacksmith.aseprite
dwelling.aseprite
field.aseprite
iron.aseprite
monolith.aseprite
tree.aseprite
)

split=(
field-single.aseprite
)

other=(
bread-resource.aseprite
button.aseprite
children.aseprite
details-panel.aseprite
dust-effect.aseprite
forest-tile.aseprite
grain-resource.aseprite
grass-tile.aseprite
headers.aseprite
info-panel-1.aseprite
info-panel-2.aseprite
info-panel-3.aseprite
info-panel-4.aseprite
info-panel-5.aseprite
info-panel-6.aseprite
info-panel-centre.aseprite
info-panel-left.aseprite
iron-resource.aseprite
menu-button.aseprite
mountain-tile.aseprite
resource-panel.aseprite
smoke.aseprite
tool-resource.aseprite
villagers-palette.aseprite
windmill-blades.aseprite
wood-resource.aseprite
year-panel.aseprite
)

hairy_layer='Hairy'
villagers=(
villagers-action.aseprite
villagers.aseprite
)

cd "$dir"

echo 'Verifying sprites.'
for building in "${buildings[@]}"; do
	if ! $aseprite --all-layers --list-layers "$building" | grep -q "^$grid_info_layer$"; then
		echo "$building is missing the '$grid_info_layer' layer."
	fi
done

villager_variants=()
for variant in hairy unhairy; do
	if [ "$variant" = 'unhairy' ]; then
		villager_variants+=(--ignore-layer "$hairy_layer")
	fi
	for villager in "${villagers[@]}"; do
		if ! $aseprite --list-layers "$villager" | grep -q "^$hairy_layer$"; then
			echo "$villager is missing the '$hairy_layer' layer."
		fi

		villager_variants+=( "$villager" )
	done
done

echo 'Creating spritesheet.'
$aseprite --inner-padding 1 --list-tags --list-slices --ignore-empty \
	--sheet "${output}.png" --data "${output}.json" --sheet-type packed \
	"${buildings[@]}" "${other[@]}" \
	"${villager_variants[@]}" \
	--split-layers "${split[@]}" \
	--layer "$grid_info_layer" "${buildings[@]}" \
	--color-mode rgb \
	>/dev/null

# Couldn't get aseprite to distinguish the hairy and non-hairy villagers :(
# The frames are counted starting from zero, and then reset when the non-hairy variant appears.
gawk -i inplace 'BEGIN { normal=0; action=0; }
{
	if(match($0,/villagers ([0-9]+)/,m)) {
		if(m[1] == normal) {
			gsub(m[1], "(Hairy) " m[1])
			normal+=1
		}
	}
	else if(match($0,/villagers-action ([0-9]+)/,m)) {
		if(m[1] == action) {
			gsub(m[1], "(Hairy) " m[1])
			action+=1
		}
	}
	print $0
}' "${output}.json"

echo "Done. Creation took $(bc <<< "scale=3; ($(date +%s%3N) - $start) / 1000") seconds."
