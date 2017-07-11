#!/bin/bash

set -o pipefail

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd "$PWD" ; cd `dirname "$0"` ; echo "$PWD")

cd "$SCRIPT_DIR/.."
source bin/common-include.sh

#
# parse the command-line arguments
#
BRANCH=master
FILE_LIST=()
REPO_LIST=()
DEFAULT_REPO_ROOT=$(cd "$SCRIPT_DIR/../.." ; echo "$PWD")
REPO_ROOT="$DEFAULT_REPO_ROOT"
DEFAULT_SKELETON_TYPE=framework
SKELETON_TYPE=$DEFAULT_SKELETON_TYPE

while [[ $1 ]]; do
	case $1 in
	--help|-h|-\?)
		SHOW_HELP=1
		;;
	
 	--file|-f)
 		while [[ $2 ]]; do
 			case $2 in
 			-*)
 				break
 				;;
 				
 			*)
				FILE_LIST+=($2)
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

 	--version|-v)
		if [[ $2 ]]; then
 			VERSION=$2
 			shift
 		fi
		;;
		
	--branch|-b)
		if [[ $2 ]]; then
 			BRANCH=$2
 			shift
 		fi
 		;;
	
	*)
		exitWithErrorSuggestHelp "Unrecognized argument: $1"
		;;
	esac
	shift
done

export REPO_ROOT

showHelp()
{
	define HELP <<HELP
$SCRIPT_NAME

	Uses the Boilerplate template processor to generate documents from
	*.boilerplate files customized for one or more Cleanroom-style repos.

	For information on Boilerplate, visit:
	
		https://github.com/emaloney/Boilerplate

Usage:

	$SCRIPT_NAME --repo <repo-list> --file <file-list>

Required arguments:

	--repo (-r) <repo-list>
	
		<repo-list> is a space-separated list of one or more repos for which
		the boilerplate file(s) will be generated.

	--file (-f) <file-list>
	
		<file-list> is a space-separated list of one or more relative paths
		specifying the boilerplate file(s) to process.

Optional arguments:

	--root <directory>

		Specifies <directory> as the location in which the repo(s) can be
		found. If --root is not specified, the script will use:
		
		$DEFAULT_REPO_ROOT

	--type (-t) <skeleton-type>
	
		Specifies the skeleton type to use for populating the repo(s).
		
		Currently supported skeletons are:
		
$SKELETON_LIST

		If the skeleton type is not explicitly specified, the value
		"$DEFAULT_SKELETON_TYPE" will be used by default.

	--decl <location>

		Specifies the location of the repo declaration file(s) to use.
		
		<location> may be a directory containing multiple repo declaration
		files, or it may be a file containing the declaration for a single
		repo. If <location> is a file, then the <repo-list> passed to the 
		--repo (or -r) argument must contain only one repo.

		A repo declaration is a Mockingbird MBML (*.xml) file containing 
		metadata describing a given repo. By convention, these files have the
		same name as the repo itself. (A declaration file for this repo would
		be named "$( cd "$SCRIPT_DIR/.." ; echo `basename $PWD` ).xml", for example.)
		
		If --decl is not specified, the script will search for an appropriate 
		file as needed within:
		
		$( echo $(cd "$PWD/repos" ; echo "$PWD") | sed s@^$HOME@~@ )

	--branch (-b) <branch> 
	
		As a safety measure, the script will fail if all repos involved in an
		operation are not on the same branch at the time of execution. 

		By default, the branch is assumed to be master. Using this argument
		overrides that and uses <branch> insead.
		
 	--version (-v) <version>

		Uses <version> as the current version number when generating
		boilerplate instead of the value of the CFBundleShortVersionString
		key in the Info-Target.plist file.
		
Help

	This documentation is displayed when supplying the --help (or -h or -?)
	argument.

	Note that when this script displays help documentation, all other
	command line arguments are ignored and no other actions are performed.

HELP
	printf "$HELP" | less
}

if [[ $SHOW_HELP ]]; then
	showHelp
	exit 1
fi

if [[ ${#FILE_LIST[@]} < 1 ]]; then
	exitWithErrorSuggestHelp "At least one file must be specified"
fi

if [[ ${#REPO_LIST[@]} < 1 ]]; then
	exitWithErrorSuggestHelp "At least one repo must be specified"
fi

#
# make sure all the repos are on the right branch
#
expectReposOnBranch $BRANCH $REPO_LIST
export BRANCH

#
# make sure boilerplate exists for each file specified
#
for f in ${FILE_LIST[@]}; do
	if [[ ! -f "$f" ]]; then
		echo "error: Expected to find boilerplate file at $f (within the directory $PWD)"
		exit 4
	fi
done

#
# process file for each repo
#
for f in ${FILE_LIST[@]}; do
	OUTPUT_BASE=`stripBoilerplateDirectory "$f"`
	OUTPUT_BASE=`dirname "$OUTPUT_BASE"`
	OUTPUT_NAME=`basename "$f" | sed s#^_#.# | sed s#\\.boilerplate\\$##`
	OUTPUT_FILE="$OUTPUT_BASE/$OUTPUT_NAME"
	echo "Generating $OUTPUT_FILE..."
	for r in ${REPO_LIST[@]}; do
		printf "    ...for the $r repo"
		PLIST_FILE_PATH="$REPO_ROOT/$r/BuildControl/Info-Target.plist"
		if [[ -f "$PLIST_FILE_PATH" ]]; then
			FRAMEWORK_VERSION=`"$PLIST_BUDDY" "$PLIST_FILE_PATH" -c "Print :CFBundleShortVersionString"`
		else
			FRAMEWORK_VERSION="0.0.0"
		fi
		export FRAMEWORK_VERSION
		if [[ "$VERSION" ]]; then
			FRAMEWORK_VERSION_PUBLIC="$VERSION"
		else
			FRAMEWORK_VERSION_PUBLIC=`echo $FRAMEWORK_VERSION | sed "sq\.[0-9]*\\$qq"`
		fi
		export FRAMEWORK_VERSION_PUBLIC
		if [[ $REPO_DECL_FILE ]]; then
			DECL_FILE="$REPO_DECL_FILE"
		else
			DECL_FILE="repos/${r}.xml"
		fi
		if [[ -r "$DECL_FILE" ]]; then
			mkdir -p "$REPO_ROOT/$r/$OUTPUT_BASE" && ./bin/plate -t "$f" -d "$DECL_FILE" -m include/repos.xml -o "$REPO_ROOT/$r/$OUTPUT_FILE"
			if [[ "$?" != 0 ]]; then
				exit 5
			fi
			if [[ $(echo "$OUTPUT_FILE" | grep -c "\.sh\$") > 0 ]]; then
				chmod a+x "$REPO_ROOT/$r/$OUTPUT_FILE"
			fi
			printf " (done!)\n"
		else
			printf "\n        !!! ERROR: Required file $DECL_FILE not found\n        !!! Couldn't generate $OUTPUT_FILE for $r\n"
		fi
	done
done
