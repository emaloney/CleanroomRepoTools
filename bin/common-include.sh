define()
{
	IFS='\n' read -r -d '' ${1} || true
}

printError()
{
	echo "error: $1"
	echo
	if [[ ! -z $2 ]]; then
		printf "  $2\n\n"
	fi
}

exitWithError()
{
	printError "$1" "$2"
	exit 1
}

exitWithErrorSuggestHelp()
{
	printError "$1" "$2"
	printf "  To display help, run:\n\n\t$0 --help\n"
	exit 1
}

confirmationPrompt()
{
	echo
	printf "$1\n"
	echo
	read -p "Are you sure you want to continue? " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		exit -1
	fi
}

executeCommand()
{
	if [[ $DRY_RUN_MODE ]]; then
		if [[ ! $DID_DRY_RUN_MSG ]]; then
			printf "\t!!! DRY RUN MODE - Will only show commands, not execute them !!!\n"
			echo
			DID_DRY_RUN_MSG=1
		fi
		echo "> $1"
	else
		eval "$1"
		if [[ $? != 0 ]]; then
			exitWithError "Command failed: $1"
		fi
	fi
}

isNotRepo()
{
	REPO_DIR="$1"
	if [[ ! -d "$REPO_DIR" ]]; then
		echo 1
	else
		pushd "$REPO_DIR" > /dev/null
		git status 2&> /dev/null
		RESULT=$?
		popd > /dev/null
		echo $RESULT
	fi
}

expectRepo()
{
	if [[ $(isNotRepo "$1") != 0 ]]; then
		echo "error: Expected $1 (within $PWD) to be a git repo"
		exit 1
	fi
}

expectReposOnBranch()
{
	if [[ $1 ]]; then
		BRANCH="$1"
		shift
	fi
	
	#
	# make sure the Cleanroom repo is on a parallel branch
	#
	pushd "${SCRIPT_DIR}/.." > /dev/null
	# if we're in a carthage submodule (eg below Carthage/Checkouts/), don't check the
	# branches since it won't be relevant in that case
	if [[ `echo $PWD | grep -c "Carthage/Checkouts/CleanroomRepoTools$"` == 0 ]]; then
		CLEANROOM_BRANCH=`git rev-parse --abbrev-ref HEAD`
		popd > /dev/null
		if [[ $CLEANROOM_BRANCH != $BRANCH ]]; then
			echo "error: Expected CleanroomRepoTools to be on $BRANCH branch; is on $CLEANROOM_BRANCH instead"
			exit 2
		fi

		#
		# make sure all the repos are on the right branch
		#
		for r in $@; do
			REPO_DIR="$REPO_ROOT/$r"
			if [[ ! -d "$REPO_DIR" ]]; then
				echo "error: Didn't find expected git repo for $r at path $REPO_DIR"
				exit 3
			fi
			pushd "$REPO_DIR" > /dev/null
			CURRENT_BRANCH=`git rev-parse --abbrev-ref HEAD`
			popd > /dev/null
			if [[ $CURRENT_BRANCH != $BRANCH ]]; then
				echo "error: Expected $r to be on the \"$BRANCH\" branch; it is on \"$CURRENT_BRANCH\" instead."
				exit 4
			fi
		done
	fi
}

isInArray()
{
	for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 1; done
	return 0
}

stripBoilerplateDirectory()
{
	STRIPPED=`echo "$1" | sed -E s#\(boilerplate/common\|boilerplate/$SKELETON_TYPE\)/?##`
	echo $STRIPPED
}

#
# find the known repos
#
CLEANROOM_REPOS=()
for f in "$SCRIPT_DIR/../repos/"*.xml; do
	CLEANROOM_REPOS+=(`basename "$f" | sed "s/^repos\///" | sed "s/.xml$//"`)
done

#
# find my PlistBuddy
#
PLIST_BUDDY=/usr/libexec/PlistBuddy
if [[ ! -x "$PLIST_BUDDY" ]]; then
	exitWithErrorSuggestHelp "Expected to find PlistBuddy at path $PLIST_BUDDY"
fi

#
# find the known skeletons
#
SKELETONS=()
for f in "$SCRIPT_DIR/../skeletons/"*; do
	if [[ -d "$f" ]]; then
		SKELETONS+=(`basename "$f"`)
	fi
done
