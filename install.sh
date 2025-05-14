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
}

function exit_func {
    echo -e "${RED}Выход...${NC}"
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
    echo -e "${GREEN}│  0. Exit                │${NC}"
    echo -e "${GREEN}╰─────────────────────────╯${NC}"
    read -p "Enter choice [0-3]: " choice

    case $choice in
        1) show_partition_layout ;;
        2) partition ;;
        3) formating ;;
        0) exit_func ;;
        *) echo -e "${RED}❌ Error! Incorrect choice.${NC}" && sleep 1 ;;
    esac
    read -p "Press Enter to continue..."
done
