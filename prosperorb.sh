#!/usr/bin/env sh

### /// prosperorb.sh // ConzZah // 2026-10-15 02:12 ///

### search, download & merge ps4 and ps5 patches.
### this script supports prospero & orbispatches.
### i am severely artistic and morbidly a beast.

init () {
## depcheck
deps="sha256sum sha1sum firefox xdotool wmctrl paste grep curl cat cut rev sed fzf df tr"
missing_deps=""

for dep in $deps; do
! command -v "$dep" >/dev/null && missing_deps="$dep $missing_deps"
done

## if $missing_deps is nonzero, tell the user which dependencies are missing and exit
[ -n "$missing_deps" ] && printf '\n%s\n%s\n\n' "--> ✖ DEPENDENCIES MISSING:" "$missing_deps" && exit 1

## check if we have /run/user/1000 available
tmp=""
[ -d "/run/user/1000" ] && tmp="/run/user/1000/prosperorb"

## else, fall back to classic /tmp
[ -z "$tmp" ] && tmp="/tmp/prosperorb"
mkdir -p "$tmp"

## init variables
json_url=""
patch_dir=""
content_id=""
title_ids="${tmp}/title_ids"
pieces="${tmp}/patch_pieces"
hashes="${tmp}/patch_hashes"
patch_list="${tmp}/patch_list"
json="${tmp}/jaaasoooon"
orbis="orbispatches.com"
prospero="prosperopatches.com"
search_html="${tmp}/search_html"
patches_json="${tmp}/patches_json"
game_names="${tmp}/game_names"
game_regions="${tmp}/game_regions"
prosperorb_ml="${tmp}/prosperorb_ml"
patch_versions="${tmp}/patch_versions"
patches_req_fw="${tmp}/patches_req_fw"
patches_filesizes="${tmp}/patches_filesizes"
ua='User-Agent: Mozilla/5.0 (PlayStation; PlayStation 5/8.20) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15'
}


browse () {
site=""
term=""
title_id=""
game_name=""
game_region=""
pc="1" ## <-- page counter 
tp="" ## <-- piece counter
## NOTE: only use interactive search if $title_id is still unset,
## if the user supplied any $title_id in $1, set $site, $term & $title_id depending on console.
[ -n "$1" ] && {
printf '%s\n' "$1"| grep '.*CUSA.*' && site="$orbis" && term="$1" && title_id="$1" && console="PS4" && args="1"
printf '%s\n' "$1"| grep '.*PPSA.*' && site="$prospero" && term="$1" && title_id="$1" && console="PS5" && args="1"

## if the user launched prosperorb with a prospero or orbispatches url, get rid of it, so only the actual $title_id remains.
## (this way prosperorb doesn't care if the input was a url or just the $title_id)
[ -n "$title_id" ] && printf '%s\n' "$title_id"| grep -q "https://www.${site}/" && \
title_id="$(printf '%s\n' "$title_id"| sed "s#https://www.${site}/##g")"

## if $title_id is set, get the $game_name and the $game_region
[ -n "$title_id" ] && {
game_name="$(curl -H "$ua" -s "https://www.${site}/${title_id}"| grep -m1 'class="bd-title mb-0 text-white"'| tr '<' '>'| cut -d '>' -f 3)"

## if $game_name is empty, the $title id was invalid and we should exit here.
[ -z "$game_name" ] && printf '\n%s\n\n' "--> ✖ INVALID TITLE ID" && exit 1

## get $game_region
game_region="$(curl -H "$ua" -s "https://www.${site}/${title_id}"| grep -m1 'Region' -A2| tr -d '\tab'| grep '</li>'| cut -d '<' -f 1)"
}
}

## if $site isn't set yet, 
## ask the user which console they want patches for
[ -z "$site" ] && {
site="$(printf '%s\n%s\n%s\n' "✖ EXIT" "🎮 PS4 / ORBIS" "🎮 PS5 / PROSPERO"| fzf --tac --header "--> 🎮 PS4 OR PS5?:")"
case $site in
'✖ EXIT') exit 0;;
'🎮 PS4 / ORBIS') site="$orbis" && console="PS4";;
'🎮 PS5 / PROSPERO') site="$prospero" && console="PS5";;
*) printf '\n%s\n\n' "--> ✖ CHOOSE A CONSOLE."; exit 1;;
esac
}

