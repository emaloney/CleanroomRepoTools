#!/bin/bash

SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd "$PWD" ; cd `dirname "$0"` ; echo "$PWD")

cd "$SCRIPT_DIR"
source common-include.sh

PLATE_BIN="$SCRIPT_DIR/plate"
DEFAULT_REPO_ROOT=$( echo $( cd "$SCRIPT_DIR/../.."; echo "$PWD" ) | sed s@^$HOME@~@ )
REPO_ROOT="$DEFAULT_REPO_ROOT"
REPO_DECL_FILE="$SCRIPT_DIR/../repos/${NEW_REPO_NAME}.xml"
POSSIBLE_PLATFORMS=( iOS macOS tvOS watchOS all )
POSSIBLE_PLATFORMS_HORIZONTAL=`echo -n "${POSSIBLE_PLATFORMS[@]}"`
POSSIBLE_PLATFORMS_VERTICAL=`printf "\t\t\t%s\n" ${POSSIBLE_PLATFORMS[@]}`
REAL_PLATFORMS=${POSSIBLE_PLATFORMS[@]:0:${#POSSIBLE_PLATFORMS[@]}-1}
REPO_BRANCH=master
DEFAULT_SKELETON_TYPE=framework
SKELETON_TYPE=$DEFAULT_SKELETON_TYPE

#
# parse the command-line arguments
#
PLATFORMS=()
while [[ $1 ]]; do
	case $1 in
	--help|-h|-\?)
		SHOW_HELP=1
		;;
	
	--force|-f)
		FORCE_ARG="$1"
		FORCE_MODE=1
		;;
	
	--commit-message-file|-m)
		if [[ $2 ]]; then
			COMMIT_MESSAGE=`cat "$2"`
			shift
		fi
		;;
		
	--branch|-b)
		while [[ $2 ]]; do
 			case $2 in
 			-*)
 				break
 				;;
 				
 			*)
				REPO_BRANCH="$2"
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
				DECL_ARG="--decl $REPO_DECL_FILE"
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
	
	--dest|-d|--root)
 		while [[ $2 ]]; do
 			case $2 in
 			-*)
 				break
 				;;
 				
 			*)
 				if [[ ${2:0:1} == '/' ]]; then
					REPO_ROOT="$2"
				else
					REPO_ROOT="$PWD/$2"
 				fi
		 		shift
				;;	
 			esac
 		done
		;;
	
	--owner|-o)
 		while [[ $2 ]]; do
 			case $2 in
 			-*)
 				break
 				;;
 				
 			*)
				REPO_OWNER="$2"
		 		shift
				;;	
 			esac
 		done
 		;;
	
 	--platform|-p)
 		while [[ $2 ]]; do
 			case $2 in
 			-*)
 				break
 				;;
 			
 			all)
 				PLATFORMS=(${PLATFORMS[@]} ${REAL_PLATFORMS[@]})
 				shift
 				;;
 				
 			*)
				PLATFORMS+=($2)
		 		shift
				;;	
 			esac
 		done
 		;;
	
	*)
		if [[ -z "$NEW_REPO_NAME" ]]; then
			NEW_REPO_NAME="$1"
		else
			exitWithErrorSuggestHelp "Unrecognized argument: $1"
		fi
		;;
	esac
	shift
done

export REPO_ROOT

