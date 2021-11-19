---
external help file: PuppetPowerShell-help.xml
Module Name: PuppetPowerShell
online version:
schema: 2.0.0
---

# Set-PuppetConfigOption

## SYNOPSIS
Sets Puppet configuration options.

## SYNTAX

```
Set-PuppetConfigOption [-ConfigOptions] <Hashtable> [[-ConfigFilePath] <String>] [[-Section] <String>]
 [-Elevated] [<CommonParameters>]
```

## DESCRIPTION
This cmdlet allows you to set Puppet configuration options en masse by supplying 
a hash of configuration options.
You can also choose the location of the puppet.conf file to use and a specific section to set
the options under.

## EXAMPLES

### EXAMPLE 1
```
Set-PuppetConfigOption @{environment = 'production'}
```

This would set the environment to 'production' in the puppet.conf file.

## PARAMETERS

### -ConfigFilePath
The path to the configuration file (if not using the default)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ConfigOptions
The option(s) to set

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Elevated
On *nix systems the 'puppet' command requires elevation, set this parameter to prefix the command with 'sudo'

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Section
The section that you wish to set the options in (defaults to 'agent')

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: Agent
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Puppet does not validate the options your are setting are valid, and neither does this cmdlet.

## RELATED LINKS
