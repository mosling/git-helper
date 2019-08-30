#!/bin/bash

createmenu ()
{
    select option
    do
        if [ "$REPLY" -eq "$#" ];
        then
            echo "Exiting..."
            break;
        elif [ 1 -le "$REPLY" ] && [ "$REPLY" -le $(($#-1)) ];
        then
            NEXTVERSION=$option
            break;
        else
            echo "Incorrect Input: Select a number 1-$#"
        fi
    done
}

banner() {
    msg="***      $*      ***"
    edge=$(echo "$msg" | sed 's/./\*/g')
    echo "$edge"
    echo "$msg"
    echo "$edge"
}

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "develop" ]
then
    tput setaf 1
    banner "You must at branch develop to start a release --> stop."
    exit 2
fi

VERSION=$(git describe)

echo "current version is: $VERSION"
V=`echo $VERSION | sed -e 's/-.*//'`

IFS='.' read -r -a varr <<< "$V"

declare -a nv
idx=0
l=${#varr[@]}
echo "found $l parts"
cv=""
for element in "${varr[@]}"
do
    nn=$((element + 1))

    ## adding optional dot
    if [ ! -z "$cv" ]
    then
        cv=$cv.
    fi

    ## adding the value
    vv=$cv$nn

    ## adding .0 for following version parts
    for ((i=1;i<$l;i++))
    do
        vv="$vv.0"
    done

    ## store result
    nv[$idx]=$vv

    ## set values for the next round
    l=$((l - 1))
    cv=$cv$element
    idx=$((idx + 1))
done
nv[$idx]="input"
idx=$((idx + 1))
nv[$idx]="none"

NEXTVERSION=none
createmenu "${nv[@]}"

if [ "input" == "$NEXTVERSION" ]
then
    echo "Attention, manual version setting!"
    read NEXTVERSION
    if [ -z "$NEXTVERSION" ]
    then
        banner "no version given --> stop"
        exit 1
    fi
fi

if [ "none" != "$NEXTVERSION" ]
then
    banner "Start Release"
    git flow release start $NEXTVERSION

    read -p "Finish the Release [y/N] " finish
    finish=${finish:-N}

    if [ "y" == "$finish" ]
    then
        SIGN=$( git config --global --list | grep 'user.signingkey' | wc -l )
        if [ "$SIGN" = "1" ]
        then
            banner "Finish Release (with signature)"
            git flow release finish -Ss $NEXTVERSION
        else
            banner "Finish Release"
            git flow release finish $NEXTVERSION
        fi

        banner "Publish Master with the Release Version"
        git checkout master
        git push

        banner "Switch Back to Develop Branch and publish"
        git checkout develop
        git push
    fi
fi

