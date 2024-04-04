# Changelog

All notable changes to this project will be documented in this file.
This changelog follows the [SemVer v1.0.0 spec](https://semver.org/spec/v1.0.0.html)

## Release

### [v0.1.4](https://github.com/Brownserve-UK/PuppetPowerShell/tree/v0.1.4) (2022-10-07)

**Features**
These are the changes that have been made since the last release:

- Install the `lsb-release` package on Debian based systems if it is not present. This package is needed so that we can determine the correct version of Puppet to install and on some forks (e.g. Proxmox) it is not installed by default.
- Bump Windows build/test tasks to use the latest version of the Docker container

**Bugfixes**
The following bugs have been closed since the last release:

- Fixes [#7](https://github.com/Brownserve-UK/PuppetPowerShell/issues/7)

**Known Issues**
N/A

### [v0.1.3](https://github.com/Brownserve-UK/PuppetPowerShell/tree/v0.1.3) (2021-11-22)

**Features**
These are the changes that have been made since the last release:

- Set newlines on csr_attributes.yaml

**Bugfixes**
The following bugs have been closed since the last release:

- Fixes csr_attributes.yaml being incorrectly formatted

**Known Issues**
N/A

### [v0.1.2](https://github.com/Brownserve-UK/PuppetPowerShell/tree/v0.1.2) (2021-11-21)

**Features**
These are the changes that have been made since the last release:

- Ensures dependencies are present when installing Puppetserver

**Bugfixes**
N/A

**Known Issues**
N/A

### [v0.1.1](https://github.com/Brownserve-UK/PuppetPowerShell/tree/v0.1.1) (2021-11-19)

**Features**
These are the changes that have been made since the last release:

- Fixes initial release credentials

**Bugfixes**
N/A

**Known Issues**
N/A

### [v0.1.0](https://github.com/Brownserve-UK/PuppetPowerShell/tree/v0.1.0) (2021-11-15)

**Features**
These are the changes that have been made since the last release:

- First release of the module!

**Bugfixes**
N/A

**Known Issues**
N/A