showHelp()
{
	define HELP <<HELP
$SCRIPT_NAME

	Creates a skeleton Xcode project structure and, if needed, initializes
	a new git repo to house it.

Usage:

	$SCRIPT_NAME <project-name> --owner <github-user-id>

Where:

	<project-name> is the name of the Xcode project to create. This is also 
	used as the name of the GitHub repo.

Required arguments:

	--owner (-o) <github-user-id> 
	
		Specifies the GitHub user ID of the repo's owner.

Optional arguments:

	--type <skeleton-type>
	
		Specifies the skeleton type to use for populating the repo.
		
		Currently supported skeletons are:
		
$SKELETON_LIST

		If the skeleton type is not explicitly specified, the value
		"$DEFAULT_SKELETON_TYPE" will be used by default.

	--dest (-d) <directory>

		Specifies <directory> as the destination location in which the new
		project repo will be placed. If not specified, the script will use:
		
		$DEFAULT_REPO_ROOT

		This script also accepts --root as an alias for --dest.

	--platform (-p) <platform-list>
	
		Generates a project that will build for the platform(s) indicated
		by <platform-list>, a space-separated list specifying of one or more
		platforms. Possible values are:
	
$POSSIBLE_PLATFORMS_VERTICAL

		Specifying "all" is an alias for supporting all possible platforms. If
		--platform is not explicitly specified, "all" is assumed; let's be
		cross-platform by default!

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
		
		$( echo $(cd "$SCRIPT_DIR/../repos" ; echo "$PWD") | sed s@^$HOME@~@ )

	--branch (-b) <branch> 
	
		As a safety measure, the script will fail if all repos involved in an
		operation are not on the same branch at the time of execution. 

		By default, the branch is assumed to be master. Using this argument
		overrides that and uses <branch> insead.

	--commit-message-file (-m) <file>
	
		Specifies the path of a file containing the message to be used for
		any git commit made.

	--force (-f)

		By default, the script won't run if the directory specified by --dest
		already contains something named <project-name>. Using --force overrides 
		this safety check, allowing the script to proceed.

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

REPO_BRANCH_ARG="--branch $REPO_BRANCH"

if [[ -z "$NEW_REPO_NAME" ]]; then
	exitWithErrorSuggestHelp "Must provide name of new repo/project"
fi

REPO_ROOT=$( cd "$REPO_ROOT"; echo $PWD )
if [[ ! -d "$REPO_ROOT" ]]; then
	exitWithErrorSuggestHelp "Couldn't find destination directory: $REPO_ROOT"
fi

if [[ -e "$REPO_ROOT/$NEW_REPO_NAME" && $FORCE_MODE != 1 ]]; then
	exitWithErrorSuggestHelp "Directory already exists: $REPO_ROOT/$NEW_REPO_NAME" "Use --force (or -f) to override"
fi

if [[ -z "$REPO_OWNER" && ! -r "$REPO_DECL_FILE" ]]; then
	exitWithErrorSuggestHelp "The repo's owner must be specified"
fi

if [[ ${#PLATFORMS[@]} == 0 ]]; then
	PLATFORMS=(${REAL_PLATFORMS[@]})
fi

INCLUDE_IOS=0
INCLUDE_MACOS=0
INCLUDE_TVOS=0
INCLUDE_WATCHOS=0
for p in "${PLATFORMS[@]}"; do
	isInArray "$p" ${REAL_PLATFORMS[@]}
	if [[ $? == 0 ]]; then
		exitWithErrorSuggestHelp "The value \"$p\" passed to the --platform (-p) argument is not recognized" "Accepted values: $POSSIBLE_PLATFORMS_HORIZONTAL"
	fi

	case $p in
	iOS)
		INCLUDE_IOS=1
		PLATFORM_MBML="$PLATFORM_MBML<Var literal=\"iOS\"/>"
		;;
		
	macOS)
		INCLUDE_MACOS=1
		PLATFORM_MBML="$PLATFORM_MBML<Var literal=\"macOS\"/>"
		;;
		
	tvOS)
		INCLUDE_TVOS=1
		PLATFORM_MBML="$PLATFORM_MBML<Var literal=\"tvOS\"/>"
		;;
		
	watchOS)
		INCLUDE_WATCHOS=1
		PLATFORM_MBML="$PLATFORM_MBML<Var literal=\"watchOS\"/>"
		;;
	esac
done

