#!/bin/bash

BASEDIR=$(dirname "$0")
source "${BASEDIR}/helper.sh"

OLDBIN=$(which changelog.sh 2>/dev/null)
if [ "$?" == 1 ]
then
    if [ -z "$1" ]
    then
        read -p "Please enter installation directory --> " INSTALLDIR
    else
        INSTALLDIR="$1"
    fi
else
    INSTALLDIR=$(dirname $OLDBIN)
fi

colorbanner ${GREEN} "Install into directory $INSTALLDIR"

installFile $BASEDIR/helper.sh $INSTALLDIR
installFile $BASEDIR/changelog.sh $INSTALLDIR
installFile $BASEDIR/git-changelog.ejs $INSTALLDIR
installFile $BASEDIR/issues.js $INSTALLDIR
