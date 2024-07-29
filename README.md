# Hotvox Docker Dependencies
This repository consists of git submodules linking to other projects we use across our ecosystem.

There is one build.sh script that when run:
1. Ensures the submodules are set to their default branches
2. Ensures the submodules have no diverging changes
3. Builds the submodules into docker images using their Dockerfiles
4. Pushes those docker images to our organizations Docker Hub