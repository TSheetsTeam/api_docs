# Query to see if the image already exists, and build it if it doesn't
image=`podman images --filter "reference=tsheets" --format "{{.Repository}}"`

if [[ -z $image ]]; then
  podman build --tag=tsheets:apidocs ${PWD}
fi

# Start the container
podman run --name=apidocs -d tsheets:apidocs

# Copy the source files into the container
podman cp ${PWD}/source/. apidocs:/usr/src/app/source

# Execute the build
podman exec -w /usr/src/app/source apidocs bundle exec middleman build --clean --verbose

# Copy the build outputs from the container to a local directory
podman cp apidocs:/usr/src/app/build/. ${PWD}/build

# Stop the container and remove it
podman stop --time=0 apidocs
podman rm apidocs

echo Opening ${PWD}/build/index.html in a browser.
open ${PWD}/build/index.html
