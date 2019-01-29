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

other=(
bread-resource.aseprite
button.aseprite
details-panel.aseprite
dust-effect.aseprite
field-single.aseprite
forest-tile.aseprite
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
tool-resource.aseprite
wheat-resource.aseprite
windmill-blades.aseprite
wood-resource.aseprite
year-panel.aseprite
)

hairy_layer='Hairy'
villagers=(
villagers-action.aseprite
villagers.aseprite
)

children=(
children.aseprite
)

villager_palettes=(
human-palette1-new.aseprite
human-palette2-new.aseprite
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

		for palette in "${villager_palettes[@]}"; do
			villager_variants+=( "$villager" --palette "$palette")
		done
	done
done

for child in "${children[@]}"; do
	for palette in "${villager_palettes[@]}"; do
		villager_variants+=( "$child" --palette "$palette")
	done
done

echo 'Creating spritesheet.'
$aseprite --inner-padding 1 --list-tags --list-slices --ignore-empty \
	--sheet "${output}.png" --data "${output}.json" --sheet-type packed \
	"${buildings[@]}" "${other[@]}" \
	"${villager_variants[@]}" \
	--layer "$grid_info_layer" "${buildings[@]}" \
	--color-mode rgb \
	>/dev/null

echo "Done. Creation took $(bc <<< "scale=3; ($(date +%s%3N) - $start) / 1000") seconds."