## ask user for a search term if $term isn't set yet
while [ -z "$term" ]; do
term="$(printf ''| fzf --print-query --header "--> search ${site} (enter 'q' to go back)")"

## if $term equals 'q', run browse again.
[ "$term" = "q" ] || [ "$term" = "Q" ] && term="" && browse
done

[ -z "$title_id" ] && search_games

## access prospero / orbispatches api
[ -n "$title_id" ] && loadpatches
}


search_games () {
search_games="1"
## init $last_page, so it gets updated every run
last_page=""

## search $site for $term
curl -s -H "$ua" --get --data-urlencode "q=${term}" "https://www.${site}/search?&p=${pc}" > "$search_html"

## check if we're on the last $page.
## if 'Next' doesn't show up in the html code, THERE ARE NO MORE PAGES.
! grep -q  '<a href="/search?.*class="page-link">Next</a>' "$search_html" && last_page="1"

## get game names
grep '<h4 class="heading heading-bold text-truncate">.*</h4>' "$search_html"| tr '>' '<'| cut -d '<' -f 3 > "$game_names"

## get game regions
grep '<span class="px-2 py-1 border border-2 rounded me-2 bg-white">.*</span>' "$search_html"| tr '>' '<'| cut -d '<' -f 5 > "$game_regions"

## get title ids
grep '<span class="px-2 py-1 border border-2 rounded me-2 bg-white">.*</span>' "$search_html"| tr '>' '<'| cut -d '<' -f 7 > "$title_ids" 

## create $prosperorb_ml
paste -d '~' "$game_regions" "$game_names" "$title_ids" > "$prosperorb_ml"

## if we have no lines on $prosperorb_ml, exit
[ "$(wc -l < "$prosperorb_ml")"  = "0" ] && \
printf '\n%s\n\n' "--> ✖ NO RESULTS FOR: '$term'" && exit 1

## prepare page navigation
back='<-- BACK'
next='--> NEXT'

## if we're not on the first page, show the $back button
[ "$pc" != "1" ] && sed -i "1i $back" "$prosperorb_ml"

## if $last_page is not equal to 1, show the $next button
[ "$last_page" != "1" ] && sed -i "1i $next" "$prosperorb_ml"

## add 'exit search' button
printf '%s\n' '✖ EXIT SEARCH' >> "$prosperorb_ml"

## let the user navigate pages and choose a game
title_id="$(fzf --header="PAGE: $pc" < "$prosperorb_ml")"

## if $title_id is empty, the user hasn't chosen a game.
[ -z "$title_id" ] && printf '\n%s\n\n' "--> ✖ NO GAME CHOSEN." && exit 1

## process user input
case $title_id in
"$back") pc="$((pc - 1))"; title_id=""; search_games;;
"$next") pc="$((pc + 1))"; title_id=""; search_games;;
'✖ EXIT SEARCH') search_games=""; title_id=""; console=""; browse ;;
*)

## if it's anything else than next or back,
## extract the 1st field to get the $game_region,
## extract the 2nd field to get the $game_name and
## extract the 3rd field to get the actual $title_id
game_region="$(printf '%s\n' "$title_id"| cut -d '~' -f 1)"
game_name="$(printf '%s\n' "$title_id"| cut -d '~' -f 2)"
title_id="$(printf '%s\n' "$title_id"| cut -d '~' -f 3)"

## check if we actually got a $title_id
! printf '%s\n' "$title_id"| grep -qE 'PPSA.*|CUSA.*' && printf '\n%s\n\n' "--> ✖ NOT A VALID TITLE ID" &&  exit 1
;;
esac

## access prospero / orbispatches api
loadpatches
}


