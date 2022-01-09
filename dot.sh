#!/bin/bash
DOTFILES_DIR="$HOME/.dotfiles"
CURRENT_PWD=$(pwd)
DOTFILES_REPO_HTTPS="https://github.com/thanhvule0310/dotfiles"
DOTFILES_REPO_SSH="git@github.com:thanhvule0310/dotfiles.git"
DOTFILES_REPO=$DOTFILES_REPO_SSH

SYSTEM_PACKAGES="grub efibootmgr networkmanager network-manager-applet dialog wpa_supplicant mtools dosfstools reflector base-devel linux-headers avahi xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bluez bluez-utils alsa-utils pulseaudio pulseaudio-alsa pavucontrol bash-completion openssh rsync reflector acpi acpi_call dnsmasq openbsd-netcat ipset acpid os-prober polkit"
USER_ARCH_PACKAGES="wget curl fd ripgrep tokei fish firefox-developer-edition kitty btop htop httpie rofi redshift numlockx nitrogen xcolor go bat neovim python-pip xclip bspwm sxhkd yarn zoxide ttf-cascadia-code ttf-fira-code starship deno dunst evince exa jq foliate gedit lazygit python-pynvim lua lua-language-server rust-analyzer seahorse gnome-keyring telegram-desktop discord fzf ibus unzip unrar p7zip pacman-contrib vlc noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-emoji unzip"
USER_AUR_PACKAGES="asdf-vm clang-format-all-git font-manager lazydocker mcmojave-cursors-git nerd-fonts-cascadia-code nerd-fonts-fira-code nordic-darker-theme notion-app-enhanced papirus-folders picom-ibhagwan-git polybar postman-bin robo3t-bin ruby-neovim visual-studio-code-bin visual-studio-code-insiders-bin pamac-aur-git stylua polkit-gnome github-cli mongodb-compass light-git redis-desktop-manager ytfzf fkill ibus-bamboo-git beekeeper-studio-bin font-manager "

function _spinner() {
  # $1 start/stop
  #
  # on start: $2 display message
  # on stop : $2 process exit status
  #           $3 spinner function pid (supplied from stop_spinner)

  local on_success="DONE"
  local on_fail="FAIL"
  local white="\e[1;37m"
  local green="\e[1;32m"
  local red="\e[1;31m"
  local nc="\e[0m"

  case $1 in
  start)
    # calculate the column where spinner and status msg will be displayed
    let column=$(tput cols)-${#2}-8
    # display message and position the cursor in $column column
    echo -ne ${2}
    printf "%${column}s"

    # start spinner
    i=1
    sp='\|/-'
    delay=${SPINNER_DELAY:-0.15}

    while :; do
      printf "\b${sp:i++%${#sp}:1}"
      sleep $delay
    done
    ;;
  stop)
    if [[ -z ${3} ]]; then
      echo "spinner is not running.."
      exit 1
    fi

    kill $3 >/dev/null 2>&1

    # inform the user uppon success or failure
    echo -en "\b["
    if [[ $2 -eq 0 ]]; then
      echo -en "${green}${on_success}${nc}"
    else
      echo -en "${red}${on_fail}${nc}"
    fi
    echo -e "]"
    ;;
  *)
    echo "invalid argument, try {start/stop}"
    exit 1
    ;;
  esac
}

function start_spinner {
  # $1 : msg to display
  _spinner "start" "${1}" &
  # set global spinner pid
  _sp_pid=$!
  disown
}

function stop_spinner {
  # $1 : command exit status
  _spinner "stop" $1 $_sp_pid
  unset _sp_pid
}

case $1 in
--help)
  echo "Usage:"
  echo -en "\t dots [OPTIONS]\n\n"
  echo "Options:"
  echo -en "\t--help \t\tShow help menu\n"
  echo -en "\t--backup \tBackup current config to dotfiles repo\n"
  echo -en "\t--restore \tRestore dotfiles only (Not include install require packages)\n"
  echo -en "\t--install \tInstall require packages, config system and restore dotfiles\n"
  ;;

