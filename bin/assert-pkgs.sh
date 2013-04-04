#!/bin/bash

#
# Usage: assert-pkgs.sh [PKG1 PKG2 PKG3...]
#
# Return codes:
# 	0: Success
# 	1: Error(s)
#

PKGS=$@
FEDORA_PKGS_DIR="$(cd "$(dirname "$0")/.." && pwd )"

GIT=`which git`
if [ "" == "$GIT" ]; then
	echo "ERROR: 'git' not found.  Please run 'yum install git'." 1>&2
	exit 1
fi

cd "$FEDORA_PKGS_DIR"

echo ""
echo ""
echo ">>>>>>>>>>>>>>>>>>>> Resetting any possible staged changes..."
$GIT reset
[ -e .gitmodules ] && $GIT checkout .gitmodules

for PKG in $PKGS; do
	echo ""
	echo ""
	echo ">>>>>>>>>>>>>>>>>>>>"
	echo ">>>>>>>>>>>>>>>>>>>> $PKG"
	echo ">>>>>>>>>>>>>>>>>>>>"

	case "$PKG" in
		drupal*)
			PKG_PREFIX=`echo "$PKG" | awk 'BEGIN { FS = "-" } { print $1 }'`
			;;
		php*)
			PKG_PREFIX=`echo "$PKG" | awk 'BEGIN { FS = "-" } { if ( NF > 2 ) print $1 "/" $2; else print $1; }'`
			if [ "${PKG_PREFIX}" == "${PKG}" ] || [ "${PKG_PREFIX}" == "php/php" ]; then
				PKG_PREFIX='php'
			fi
			;;
		*)
			PKG_PREFIX='other'
			;;
	esac

	PKG_DIR="$PKG_PREFIX/$PKG"

	echo "---------- Asserting pkg dir '$PKG_DIR'..."
	if [ ! -d "$PKG_DIR" ]; then
		$GIT submodule add ssh://pkgs.fedoraproject.org/${PKG}.git $PKG_DIR
		$GIT commit -m "[$PKG] Added"
	else
		$GIT submodule update --init $PKG_DIR
	fi

	pushd $PKG_DIR > /dev/null

	echo "---------- Updating origin..."
	$GIT checkout master
	$GIT pull

	echo "---------- Looping through origin branches..."
	for ORIGIN_BRANCH in $(git for-each-ref --format='%(refname:short)' refs/remotes/origin/ | sed 's:origin/::'); do
		[ "$ORIGIN_BRANCH" == "HEAD" ] && continue

		echo "----- ${ORIGIN_BRANCH}"

		# Check for obsoleted branches
		ORIGIN_BRANCH_OS=`echo "$ORIGIN_BRANCH" | sed 's/[[:digit:]]//g'`
		ORIGIN_BRANCH_VER=`echo "$ORIGIN_BRANCH" | sed 's/[[:alpha:]]//g'`
		if [ "f" == "$ORIGIN_BRANCH_OS" ] && [ "$ORIGIN_BRANCH_VER" -lt 17 ]; then
			echo "----- WARNING: This branch has been EOL'd. If you really need to make changes in branch '${ORIGIN_BRANCH}' you must do them manually."
			continue
		elif [ "el" == "$ORIGIN_BRANCH_OS" ] && [ "$ORIGIN_BRANCH_VER" -lt 5 ]; then
			echo "----- WARNING: This branch has been EOL'd. If you really need to make changes in branch '${ORIGIN_BRANCH}' you must do them manually."
			continue
		fi

		# Test if local branch exists
		git show-branch "$ORIGIN_BRANCH" >& /dev/null

		# Local branch exists
		if [ $? -eq 0 ]; then
			LOCAL_REMOTE=$(git config "branch.${ORIGIN_BRANCH}.remote")
			LOCAL_REMOTE_BRANCH=$(git config "branch.${ORIGIN_BRANCH}.merge" | sed 's:refs/heads/::')

			# Local branch is tracking correctly
			if [ "$LOCAL_REMOTE" == "origin" ] && [ "$LOCAL_REMOTE_BRANCH" == "$ORIGIN_BRANCH" ]; then
				$GIT rebase "origin/$ORIGIN_BRANCH" "$ORIGIN_BRANCH"
			# Local branch is NOT tracking correctly
			else
				$GIT branch -D "$ORIGIN_BRANCH" && \
					$GIT branch --track "$ORIGIN_BRANCH" "origin/$ORIGIN_BRANCH"
			fi
		# Local branch does not exist
		else
			$GIT branch --track "$ORIGIN_BRANCH" "origin/$ORIGIN_BRANCH"
		fi
	done

	echo "---------- Reseting checked out branch to master..."
	$GIT checkout master

	popd > /dev/null

	echo "---------- Checking for changes..."
	PKG_CHANGES=$($GIT status --porcelain "$PKG_DIR" 2>/dev/null | wc -l)
	if [ $PKG_CHANGES != 0 ]; then
		$GIT add "$PKG_DIR"
		$GIT commit -m "[$PKG] Updated"
	fi
done
