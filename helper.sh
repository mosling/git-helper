#!/bin/bash

## define some colors
NOCOLOR='\e[0m'
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'

# requires a array of values 
# returns the selected index 1 .. $# 
# example:
# 
# menu=("One" "Two" "Three" "Exit")
# createmenu "${menu[@]}"
# SELIDX=$?
# IDX=$((SELIDX - 1 ))
#
# colorbanner $GREEN "Menu[$SELIDX]=${menu[$IDX]}"
createmenu ()
{
	array=("$@")
	length=${#array[@]}

	select option in "${array[@]}"
	do 
		if [ -n "$option" ]
		then
			return $REPLY
		fi

		for i in "${!array[@]}"
		do
			if [[ "${array[$i]}" = "$REPLY" ]]
			then
				return $((i +1))
			fi
		done

		echo -e "${RED}Incorrect Input:${GREEN} Select a number 1-${#array[@]} or type the value.${NOCOLOR}"
	done
}

banner() {
	msg="***      $*      ***"
	edge=$(echo "$msg" | sed 's/./\*/g')
	echo "$edge"
	echo "$msg"
	echo "$edge"
}

colorbanner() {
	echo -e $1
	banner "${@:2}"
	echo -e ${NOCOLOR}
}

installFile()
{
	if [ -z "$1" ] || [ -z "$2" ]
	then
		colorbanner ${RED} "installFile needs to parameter <file> <target directory>"
		exit 2
	fi

	if [ -f "$2/$1" ]
	then
		echo "overwrite $1 --> $2"
	else
		echo "  install $1 --> $2"
	fi

	cp $1 $2
}
