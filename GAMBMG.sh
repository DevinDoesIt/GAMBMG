#!/bin/bash

set -euo pipefail

# Default path to GAM. Update if different on your system
GAM_CMD="gam"
DOMAIN="burningman.org"

usage() {
  cat <<USAGE
Usage: gambmg [-group name] [-typeName alias|announce|discussion] [-owner email] \
              [-mailPref allmail|nomail] [-dept department] [-Force y|n] \
              [-TestMode y|n]
Run without arguments for interactive mode.
USAGE
}

about() {
  cat <<ABOUT
GAMBMG_V2 ported to bash - $(date +%m/%d/%Y)
This script automates creation of Google Groups using GAM.
Template Groups are required to provide settings for the new group.
ABOUT
}

# Helpers
to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

Test_Exists() {
  local email="$1"
  local mode="${2:-}"
  if [[ $mode == group ]]; then
    "$GAM_CMD" info group "$email" >/dev/null 2>&1 && return 0 || return 1
  fi
  if "$GAM_CMD" whatis "$email" 2>&1 | grep -Eq "Service not applicable|Entity does not exist"; then
    return 1
  fi
  return 0
}

Show_Group_Summary() {
  local groupName="$1"
  local block=""
  echo -e "\n=== GROUP SUMMARY ==="
  "$GAM_CMD" whatis "$groupName" 2>&1 | while IFS= read -r line; do
    trimmed="${line##*( )}"
    if [[ $trimmed =~ ^Group: ]] || [[ $trimmed =~ ^Total\ Members\ in\ Group: ]]; then
      echo "$trimmed"
    elif [[ $trimmed =~ ^(id|name|description|customFooterText): ]]; then
      echo "    $trimmed"
    elif [[ $trimmed == "Group Settings:" ]]; then
      echo "  Group Settings:"
    elif [[ $trimmed == Non-Editable\ Aliases:* ]]; then
      echo "  Non-Editable Aliases:${trimmed#Non-Editable Aliases:}"
      block="aliases"
    elif [[ $trimmed == Members:* ]]; then
      echo "  Members:${trimmed#Members:}"
      block="members"
    elif [[ $block == aliases && $trimmed =~ ^alias: ]]; then
      echo "    $trimmed"
    elif [[ $block == members && $trimmed =~ ^(owner|manager|member): ]]; then
      echo "    $trimmed"
    elif [[ -z $trimmed ]]; then
      block=""
    fi
  done
  echo "======================"
}

Get_Template() {
  case "$(to_lower "$1")" in
    a* ) echo "aliastemplate@$DOMAIN alias";;
    an* ) echo "announcetemplate@$DOMAIN announce";;
    d* ) echo "discussiontemplate@$DOMAIN discussion";;
    * ) return 1;;
  esac
}

# Parse args
GROUP=""; TYPE=""; OWNER=""; MAILPREF=""; DEPT=""; FORCE="n"; TESTMODE="n"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -group) GROUP="$2"; shift 2;;
    -typeName) TYPE="$2"; shift 2;;
    -owner) OWNER="$2"; shift 2;;
    -mailPref) MAILPREF="$2"; shift 2;;
    -dept) DEPT="$2"; shift 2;;
    -Force) FORCE="$2"; shift 2;;
    -TestMode) TESTMODE="$2"; shift 2;;
    about) about; exit 0;;
    help|-h|--help) usage; exit 0;;
    *) usage; exit 1;;
  esac
done

SHOULD_FORCE=false
[[ $(to_lower "$FORCE") == y* ]] && SHOULD_FORCE=true
SHOULD_TEST=false
[[ $(to_lower "$TESTMODE") == y* ]] && SHOULD_TEST=true

# Interactive prompts for missing args
if [[ -z $GROUP ]]; then
  while :; do
    read -p "Enter the group email: " GROUP
    GROUP=${GROUP%%@*}
    if Test_Exists "$GROUP@$DOMAIN" group; then
      echo "Group already exists. Try a new address."; Show_Group_Summary "$GROUP@$DOMAIN"; GROUP="";
    else
      break
    fi
  done
else
  GROUP=${GROUP%%@*}
  if Test_Exists "$GROUP@$DOMAIN" group; then
    echo "CRITICAL ERROR: Group already exists." >&2
    exit 1
  fi
