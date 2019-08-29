# Git Changelog

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

