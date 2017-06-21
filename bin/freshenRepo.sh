#!/bin/bash

set -o pipefail

BOILERMAKER_ARGS="$@"

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd "$PWD" ; cd `dirname "$0"` ; echo "$PWD")

cd "$SCRIPT_DIR/.."
source bin/common-include.sh

REPO_LIST=()
BRANCH=master
DEFAULT_REPO_ROOT="$PWD/.."
REPO_ROOT="$DEFAULT_REPO_ROOT"
REPO_DECL_FILE="$PWD/repos"
SKELETON_TYPE=framework

while [[ $1 ]]; do
	case $1 in
	--repo|-r)
 		while [[ $2 ]]; do
 			case $2 in
 			-*)
 				break
 				;;
 				
 			*)
		 		REPO_FLAG=1
				REPO_LIST+=($2)
				shift
				;;	
 			esac
 		done
 		;;
 		
	--root)
		if [[ $2 ]]; then
 			REPO_ROOT=$2
 			shift
 		fi
		;;

	--decl)
 		while [[ $2 ]]; do
 			case $2 in
 			-*)
 				break
 				;;
 				
 			*)
				REPO_DECL_FILE="$2"
		 		shift
				;;	
 			esac
 		done
		;;

	--type|-t)
		while [[ $2 ]]; do
 			case $2 in
 			-*)
 				break
 				;;
 				
 			*)
				SKELETON_TYPE="$2"
		 		shift
				;;	
 			esac
 		done
 		;;

 	--all|-a)
		ALL_REPOS_FLAG=1
		;;

	--force|-f)
		FORCE_MODE=1
		;;
	
	--branch|-b)
		if [[ $2 ]]; then
 			BRANCH=$2
 			shift
 		fi
 		;;
	
	--help|-h|-\?)
		SHOW_HELP=1
		;;
	esac
	shift
done

export REPO_ROOT

if [[ $REPO_FLAG != 1 && $ALL_REPOS_FLAG != 1 ]]; then
	echo "- Must specify repos to freshen using --repo <repo-list> or --all"
	echo
	echo "HELP:"
	echo
	SHOW_HELP=1
fi

if [[ $SHOW_HELP == 1 ]]; then
	echo "$SCRIPT_NAME"
	echo
	printf "\tFreshens the files in a repo.\n"
	echo
	echo "Usage:"
	echo
	printf "\t$SCRIPT_NAME ( --repo <repo-list>] | --all )\n"
	echo
	printf "\tThe script either accepts a list of one or more repos, or a\n"
	printf "\tflag indicating that all repos should be freshened.\n"
	echo
	echo "Where:"
	echo
	printf "\t<repo-list> is a space-separated list of one or more Cleanroom\n"
	printf "\tProject repos that must be provided when the --repo (or -r) option\n"
	printf "\tis specified. Acceptable values include:\n"
	echo
	printf "\t\t%s\n" ${CLEANROOM_REPOS[@]}
	echo
	printf "\tIf --all (or -a) is specified, the script attempts to freshen all\n"
	printf "\trepos listed above.\n"
	echo
	exit 1
fi

if [[ $ALL_REPOS_FLAG == 1 ]]; then
	REPO_LIST=${CLEANROOM_REPOS[@]}
fi

if [[ $FORCE_MODE ]]; then
	CP_ARGS="f"
else
	CP_ARGS="i"
fi

processBoilerplateFile()
{
	pushd "$SCRIPT_DIR" > /dev/null

	executeCommand "./boilermaker.sh $BOILERMAKER_ARGS --type $SKELETON_TYPE --file \"$1\""

	popd > /dev/null
}

COPY_ARGS=""
if [[ $FORCE_MODE ]]; then
	COPY_ARGS="--force $COPY_ARGS"
fi
if [[ ${#REPO_LIST[@]} ]]; then
	COPY_ARGS="--repo ${REPO_LIST[@]} $COPY_ARGS"
fi
if [[ $BRANCH ]]; then
	COPY_ARGS="--branch $BRANCH $COPY_ARGS"
fi
if [[ $REPO_ROOT ]]; then
	COPY_ARGS="--root $REPO_ROOT $COPY_ARGS"
fi

processStandardFile()
{
	pushd "$SCRIPT_DIR" > /dev/null
	
	OUTPUT_FILE=`stripBoilerplateDirectory "$1"`

	executeCommand "./copyToCleanroomRepos.sh \"$1\" \"$OUTPUT_FILE\" $COPY_ARGS"

	popd > /dev/null
}

processSubpath()
{
	for f in $1/*; do
		if [[ -d "$f" ]]; then
			processSubpath "$f"
		elif [[ $(echo "$f" | grep -c "\.boilerplate\$") > 0 ]]; then
			processBoilerplateFile "$f"
		else
			
			processStandardFile "$f"
		fi
	done
}

processSubpath boilerplate/common
processSubpath boilerplate/$SKELETON_TYPE

for r in ${REPO_LIST[@]}; do
	MASTER_XML="$PWD/include/repos.xml"
	REPO_DECL_BASE=`basename $REPO_DECL_FILE`
	if [[ -d "$REPO_DECL_FILE" ]]; then
		REPO_XML="$REPO_DECL_FILE/${r}.xml"
	elif [[ $REPO_DECL_BASE != "${r}.xml" ]]; then
		REPO_XML="$REPO_DECL_FILE/${r}.xml"
	else
		REPO_XML="$REPO_DECL_FILE"
	fi
	XML_DEST="$REPO_ROOT/${r}/BuildControl/."
	if [[ ! -f "$REPO_XML" ]]; then
		echo "error: Didn't find expected $r repo description file: $REPO_XML"
		continue
	fi
	if [[ ! -d "$XML_DEST" ]]; then
		echo "error: Didn't find expected $r repo directory: $XML_DEST"
		continue
	fi
	
	echo "Copying $MASTER_XML to $r/BuildControl"
	executeCommand "cp -${CP_ARGS} \"$MASTER_XML\" \"$XML_DEST\""
	
	echo "Copying $REPO_XML to $r/BuildControl"
	executeCommand "cp -${CP_ARGS} \"$REPO_XML\" \"$XML_DEST\""
done
