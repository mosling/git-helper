#!/bin/bash

BASEDIR=$(dirname "$0")
source "${BASEDIR}/helper.sh"

## git url without slash at the end
GITLABURL="https://gitlab.com/jat-gmbh"
AUTHORS=${BASEDIR}/authors.txt
TMPAUTHORS=/tmp/cvs-authors.txt

## check if we not in the git-script-collection directory
ISGIT=$(find . -maxdepth 1 -type d -name '.git' | wc -l)
if [ "$ISGIT" -gt 0 ]
then
	echo -e "${RED} found a ${GREEN}.git${RED} directory please ${BLUE}restart from another directory${NOCOLOR}"
	exit 1
fi

## check if CVSROOT is set
if [ -z "$CVSROOT" ]; then
	echo -e "${RED}Please set environment variable ${GREEN}CVSROOT${RED} and restart.${NOCOLOR}"
	exit 1
fi	

colorbanner ${GREEN} "Convert existing CVS Module to a Git Repository"
echo -e "${BLUE}Using CVSROOT=${GREEN}'$CVSROOT'${NOCOLOR}"

## ask the repository
read -p 'Module Name: ' CVSREPOSITORY
if [ -d "$CVSREPOSITORY" ]
then
	echo -e "${BLUE}Find existing directory for ${GREEN}$CVSREPOSITORY${BLUE} (remove it to restart the process).${NOCOLOR}"
else
	echo -e "${BLUE}Checkout Repository ${GREEN}$CVSREPOSITORY${BLUE} ...${NOCOLOR}"
	cvs -Q checkout "$CVSREPOSITORY"
	if [[ $? != 0 ]]
	then
		colorbanner ${RED} "CVS Repository '$CVSREPOSITORY' not found"
		exit 1
	fi
fi

## check if all authors are replaced by their email
echo -e "${BLUE}switch to repository directory ${GREEN}$CVSREPOSITORY${NOCOLOR}"
cd "$CVSREPOSITORY"
cvs log -N 2>&1 | grep author | awk '{ print $6 }' | sort | uniq | sed -e "s/;/=/" > /tmp/cvs-authors.txt

MISSING_AUTHOR=0
for a in $(cat $TMPAUTHORS); do
	grep $a $AUTHORS >/dev/null
	if [ 0 != $? ]
	then
		echo -e "${RED}Missing Entry $a${NOCOLOR}"
		MISSING_AUTHOR=1
	fi
done

if [ 1 = $MISSING_AUTHOR ]
then
	echo -e "${RED}Please add the unknown authors to ${BLUE}$AUTHORS${NOCOLOR}"
	exit 1
fi

## Find the module to convert
echo -e "${BLUE}The following modules were found; select one:${NOCOLOR}"

# Create a list of modules and ask the user
LIST=$(cvs ls -e | sed -n -e '/^D/s!^D!!p' | sed -e 's!/!!g')
OIFS="$IFS"
IFS='
'
menu=($LIST)
menu=( "${menu[@]}" "migrate-all" )
IFS="$OIFS"
createmenu ${menu[@]} "stop"
SELIDX=$?
CVSMODULE=${menu[$((SELIDX - 1))]}

if [ -n "$CVSMODULE" ]
then
	read -p "Select a branch to migrate -- [y/N]: " WITHBRANCH
	WITHBRANCH=${WITHBRANCH:-N}
	CVSBRANCH=
	if [ "$WITHBRANCH" == "y" ]
	then
		# Create a list of branches and ask the user
		echo -e "${BLUE}Collect branches, this takes a while ... ${NOCOLOR}"
		LIST=$(cvs log -h 2>&1 | awk -F"[.:]" '/^\t/&&$(NF-1)==0{print $1}' | awk '{print $1}' | sort -u)
		OIFS="$IFS"
