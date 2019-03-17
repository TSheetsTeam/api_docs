@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

SET me=%~nx0

SET help_message=^

Usage: !me! [-c FILE] [^<options^>]^

Deploy generated files to a git branch.^

^

Options:^

^

  -h, --help               Show this help information.^

  -v, --verbose            Increase verbosity. Useful for debugging.^

  -e, --allow-empty        Allow deployment of an empty directory.^

  -m, --message MESSAGE    Specify the message used when committing on the^

                           deploy branch.^

  -n, --no-hash            Don't append the source commit's hash to the deploy^

                           commit's message.^

      --source-only        Only build but not push^

      --push-only          Only push but not build

IF "%1%" == "--source-only" (
  CALL :run_build
) ELSE (
  IF "%1%" == "--push-only" (
    CALL :main %*
  ) ELSE (
    CALL :run_build
    CALL :main %*
  )
)

EXIT /B %ERRORLEVEL%


:run_build
  :: Start the container
  docker run --name=apidocs -d tsheets:apidocs 1>nul

  :: Copy the source files into the container
  docker cp %cd%\source\. apidocs:/usr/src/app/source

  :: Execute the build
  docker exec -w /usr/src/app/source apidocs bundle exec middleman build --clean --verbose

  :: Copy the build outputs from the container to a local directory
  docker cp apidocs:/usr/src/app/build/. %cd%\build

  :: Stop the container and remove it
  docker stop --time=0 apidocs 1>nul
  docker rm apidocs 1>nul

  EXIT /B 0


:parse_args
  :: append commit hash to the end of message by default
  SET append_hash=true

  :loop
  IF "%~1" NEQ "" (

    SET help_needed=
    IF "%1%" == "-h" (SET help_needed=true)
    IF "%1%" == "--help" (SET help_needed=true)

    SET verbose_enabled=
    IF "%1%" == "-v" (SET verbose_enabled=true)
    IF "%1%" == "--verbose" (SET verbose_enabled=true)

    SET allow_empty_enabled=
    IF "%1%" == "-e" (SET allow_empty_enabled=true)
    IF "%1%" == "--allow-empty" (SET allow_empty_enabled=true)

    SET is_message=
    IF "%1%" == "-m" (SET is_message=true)
    IF "%1%" == "--message" (SET is_message=true)

    SET no_hash_enabled=
    IF "%1%" == "-n" (SET no_hash_enabled=true)
    IF "%1%" == "--no-hash" (SET no_hash_enabled=true)

    IF DEFINED help_needed (
      ECHO !help_message!
      EXIT /B 0
    )

    IF DEFINED verbose_enabled (
      SET verbose=true
    )

    IF DEFINED allow_empty_enabled (
      SET allow_empty=true
    )      

    IF DEFINED is_message (
      SET commit_message=%2%
      shift
    )

    IF DEFINED no_hash_enabled (
      SET append_hash=
    )     

    shift
    goto :loop
  )

  :: Source directory & target branch.
  SET deploy_directory=build
  SET deploy_branch=gh-pages

  :: repository to deploy to. must be readable and writable.
  SET repo=origin

  EXIT /B 0


:main
  CALL :parse_args %*

  CALL :enable_expanded_output

  CALL git diff --exit-code --quiet
  ::IF %ERRORLEVEL% NEQ 0 (
    ::ECHO Aborting due to uncommitted changes in the index >&2
    ::EXIT /B %ERRORLEVEL%
  ::)

  git log -n 1 --format="%%s" HEAD>temp
  SET /P commit_title=<temp
  DEL temp

  git log -n 1 --format="%%H" HEAD>temp
  SET /P commit_hash=<temp
  DEL temp

  :: default commit message uses last title if a custom one is not supplied
  IF NOT DEFINED commit_message (
    SET commit_message=publish: %commit_title%
  )

  :: append hash to commit message unless no hash flag was found
  IF DEFINED append_hash (
    SET commit_message=%commit_message% generated from commit %commit_hash%
  )

  git rev-parse --abbrev-ref HEAD>temp
  SET /P previous_branch=<temp
  DEL temp

  IF NOT exist %deploy_directory% (
    echo Deploy directory '%deploy_directory%' does not exist. Aborting. >&2
    EXIT /B 1
  )

  dir /b /a "%deploy_directory%" | findstr . > nul || (
    IF NOT DEFINED allow-empty (
      echo Deploy directory '%deploy_directory%' is empty. Aborting. If you're sure you want to deploy an empty tree, use the --allow-empty / -e flag. >&2
      EXIT /B 1
    )
  )

  CALL git ls-remote --quiet --exit-code %repo% "refs/heads/%deploy_branch%" 1>nul
  IF %ERRORLEVEL% == 0 (
    :: deploy_branch exists in repo; make sure we have the latest version
    CALL :disable_expanded_output
    git fetch --quiet --force %repo% %deploy_branch%:%deploy_branch%
    CALL :enable_expanded_output
  )  

  :: check if deploy_branch exists locally
  CALL git show-ref --verify --quiet "refs/heads/%deploy_branch%"
  IF %ERRORLEVEL% == 0 (
    CALL :incremental_deploy
  ) ELSE (
    CALL :initial_deploy
  )

  CALL :restore_head

  echo Deployment Complete.

  EXIT /B 0


:initial_deploy
  CALL git --work-tree "%deploy_directory%" checkout --orphan %deploy_branch%
  CALL git --work-tree "%deploy_directory%" add --all

  CALL :commit_push
  EXIT /B 0


:incremental_deploy
  :: make deploy_branch the current branch
  CALL git symbolic-ref HEAD refs/heads/%deploy_branch%

  :: put the previously committed contents of deploy_branch into the index
  CALL git --work-tree "%deploy_directory%" reset --mixed --quiet
  CALL git --work-tree "%deploy_directory%" add --all

  CALL git --work-tree "%deploy_directory%" diff --exit-code --quiet HEAD --
  IF %ERRORLEVEL% == 0 (
    echo No changes to files in %deploy_directory%. Skipping commit.
  ) ELSE (
    IF %ERRORLEVEL% == 1 (
      CALL :commit_push
    ) ELSE (
      echo git diff exited with code %ERRORLEVEL%. Aborting. Staying on branch %deploy_branch% so you can debug. To switch back to master, use: git symbolic-ref HEAD refs/heads/master && git reset --mixed >&2
      EXIT /B %ERRORLEVEL%
    )
  )

  EXIT /B 0


:commit_push
  CALL git --work-tree "%deploy_directory%" commit -m "%commit_message%"

  CALL :disable_expanded_output
  :: --quiet is important here to avoid outputting the repo URL, which may contain a secret token
  CALL git push --quiet %repo% %deploy_branch%
  CALL :enable_expanded_output

  EXIT /B 0


:enable_expanded_output
  IF DEFINED verbose (
    @echo on
  )
  EXIT /B 0


:disable_expanded_output
  IF DEFINED verbose (
    @echo off
  )
  EXIT /B 0

:restore_head
  IF "%previous_branch%" == "HEAD" (
    :: we weren't on any branch before, so just set HEAD back to the commit it was on
    CALL git update-ref --no-deref HEAD %commit_hash% %deploy_branch%
  ) ELSE (
    CALL git symbolic-ref HEAD refs/heads/%previous_branch%
  )

  CALL git reset --mixed
  EXIT /B 0
