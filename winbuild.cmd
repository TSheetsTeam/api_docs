@echo off
SETLOCAL

REM Query to see if the image already exists, and build it if it doesn't
FOR /F "tokens=*" %%a in ('docker images --filter "reference=tsheets" --format "{{.Repository}}"') do SET image=%%a

set buildNewImage=
IF NOT DEFINED image set buildNewImage=true
IF "%1" == "-c" set buildNewImage=true

IF DEFINED buildNewImage (
  docker build --tag=tsheets:apidocs %cd%
)

REM Start the container
docker run --name=apidocs -d tsheets:apidocs 1>nul

REM Copy the source files into the container
docker cp %cd%\source\. apidocs:/usr/src/app/source

REM Execute the build
docker exec -w /usr/src/app/source apidocs bundle exec middleman build --clean --verbose

REM Copy the build outputs from the container to a local directory
docker cp apidocs:/usr/src/app/build/. %cd%\build

REM Stop the container and remove it
docker stop --time=0 apidocs 1>nul
docker rm apidocs 1>nul

echo Navigate to %cd%\build\index.html in a browser.

