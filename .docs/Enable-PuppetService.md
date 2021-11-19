---
external help file: PuppetPowerShell-help.xml
Module Name: PuppetPowerShell
online version:
schema: 2.0.0
---

# Enable-PuppetService

## SYNOPSIS
Enables the Puppet service on a machine

## SYNTAX

```
Enable-PuppetService [[-ServiceName] <String>] [<CommonParameters>]
```

## DESCRIPTION
Very basic function for quickly starting and enabling the Puppet agent service at boot on a machine.

## EXAMPLES

### EXAMPLE 1
```
Enable-PuppetService
```

This would enable the Puppet service on the local machine and make sure it is running

## PARAMETERS

### -ServiceName
The name of the Puppet service

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: Puppet
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
This is a very simple cmdlet made purely for convenience and is rather rough around the edges.
The intended use case is for reenabling the Puppet service after making changes to a local node.

## RELATED LINKS
