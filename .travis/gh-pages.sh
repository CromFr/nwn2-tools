#!/bin/bash
set -e -v

# https://gist.github.com/domenic/ec8b0fc8ab45f39403dd

SOURCE_BRANCH="master"

# Dont deploy pull requests & branches != master
if [ "$TRAVIS_PULL_REQUEST" != "false" -o "$TRAVIS_BRANCH" != "$SOURCE_BRANCH" ]; then
    echo "Skipping deploy"
    exit 0
fi

REPO=`git config remote.origin.url`
SSH_REPO=${REPO/https:\/\/github.com\//git@github.com:}
SHA=`git rev-parse --verify HEAD`

# Clone ===============================
mkdir out
cd out
git init

# Git cfg
git config user.name "Travis CI"
git config user.email "cromfr@gmail.com"

# Reinstall content ===================
rm -rf *
# Home
cp ../.travis/index.html .

# binaries
cp -R ../{linux-x86,linux-x86_64,win-x86} .


# Commit ==============================
git add --all
git commit -m "Automated build: ${SHA}"

# Get the deploy key by using Travis's stored variables to decrypt deploy_key.enc
openssl aes-256-cbc -K $encrypted_addd21bf501b_key -iv $encrypted_addd21bf501b_iv -in ../.travis/travis_id_rsa.enc -out deploy_key -d
chmod 600 deploy_key
eval `ssh-agent -s`
ssh-add deploy_key

# Push
git push --force $SSH_REPO master:gh-pages
