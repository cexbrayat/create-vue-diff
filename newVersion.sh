#!/bin/bash

set -e

versions=$(npm view create-vue versions --json)

versions=${versions//\"/}
versions=${versions//\[/}
versions=${versions//\]/}
versions=${versions//\,/}

versions=(${versions})

blocklist=(0.0.0)

lastVersion="3.0.0"
rebaseNeeded=false

for version in "${versions[@]}"
do

  if [ `npx semver ${version} --include-prerelease --range "<3.0.0"` ]
  then
    echo "Skipping version ${version} (before 3.0.0)"
    continue
  fi

  if [[ " ${blocklist[@]} " =~ " ${version} " ]]
  then
    echo "Skipping blocklisted ${version}"
    continue
  fi

  if [ `git branch --list ${version}` ] || [ `git branch --list --remote origin/${version}` ]
  then
    echo "${version} already generated."
    git checkout ${version}
    if [ ${rebaseNeeded} = true ]
    then
      git rebase --onto ${lastVersion} HEAD~ ${version} -X theirs
      diffStat=`git --no-pager diff HEAD~ --shortstat`
      git push origin ${version} -f
      diffUrl="[${lastVersion}...${version}](https://github.com/cexbrayat/create-vue-diff/compare/${lastVersion}...${version})"
      git checkout main
      # rewrite stats in README after rebase
      sed -i.bak -e "/^${version}|/ d" README.md && rm README.md.bak
      sed -i.bak -e 's/----|----|----/----|----|----\
NEWLINE/g' README.md && rm README.md.bak
      sed -i.bak -e "s@NEWLINE@${version}|${diffUrl}|${diffStat}@" README.md && rm README.md.bak
      git commit -a --amend --no-edit
      git checkout ${version}
    fi
    lastVersion=${version}
    continue
  fi

  echo "Generate ${version}"
  rebaseNeeded=true
  git checkout -b ${version}
  # delete app
  rm -rf ponyracer
  # generate app with new create-vue version
  npx create-vue@${version} --typescript --tests --eslint-with-prettier ponyracer
  git add ponyracer
  git commit -am "chore: version ${version}" --allow-empty
  diffStat=`git --no-pager diff HEAD~ --shortstat`
  git push origin ${version} -f
  git checkout main
  diffUrl="[${lastVersion}...${version}](https://github.com/cexbrayat/create-vue-diff/compare/${lastVersion}...${version})"
  # insert a row in the version table of the README
  sed -i.bak "/^${version}|/ d" README.md && rm README.md.bak
  sed -i.bak 's/----|----|----/----|----|----\
NEWLINE/g' README.md && rm README.md.bak
  sed -i.bak "s@NEWLINE@${version}|${diffUrl}|${diffStat}@" README.md && rm README.md.bak
  # commit
  git commit -a --amend --no-edit
  git checkout ${version}
  lastVersion=${version}

done

git checkout main
git push origin main -f
