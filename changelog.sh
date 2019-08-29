## check if the app is available
which git-release-notes &>/dev/null
if [ "$?" -ne 0 ]; then
    echo "Can't find the application 'git-release-notes' ..."
    echo "Please checkout https://github.com/mosling/git-release-notes"
    echo "Install it using npm install"
    echo "Make ii accessible with npm link"
    exit 1
fi

## default parameters
BASEPATH=$(dirname $0)
SCRIPT=$BASEPATH/issues.js
TEMPLATE=$BASEPATH/git-changelog.ejs
HISTORY=$BASEPATH/changelog.history
RELTAG=
FROMTAG=
REPOPATH="."
OPTION="no-max-parents"
OUTFOLDER=${CHANGELOGFOLDER:-$HOME/development/changelog}
CLEANUP="no"
OVERLAP=3

usage() {
    if [ -n "$1" ]; then
        echo "-------------------------------------------------------------------------------------------------"
        echo "ERROR: $1"
    fi
    echo
    echo "Create changelog files for the given repository and release tag"
    echo
    echo "Usage: $0 -r <release-tag> [-i <'JSON-object'>] [-w <output-folder>] [-f <from-release-tag>]"
    echo "           [-o <option>] [-g <repository>] [-s <script> ] [-t <template>] [hc]"
    echo ""
    echo "   -r : existing release tag for the repository"
    echo "   -p : path to the git local git repository (default ${REPOPATH})"
    echo "   -f : existing release tag uses as since part for the revision range"
    echo "   -o : some additional options for the git log (e.g. -o min-parents=0 -o grep=W-123456) (default ${OPTION})"
    echo "   -i : some information used during template processing (default ${TMPLINFO})"
    echo "   -s : post processing string (default ${SCRIPT})"
    echo "   -t : template (default = ${TEMPLATE})"
    echo "   -w : write the generated output to this folder (default ${OUTFOLDER})"
    echo "   -c : cleanup output folder (i.e. rm -f <OUTFOLDER>/*) (default ${CLEANUP})"
    echo "   -g : repository type (github,bitbucket) to generate repository commit link"
    echo ""
    echo "Examples: "
    echo " changelog.sh -rHEAD -fam-1.9.1 -i'${TMPLINFO}' -w$HOME/development/changelog/am/am -p$HOME/development/dw/am/am"
    
    exit 1
}

checkObject() {
    OBJID=$1
    ## check if the given tag/commit exists
    git describe $OBJID &>/dev/null
    if [ "$?" -ne 0 ]; then
        echo -n "Can't found git tag '${OBJID}' -- check for commit"
        git log --abbrev-commit --oneline $OBJID &>/dev/null
        if [ "$?" -ne 0 ]; then
            echo " -- can't found -- exiting."
            echo "Here is a list of existing tags:"
            git tag | column
            exit 1
        else
            echo " -- found."
        fi
    fi
}

# this function corrects the very rare case where the describe function has an error
# warning: tag '1.9.1' is really 'foo-1.9.1' here
# in this case we use the real tag name 'foo-1.9.1'
correctFromTag() {
    if [[ "$FROMTAG" == warning:* ]]; then
        echo -n "found a mystic tag -- $FROMTAG"
        FROMTAG=$(echo $FROMTAG | sed -n -e "s/^warning.*is really '\([^']*\).*/\\1/p")
        echo " -- converted to -- $FROMTAG"
    fi
}

