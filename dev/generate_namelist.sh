#!/bin/bash -eu
#Copyright (C) 2019  Albert Diserholt (@Drauthius)
#
#This file is part of A Village in the Sky.
#
#A Village in the Sky is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#A Village in the Sky is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with A Village in the Sky. If not, see <http://www.gnu.org/licenses/>.

declare -r dir="$(dirname "$0")"

declare -ra feminine=(
	https://www.behindthename.com/names/gender/feminine/origin/old-norse
	https://www.behindthename.com/names/gender/feminine/origin/old-norse/2
)
declare -r feminine_output="$dir/../asset/misc/feminine_names.lua"

declare -ra masculine=(
	https://www.behindthename.com/names/gender/masculine/origin/old-norse
	https://www.behindthename.com/names/gender/masculine/origin/old-norse/2
)
declare -r masculine_output="$dir/../asset/misc/masculine_names.lua"

# Characters that just won't show up in the game.
declare -r unsupported_characters='Ǫ'

get_names() {
	declare url=${1:?Missing URL}

}

for gender in feminine masculine; do
	declare array=$gender[@]
	declare output="${gender}_output"
	{
		printf 'return {'
		for url in "${!array}"; do
			[[ $url != "${!gender}" ]] && printf ','

			xmllint --html --xpath '//div/span[@class="listname"]/a/text()' <(curl -s "$url" --output -) 2>/dev/null \
				| sed -nr 's/\w{1,15}/"&"/p' \
				| grep -iv "[$unsupported_characters]" \
				| paste -s -d ','
		done
		printf '}'
	} > "${!output}"
done
