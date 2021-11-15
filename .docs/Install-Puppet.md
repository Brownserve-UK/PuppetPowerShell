---
external help file: PuppetPowerShell-help.xml
Module Name: PuppetPowerShell
online version:
schema: 2.0.0
---

# Install-Puppet

## SYNOPSIS
Installs Puppet tooling on a machine

## SYNTAX

```
Install-Puppet [[-MajorVersion] <Int32>] [[-ExactVersion] <Version>] [[-Application] <String>]
 [<CommonParameters>]
```

## DESCRIPTION
Installs the requested version of Puppet agent/server/bolt for your operating system.
You can either specify the major version that you want installed whereby the latest version for that release will be installed,
or you can specify a specific version.
(e.g. 6.10.2)

## EXAMPLES

### EXAMPLE 1
```
Install-Puppet -MajorVersion 6
```

This would install the latest version of Puppet 6 agent for your operating system.

### EXAMPLE 2
```
Install-Puppet -ExactVersion 6.10.2 -Application 'puppetserver'
```

This would install Puppet server 6.10.2 for your operating system.

### EXAMPLE 3
```
Install-Puppet -Application 'puppet-bolt'
```

This would install the latest version of Puppet bolt for your operating system.

## PARAMETERS

### -Application
Whether to install Puppet server or Puppet agent

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: Puppet-agent
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExactVersion
The specific version of Puppet agent to install

```yaml
Type: Version
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MajorVersion
The major version of Puppet agent to install

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
