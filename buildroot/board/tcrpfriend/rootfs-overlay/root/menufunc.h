#!/usr/bin/env bash

##### explanation ###################################################################################
# As you edit the cmdline of grub.cfg
# Edit /mnt/tcrp/user_config.json to modify cmdline used by TCRP FRIEND
#####################################################################################################

TMP_PATH=/tmp
USER_CONFIG_FILE="/mnt/tcrp/user_config.json"

###############################################################################
# Read json config file
function readConfigMenu() {

    USB_LINE=$(jq -r -e '.general.usb_line' "$USER_CONFIG_FILE")
    SATA_LINE=$(jq -r -e '.general.sata_line' "$USER_CONFIG_FILE")

    MODEL=$(jq -r -e '.general.model' "$USER_CONFIG_FILE")
    BUILD=$(jq -r -e '.general.version' "$USER_CONFIG_FILE" | cut -c 7-)
    SN=$(jq -r -e '.extra_cmdline.sn' "$USER_CONFIG_FILE")

    MACADDR1="$(jq -r -e '.extra_cmdline.mac1' $USER_CONFIG_FILE)"
    MACADDR2="$(jq -r -e '.extra_cmdline.mac2' $USER_CONFIG_FILE)"
    MACADDR3="$(jq -r -e '.extra_cmdline.mac3' $USER_CONFIG_FILE)"
    MACADDR4="$(jq -r -e '.extra_cmdline.mac4' $USER_CONFIG_FILE)"

    LAYOUT=$(jq -r -e '.general.layout' "$USER_CONFIG_FILE")
    KEYMAP=$(jq -r -e '.general.keymap' "$USER_CONFIG_FILE")

    DMPM=$(jq -r -e '.general.devmod' "$USER_CONFIG_FILE")
    LDRMODE=$(jq -r -e '.general.loadermode' "$USER_CONFIG_FILE")

}

###############################################################################
# Mounts backtitle dynamically
function backtitle() {
  BACKTITLE="TCRP 0.9.4.3-1"
  BACKTITLE+=" ${DMPM}"
  BACKTITLE+=" ${LDRMODE}"
  if [ -n "${MODEL}" ]; then
    BACKTITLE+=" ${MODEL}"
  else
    BACKTITLE+=" (no model)"
  fi
  if [ -n "${BUILD}" ]; then
    BACKTITLE+=" ${BUILD}"
  else
    BACKTITLE+=" (no build)"
  fi
  if [ -n "${SN}" ]; then
    BACKTITLE+=" ${SN}"
  else
    BACKTITLE+=" (no SN)"
  fi
  if [ "${MACADDR1}" == "null" ]; then
    BACKTITLE+=" (no MAC1)"  
  else
    BACKTITLE+=" ${MACADDR1}"
  fi
  if [ "${MACADDR2}" == "null" ]; then
    BACKTITLE+=" (no MAC2)"  
  else
    BACKTITLE+=" ${MACADDR2}"
  fi
  if [ "${MACADDR3}" == "null" ]; then
    BACKTITLE+=" (no MAC3)"  
  else
    BACKTITLE+=" ${MACADDR3}"
  fi
  if [ "${MACADDR4}" == "null" ]; then
    BACKTITLE+=" (no MAC4)"  
  else
    BACKTITLE+=" ${MACADDR4}"
  fi
  if [ -n "${KEYMAP}" ]; then
    BACKTITLE+=" (${LAYOUT}/${KEYMAP})"
  else
    BACKTITLE+=" (qwerty/us)"
  fi
  echo ${BACKTITLE}
}

###############################################################################
# Shows menu to user type one or generate randomly
function usbMenu() {
      while true; do
        dialog --backtitle "`backtitle`" \
          --inputbox "Edit USB Command Line " 0 0 "${USB_LINE}" \
          2>${TMP_PATH}/resp
        [ $? -ne 0 ] && return
        USB_LINE=`cat ${TMP_PATH}/resp`
        if [ -z "${USB_LINE}" ]; then
          return
        else
          break
        fi
      done
      
    json=$(jq --arg var "${USB_LINE}" '.general.usb_line = $var' $USER_CONFIG_FILE) && echo -E "${json}" | jq . >$USER_CONFIG_FILE

}

###############################################################################
# Shows menu to generate randomly or to get realmac
function sataMenu() {
      while true; do
        dialog --backtitle "`backtitle`" \
          --inputbox "Edit Sata Command Line" 0 0 "${SATA_LINE}" \
          2>${TMP_PATH}/resp
        [ $? -ne 0 ] && return
        SATA_LINE=`cat ${TMP_PATH}/resp`
        if [ -z "${SATA_LINE}" ]; then
          return
        else
          break
        fi
      done
      
    json=$(jq --arg var "${SATA_LINE}" '.general.sata_line = $var' $USER_CONFIG_FILE) && echo -E "${json}" | jq . >$USER_CONFIG_FILE      

}

function forcejunior() {
    clear
    initialize
    boot forcejunior
}

function bootmenu() {
    clear 
    initialize    
    boot
}

# Main function loop
function mainmenu() {
  
  readConfigMenu

  NEXT="m"
  while true; do

    echo "s \"Edit USB Line\""         > "${TMP_PATH}/menu"
    echo "a \"Edit SATA Line\""        >> "${TMP_PATH}/menu"
    echo "j \"Boot Force Junior\""     >> "${TMP_PATH}/menu"    
    echo "r \"continue boot\""         >> "${TMP_PATH}/menu"

    dialog --clear --default-item ${NEXT} --backtitle "`backtitle`" --colors \
      --menu "As you edit the cmdline of grub.cfg\nEdit /mnt/tcrp/user_config.json to modify cmdline used by TCRP FRIEND" 0 0 0 --file "${TMP_PATH}/menu" \
      2>${TMP_PATH}/resp
    [ $? -ne 0 ] && break
    case `<"${TMP_PATH}/resp"` in
      s) usbMenu;      NEXT="r" ;;
      a) sataMenu;     NEXT="r" ;;
      j) forcejunior ;;      
      r) bootmenu ;;
      e) break ;;
    esac
  done

}    
