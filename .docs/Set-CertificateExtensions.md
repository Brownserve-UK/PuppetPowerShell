---
external help file: PuppetPowerShell-help.xml
Module Name: PuppetPowerShell
online version:
schema: 2.0.0
---

# Set-CertificateExtensions

## SYNOPSIS
Sets CSR extension attributes for Puppet agent requests

## SYNTAX

```
Set-CertificateExtensions [-ExtensionAttributes] <Hashtable> [<CommonParameters>]
```

## DESCRIPTION
Sets CSR extension attributes for Puppet agent requests, this can be useful when trying to more specifically scope node configurations

## EXAMPLES

### EXAMPLE 1
```
Set-CertificateRequestExtension @{pp_service = 'sqlserver'; pp_role = 'mysql'}
```

This would set the pp_service and pp_role certificate extension attributes

## PARAMETERS

### -ExtensionAttributes
The extension attributes to be set

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