# This generates an index html containing all tags with its date
generateIndex() {
    echo "Generate Index for all tags .."
    
    ## html header
    IDXNAME="${OUTFOLDER}/index.html"
    echo '
<!DOCTYPE html>
<html lang="en">
	<head>
		<meta charset="utf-8">
		<meta http-equiv="X-UA-Compatible" content="IE=edge">
		<meta name="viewport" content="width=device-width, initial-scale=1">

		<title>Changelog Index</title>

		<!-- Latest compiled and minified CSS -->
		<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css"
	      	integrity="sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u" crossorigin="anonymous">
		<link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/v/bs/dt-1.10.13/datatables.min.css"/>
		<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/font-awesome/4.7.0/css/font-awesome.min.css">
	</head>
<body>
	<div class="container" role="main">
	<div class="row">
		<h1>Release Overview '$1'/'$2'</h1>
	</div>

	<div class="row">
		<table id="example" class="table table-bordered table-striped table-hover" cellspacing="0" width="100%">
        	<thead> <tr> <th>Date</th> <th>Changelog</th> </tr> </thead>
			<tfoot> <tr> <th>Date</th> <th>Changelog</th> </tr> </tfoot>
    <tbody>' >$IDXNAME
    
    ## generate link entries
    echo "<tr><td>$(date '+%Y-%m-%d %H:%M:%S')</td><td><a href='changelog-ALL.html'>Overall</a></td></tr>" >>$IDXNAME
    echo "<tr><td>$(date '+%Y-%m-%d %H:%M:%S')</td><td><a href='changelog-HEAD.html'>HEAD</a></td></tr>" >>$IDXNAME
    git log --date-order --tags --simplify-by-decoration --pretty="format:%ai,%D" | grep tag | sed -n -e "s/\([- 0-9:]*\) .*tag: \([^,]*\).*/<tr><td>\\1<\/td><td><a href='changelog-\\2.html'>\\2<\/a><\/td><\/tr>/p" >>$IDXNAME
    
    ## html footer
    echo '
			</tbody>
		</table>
	</div>
	</div>

	<script type="text/javascript"
	src="https://cdn.datatables.net/v/bs-3.3.7/jqc-1.12.4/dt-1.10.13/datatables.min.js"></script>
	<script>
		$(document).ready(function () {
		$("#example").DataTable({
			'iDisplayLength': 25,
			columnDefs: [
				{type: "date-euro", targets: 0}
			],
			"order": [[0, "desc"]]
		});
	});
	</script>
</body>
    </html>' >>$IDXNAME
}

generateCommitLog() {
    RELTAG=$1
    FROMTAG=$2
    
    ## generate filename f(-r, -f) before we change FROMTAG
    
    if [ "HEAD" == "$RELTAG" ] && [ "root" == "$FROMTAG" ]; then
        VER_FILENAME="ALL"
    else
        VER_FILENAME=$(echo $RELTAG | sed -e "s/\//_/")
    fi
    
    if [ -n "$FROMTAG" ]; then
        ## check if the given tag/commit exists
        if [ "root" == "$FROMTAG" ]; then
            echo "find root node for git repository .."
            FROMTAG=$(git log --abbrev-commit --max-parents=0 --pretty=format:%h) &>/dev/null
        fi
        checkObject $FROMTAG
    else
        ## check if there is an tag before the given tag
        FROMTAG=$(git describe --tags --always --abbrev=0 ${RELTAG}^ 2>&1)
        if [ "$?" -ne 0 ]; then
            echo -n "Can't found git tag before '${RELTAG}' -- use first commit"
            FROMTAG=$(git log --abbrev-commit --max-parents=0 --pretty=format:%h) &>/dev/null
            if [ "$?" -ne 0 ]; then
                echo " -- something wrong with the repository (?) -- not found."
                exit 1
            else
                echo " -- found $FROMTAG"
            fi
        fi
    fi
    
    correctFromTag
    
    if [ "$FROMTAG" == "$RELTAG" ]; then
        echo "Revision range with equal value = '$FROMTAG' -- stop process"
        break
    fi
    
    CHANGELOG_FILE=${OUTFOLDER}/changelog-${VER_FILENAME}.html
    
    if [ -f "$CHANGELOG_FILE" ]; then
        let OVERLAP=OVERLAP-1
        if [ $OVERLAP -eq 0 ]; then
            return 42
        fi
    fi
    
    echo "Create changelog for ${FROMTAG} .. ${RELTAG} ==>> ${CHANGELOG_FILE}"
    
    git-release-notes $OPTION -i "$TMPLINFO" -s $SCRIPT ${FROMTAG}..${RELTAG} $TEMPLATE >$CHANGELOG_FILE
    
    ## create a changelog for each work-item (i.e. ^FOO-4242 )
    WORKITEMS=$(git log ${FROMTAG}..${RELTAG} --format="%s" | sed -ne 's/\([A-Z]*-[0-9]\{1,\}\):.*/\1/p' | tr ',/' '\n' | sed -e 's/[^-A-Z0-9]//g' | sort -u -t\- -k1,1 -k2,2n)
    for wi in $WORKITEMS; do
        WORKFILE=${OUTFOLDER}/changelog-${wi}.html
        if [ ! -f $WORKFILE ]; then
            echo "${RELTAG} -- work item $wi"
            git-release-notes -o grep=${wi} -i "$TMPLINFO" -s $SCRIPT ${FROMTAG}..${RELTAG} $TEMPLATE >${OUTFOLDER}/changelog-${wi}.html
        fi
    done
    
}

