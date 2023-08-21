#!/bin/bash

# Updates compose service versions.

default_branch="$1"
# generate $skip_patterns
IFS=',' read -ra skip_patterns <<< "$2"

# branching, pr, senver compare and sed logic
versions_magic() {
    if [ "$latest_version_in_registry" != "$v_rematched" ]
    then
        skip=false
        for skip_pattern in "${skip_patterns[@]}"
        do
            if [[ "$image:$latest_version_in_registry" == *"$skip_pattern"* ]]
            then
                skip=true
                break
            fi
        done
        if "$skip"
        then
            return
        fi
        echo "WARN: There is a new version [$latest_version_in_registry] for $image:$v_rematched"
        # branch out and pr if changes
        git checkout -B "compose/$image"
        git pull origin "compose/$image"
        # sed compose files on branch
        for file in $(find -name '*compose*.yml' -o -name '*compose*.yaml' -type f)
        do
            if [[ -f "$file" ]]
            then
                sed -i -e "s|$image:$v_rematched|$image:$latest_version_in_registry|g" "$file"
                sed -i -e "s|$image_orig:$v_rematched|$image_orig:$latest_version_in_registry|g" "$file" # hack for some of the images such as library/* nginx, prometheus, etc
            else
                echo "No compose file/s found."
                exit 1
            fi
        done
        if [[ $(git status --porcelain) ]]
        then
            # git actions as there are commits pending
            git add .
            git commit -m "bump $image:$latest_version_in_registry over $v_rematched"
            git push origin "compose/$image" --force
            pr_number=$(gh pr list --head "compose/$image" --json number --jq '.[0].number')
            if [ -n "$pr_number" ]; then
            echo "Updating PR #$pr_number"
            gh pr edit "$pr_number" --title "docker-compose: bump $image:$latest_version_in_registry" --body "Automated PR updated by GitHub Actions"
            else
            echo "No open PRs found for branch compose/$image. Creating a new PR."
            gh pr create --title "docker-compose: bump $image:$latest_version_in_registry" --head "compose/$image" --base "$default_branch" --body "Automated PR created by GitHub Actions"
            fi
        else
            echo "No porcelain, nothing to do."
        fi
        # go back to base branch
        git checkout "$default_branch"
    fi
}

# dockerhub
versions_dockerio=$(yq '.services[].image' ./*compose*.y* | grep docker.io | sort | uniq)
for version in $versions_dockerio
do
    versions_in_registry=''
    latest_version_in_registry=""

    [[ $version =~ docker.io\/(.*)\:(.*) ]]
    image=${BASH_REMATCH[1]}
    v_rematched=${BASH_REMATCH[2]}

    # this registry has some images under library/ those do not match the compose structures
    # images such as telegraf, nginx, prometheus, etc
    if [[ "$image" != *'/'* ]]
    then 
        image_orig="$image"
        image="library/$image"
    fi

    echo "image: $image, v: $v_rematched"
    # read X number of tag pages
    for page in 1 2 3
    do
        versions_in_registry+="$(curl -s https://hub.docker.com/v2/repositories/$image/tags?page=$page | jq -r '.results[].name' | grep -oP '^v?[0-9]+\.[0-9]+\.[0-9]+$') " # needs the empty space after the ) before the " so gets split by tr 2 lines bellow
    done
    latest_version_in_registry=$(echo "$versions_in_registry" | tr ' ' "\n" | sort --version-sort | tail -n 1)

    # the magic
    [ -n "$latest_version_in_registry" ] && versions_magic
done

# microsoft mcr
versions_mcr=$(yq '.services[].image' ./*compose*.y* | grep mcr.microsoft.com | sort | uniq)
for version in $versions_mcr
do
    latest_version_in_registry=""

    [[ $version =~ mcr.microsoft.com\/(.*)\:(.*) ]]
    image=${BASH_REMATCH[1]}
    v_rematched=${BASH_REMATCH[2]}
    echo "image: $image, v: $v_rematched"
    
    latest_version_in_registry="$(curl -s https://mcr.microsoft.com/v2/$image/tags/list | jq -r '.tags[]' | sort -V -t. -k1,1 -k2,2 -k3,3 | grep -oP '^v?[0-9]+\.[0-9]+\.[0-9]+$' | tail -n 1)"

    # the magic
    [ -n "$latest_version_in_registry" ] && versions_magic
done

# considerations "how to edit/contribute"
# add each new registry in a separated block loop as per the existing ones
# authentication happens via env_vars in the action block if required
# follow the pattern of "latest_version_in_registry" var as as sole tag for evaluation logic following rematch
# consider the impact on all registries when modifiying the "versions_magic" function
