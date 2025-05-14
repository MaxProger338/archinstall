#!/bin/sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

disk=""

function show_header {
        echo -e "${YELLOW}"
        cat << "EOF"
            _             _     ___           _        _ _
           / \   _ __ ___| |__ |_ _|_ __  ___| |_ __ _| | |
          / _ \ | '__/ __| '_ \ | || '_ \/ __| __/ _` | | |
         / ___ \| | | (__| | | || || | | \__ \ || (_| | | |
        /_/   \_\_|  \___|_| |_|___|_| |_|___/\__\__,_|_|_|
EOF
        echo -e "${NC}"
}

function show_partition_layout {
    echo -e "${YELLOW}1 -> ${GREEN}/boot/efi${NC}"
    echo -e "${YELLOW}2 -> ${GREEN}/boot${NC}"
    echo -e "${YELLOW}3 -> ${GREEN}/root${NC}"
    echo -e "${YELLOW}4 -> ${GREEN}/${NC}"
    echo -e "${YELLOW}5 -> ${GREEN}/home${NC}"
}

function partition {
    echo -e "${GREEN}Disk partition...${NC}"
    lsblk
    echo "----------------------------------------------"
    echo -n "Enter the disk: "
    read disk
    echo -en "Disk ${YELLOW}${disk}${NC}, sure? "
    read
    cfdisk "/dev/${disk}"
}

function formating {
    echo -e "${YELLOW}Formating...${NC}"
    if [[ -z "${disk}" ]]; then
            lsblk
            echo "----------------------------------------------"
            echo -n "Enter the disk: "
            read disk
            echo -en "Disk ${YELLOW}${disk}${NC}, sure? "
            read
    fi
    if [[ "${disk}" =~ ^nvme.* ]]; then
            echo "Ahahaha, nvme"
            disk="${disk}p"
            echo "Added 'p' to disk; now ${disk}"
    fi
  
    echo -e "Formating /dev/${disk}1 to fat32 (will be with label ESP)..."
    mkfs.fat -F32 "/dev/${disk}1" -n ESP}

    echo -e "Formating /dev/${disk}2 to ext4 (will be with label BOOT)..."
    mkfs.ext4 "/dev/${disk}2" -L BOOT

    echo -e "Formating /dev/${disk}3 to ext4 (will be with label ROOT)..."
    mkfs.ext4 "/dev/${disk}3" -L ROOT

    echo -e "Formating /dev/${disk}4 to ext4 (will be with label SLASH)..."
    mkfs.ext4 "/dev/${disk}4" -L SLASH

    echo -e "Formating /dev/${disk}5 to ext4 (will be with label HOME)..."
    mkfs.ext4 "/dev/${disk}5" -L HOME
}

function mounting {
        echo -e "${YELLOW}Mounting...${NC}"
        ESP=/dev/disk/by-label/ESP
        ROOT=/dev/disk/by-label/ROOT
        BOOT=/dev/disk/by-label/BOOT
        SLASH=/dev/disk/by-label/SLASH
        HOME=/dev/disk/by-label/HOME
        if [[ ! -e $ESP ]] || [[ ! -e $ROOT ]] || [[ ! -e $BOOT ]] || [[ ! -e $SLASH ]] || [[ ! -e $HOME ]]; then
                echo -e "${RED}Labels don't exist!"
                exit 1
        fi
        mount $SLASH /mnt
        mkdir /mnt/{boot,root,home}
        mount $BOOT /mnt/boot
        mkdir /mnt/boot/efi
        mount $ESP /mnt/boot/efi
        mount $ROOT /mnt/root
        mount $HOME /mnt/home
}

function mirrors {
        echo -e "${YELLOW}Mirrors...${NC}"
        reflector -l 3 -c Russia --sort rate --save /etc/pacman.d/mirrorlist
}

function draw_menu {
    local items=("${!1}")
    local current=$2

    clear
    echo -e "\033[1mУправление: ↑/↓ - выбор, Enter - переключить, a - добавить, d - удалить, q - выход\033[0m"
    echo

    for i in "${!items[@]}"; do
        if [ $i -eq $current ]; then
            echo -e "   \033[1;32m› ${items[$i]}\033[0m"
        else
            echo "    ${items[$i]}"
        fi
    done
}

function prepare_items {
	local input_arr=("$@")
	local output_arr=()

	for item in "${input_arr[@]}"; do
		output_arr+=("[+] $item")
	done

        declare -p output_arr | sed "s/^declare -a output_arr=//"
}

function unprepare_items {
	local input_arr=("$@")
	local output_arr=()

	for item in "${input_arr[@]}"; do
		if [[ "$item" == "[+] "* ]]; then
			local name="${item:4}"
			output_arr+=("$name")
		fi
	done

	echo "${output_arr[@]}"
}

function packages {
    clear
    tput civis

    local current_selection=0
    local original_menu_items=(
        "base"
        "base-devel"
	"linux"
	"linux-firmware"
	"amd-ucode"
	"sudo"
	"vim"
	"bash-completion"
	"grub"
	"efibootmgr"
	"dhcpcd"
    )
	
    local menu_items
    eval "menu_items=$(prepare_items "${original_menu_items[@]}")"

    add_item() {
        echo -ne "\033[?25h"
        read -p "Введите текст нового пункта: " new_item
        echo -ne "\033[?25l"
        menu_items+=("[+] $new_item")
        current_selection=$((${#menu_items[@]}-1))
    }

    delete_item() {
        if [ ${#menu_items[@]} -gt 0 ]; then
            unset menu_items[$current_selection]
            menu_items=("${menu_items[@]}")
            [ $current_selection -ge ${#menu_items[@]} ] && current_selection=$((${#menu_items[@]}-1))
            [ $current_selection -lt 0 ] && current_selection=0
        fi
    }

    while true; do
        draw_menu menu_items[@] $current_selection

        IFS= read -rsn1 key
        [[ "$key" == $'\x1b' ]] && { read -rsn2 -t 0.1 key2; key+="$key2"; }

        case "$key" in
            $'\x1b[A') [ $current_selection -gt 0 ] && ((current_selection--)) ;;
            $'\x1b[B') [ $current_selection -lt $((${#menu_items[@]}-1)) ] && ((current_selection++)) ;;
            "")
                item="${menu_items[$current_selection]}"
                [[ "$item" == "[+]"* ]] && menu_items[$current_selection]="[-]${item:3}" || menu_items[$current_selection]="[+]${item:3}"
                ;;
            "a"|"A") add_item ;;
            "d"|"D") delete_item ;;
            "q"|"Q")
                tput cnorm
                clear
		local packages_str=$(unprepare_items "${menu_items[@]}")
		
		echo -e "${YELLOW}$packages_str${NC}"
		pacstrap -i /mnt "$packages_str"

                break
		;;
        esac
    done	
}

function exit_func {
    echo -e "${RED}Exit...${NC}"
    exit 0
}

while true; do
    clear
    show_header
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Execute with sudo!${NC}"
        exit 1
    fi

    echo -e "${GREEN}╭─────────────────────────╮${NC}"
    echo -e "${GREEN}│  1. Show part. layout   │${NC}"
    echo -e "${GREEN}│  2. Partition           │${NC}"
    echo -e "${GREEN}│  3. Formating           │${NC}"
    echo -e "${GREEN}│  4. Mounting            │${NC}"
    echo -e "${GREEN}│  5. Mirrors             │${NC}"
    echo -e "${GREEN}│  6. Packages            │${NC}"
    echo -e "${GREEN}│  0. Exit                │${NC}"
    echo -e "${GREEN}╰─────────────────────────╯${NC}"
    read -p "Enter choice [0-6]: " choice

    case $choice in
        1) show_partition_layout ;;
        2) partition ;;
        3) formating ;;
        4) mounting ;;
        5) mirrors ;;
        6) packages ;;
        0) exit_func ;;
        *) echo -e "${RED}❌ Error! Incorrect choice.${NC}" && sleep 1 ;;
    esac
    read -p "Press Enter to continue..."
done
                   
