# Query to see if the image already exists, and build it if it doesn't
image=`docker images --filter "reference=tsheets" --format "{{.Repository}}"`

if [[ -z $image ]]; then
  docker build --tag=tsheets:apidocs ${PWD}
fi

# Start the container
docker run --name=apidocs -d tsheets:apidocs

# Copy the source files into the container
docker cp ${PWD}/source/. apidocs:/usr/src/app/source

# Execute the build
docker exec -w /usr/src/app/source apidocs bundle exec middleman build --clean --verbose

# Copy the build outputs from the container to a local directory
docker cp apidocs:/usr/src/app/build/. ${PWD}/build

# Stop the container and remove it
docker stop --time=0 apidocs
docker rm apidocs

echo Navigate to ${PWD}/build/index.html in a browser.