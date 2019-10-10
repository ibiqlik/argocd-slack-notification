#!/bin/sh

# Required environment variables:
#     ARGOCD_SERVER
#     ARGOCD_ADMIN_PASS or ARGOCD_TOKEN
#     ARGOCD_APP
#     ARGOCD_HOOKSTATE
#     SLACK_WEBHOOK_URL
#     SLACK_CHANNEL

if [ -z "$ARGOCD_SERVER" ] || [ -z "$ARGOCD_APP" ] || [ -z "$ARGOCD_HOOKSTATE" ] || [ -z "$SLACK_WEBHOOK_URL" ] || [ -z "$SLACK_CHANNEL" ]; then
  echo 'One or more of the required variables are not set'
  exit 1
fi

# Determine if Admin pass or Token was provided
if [ -z "$ARGOCD_TOKEN" ] && [ -z "$ARGOCD_ADMIN_PASS" ]; then
    echo "Missing ARGOCD_TOKEN or ARGOCD_ADMIN_PASS"
    exit 1
fi

if [ ! -z "$ARGOCD_ADMIN_PASS" ]; then
    ARGOCD_TOKEN=$(curl -s $ARGOCD_SERVER/api/v1/session -d "{\"username\": \"admin\", \"password\": \"$ARGOCD_ADMIN_PASS\"}" | jq -r .token)
fi

if [ -z "$ARGOCD_TOKEN" ]; then
    echo "ARGOCD_TOKEN is empty"
    exit 1
fi

# Get token, or simply use it if it was provided as env var
# curl -s $ARGOCD_SERVER/api/v1/applications -H "Authorization: Bearer $ARGOCD_TOKEN" > tmp.json
curl -s $ARGOCD_SERVER/api/v1/applications --cookie "argocd.token=$ARGOCD_TOKEN" > tmp.json

# Set app url to include in the message
ARGOCD_APP_URL="$ARGOCD_SERVER/applications/$ARGOCD_APP"

REVISION=$(jq -r '.items[] | select( .metadata.name == "'$ARGOCD_APP'") | .status.operationState.operation.sync.revision' tmp.json)

# Get information about git repo
REPO_URL=$(jq -r '.items[] | select( .metadata.name == "'$ARGOCD_APP'") | .spec.source.repoURL' tmp.json)
REPO_URL=${REPO_URL%.git*}
REPO_OWNER=$(echo ${REPO_URL##http**.com} | cut -d '/' -f2)
REPO=$(echo ${REPO_URL##http**.com} | cut -d '/' -f3)

# Set Slack color and status based on hook
case $ARGOCD_HOOKSTATE in
    SyncFail)
        COLOR="danger"
        STATUS="error"
    ;;
    PostSync)
        COLOR="good"
        STATUS="success"
    ;;
    *)
        COLOR="warning"
        STATUS="unknown"
    ;;
esac

generate_data()
{
    cat <<EOF
{
    "channel": "$SLACK_CHANNEL",
    "attachments": [
        {
            "title": "Application: $ARGOCD_APP",
            "title_link": "$ARGOCD_APP_URL",
            "color": "$COLOR",
            "pretext": "ArgoCD",
            "fields": [
                {
                    "title": "Status",
                    "value": "$STATUS",
                    "short": true
                },
                {
                    "title": "Commit",
                    "value": "<$REPO_URL/commit/$REVISION|$REVISION>",
                    "short": false
                }
            ],
            "footer": "$REPO_URL",
            "footer_icon": "https://github.githubassets.com/favicon.ico",
            "ts": $(date +%s)
        }
    ]
}
EOF
}

curl -X POST -H 'Content-type: application/json' --data "$(generate_data)" "$SLACK_WEBHOOK_URL"