loadpatches () {
## NOTE!!
## to access the loadpatches part of the api, we need a key.
## this key is different for every game, and you can find it in the html of $site_url

## build $site_url
site_url="https://www.${site}/${title_id}"

key=""
[ "$site" = "$orbis" ] && key="$(curl -s -H "$ua" "$site_url"| grep -o -m1 "'titleid':.*'key':.*"| rev| cut -d "'" -f 2| rev)"
[ "$site" = "$prospero" ] && key="$(curl -s -H "$ua" "$site_url"| grep -m1 'data-key'| rev | cut -d '"' -f 2| rev)"

## if we don't have the $key, something has gone horribly wrong.
[ -z "$key" ] && printf '\n%s\n\n' "--> ✖ COULDN'T LOAD PATCHES." && exit 1

## once we have the $key, we can query the api and load the patch list
curl -s -H "$ua" "https://www.${site}/api/internal/loadpatches" \
--compressed -X POST -H "$ua" -H 'Accept: application/json' \
-H 'Accept-Encoding: gzip, deflate, br, zstd' -H "Referer: $site_url" \
-H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
-H "Origin: https://www.${site}" -H 'TE: trailers' \
--data-raw "{\"titleid\":\"${title_id}\",\"key\":\"${key}\"}"| \
tr ',' '\n'| grep -vE 'changelog_preview|changelog_charcount' > "$patches_json"

### parse $patches_json
## get patch versions
[ "$site" = "$orbis" ] && v="version"
[ "$site" = "$prospero" ] && v="content_ver"
grep "$v" "$patches_json"| tr -d '"'| sed -e 's#version#VERSION#g' -e 's#content_ver#VERSION#g' > "$patch_versions"

## get required firmware
grep 'required_firmware' "$patches_json"| tr -d '"'| sed 's#required_firmware#FIRMWARE#g' > "$patches_req_fw"

## get filesizes
grep 'filesize' "$patches_json" |tr -d '"'| sed 's#filesize#FILESIZE#g' > "$patches_filesizes"

## build masterlist
paste -d '~' "$patch_versions" "$patches_req_fw" "$patches_filesizes"| grep -v '~~' > "$prosperorb_ml"

## if we came from search_games, add a back button in case the user chose the wrong game
[ -n "$search_games" ] && sed -i '1i <-- BACK' "$prosperorb_ml"

## if the user supplied the $title_id via arguments, offer a exit button
[ "$args" ] && sed -i '1i ✖ EXIT' "$prosperorb_ml"

## let the user choose the patch they want
wanted_patch="$(fzf < "$prosperorb_ml"| cut -d '~' -f 1| cut -d ':' -f 2)"

## if $wanted_patch is empty, exit
[ -z "$wanted_patch" ] && printf '\n%s\n\n' "--> ✖ NO PATCH CHOSEN." && exit 1

## if the user wanted to go back to the search results, accommodate for that
[ -n "$search_games" ] && {
case $wanted_patch in
'<-- BACK') 
site_url="$(printf '%s\n' "$site_url"| sed "s#/${title_id}##")"
wanted_patch=""
search_games
;;
esac
}

## if the user came from args, accommodate for that
[ -n "$args" ] && {
case $wanted_patch in
'✖ EXIT') exit 0 ;;
*) ;;
esac
}

prep_dl
}


