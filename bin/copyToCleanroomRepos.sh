#!/bin/bash

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd "$PWD" ; cd `dirname "$0"` ; echo "$PWD")

cd "$SCRIPT_DIR/.."
source bin/common-include.sh

showHelp()
{
	define HELP <<HELP
$SCRIPT_NAME

	Copies files and directories from this $( echo `basename "$PWD"` ) repo
	into one or more other Cleanroom-style repos.

Usage:

	$SCRIPT_NAME <file-list> --repo <repo-list>

	Each relative path in <file-list> is recursively copied to the appropriate
	location in each of the repos in <repo-list>.

Where:

	<file-list> contains one or more space-separated relative paths
	referring to files within:
	
		$(formatPathForDisplay "$PWD")

	--repo (-r) <repo-list>
	
		<repo-list> is a space-separated list of one or more repos to which 
		the files will be copied.

Optional arguments:

	--root <directory>

		Specifies <directory> as the location in which the repo(s) can be
		found. If --root is not specified, the script will use:
		
		$(formatPathForDisplay "$DEFAULT_REPO_ROOT")

	--branch (-b) <branch> 
	
		As a safety measure, the script will fail if all repos involved in an
		operation are not on the same branch at the time of execution. 

		By default, the branch is assumed to be master. Using this argument
		overrides that and uses <branch> insead.
		
	--force (-f)
	
		Normally, when an operation would result in a file being overwritten,
		the user will be prompted to confirm before proceeding. If --force
		is specified, files will be overwritten without any user intervention.
		
Help

	This documentation is displayed when supplying the --help (or -help, -h,
	or -?) argument.

	Note that when this script displays help documentation, all other
	command line arguments are ignored and no other actions are performed.

HELP
	printf "$HELP" | less
}

#
# parse the command-line arguments
#
ARGS=()
REPO_LIST=()
DEFAULT_REPO_ROOT=$(cd "$SCRIPT_DIR/../.." ; echo "$PWD")
REPO_ROOT="$DEFAULT_REPO_ROOT"
BRANCH=master
while [[ $1 ]]; do
	case $1 in
	--help|-help|-h|-\?)
		SHOW_HELP=1
		;;
	
	--repo|-r)
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
export REPO_ROOT

#
# validate the input
#
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
	IGNORE_FAILS=1
fi

SRCDIR="${SCRIPT_DIR}/.."
for r in ${REPO_LIST[@]}; do
	RENAMED_ITEM=$( echo "$DESTITEM" | sed sq^_q.q )
	echo "Copying $SRCITEM to $DESTITEM for $r"
	mkdir -p "$REPO_ROOT/$r/$DESTDIR"
	cp -${CP_ARGS}R "${SRCDIR}/${SRCITEM}" "$REPO_ROOT/$r/$DESTITEM"
	if [[ $? == 0 ]]; then
		if [[ "$DESTITEM" != "$RENAMED_ITEM" ]]; then
			echo "Moving $DESTITEM into place at $RENAMED_ITEM"
			mv -${CP_ARGS} "$REPO_ROOT/$r/${DESTITEM}" "$REPO_ROOT/$r/${RENAMED_ITEM}"
			if [[ $? != 0 && ! $IGNORE_FAILS ]]; then
				echo "Failed to move ${DESTITEM} into place at: $REPO_ROOT/$r/${RENAMED_ITEM}"
			fi
			if [[ -e "$REPO_ROOT/$r/${DESTITEM}" ]]; then
				# if we failed to move the file, clean it up
				rm -rf "$REPO_ROOT/$r/${DESTITEM}"
			fi
		fi
	elif [[ ! $IGNORE_FAILS ]]; then
		echo "Command failed with exit code $?: $1"
	fi
done
