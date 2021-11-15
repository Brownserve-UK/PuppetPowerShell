# Contributing
Pull requests are welcome but please bear in mind that these tools are designed to work in Brownserve-UK workflows.

We'd ask that you follow the styling used throughout the module and write notes where applicable.

## Update help files
Our public cmdlets/functions **must** have help documentation, it's a requirement to build the module successfully.  
We use [platyPS](https://github.com/PowerShell/platyPS) (the same tool Microsoft use) to help generate our help documentation.  
This allows us to create Markdown based help files in the `.docs` directory which are much easier to read for us humans, then have platyPS generate the module's XML MAML documentation from these Markdown files.

Our `_init.ps1` script contains some helper functions for creating/updating documentation:
```powershell
Update-Documentation
Update-ModuleHelp
```
The first function will create/update all the Markdown help in the `.docs` directory and the second will update the module's XML MAML help file.