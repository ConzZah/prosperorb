# prosperorb


## DESCRIPTION:

**search, download & merge ps4 and ps5 retail patches.**

this shell script interacts with prosperopatches.com & orbispatches.com's apis and uses fzf as tui.

once you chose the console, the game, and the patch you want, it will open firefox and navigate to the wanted patch automatically using xdotool.

(it won't use your firefox profile, instead it will launch fpp, which is one of my older projects)

after it got the json url for the patch, it will then check if you have enough storage-space and use curl to download the pieces of the patch directly fron sony's servers.

i also implemented hash-checking (sha1 & sha256) to make sure the patch-pieces are intact.

after the download is complete and the hash is checked, it merges the pieces using cat.


## DEPENDENCIES:

- standard unix tools (grep, sed, cut, etc.)
- sha256sum
- sha1sum
- xdotool
- firefox
- wmctrl
- fzf


## DEMO:

https://github.com/user-attachments/assets/ec49081d-7ad2-4b45-b7c7-ba4719698017


### NOTE:

i spend quite alot of time on this and am very happy to finally present this project to you.

i did not (and never will) use ai for anything on my github, since i think it robs me of my learning experience.

yes, i may need more time to complete projects, but in the end i can produce something that i am actually proud of.

**Cheers, ConzZah**
