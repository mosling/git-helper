# Changelog

This script can be used to generate a set of html files for each commit with links to an optional issue management system and the commit itself.

## Prerequisites

This project uses a fork from https://github.com/ariatemplates/git-release-notes

You must first clone the project and link it to your system.

    git clone https://github.com/mosling/git-release-notes.git
    cd git-release-notes
    npm install
    npm link

Please set the base output folder for the resulting files 

    export CHANGELOGFOLDER=<folder>

## Usage

Go to the local git repository and call ```changelog.sh```. This starts an interview process to ask all values. Normally the precomputed values from the git information matches. 

# Nextversion

This script ask the user for the next release version depending at the existing tag.

## Usage

Go to the git repository folder and type 

    nextversion.sh

The script guides the user to process:

* check that the develop branch is active
* request the next version number
* do a release finish if wished
* use signing if the global config key **user.signingkey** is set
* push the changed **master** and **develop** branches