readValue() {
    SUB=$1
    DEF=$2
    RES=""
    
    if [ "$BASH_VERSINFO" -ge 4 ]; then
        read -e -i "$DEF" -p "$SUB" RES
    else
        read -e -p "$SUB [$DEF]" INP
        RES=${INP:-DEF}
    fi
    
    echo $RES
}

## based on the remote repository URL for origin the parts to generate links later are created
getGitRepositoryParts() {
    parts=$(git remote get-url origin | tr '/' '\n')
    
    GIT_PROJECT_SEP=""
    FIRST_PART="true"
    TMPLREPO=""
    TMPLPRJ=""
    
    for part in $parts
    do
        if [[ "$part" =~ ^http.* ]] || [[ -z "${part}" ]]
        then
            continue
        fi
        
        # first part is the git url
        if [ "$FIRST_PART" = "true" ]
        then
            TMPLGITURL=$part
            FIRST_PART="false"
        else
            if [ -n "$TMPLREPO" ]
            then
                TMPLPRJ=${TMPLPRJ}${GIT_PROJECT_SEP}${TMPLREPO}
                GIT_PROJECT_SEP="/"
            fi
            TMPLREPO=$part
        fi
        
        cntPart=$((cntPart + 1))
    done
    
    TMPLREPO=$(echo $TMPLREPO | sed -e "s!\.git!!")
    
    # suggest the first part of the url is used as git system type
    TMPLGIT=$(echo $TMPLGITURL | cut -d'.' -f1)
}

