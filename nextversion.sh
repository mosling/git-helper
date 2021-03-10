#!/bin/bash

BASEDIR=$(dirname "$0")
# shellcheck source=./helper.sh
source "${BASEDIR}/helper.sh"
MODE=remote
isRelease=false
CHECKMARK="${GREEN}\u2713${NOCOLOR}"

updateRemoteBranch() {
    if [[ $# -ne 2 ]]; then
        colorbanner "${RED}" "function updateRemoteBranch need two parameter"
        exit 2
    fi

    colorbanner "${GREEN}" "$2"
    git checkout "$1" --recurse-submodules
    git push
}

if [[ "local" == "$1" ]]; then
    MODE=local
    colorbanner "${GREEN}" "Local Mode -- no remote connection used."
elif [[ $# -ne 0 ]]; then
    colorbanner "${RED}" "Please start with $0 [local] and follow the interview."
    exit 2
else
    colorbanner "${GREEN}" "Create new Release from Develop Branch"
fi

git status >/dev/null
if [ "$?" == 128 ]; then
    colorbanner "${RED}" "The current directory isn't part of a git repository --> stop."
    exit 2
else
    echo "preconditions:"
    echo -e "  ${CHECKMARK} git repository"
fi

git flow config >/dev/null 2>&1
if [ "$?" == 1 ]; then
    colorbanner "${RED}" "The repository must have git flow initialized, please call 'git flow init'."
    exit 2
else
    echo -e "  ${CHECKMARK} git flow activated"
fi

if [[ -f .gitmodules ]]; then
    echo -e "  ${CHECKMARK} project has submodules"
fi

if [[ -n $(git status -s) ]]; then
    colorbanner "${RED}" "The branch has changes not on stage."
    exit 2
else
    echo -e "  ${CHECKMARK} all changes staged"
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" =~ ^release/.* ]]; then
    NEXT_VERSION=$(echo "${CURRENT_BRANCH}" | sed -n -e 's/release\///p')
    isRelease=true
    echo -e "  ${CHECKMARK} continue with release branch $NEXT_VERSION"
elif [ "$CURRENT_BRANCH" != "develop" ]; then
    colorbanner "${RED}" "You must at branch develop to start a release --> stop."
    exit 2
else
    echo -e "  ${CHECKMARK} on develop branch"
fi

if [ "remote" == "${MODE}" ]; then
    if [[ "false" == "$isRelease" ]]; then
        ## check for not pushed changes for develop branch only
        ahead=$(git log --oneline origin/develop..HEAD | wc -l)
        if [ "$ahead" -gt 0 ]; then
            colorbanner "${RED}" "Your branch is ahead of 'origin/develop' by ${ahead} commit(s). --> stop."
            exit 2
        else
            echo -e "  ${CHECKMARK} all commits pushed"
        fi
    fi


    if ! git pull >/dev/null 2>&1; then
        if [[ "true" == "$isRelease" ]]; then
            echo -e "  ${CHECKMARK} assume continue at local release branch"
        else
            remoteUrl=$(git remote get-url --push origin)
            colorbanner "${RED}" " Can't connect repository at '${remoteUrl}' --> stop."
            exit 2
        fi
    else
        echo -e "  ${CHECKMARK} remote connection exists"
    fi
fi

if [[ "false" == "$isRelease" ]]; then
    VERSION=$(git describe 2> /dev/null)
    if [[ -z "$VERSION" ]]; then
        colorbanner "${BLUE}" " Can't find annotated tag --> search for normal tag"
        VERSION=$(git describe --tags 2> /dev/null)
        if [[ -z "$VERSION" ]]; then
            colorbanner "${BLUE}" " Can't find any tag in the repository --> use 0.0.0"
            VERSION="0.0.0-0-g123456"
        fi
    fi

    echo -e "current version is: ${GREEN}$VERSION${NOCOLOR}"
    # shellcheck disable=SC2001
    V=$(echo $VERSION | sed -e 's/-.*//')

    IFS='.' read -r -a varr <<<"$V"

    declare -a nv
    idx=0
    l=${#varr[@]}
    echo "please select the next release number for the application:"
    cv=""
    for element in "${varr[@]}"; do
        nn=$((element + 1))

        ## adding optional dot
        if [ -n "$cv" ]; then
            cv=$cv.
        fi

        ## adding the value
        vv=$cv$nn

        ## adding .0 for following version parts
        for ((i = 1; i < l; i++)); do
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
    nv[$idx]="stop"

    createmenu "${nv[@]}"
    NEXT_VERSION=${nv[$(($? - 1))]}

    if [ "input" == "$NEXT_VERSION" ]; then
        read -rp "set next version to --> " NEXT_VERSION
    fi
fi

if [ "stop" != "$NEXT_VERSION" -a "" != "$NEXTVERSION" ]; then
    if [ "false" == ${isRelease} ]; then
        colorbanner "${GREEN}" "Start Release"
        git flow release start "$NEXT_VERSION"
    fi

    read -rp "Finish the Release [y/N] " finish
    finish=${finish:-N}

    if [ "y" == "$finish" ]; then
        SIGN_KEY=$(git config user.signingkey)

        if [ -n "$SIGN_KEY" ]; then
            colorbanner "${GREEN}" "Finish Release (with signature)"
            git flow release finish --sign "$NEXT_VERSION"
        else
            colorbanner "${GREEN}" "Finish Release (without signature)"
            git flow release finish "$NEXT_VERSION"
        fi

        if [ "remote" == "${MODE}" ]; then
            updateRemoteBranch master "Publish Master with the Release Version"
            updateRemoteBranch develop "Switch Back to Develop Branch and Publish"
        fi
    elif [ "remote" == "${MODE}" ]; then
        read -rp "Publish the Release Branch [y/N] " publishRelease
        publishRelease=${publishRelease:-N}

        if [ "y" == "$publishRelease" ]; then
            git flow release publish
        fi
    fi
else
	if [ "stop" == "$NEXT_VERSION" ]; then
		colorbanner "${GREEN}" "Stopped by the User"
	else
		colorbanner "${RED}" "Missing Value for the Next Release."
	fi
fi

