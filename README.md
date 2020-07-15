# art-cli

## Why?

Tool to run and organize scripts in hierarchy with single entry point.

### Features

- Script is just a script.
- Flat namespace mean that all virtual script paths should be unique globally.
- All scripts is near your project files but available in any CLI context globally.
- Organize scripts in virtual hierarchy per projects with flat namespace.
- Virtual paths reflection allow to view all available scripts per projects:
  - If specify the script path - `art-cli` run the script with parameters
  - If specify the script folder path - `art-cli` display the all available scripts for this path.

### Example

Files structure: `/opt/art/p` - workspace root with project folders (may contain a symbolic links).

```text
project1       <-- your first project folder
  ...
  art-cli      <-- tool folder (by convention all your project related scripts is here)
    tools      <-- custom folder
      a        <-- script
      b        <-- script
      deploy   <-- custom folder
        dev    <-- script
        prod   <-- script
...
project2       <-- your next project folder
  ...
  art-cli      <-- tool folder
    apps       <-- custom folder
      run      <-- script
    configure  <-- script
```

#### Run `art`

Observe all available commands from root.

```bash
user@ubuntu:~$ art
[art-cli]
1) art . env
2) art . help
3) art . projects
4) art . version

[project1]
1) * art tools - 4 command(s)

[project2]
1) * art apps - 1 command(s)
2) . art configure
```

#### Run `art tools`

Observe all available commands for `tools` path.

```bash
user@ubuntu:~$ art tools
[project1]
1) . art tools/a
2) . art tools/b
3) * art tools/deploy - 2 command(s)
```

#### Run `art tools/deploy`

Observe all available commands for `tools/deploy` path.

```bash
user@ubuntu:~$ art tools/deploy
[project1]
1) art . tools/deploy/dev
2) art . tools/deploy/prod
```

#### Run `art/apps`

Observe all available commands for `apps` path.

```bash
user@ubuntu:~$ art apps
[project2]
1) art . apps/run
```

## Setup

### Install

`curl -s https://raw.githubusercontent.com/art-ws/art-cli/master/install.sh | bash -`

### Uninstall

`curl -s https://raw.githubusercontent.com/art-ws/art-cli/master/uninstall.sh | bash -`

### Requirements

- [Git](https://git-scm.com/download/linux)
- [Ubuntu](https://ubuntu.com/download)