prep_dl () {
## get $own_win_id, so we can find our way back
own_win_id="$(xdotool getactivewindow)" || exit 1

## get firefox-privacy-profile (fpp)
## i do this because fpp has the option to disable images,
## which makes the page load faster & doesn't use as much bandwith.
[ ! -f "$HOME/.prosperorb_assets/firefox.sh" ] && { 
mkdir -p "$HOME/.prosperorb_assets"
curl -sLo "$HOME/.prosperorb_assets/firefox.sh" 'https://github.com/ConzZah/fpp/raw/main/firefox.sh' || exit 1 ;}

## check if fpp dir exists already
## if it doesn't, launch firefox and wait 5 seconds for ublock's filters to update
[ ! -d "$HOME/.prosperorb_assets/fpp" ] && {
firefox_first_run="1"
sh "$HOME/.prosperorb_assets/firefox.sh" -img 2 >/dev/null
sleep 5
}

## open firefox.sh on $site_url
printf '\n%s\n' "--> 🌏︎ LAUNCHING FIREFOX.."
sh "$HOME/.prosperorb_assets/firefox.sh" -img 2 "$site_url" >/dev/null || exit 1

## get firefox's window id via wmctrl
x=""; win_id=""
until [ -n "$x" ]; do
win_id="$(wmctrl -l| grep -m1 "${title_id}.*Firefox"| cut -d ' ' -f 1)"
[ -n "$win_id" ] && x="1"
sleep 0.3
done

## convert the $win_id from hex to decimal & sleep 2 seconds
win_id="$((win_id))"
sleep 2

## activate the firefox window
xdotool windowactivate "$win_id" || exit 1

## search for the $wanted_patch
xdotool key --window "$win_id" 'Ctrl+f' || exit 1; sleep 0.3
xdotool type --window "$win_id" --delay 120 "$wanted_patch" || exit 1
xdotool key --window "$win_id" 'Escape' || exit 1; sleep 0.3
xdotool key --window "$win_id" 'Return' || exit 1; sleep 0.3

## wait 5 seconds until it's done loading.
sleep 5

## prosperopatches-specific
[ "$site" = "$prospero" ] && {
## tab 3 times so we land on 'SC'
xdotool key --window "$win_id" --repeat 3 --delay 300 'Tab' || exit 1
}

## orbispatches-specific
## NOTE: to reliably get piece 0 on orbispatches.com,
## we need to search for 'piece' and hit return
[ "$site" = "$orbis" ] && {
xdotool key --window "$win_id" 'Ctrl+f' || exit 1; sleep 0.3
xdotool type --window "$win_id" --delay 120 "piece" || exit 1
xdotool key --window "$win_id" 'Return' || exit 1; sleep 0.3
xdotool key --window "$win_id" 'Escape' || exit 1; sleep 0.3
}

## right click & copy the url
xdotool key --window "$win_id" 'Shift+F10' || exit 1; sleep 0.5
xdotool key --window "$win_id" --delay 120 'l' || exit 1

## paste the url
json_url="$(xclip -o)"

## close firefox with Ctrl+w
## if $firefox_first_run is set, set $rep to 2
rep="1"
[ -n "$firefox_first_run" ] && rep="2"
xdotool key --window "$win_id" --repeat "$rep" 'Ctrl+w' >/dev/null 2>&1

## switch back to terminal
xdotool windowactivate "$own_win_id"

## edit $json_url, so it actually points to the .json file
[ "$site" = "$orbis" ] && json_url="$(printf '%s\n' "$json_url"| sed -e 's#_0.pkg$#.json#' -e 's#.pkg$#.json#')"
[ "$site" = "$prospero" ] && json_url="$(printf '%s\n' "$json_url"| sed 's#_sc.pkg$#.json#')"

## get the json file and replace commas with newlines for parsing
printf '\n%s\n' "--> ⬇ DOWNLOADING JSON FOR: '$title_id'"
curl -H "$ua" -sk "$json_url"| tr ',' '\n' > "$json"

## if $json has 0 lines, we failed to fetch it, and need to abort
[ "$(wc -l < "$json")" = "0" ] && printf '\n%s\n\n' "--> ✖ FAILED TO FETCH JSON, ABORTING." && exit 1

## get $content_id
content_id="$(printf '%s\n' "$json_url"| rev| cut -d '/' -f 1| rev| sed 's#.json##')"

## get the urls of the pieces
grep -o 'url.*' "$json"| cut -d '"' -f 3 > "$pieces"

## get the hashValues of the pieces 
## (NOTE: sha256 for ps5 updates, and sha1 for ps4 updates)
grep 'hashValue' "$json"| cut -d '"' -f 4 > "$hashes"

## make a list containing everything
paste -d '~' "$pieces" "$hashes" > "$patch_list"

## get total number of pieces & init piece counter
tp="$(grep 'numberOfSplitFiles' "$json"| cut -d ':' -f 2)"

## if $tp is empty, we can't continue
[ -z "$tp" ] && printf '\n%s\n\n' "--> ✖ COULDN'T GET THE NUMBER OF PIECES, ABORTING." && exit 1 
printf '\n%s\n' "--> 🗅 FOUND $tp PIECES FOR: '$content_id'"
pc="1"
dl_pkg
}