if [ $# -eq 0 ]; then
    echo "no options given .. start interview mode"
    RELTAG=$(readValue "Changelog for tag (leave empty for all)   : " "")
    if [ -n "$RELTAG" ]; then
        FROMTAG=$(readValue "Changelog from tag (leave empty for previous) : ")
    fi
    TMPLROWHL="Merge branch"
    getGitRepositoryParts
    
    TMPLGIT=$(readValue "Repository Type                           : " "$TMPLGIT")
    TMPLGITURL=$(readValue "Repository Address                        : " "$TMPLGITURL")
    TMPLPRJ=$(readValue "Project Name                              : " "$TMPLPRJ")
    TMPLREPO=$(readValue "Repository Name                           : " "$TMPLREPO")
    TMPLROWHL=$(readValue "Substring to highlight a row              : " "$TMPLROWHL")
    OUTFOLDER=$OUTFOLDER/$TMPLPRJ/$TMPLREPO
    OUTFOLDER=$(readValue "Output folder                             : " "$OUTFOLDER")
    OPTION=$(readValue "Options for git log                       : " "$OPTION")
    CLEANUP=$(readValue "Remove existing changelogs?               : " "no")
    
    TMPLINFO='{ "project":"'$TMPLPRJ'", "repo":"'$TMPLREPO'", "rowHl": "'$TMPLROWHL'", "gittype":"'$TMPLGIT'", "giturl":"'$TMPLGITURL'" }'
    COPT=""
    ROPT=""
    if [ "yes" == "$CLEANUP" ]; then
        COPT="-c"
    fi
    if [ -n "$RELTAG" ]; then
        ROPT=" -r $RELTAG"
    fi
    if [ -n "$FROMTAG" ]; then
        FOPT=" -f $FROMTAG"
    fi
    if [ -n "$OPTION" ]; then
        OOPT=" -o $OPTION"
    fi
    echo "next time you can use the following command line:"
    echo "-------------------------------------------------"
    echo "changelog.sh${ROPT}${FOPT}${OOPT} -i'$TMPLINFO' -w$OUTFOLDER $COPT"
    echo "-------------------------------------------------"
else
    while getopts ":r:f:o:w:i:p:s:t:hac" opt; do
        case $opt in
            r)
                RELTAG=$OPTARG
            ;;
            f)
                FROMTAG=$OPTARG
            ;;
            o)
                OPTION=$OPTARG
            ;;
            p)
                REPOPATH=$OPTARG
            ;;
            i)
                TMPLINFO=$OPTARG
            ;;
            h)
                usage
            ;;
            s)
                SCRIPT=$OPTARG
            ;;
            t)
                TEMPLATE=$OPTARG
            ;;
            w)
                OUTFOLDER=$OPTARG
            ;;
            c)
                CLEANUP="yes"
            ;;
            \?)
                usage "Invalid option -$OPTARG"
            ;;
        esac
    done
fi

OPTION=$(echo $OPTION | sed -e "s/ / -o /g")
OPTION="-o $OPTION"

echo "Switch to repository path '${REPOPATH}' .."
cd $REPOPATH

## check if the given tag/commit exists
checkObject $RELTAG

echo "Options to generate changelog files"
echo "-----------------------------------"
echo "basepath        : $BASEPATH"
echo "script          : $SCRIPT"
echo "template        : $TEMPLATE"
if [ -z "$RELTAG" ]; then
    echo "release tag     : changelog for all tags"
else
    echo "release tag     : $RELTAG"
fi
echo "previous tag    : $FROMTAG"
echo "repository path : $REPOPATH"
echo "options         : $OPTION"
echo "template info   : $TMPLINFO"
echo "output folder   : $OUTFOLDER"
if [ "yes" == "$CLEANUP" ]; then
    echo "cleanup folder  : ${OUTFOLDER}"
else
    echo "cleanup folder  : nothing removed"
fi
echo "-----------------------------------"
echo ""

if [ ! -d "${OUTFOLDER}" ]; then
    echo "Creating missing output folder ${OUTFOLDER}"
    mkdir -p $OUTFOLDER
fi

if [ "yes" == "$CLEANUP" ]; then
    rm -f ${OUTFOLDER}/changelog-* index.html
fi

if [ -z "$RELTAG" ]; then
    if [ -n "$FROMTAG" ]; then
        echo ".. ignore from '$FROMTAG'"
    fi
    TAGS=$(git tag --sort=-creatordate)
    for t in $TAGS; do
        generateCommitLog $t ""
        RES=$?
        if [ 42 -eq "$RES" ]; then
            echo " ... stop generating at $t, run into existing changelogs"
            break
        fi
    done
    echo ""
    
    echo "Generate overall changelog file .."
    generateCommitLog HEAD root
    echo ""
    
    echo "Generate HEAD changelog .."
    generateCommitLog HEAD ""
    echo ""
else
    generateCommitLog $RELTAG $FROMTAG
    echo ""
fi

generateIndex "$TMPLPRJ" "$TMPLREPO"
echo "Ready."
