#!/bin/bash

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd "$PWD" ; cd `dirname "$0"` ; echo "$PWD")

cd "$SCRIPT_DIR/.."
source bin/common-include.sh

showHelp()
{
	echo "$SCRIPT_NAME"
	echo
	printf "\tCopies one or more portions of the Cleanroom master repo\n"
	printf "\tinto one or more parallel Cleanroom Project code repos.\n"
	echo
	echo "Usage:"
	echo
	printf "\t$SCRIPT_NAME <relative-path> [<relative-path> [...]]\n"
	echo
	echo "Where:"
	echo
	printf "\t<relative-path> is the relative path of a file or directory\n"
	printf "\twithin the instance of the Cleanroom master repository at:\n"
	echo
	printf "\t\t$REPO_ROOT_DEFAULT\n"
	echo
	printf "\tEach <relative-path> is recursively copied to the appropriate\n"
	printf "\tlocation in the individual Cleanroom Project repos that exist\n"
	printf "\twithin:"
	echo
	printf "\t\t$REPO_ROOT_DEFAULT\n"
	echo
	printf "\tThe following Cleanroom Project repos have been detected:\n"
	echo
	printf "\t\t%s\n" ${CLEANROOM_REPOS[@]}
	echo
	echo "Help"
	echo
	printf "\tThis documentation is displayed when supplying the --help (or\n"
	printf "\t-h or -?) argument.\n"
	echo
	printf "\tNote that when this script displays help documentation, all other\n"
	printf "\tcommand line arguments are ignored and no other actions are performed.\n"
	echo
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
		ARGS+=($1)
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
expectRepo "$REPO_NAME"

#
# ensure all the repos are on the expected branch
#
pushd "$SCRIPT_DIR/.." > /dev/null
expectReposOnBranch $BRANCH $REPO_LIST
popd > /dev/null

#
# ensure that the arguments are all things that can be copied
#
for f in ${ARGS[@]}; do
	ITEM=`basename "$f"`
	DIR=`dirname "$f"`
	if [[ $DIR == '.' ]]; then
		DIR=""
	else
		DIR="$DIR/"
	fi
	if [[ $FORCE_MODE ]]; then
		CP_ARGS="f"
	else
		CP_ARGS="i"
	fi
	
	SRCDIR="${REPO_NAME}/boilerplate"
	for r in ${REPO_LIST[@]}; do
		DESTITEM=$( echo "$ITEM" | sed sq^_q.q )
		echo "Copying $ITEM to $r/${DIR}${DESTITEM}"
		mkdir -p "$r/$DIR"
		executeCommand "cp -${CP_ARGS}R \"${SRCDIR}/${DIR}${ITEM}\" \"$r/$DIR.\""
		if [[ "$DESTITEM" != "$ITEM" ]]; then
			executeCommand "mv -f \"$r/${DIR}${ITEM}\" \"$r/${DIR}${DESTITEM}\""
		fi
	done
done
