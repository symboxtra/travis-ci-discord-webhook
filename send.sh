#!/bin/bash
# Modified: Symboxtra Software
# Author: Sankarsan Kampa (a.k.a. k3rn31p4nic)
# License: MIT

WEBHOOK_VERSION="2.0.0.0"

STATUS="$1"
WEBHOOK_URL="$2"
CURRENT_TIME=`date +%s`

unamestr=`uname`
if [[ "$unamestr" == 'Darwin' ]]; then
    OS_NAME="OSX"
else
    OS_NAME="Linux"
fi

if [ -z "$STATUS" ]; then
    echo -e "WARNING!!"
    echo -e "You need to pass the WEBHOOK_URL environment variable as the second argument to this script."
    echo -e "For details & guide, visit: https://github.com/symboxtra/travis-ci-discord-webhook"
    exit
fi

echo -e "[Webhook]: Sending webhook to Discord..."

case $1 in
  "success" )
    EMBED_COLOR=3066993
    STATUS_MESSAGE="Passed"
    AVATAR="https://travis-ci.org/images/logos/TravisCI-Mascot-blue.png"
    ;;
  "failure" )
    EMBED_COLOR=15158332
    STATUS_MESSAGE="Failed"
    AVATAR="https://travis-ci.org/images/logos/TravisCI-Mascot-red.png"
    ;;
  * )
    EMBED_COLOR=0
    STATUS_MESSAGE="Status Unknown"
    AVATAR="https://travis-ci.org/images/logos/TravisCI-Mascot-1.png"
    ;;
esac

if [ -z "$TRAVIS_COMMIT" ]; then
    TRAVIS_COMMIT="$(git log -1 --pretty="%H")"
fi

AUTHOR_NAME="$(git log -1 "${TRAVIS_COMMIT}" --pretty="%aN")"
COMMITTER_NAME="$(git log -1 "${TRAVIS_COMMIT}" --pretty="%cN")"
COMMIT_SUBJECT="$(git log -1 "${TRAVIS_COMMIT}" --pretty="%s")"
COMMIT_MESSAGE="$(git log -1 "${TRAVIS_COMMIT}" --pretty="%b")"
COMMIT_TIME="$(git log -1 "${TRAVIS_COMMIT}" --pretty="%ct")"


if [ "$AUTHOR_NAME" == "$COMMITTER_NAME" ]; then
  CREDITS="$AUTHOR_NAME authored & committed"
else
  CREDITS="$AUTHOR_NAME authored & $COMMITTER_NAME committed"
fi

# Calculate approximate build time based on commit
DISPLAY_TIME=$(date -u -d "0 $CURRENT_TIME seconds - $COMMIT_TIME seconds" +"%M:%S")


# Regex match co-author names
if [[ "$COMMIT_MESSAGE" =~ Co-authored-by: ]]; then
    IFS=$'\n'
    CO_AUTHORS=($(echo "$COMMIT_MESSAGE" | grep -o "\([A-Za-z]\+ \)\+[A-Za-z]\+"))

    if [ ${#CO_AUTHORS[@]} -gt 0 ]; then
        IFS=","
        CO_AUTHORS="${CO_AUTHORS[*]}"
        CO_AUTHORS="${CO_AUTHORS//,/, }"
    fi
    unset IFS
else
    CO_AUTHORS="None"
fi

# Replace git hashes in merge commits
IFS=$'\n'
MATCHES=($(echo "$COMMIT_SUBJECT" | grep -o "Merge \w\{40\}\b into \w\{40\}\b"))
if [ "${#MATCHES[@]}" -gt 0 ]; then
    IS_PR=true
    MATCHES=($(echo "$COMMIT_SUBJECT" | grep -o "\w\{40\}\b"))
    for MATCH in "${MATCHES[@]}"
    do
        HASH="$MATCH"
        BRANCH_NAME="$(git name-rev $HASH --name-only)"
        COMMIT_SUBJECT="${COMMIT_SUBJECT//$HASH/${BRANCH_NAME:-$HASH}}"
    done
fi
unset IFS

# Remove repo owner: symboxtra/project -> project
REPO_NAME=${TRAVIS_REPO_SLUG#*/}

#Create appropriate link
if [[ $TRAVIS_PULL_REQUEST != false ]] || [[ -n "$IS_PR" ]]; then
    URL="https://github.com/$TRAVIS_REPO_SLUG/pull/$TRAVIS_PULL_REQUEST"
else
    URL="https://github.com/$TRAVIS_REPO_SLUG/commit/$TRAVIS_COMMIT"
fi


TIMESTAMP=$(date --utc +%FT%TZ)
WEBHOOK_DATA='{
  "username": "",
  "avatar_url": "https://travis-ci.org/images/logos/TravisCI-Mascot-1.png",
  "embeds": [ {
    "color": '$EMBED_COLOR',
    "author": {
      "name": "#'"$TRAVIS_BUILD_NUMBER"' - '"$REPO_NAME"' - '"$STATUS_MESSAGE"'",
      "url": "https://travis-ci.org/'"$TRAVIS_REPO_SLUG"'/builds/'"$TRAVIS_BUILD_ID"'",
      "icon_url": "'$AVATAR'"
    },
    "title": "'"$COMMIT_SUBJECT"'",
    "url": "'"$URL"'",
    "description": "'"${COMMIT_MESSAGE}"\\n\\n"$CREDITS"'",
    "fields": [
      {
        "name": "OS",
        "value": "'"$OS_NAME"'",
        "inline": true
      },
      {
        "name": "Build Time",
        "value": "'"~$DISPLAY_TIME"'",
        "inline": true
      },
      {
        "name": "Build ID",
        "value": "'"${TRAVIS_BUILD_NUMBER}CI"'",
        "inline": true
      },
      {
        "name": "Commit",
        "value": "'"[\`${TRAVIS_COMMIT:0:7}\`](https://github.com/$TRAVIS_REPO_SLUG/commit/$TRAVIS_COMMIT)"'",
        "inline": true
      },
      {
        "name": "Branch/Tag",
        "value": "'"[\`$TRAVIS_BRANCH\`](https://github.com/$TRAVIS_REPO_SLUG/tree/$TRAVIS_BRANCH)"'",
        "inline": true
      },
      {
        "name": "Co-Authors",
        "value": "'"$CO_AUTHORS"'",
        "inline": true
      }
    ],
    "footer": {
        "text": "'"v$WEBHOOK_VERSION"'"
      },
    "timestamp": "'"$TIMESTAMP"'"
  } ]
}'



(curl -v --fail --progress-bar -A "TravisCI-Webhook" -H Content-Type:application/json -H X-Author:k3rn31p4nic#8383 -d "$WEBHOOK_DATA" "$WEBHOOK_URL" \
  && echo -e "\\n[Webhook]: Successfully sent the webhook.") || echo -e "\\n[Webhook]: Unable to send webhook."
