#!/bin/bash

# Get the directory of this script to refer to relative paths
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Set the tag to the current unix timestamp
TAG=$(date +%s)

# Function to pull the latest git changes for the project
pull_latest() {
    local project_dir=$1
    local repo_name
    repo_name=$(basename "$project_dir")
    if [ -z "$project_dir" ]; then
        echo "Please provide the project directory"
        return 1
    fi

    # Check if the directory exists
    if [ ! -d "$project_dir" ]; then
        echo "Directory $project_dir does not exist"
        return 1
    fi

    # Check if the repo_name is submodule of the main repository (located at $DIR)
    if ! git -C "$DIR" submodule status "$repo_name" | grep -q "$repo_name"; then
        echo "$repo_name is not a submodule of the main repository"
        return 1
    fi

    # Get the name of the default branch for the repository
    local default_branch
    default_branch=$(git -C "$project_dir" remote show origin | grep "HEAD branch" | cut -d ":" -f 2 | xargs)
    if [ -z "$default_branch" ]; then
        echo "Failed to determine the default branch for $project_dir"
        return 1
    fi

    # Check that the branch is set to the default branch
    local current_branch
    current_branch=$(git -C "$project_dir" rev-parse --abbrev-ref HEAD)
    if [ "$current_branch" != "$default_branch" ]; then
        echo "Branch is not set to $default_branch in $project_dir"
        return 1
    fi

    # Check that there are no uncommitted changes
    if ! git -C "$project_dir" diff --quiet; then
        echo "There are uncommitted changes in $project_dir"
        return 1
    fi

    # Check that there are no untracked files
    if [ -n "$(git -C "$project_dir" ls-files --others --exclude-standard)" ]; then
        echo "There are untracked files in $project_dir"
        return 1
    fi

    # Check that there are no unpushed changes
    if [ -n "$(git -C "$project_dir" log "origin/$default_branch..HEAD")" ]; then
        echo "There are unpushed changes in $project_dir"
        return 1
    fi

    if ! git -C "$project_dir" pull; then
        echo "Failed to pull the latest changes in $project_dir"
        return 1
    fi
}

# Function to build the docker image with the latest source code
build_latest() {
    local project_dir=$1
    local image_name=$2
    local dockerfile_path=$3
    local docker_context=$4 # Optional

    if [ -z "$project_dir" ]; then
        echo "Please provide the project directory"
        return 1
    fi

    if [ ! -d "$project_dir" ]; then
        echo "Directory $project_dir does not exist"
        return 1
    fi

    if [ -z "$image_name" ]; then
        echo "Please provide the Docker image name"
        return 1
    fi

    if [ -z "$dockerfile_path" ]; then
        echo "Please provide the path to the Dockerfile"
        return 1
    fi

    if [ ! -f "$dockerfile_path" ]; then
        echo "Dockerfile does not exist at $dockerfile_path"
        return 1
    fi

    # Set the docker context to the project directory if not provided
    if [ -z "$docker_context" ]; then
        docker_context="$project_dir"
    fi

    # Ensure the docker context is either the project directory or a subdirectory
    if [ "${docker_context:0:${#project_dir}}" != "$project_dir" ]; then
        echo "Docker context must be the project directory or a subdirectory"
        return 1
    fi

    # Ensure the project is up to date
    if ! pull_latest "$project_dir"; then
        return 1
    fi

    if ! docker buildx build --platform linux/amd64 --push -t "$image_name:$TAG" -f "$dockerfile_path" "$docker_context"; then
        echo "Failed to build the Docker image for $project_dir"
        return 1
    fi
}

# glances
build_latest "$DIR/glances"         "hotvox/glances"        "$DIR/glances/docker-files/ubuntu.Dockerfile" || exit 1

# homepage
build_latest "$DIR/homepage"        "hotvox/homepage"       "$DIR/homepage/Dockerfile" || exit 1

# pi-gen
build_latest "$DIR/pi-gen"          "hotvox/pi-gen"         "$DIR/pi-gen/Dockerfile" || exit 1

# nginx
build_latest "$DIR/docker-nginx"    "hotvox/nginx"          "$DIR/docker-nginx/stable/debian/Dockerfile"    "$DIR/docker-nginx/stable/debian" || exit 1

# anything-llm
build_latest "$DIR/anything-llm"    "hotvox/anything-llm"   "$DIR/anything-llm/docker/Dockerfile" || exit 1

# completed
echo "Builds completed and pushed successfully. 🎉"