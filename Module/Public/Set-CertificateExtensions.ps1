<#
.SYNOPSIS
    Sets CSR extension attributes for Puppet agent requests
.DESCRIPTION
    Sets CSR extension attributes for Puppet agent requests
.EXAMPLE
    Set-CertificateRequestExtension @{pp_service = 'sqlserver'; pp_role = 'mysql'}
    
    This would set the pp_service and pp_role certificate extension attributes
#>
function Set-CertificateExtensions
{
    [CmdletBinding()]
    param
    (
        # The extension attributes to be set
        [Parameter(Mandatory = $true, Position = 0)]
        [hashtable]
        $ExtensionAttributes
    )
    
    begin
    {
        $ppRegCertExtShortNames = @(
            'pp_uuid',
            'pp_uuid',
            'pp_instance_id',
            'pp_image_name',
            'pp_preshared_key',
            'pp_cost_center',
            'pp_product',
            'pp_project',
            'pp_application',
            'pp_service',
            'pp_employee',
            'pp_created_by',
            'pp_environment',
            'pp_role',
            'pp_software_version',
            'pp_department',
            'pp_cluster',
            'pp_provisioner',
            'pp_region',
            'pp_datacenter',
            'pp_zone',
            'pp_network',
            'pp_securitypolicy',
            'pp_cloudplatform',
            'pp_apptier',
            'pp_hostname'
        )
        $ppAuthCertExtShortNames = @(
            'pp_authorization',
            'pp_auth_role'
        )
        $ValidExtensionShortNames = $ppRegCertExtShortNames + $ppAuthCertExtShortNames
    }
    
    process
    {
        $CSRYamlContent = "extension_requests:`n"
        # Make sure they are all valid
        $ExtensionAttributes.GetEnumerator() | ForEach-Object {
            if ($_.Key -notin $ValidExtensionShortNames)
            {
                throw "Invalid extension short name: $($_.Key)"
            }
            $CSRYamlContent += "    $($_.Key): $($_.Value)`n"
        }
        # Things are in different places depending on OS
        if ($IsLinux -or $IsMacOS)
        {
            $CSRYamlPath = "/etc/puppetlabs/puppet/csr_attributes.yaml"
        }
        if ($IsWindows)
        {
            $CSRYamlPath = "C:\ProgramData\PuppetLabs\puppet\etc\csr_attributes.yaml"
        }
        # Write the file, we set force so it always overwrites even if it already exists
        New-Item $CSRYamlPath -Force -ItemType File -Value $CSRYamlContent
    }
    
    end
    {
        
    }
}