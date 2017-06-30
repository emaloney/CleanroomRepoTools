#!/bin/bash

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd "$PWD" ; cd `dirname "$0"` ; echo "$PWD")

cd "$SCRIPT_DIR/.."
source bin/common-include.sh

showHelp()
{
	CLEANROOM_REPO_LIST=`printf "\t\t%s\n" ${CLEANROOM_REPOS[@]}`

	define HELP <<HELP
$SCRIPT_NAME

	Copies one or more portions of the Cleanroom master repo
	into one or more parallel Cleanroom Project code repos.

Usage:

	$SCRIPT_NAME <relative-path> [<relative-path> [...]]

Where:

	<relative-path> is the relative path of a file or directory
	within the instance of the Cleanroom master repository at:

		$REPO_ROOT_DEFAULT

	Each <relative-path> is recursively copied to the appropriate
	location in the individual Cleanroom Project repos that exist
	within:

		$REPO_ROOT_DEFAULT

	The following Cleanroom Project repos have been detected:

$CLEANROOM_REPO_LIST

Help

	This documentation is displayed when supplying the --help (or -h or -?)
	argument.

	Note that when this script displays help documentation, all other
	command line arguments are ignored and no other actions are performed.

HELP
	printf "$HELP"
}

#
# parse the command-line arguments
#
ARGS=()
REPO_LIST=()
REPO_ROOT_DEFAULT="$PWD/.."
REPO_ROOT="$REPO_ROOT_DEFAULT"
BRANCH=master
while [[ $1 ]]; do
	case $1 in
	--help|-h|-\?)
		SHOW_HELP=1
		;;
	
	--repo|-r)
 		REPOS_SPECIFIED=1
 		while [[ $2 ]]; do
 			case $2 in
 			-*)
 				break
 				;;
 				
 			*)
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
 		
 	--all|-a)
		ALL_REPOS_FLAG=1
		;;
	
	--branch|-b)
		if [[ $2 ]]; then
 			BRANCH=$2
 			shift
 		fi
 		;;

	--force|-f)
		FORCE_MODE=1
		;;
	
	-*)
		exitWithErrorSuggestHelp "Unrecognized argument: $1"
		;;
		
	*)
		if [[ -z $ARGS ]]; then
			ARGS=$1		
		else
			ARGS="$ARGS $$1"
		fi
		;;
	esac
	shift
done

if [[ $SHOW_HELP ]]; then
	showHelp
	exit 1
fi

REPO_NAME=`basename "$PWD"`
cd "$REPO_ROOT"
export REPO_ROOT

#
# validate the input
#
if [[ $REPOS_SPECIFIED && $ALL_REPOS_FLAG ]]; then
	exitWithErrorSuggestHelp "--repo|-r and --all|-a are mutually exclusive; they may not both be specified at the same time"
fi
if [[ ! $REPOS_SPECIFIED ]]; then
	if [[ ! $ALL_REPOS_FLAG ]]; then
		exitWithErrorSuggestHelp "If no --repo|-r values were specified, --all|-a must be specified"
	fi

	REPO_LIST=${CLEANROOM_REPOS[@]}
fi

if [[ ${#REPO_LIST[@]} < 1 ]]; then
	exitWithErrorSuggestHelp "At least one repo must be specified"
fi

if [[ ${#ARGS[@]} < 1 ]]; then
	exitWithErrorSuggestHelp "At least file to copy must be specified"
fi

#
# make sure we're being run from the expected place
#
pushd "$SCRIPT_DIR/../.." > /dev/null
expectRepo "$REPO_NAME"
popd > /dev/null

#
# ensure all the repos are on the expected branch
#
pushd ".." > /dev/null
expectReposOnBranch $BRANCH $REPO_LIST
popd > /dev/null

#
# copy the item to each repo
#
SRCITEM="${ARGS[0]}"
DESTITEM="${ARGS[1]}"
DESTDIR=`dirname "$DESTITEM"`
if [[ $FORCE_MODE ]]; then
	CP_ARGS="f"
else
	CP_ARGS="i"
fi

SRCDIR="${SCRIPT_DIR}/.."
for r in ${REPO_LIST[@]}; do
	RENAMED_ITEM=$( echo "$DESTITEM" | sed sq^_q.q )
	echo "Copying $SRCITEM to $r/${DESTITEM}"
	mkdir -p "$REPO_ROOT/$r/$DESTDIR"
	executeCommand "cp -${CP_ARGS}R \"${SRCDIR}/${SRCITEM}\" \"$REPO_ROOT/$r/$DESTITEM\""
	if [[ "$DESTITEM" != "$RENAMED_ITEM" ]]; then
		executeCommand "mv -f \"$REPO_ROOT/$r/${DESTITEM}\" \"$REPO_ROOT/$r/${RENAMED_ITEM}\""
	fi
done
