# nvidia_ffmpeg
Bash script to convert video file using nvidia hardware on linux Ubuntu and post processing for Radarr and Sonarr with Plex library refresh
The script uses jellyfin-ffmpeg5 on top of the default ffmpeg 

### https://jellyfin.org/downloads/server
## You can use the full jellyfin but you can add the repo and only install jellyfin-ffmpeg5
##sudo wget -O- https://repo.jellyfin.org/install-debuntu.sh | sudo bash
## manual
sudo apt install curl gnupg
sudo mkdir /etc/apt/keyrings
DISTRO="$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release )"
CODENAME="$( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release )"
curl -fsSL https://repo.jellyfin.org/${DISTRO}/jellyfin_team.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg
cat <<EOF | sudo tee /etc/apt/sources.list.d/jellyfin.sources
Types: deb
URIs: https://repo.jellyfin.org/${DISTRO}
Suites: ${CODENAME}
Components: main
Architectures: $( dpkg --print-architecture )
Signed-By: /etc/apt/keyrings/jellyfin.gpg
EOF
###########
sudo apt update
## install only
sudo apt install jellyfin-ffmpeg5