--install)
  echo -e " Starting install packages, config and restore dotfiles"
  echo " > Time, language, hostname, hosts"
  ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
  hwclock --systohc
  sed -i '177s/.//' /etc/locale.gen
  locale-gen
  echo "LANG=en_US.UTF-8" >>/etc/locale.conf
  echo "arch" >>/etc/hostname
  echo "127.0.0.1 localhost" >>/etc/hosts
  echo "::1       localhost" >>/etc/hosts
  echo "127.0.1.1 arch.localdomain arch" >>/etc/hosts

  echo " > Create root password"
  passwd

  echo " > Install system packages"
  pacman -S --noconfirm $SYSTEM_PACKAGES

  echo " > Install GPU Driver"
  pacman -S --noconfirm nvidia nvidia-utils nvidia-settings

  echo " > Config NVIDIA Optimus"
  touch /etc/X11/xorg.conf.d/10-nvidia-drm-outputclass.conf
  echo 'Section "OutputClass"
    Identifier "intel"
    MatchDriver "i915"
    Driver "modesetting"
EndSection
Section "OutputClass"
    Identifier "nvidia"
    MatchDriver "nvidia-drm"
    Driver "nvidia"
    Option "AllowEmptyInitialConfiguration"
    Option "PrimaryGPU" "yes"
    ModulePath "/usr/lib/nvidia/xorg"
    ModulePath "/usr/lib/xorg/modules"
EndSection' >/etc/X11/xorg.conf.d/10-nvidia-drm-outputclass.conf

  echo " > Install X.org"
  pacman -S --noconfirm xorg xorg-xinit

  echo " > Install OpenGL"
  pacman -S --noconfirm mesa mesa-demos xf86-video-intel

  echo " > Install user packages"
  pacman -S --noconfirm $USER_ARCH_PACKAGES

  echo " > Install GRUB"
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
  nano /etc/default/grub
  grub-mkconfig -o /boot/grub/grub.cfg

  echo " > Enable services"
  systemctl enable NetworkManager
  systemctl enable bluetooth
  systemctl enable sshd
  systemctl enable avahi-daemon
  systemctl enable reflector.timer
  systemctl enable acpid
  systemctl enable docker
  systemctl enable dhcpcd

  echo " > Create normal user"
  useradd -mG wheel tuyetlien
  echo " > Add password for user"
  passwd tuyetlien
  echo " > Add permission to user"
  nano /etc/sudoers

  echo " > Install AUR helper: paru"
  sudo -u tuyetlien git clone https://aur.archlinux.org/paru.git /tmp/paru
  cd /tmp/paru
  sudo -u tuyetlien makepkg -si --noconfirm
  cd

  echo " > Config pacman"
  nano /etc/pacman.conf

  echo " > Install AUR packages"
  sudo -u tuyetlien paru -S --noconfirm $USER_AUR_PACKAGES

  echo " > Set fish as default shell for user"
  sudo -u tuyetlien chsh -s /usr/bin/fish

  echo " > Touchpad config"
  touch /etc/X11/xorg.conf.d/30-touchpad.conf
  echo 'Section "InputClass"
      Identifier "devname"
      Driver "libinput"
      Option "Tapping" "on"
      Option "NaturalScrolling" "true"
EndSection' >/etc/X11/xorg.conf.d/30-touchpad.conf

  echo " > Ibus config"
  echo "GTK_IM_MODULE=ibus
QT_IM_MODULE=ibus
XMODIFIERS=@im=ibus
QT4_IM_MODULE=ibus
CLUTTER_IM_MODULE=ibus
GLFW_IM_MODULE=ibus
GH_TOKEN=replace-me" >/etc/environment

  echo "Install Done!"

  ;;

*)
  echo -e "Invalid Option, dots --help for more info."
  ;;
esac