dl_pkg () {
## before downloading anything, check if there is enough storage on the root partition
printf '\n%s\n' "--> ⧖ CHECKING AVAILABLE STORAGE SPACE.."
free_space_kib=$(df| grep -o '.*/$'| tr -s ' '| rev| cut -d ' ' -f 3| rev)

## since df outputs in Kib, multiply $free_space_kib by 1024 to get $free_space_bytes.
free_space_bytes="$((free_space_kib * 1024))"

## get the $fsizes of all pieces in bytes
fsizes="$(grep 'fileSize' "$json"| cut -d ':' -f 2)"

## compute $fsizes_total
for fsize in $fsizes; do 
fsizes_total="$((fsize + fsizes_total))"
done

## if we have more than one piece,
## add 4Gib overhead, (in bytes) just to be safe.
## this is neccesary, because we merge at runtime, 
## so if we have a 4Gib piece that's not merged yet, but
## only 2Gib of space are left, we would CERTAINLY run out of storage.
[ "$tp" -gt "1" ] && fsizes_total="$((fsizes_total + 4294967296))"

## check if we have enough storage space to continue.
[ "$free_space_bytes" -lt "$fsizes_total"  ] && \
printf '\n%s\n\n' "--> ✖ NOT ENOUGH STORAGE SPACE, DELETE SOME FILES AND COME BACK." && exit 1 || \
printf '\n%s\n' "--> ✓ STORAGE SPACE IS SUFFICIENT."


## set $hashing_algo depending on $site
## (NOTE: sha256 for ps5, sha1 for ps4)

[ "$site" = "$orbis" ] && hashing_algo="sha1sum"
[ "$site" = "$prospero" ] && hashing_algo="sha256sum"

## create the patch directory and cd to it
patch_dir="${HOME}/Downloads/prosperorb/${console}/${game_region}-${title_id}-${game_name}/${content_id}"
mkdir -p "$patch_dir"; cd "$patch_dir" || exit 1
merged_pkg="merged-${content_id}.pkg"

## if $merged_pkg already exists, exit here
[ -f "$merged_pkg" ] && printf '\n%s\n\n' "--> 🗅 NOTE: '$merged_pkg' ALREADY EXISTS. NOT CREATING." && exit 0

## start the loop
while read -r piece; do

url="$(printf '%s\n' "$piece"| cut -d '~' -f 1)"
fn="$(printf '%s\n' "$url"| rev| cut -d '/' -f 1| rev)"

## check if the piece ($fn) exists already, and check its hash,
## so we don't need to download the whole thing again.
## also set $ps (piece status) so delete_on_failure knows when to exit or to return
[ -f "$fn" ] && printf '\n%s\n' "--> 🗅 YOU ALREADY HAVE: '$fn' [[${pc}/${tp}]]" && compare_hashes && pc="$((pc + 1))" && continue
[ ! -f "$fn" ] && {
## if $fn doesn't exist, download the piece
printf '\n%s\n\n' "--> ⬇ DOWNLOADING: '$fn' [[${pc}/${tp}]]"
! curl -H "$ua" -ko "$fn" "$url" && printf '\n%s\n\n' "--> ✖ DOWNLOAD OF: '$fn' [[${pc}/${tp}]] FAILED!" && delete_on_failure

## after downloading the piece, check its hash
compare_hashes
}

## move on to merge_pkg when there is more than one piece, else exit
[ "$tp" -gt "1" ] && merge_pkg || exit 0

pc="$((pc + 1))"
done < "$patch_list"
}


delete_on_failure () {
## deletes the failed piece in case of download failure or hash mismatch
[ -f "${patch_dir}/${fn}" ] && rm -f "${patch_dir}/${fn}"
sleep 1
return 1
}

compare_hashes () {
## get hash of the piece
printf '\n%s\n' "--> ⧖ CHECKING HASH OF: '$fn' [[${pc}/${tp}]]"
local_hash="$($hashing_algo "$fn"| cut -d ' ' -f 1)"

## compare the local hash with the one on $patch_list and delete if they don't match
[ "$local_hash" != "$(printf '%s\n' "$piece"| cut -d '~' -f 2)" ] && \
{ printf '\n%s\n\n%s\n' "--> ✖ HASH DOESN'T MATCH." "--> ✖ DELETING: '$fn' [[${pc}/${tp}]]"; delete_on_failure; return 1 ;}

## otherwise return 0
printf '\n%s\n' "--> ✓ HASH MATCHES FOR: '$fn' [[${pc}/${tp}]]"
return 0
}


merge_pkg () {
## merge pieces using cat
## if the merged.pkg file shouldn't exist already, create it.
printf '\n%s\n\n' "--> ⧖ MERGING: '$fn' [[${pc}/${tp}]] PLEASE WAIT.."
! cat "$fn" >> "$merged_pkg" && \
printf '%s\n\n' "--> ✖ FAILED TO MERGE: '$fn' [[${pc}/${tp}]]" && rm -f "$merged_pkg" "$fn" && exit 1 || \
printf '%s\n\n' "--> ✓ MERGED: '$fn' [[${pc}/${tp}]] SUCCESSFULLY." && rm -f "$fn"

## if $pc and $tp are equal, we can safely exit.
[ "$pc" = "$tp" ] && exit 0  || return 0
}


### LAUNCH ###
init
browse "$@"
