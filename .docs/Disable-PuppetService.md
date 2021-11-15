---
external help file: PuppetPowerShell-help.xml
Module Name: PuppetPowerShell
online version:
schema: 2.0.0
---

# Disable-PuppetService

## SYNOPSIS
Disables the Puppet service on a machine

## SYNTAX

```
Disable-PuppetService [[-ServiceName] <String>] [<CommonParameters>]
```

## DESCRIPTION
Very basic function for quickly stopping and disabling the Puppet agent service on a machine.  
Useful when you need to temporarily disable the Puppet agent service to make local changes.

## EXAMPLES

### EXAMPLE 1
```
Disable-PuppetService
```

This would disable the Puppet service on the local machine and make sure it is stopped

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
The primary use case is for quickly stopping Puppet on a system to make sure it doesn't overwrite local changes.

## RELATED LINKS