fi

if [[ -z $TYPE ]]; then
  while :; do
    read -p "Enter the group type (alias, discussion, announce): " input
    if result=$(Get_Template "$input" 2>/dev/null); then
      TEMPLATE=${result%% *}; TYPE=${result##* };
      break
    else
      echo "Please enter a valid group type.";
    fi
  done
else
  if result=$(Get_Template "$TYPE" 2>/dev/null); then
    TEMPLATE=${result%% *}; TYPE=${result##* };
  else
    echo "CRITICAL ERROR: Invalid group type." >&2
    exit 1
  fi
fi

if [[ -z $OWNER ]]; then
  while :; do
    read -p "Enter the owner email: " OWNER
    OWNER=${OWNER%%@*}
    if Test_Exists "$OWNER"; then
      break
    else
      echo "Owner not found. Try again."; OWNER="";
    fi
  done
else
  OWNER=${OWNER%%@*}
  if ! Test_Exists "$OWNER"; then
    echo "CRITICAL ERROR: Owner email provided does not exist." >&2
    exit 1
  fi
fi

if [[ -z $MAILPREF ]]; then
  while :; do
    read -p "Should the owner receive mail from the group? [y/n] " resp
    case $(to_lower "$resp") in
      y*) MAILPREF="allmail"; break;;
      n*) MAILPREF="nomail"; break;;
      *) echo "Please enter 'y' or 'n'.";;
    esac
  done
fi

if [[ -z $DEPT ]]; then
  read -p "Enter the department: " DEPT
fi

DESC="This Group is managed by Burning Man for $DEPT"

echo -e "\n=== GROUP SETTING PREVIEW ==="
echo "Group:      $GROUP"
echo "Type:       $TYPE"
echo "Owner:      $OWNER ($MAILPREF)"
echo "Template:   $TEMPLATE"
echo "Department: $DEPT"
if $SHOULD_TEST; then
  echo "NOTE: This is a DRY RUN. No changes will be made."
else
  echo "SYSTEM READY, CONFIRM DEPLOYMENT"
fi
echo "============================="

if ! $SHOULD_FORCE; then
  while :; do
    read -p "DEPLOY AS PREVIEWED? [y/n] " conf
    case $(to_lower "$conf") in
      y*) break;;
      n*) echo "Abort command received. No changes made."; exit 0;;
      *) echo "Please enter 'y' or 'n'.";;
    esac
  done
else
  echo "AUTHORIZATION PRE-APPROVED. Skipping confirmation prompt."
fi

if ! $SHOULD_TEST; then
  echo "Creating group..."
  "$GAM_CMD" create group "$GROUP" copyfrom "$TEMPLATE" name "$GROUP $TYPE Group" description "$DESC"
  sleep 3
  "$GAM_CMD" update group "$GROUP" add owner "$MAILPREF" user "$OWNER"
  if Test_Exists "$GROUP@$DOMAIN" group; then
    echo -e "\nGroup creation successful"
    done=false
    while ! $done; do
      read -p $'\nAdd additional users? [Y] Member / [O] Owner / [M] Manager / [N] No: ' opt
      role=""
      case $(to_lower "$opt") in
        y*) role="member";;
        o*) role="owner";;
        m*) role="manager";;
        n*) echo "No additional users added."; done=true;;
        *) echo "Invalid option. Please enter Y, O, M, or N.";;
      esac
      if [[ -n $role ]]; then
        read -p "Enter email address to add as $role: " newUser
        newUser=${newUser%%@*}
        if Test_Exists "$newUser"; then
          echo "Adding $newUser as $role..."
          "$GAM_CMD" update group "$GROUP" add "$role" user "$newUser"
          echo "$newUser added as $role."
        else
          if [[ $newUser != *@* ]]; then
            echo "ERROR: User not found and input does not contain '@'. Please try again." >&2
          else
            echo "ERROR: User '$newUser' does not exist. Please try again." >&2
          fi
        fi
      fi
    done
    Show_Group_Summary "$GROUP@$DOMAIN"
  else
    echo -e "\nERROR: Group creation failed." >&2
  fi
else
  echo -e "\nDRY RUN: No changes were made."
fi