IFS='
'
		menu=($LIST)
		IFS="$OIFS"
		createmenu ${menu[@]} "migrate all-branches"
		SELIDX=$?
		CVSBRANCH=${menu[$((SELIDX - 1))]}
	fi

	ADDMODULEFILES="N"
	CVSFOLDER=$CVSREPOSITORY
	if [ "migrate-all" != "$CVSMODULE" ]
	then
		MODULEFILES=$(find -maxdepth 1 -type f -name "${CVSMODULE}*")
		if [[ -n "$MODULEFILES" ]]
		then
			echo -e "${BLUE}Found files with the same base name as the CVSModule"
			echo -e "${GREEN}$MODULEFILES${NOCOLOR}"
			read -p "Adding this files to repository after conversion -- [y/N]: " ADDMODULEFILES
			ADDMODULEFILES=${ADDMODULEFILES:-N}
		fi

		echo -e "${BLUE}switch to module directory ${GREEN}$CVSMODULE${NOCOLOR}"
		cd "$CVSMODULE" || exit 2
		CVSFOLDER="$CVSREPOSITORY/$CVSMODULE"
	else
		echo -e "${BLUE}Migrate repository will ${RED}fail${BLUE} under some circumstances.${NOCOLOR}" 
		echo -e "${BLUE}Especially if a module has the same name as the repository.${NOCOLOR}"
	fi

	if [ -d .git ] 
	then
		echo -e "${BLUE}Remove existing ${GREEN}.git${BLUE} directory ...${NOCOLOR}"
		rm -rf .git
	fi

	colorbanner ${GREEN} "Start migration for $CVSFOLDER ... please be patient"
	git -c i18n.commitencoding=windows-1252 cvsimport -p "-v" -o master -r origin -a -k -A ${AUTHORS}
	if [ $? != 0 ]
	then
		echo -e "${RED}Error migrating cvs module $CVSFOLDER (return code $?)${NOCOLOR}"
		exit 2
	fi
	
	colorbanner ${GREEN} "Ready ... add git information"
	OK="N"
	while [ "$OK" != "y" ]
	do
		read -e -p "GitLab Repository Name: " -i "$GITREPOSITORY" GITREPOSITORY
		
		if [[ ! "$GITREPOSITORY" =~ ^\/.* ]]
		then
    		GITREPOSITORY="/$GITREPOSITORY"
		fi

		if [[ ! "$GITREPOSITORY" =~ .*.git$ ]]
		then
    		GITREPOSITORY="$GITREPOSITORY.git"
		fi

		GITURL=$GITLABURL$GITREPOSITORY
		read -p "URL is $GITURL -- [y/N]: " OK
		OK=${OK:-N}
	done

	echo -e "${BLUE}Set origin remote url to ${GREEN}$GITURL${NOCOLOR}" 
	git remote add origin "$GITURL"
	echo -e "${BLUE}Remove all the untracked files in your working directory${NOCOLOR}"
	git clean -f -d

	if [[ "$ADDMODULEFILES" =~ [yY] ]]
	then
		echo -e "${BLUE}Adding cvs root directory files${NOCOLOR}"
		cd ..
		cp $MODULEFILES "$CVSMODULE"
		cd "$CVSMODULE"
		git add $MODULEFILES
		git commit -m "adding module files from CVS directory"
	fi

	echo -e "Checkout all branches to prepare git push.${NOCOLOR}"
	## Für alle zu übertragenden Branches git checkout aufrufen
	git branch -a | sed -n -e 's!remotes/origin/\([^ ]*\)$!\1!p' | xargs -n1 git checkout

	echo -e "${BLUE}Finish the process with: ${NOCOLOR}"
	echo -e "${GREEN}cd $CVSFOLDER"
	echo -e "${GREEN}git push --all${NOCOLOR}"
	echo -e "${GREEN}git push --tags${NOCOLOR}"
else
	echo -e "${BLUE}no modules selected ... do nothing.${NOCOLOR}"
fi