processDirectory()
{
	pushd "$1" > /dev/null
	for f in *; do
		DEST_NAME=$( echo "$f" | sed "s/CleanroomSkeleton/${NEW_REPO_NAME}/" )
		if [[ $( echo "$f" | grep -c "^_" ) > 0 ]]; then
			DEST_NAME=$( echo "$f" | sed "s/^_/./" )
		fi
		
		if [[ ! -z "$2" ]]; then
			DEST_DIR="$2/"
		fi
		
		if [[ -d "$f" ]]; then
			printf "\t${REPO_ROOT}/${DEST_DIR}. <- ${DEST_NAME}/\n"
			executeCommand "mkdir -p \"${REPO_ROOT}/${DEST_DIR}${DEST_NAME}\""
			processDirectory "$f" "${DEST_DIR}${DEST_NAME}"
		elif [[ $( echo "$f" | grep -c "\.boilerplate\$" ) > 0 ]]; then
			DEST_NAME=$( echo "$DEST_NAME" | sed "s/\.boilerplate\$//" )
				printf "\t${REPO_ROOT}/${DEST_DIR}${DEST_NAME} <- $f\n"
			CREATOR_USER=`id -un`
			CREATOR_NAME=`id -F`
			if [[ -r "$REPO_DECL_FILE" ]]; then
				$PLATE_BIN -t "$f" -o "${REPO_ROOT}/${DEST_DIR}${DEST_NAME}" -m ../include/repos.xml -d "$REPO_DECL_FILE"
			else
				$PLATE_BIN -t "$f" -o "${REPO_ROOT}/${DEST_DIR}${DEST_NAME}" -m ../include/repos.xml --stdin-data <<MBML_BLOCK
<MBML>
	<Var name="repo:owner" literal="${REPO_OWNER}"/>
	<Var name="project:name" literal="${NEW_REPO_NAME}"/>
	<Var name="project:creator:name" literal="${CREATOR_NAME}"/>
	<Var name="project:creator:id" literal="${CREATOR_USER}"/>
	<Var name="project:platforms" type="list">
		$PLATFORM_MBML
	</Var>
</MBML>
MBML_BLOCK
			fi
			if [[ $( echo "$DEST_NAME" | grep -c "\.sh\$" ) > 0 ]]; then
				chmod a+x "${REPO_ROOT}/${DEST_DIR}${DEST_NAME}"
			fi
		else
			if [[ "$f" == "$DEST_NAME" ]]; then
				printf "\t${REPO_ROOT}/${DEST_DIR}. <- $f\n"
			else
				printf "\t${REPO_ROOT}/${DEST_DIR}${DEST_NAME} <- $f\n"
			fi
			executeCommand "cp \"$f\" \"${REPO_ROOT}/${DEST_DIR}${DEST_NAME}\""
		fi
	done
	popd > /dev/null
}

cd "$SCRIPT_DIR/../skeletons"
echo "Creating new Xcode $SKELETON_TYPE project repo $NEW_REPO_NAME in $REPO_ROOT"
processDirectory "$SKELETON_TYPE"

cd "$REPO_ROOT"

if [[ ! -d "$NEW_REPO_NAME/.git" ]]; then
	# we need to create the repo first because the freshenRepo.sh script below
	# requires the git repo to already have been created & have at least 1 commit
	pushd "$REPO_ROOT/$NEW_REPO_NAME" > /dev/null
	if [[ -z $COMMIT_MESSAGE ]]; then
		define COMMIT_MESSAGE <<__COMMIT_MESSAGE__
Initial commit of $NEW_REPO_NAME

Automated by $SCRIPT_NAME
__COMMIT_MESSAGE__
	fi
	USE_GIT=1
	echo "Creating git repo and performing initial commit"
	git init -q
	git checkout -qb "$REPO_BRANCH"
	git add .
	printf "%s" "$COMMIT_MESSAGE" | git commit -q -F -
	popd > /dev/null
fi

expectReposOnBranch "$REPO_BRANCH" "$NEW_REPO_NAME"

echo "Generating boilerplate files"
"${SCRIPT_DIR}/freshenRepo.sh" --repo "$NEW_REPO_NAME" $FORCE_ARG $REPO_BRANCH_ARG --root "$REPO_ROOT" --type "$SKELETON_TYPE" $DECL_ARG

pushd "$REPO_ROOT/$NEW_REPO_NAME" > /dev/null

if [[ $USE_GIT ]]; then
	echo "Committing final files to git"
	git add .
	git commit -q --amend --no-edit
	popd > /dev/null
	echo "Done!"
fi
