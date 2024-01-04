#!/bin/bash

# Updates compose service versions.

default_branch="${1:-main}"
prs="${2:-generate}"
# generate $skip_patterns
IFS=',' read -ra skip_patterns <<< "$3"
# generate $ignore_patterns
IFS=',' read -ra ignore_patterns <<< "$4"

# branching, pr, senver compare and sed logic

ignore_check() {
    for ignore_pattern in "${ignore_patterns[@]}"
    do
        echo "checking ignore_pattern: $ignore_pattern for image: $image"
        # this might be to wide and catch more than expected but it's a start
        if [[ "$image" == *"$ignore_pattern"* ]]
        then
            ignore=true
            break
        fi
    done
}

skip_check() {
    for skip_pattern in "${skip_patterns[@]}"
    do
        echo "checking skip_pattern: $skip_pattern for image: $image:$latest_version_in_registry"
        if [[ "$image:$latest_version_in_registry" == *"$skip_pattern"* ]]
        then
            skip=true
            break
        fi
    done
}


versions_magic() {
    skip=false
    if [ "$latest_version_in_registry" != "$v_rematched" ] && [ "$prs" = "generate" ]
    then
        skip_check # check if image is in skip_patterns and break
        if $skip
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
    else
        echo "debug: prs=$prs, latest_version_in_registry=$latest_version_in_registry, v_rematched=$v_rematched, skip_patterns=${skip_patterns[*]}"
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

    ignore=false
    ignore_check # check if image is in ignore_patterns and break
    if $ignore
    then
        break
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
    
    ignore=false
    ignore_check # check if image is in ignore_patterns and break
    if $ignore
    then
        break
    fi

    latest_version_in_registry="$(curl -s https://mcr.microsoft.com/v2/$image/tags/list | jq -r '.tags[]' | sort -V -t. -k1,1 -k2,2 -k3,3 | grep -oP '^v?[0-9]+\.[0-9]+\.[0-9]+$' | tail -n 1)"

    # the magic
    [ -n "$latest_version_in_registry" ] && versions_magic
done

# google gcr
versions_gcr=$(yq '.services[].image' ./*compose*.y* | grep gcr.io | sort | uniq)
for version in $versions_gcr
do
    latest_version_in_registry=""

    [[ $version =~ gcr.io\/(.*)\:(.*) ]]
    image=${BASH_REMATCH[1]}
    v_rematched=${BASH_REMATCH[2]}
    echo "image: $image, v: $v_rematched"
    
    ignore=false
    ignore_check # check if image is in ignore_patterns and break
    if $ignore
    then
        break
    fi

    latest_version_in_registry="$(curl -s https://gcr.io/v2/$image/tags/list | jq -r '.tags[]' | sort -V -t. -k1,1 -k2,2 -k3,3 | grep -oP '^v?[0-9]+\.[0-9]+\.[0-9]+$' | tail -n 1)"

    # the magic
    [ -n "$latest_version_in_registry" ] && versions_magic
done

# github ghcr
versions_ghcr=$(yq '.services[].image' ./*compose*.y* | grep ghcr.io | sort | uniq)
for version in $versions_ghcr
do
    latest_version_in_registry=""

    [[ $version =~ ghcr.io\/(.*)\:(.*) ]]
    image=${BASH_REMATCH[1]}
    v_rematched=${BASH_REMATCH[2]}
    echo "image: $image, v: $v_rematched"
    
    ignore=false
    ignore_check # check if image is in ignore_patterns and break
    if $ignore
    then
        break
    fi

    # TODO: Private repos require authentication with a PAT or github token
    # ghcr_token=$(echo $GITHUB_TOKEN | base64)
    
    ghcr_token=$(curl -s https://ghcr.io/token\?scope\="repository:$image:pull" | jq -r .token)
    latest_version_in_registry="$(curl -H "Authorization: Bearer ${ghcr_token}" -s https://ghcr.io/v2/$image/tags/list | jq -r '.tags[]' | sort -V -t. -k1,1 -k2,2 -k3,3 | grep -oP '^v?[0-9]+\.[0-9]+\.[0-9]+$' | tail -n 1)"

    # the magic
    [ -n "$latest_version_in_registry" ] && versions_magic
done

# considerations "how to edit/contribute"
# add each new registry in a separated block loop as per the existing ones
# authentication happens via env_vars in the action block if required
# follow the pattern of "latest_version_in_registry" var as as sole tag for evaluation logic following rematch
# consider the impact on all registries when modifiying the "versions_magic" function
