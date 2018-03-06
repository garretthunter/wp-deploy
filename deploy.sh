#!/bin/bash -x

# set working dir and include env setup
cd "$(dirname "$0")"
source setup-bash.sh

# args
MSG=${1-'Deploy from Git'}
BRANCH=${2-'trunk'}

SRC_DIR=${BASEDIR}/git
DEST_DIR=${BASEDIR}/svn/$BRANCH

# make sure the destination dir exists
mkdir -p $DEST_DIR
svn add $DEST_DIR 2> /dev/null

# delete everything except .svn dirs
for file in $(find $DEST_DIR/* -not -name ".svn" -print); do
	rm -rf $file
done

# check if we need to checkout a branch
if git rev-parse --verify $BRANCH; then
	echo "Checking out the $BRANCH branch"
	git checkout $BRANCH
else
	echo "Checking out the master branch"
	git checkout master
fi

# copy source code from git
rsync --recursive --exclude=".*" $SRC_DIR/* $DEST_DIR
#robocopy $SRC_DIR $DEST_DIR -S -xd "assets" -xd ".git" -xd ".idea" -xd ".svn" -xf ".*" -purge

# copy assets from git
rsync --recursive --exclude=".*" $SRC_DIR/assets/* $DEST_DIR/../assets
#robocopy $SRC_DIR/assets $DEST_DIR/../assets -Xd ".git" -xd ".idea" -xd ".svn" -xf ".*" -purge

# check .svnignore
for file in $(cat "$SRC_DIR/.svnignore" 2> /dev/null)
do
	rm -rf $DEST_DIR/$file
done

cd $DEST_DIR

# Transform the readme
if [ -f README.md ]; then
	mv README.md readme.txt
	sed -i '' -e 's/^# \(.*\)$/=== \1 ===/' -e 's/ #* ===$/ ===/' -e 's/^## \(.*\)$/== \1 ==/' -e 's/ #* ==$/ ==/' -e 's/^### \(.*\)$/= \1 =/' -e 's/ #* =$/ =/' readme.txt
fi

# svn addremove
svn stat | awk '/^\?/ {print $2}' | xargs svn add > /dev/null 2>&1
svn stat | awk '/^\!/ {print $2}' | xargs svn rm --force

svn stat

read -r -p "Commit to SVN? (y/n) " should_commit

if [ "$should_commit" = "y" ]; then
    cd ${BASEDIR}/svn
	svn ci -m "$MSG"
else
	echo "Commit Aborted!"
fi
