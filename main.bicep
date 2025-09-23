// Before script execution, create a resource group in the azure subscription "rg-avd-prod-01", then start azure cloud shell and upload files with folder structure
// Deployment parameters
@description('Location to depoloy all resources. Leave this value as-is to inherit the location from the parent resource group.')
param location string = 'germanywestcentral'

// Virtual network parameters. Change "virtualNetworkAddressSpace" and corresponding "subnetAddressRange" to fit your needs.
@description('Name for the virtual network.')
param virtualNetworkName string = 'vnet-avd-prod-01'
@description('Address space for the virtual network, in IPv4 CIDR notation.')
param virtualNetworkAddressSpace string = '10.0.0.0/16'
@description('Name for the default subnet in the virtual network.')
param subnetName string = 'default-subnet'
@description('Address range for the default subnet, in IPv4 CIDR notation.')
param subnetAddressRange string = '10.0.0.0/24'
@description('Public IP address of your local machine, in IPv4 CIDR notation. Used to restrict remote access to resources within the virtual network.')
param allowedSourceIPAddress string = '0.0.0.0/0'

// nat gateway parameters
param natGatewayName string = 'natgw-az-prod-01'
param natPublicIpName string = 'pip-natgw-prod-01'

// Virtual machine parameters for domain controller
@description('Name for the domain controller virtual machine.')
param domainControllerName string = 'vm-dc-prod-01'

// Virtual machine size for the domain controller
@description('Virtual machine size for the domain controller.')
@allowed([
  'Standard_D2s_v6'
])
param virtualMachineSizeDC string = 'Standard_D2s_v6'

// Domain parameters
// Domain names like "ad.contoso.local" are not supported. Use a simple domain like "contoso.local" instead.
// Always use .local as the top-level domain
@description('FQDN for the Active Directory domain (e.g. contoso.local).')
@minLength(3)
@maxLength(255)
param domainFQDN string = 'OUCICW.local' //change domain here. Use simple domain like "contoso.local" instead of "ad.contoso.local". Always use .local as the top-level domain
// currently not used
//param domainSuffix string = 'contoso.com'

// AVD parameters. Default is avd session host with pre-installed office suite. If you want to use a different image, change the "avdSessionHostOffer" and "avdSessionHostSku" parameters.
param avdHostPoolName string = 'avd-hostpool-prod-01'
param avdRegistrationExpirationTime string = dateTimeAdd(utcNow(), 'P7D')
param avdSessionHostPrefix string = 'sh-'
param avdSessionHostCount int = 1 // Number of AVD session hosts to deploy. Change this value to fit your needs.
param avdSessionHostSize string = 'Standard_D2s_v6'
param avdSessionHostPublisher string = 'MicrosoftWindowsDesktop'
param avdSessionHostOffer string = 'office-365' // change to 'windows-11' for a vanilla Windows 11 image with param avdSessionHostSku
param avdSessionHostSku string = 'win11-24h2-avd-m365'  // change to 'win11-24h2-pro' for a vanilla Windows 11 image
param avdSessionHostVersion string = 'latest'
param avdSessionHostStorageAccountType string = 'StandardSSD_LRS'
param avdworkspaceName string = 'avd-workspace-prod-01'
param avdappGroupName string = 'avd-appgroup-prod-01'
param avdmaxSessionLimit int = 4 // Maximum number of concurrent sessions per AVD session host. Change this value to fit your needs.

@description('Administrator username for both the domain controller and workstation virtual machines.')
@minLength(1)
@maxLength(20)
param adminUsername string = 'adminala' // Change this value to fit your needs. Do not use "admin" or "administrator" as the username, as these are reserved usernames in Azure.

// You will need to set a strong password for the administrator account. The password must be at least 12 characters long and contain a mix of uppercase and lowercase letters, numbers, and special characters.
// The password must not contain the username or parts of the username, and it must not be a commonly used password.
// The password must not contain the domain name or parts of the domain name.
// The password must not contain the word "password" or any variations of it.
// The password must not contain the word "admin" or any variations of it.
// The password must not contain the word "administrator" or any variations of it.
@description('Administrator password for both the domain controller and workstation virtual machines.')
@minLength(12)
@maxLength(123)
@secure()
param adminPassword string

// storage Account parameters
param storageAccountName string = 'storage${uniqueString(resourceGroup().id, deployment().name)}'

// Deploy the virtual network
module virtualNetwork 'modules/network.bicep' = {
  name: 'virtualNetwork'
  params: {
    location: location
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressSpace: virtualNetworkAddressSpace
    subnetName: subnetName
    subnetAddressRange: subnetAddressRange
    allowedSourceIPAddress: allowedSourceIPAddress
    natGatewayName: natGatewayName
    natPublicIpName: natPublicIpName
  }
}

// Deploy the domain controller
module domainController 'modules/vm.bicep' = {
  name: 'domainController'
  params: {
    location: location
    subnetId: virtualNetwork.outputs.subnetId
    vmName: domainControllerName
    vmSize: virtualMachineSizeDC
    vmPublisher: 'MicrosoftWindowsServer'
    vmOffer: 'WindowsServer'
    vmSku: '2022-datacenter-g2'
    vmVersion: 'latest'
    vmStorageAccountType: 'StandardSSD_LRS'
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

// Use PowerShell DSC to deploy Active Directory Domain Services on the domain controller
resource domainControllerConfiguration 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  name: '${domainControllerName}/Microsoft.Powershell.DSC'
  dependsOn: [
    domainController
  ]
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.77'
    autoUpgradeMinorVersion: true
    settings: {
      ModulesUrl: 'https://github.com/alangerotaouh/avd/raw/refs/heads/main/Deploy-DomainServices.zip'
      ConfigurationFunction: 'Deploy-DomainServices.ps1\\Deploy-DomainServices'
      Properties: {
        domainFQDN: domainFQDN
        //domainSuffix: domainSuffix
        adminCredential: {
          UserName: adminUsername
          Password: 'PrivateSettingsRef:adminPassword'
        }
      }
    }
    protectedSettings: {
      Items: {
          adminPassword: adminPassword
      }
    }
  }
}

// Update the virtual network with the domain controller as the primary DNS server
module virtualNetworkDNS 'modules/network.bicep' = {
  name: 'virtualNetworkDNS'
  dependsOn: [
    domainControllerConfiguration
  ]
  params: {
    location: location
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressSpace: virtualNetworkAddressSpace
    subnetName: subnetName
    subnetAddressRange: subnetAddressRange
    allowedSourceIPAddress: allowedSourceIPAddress
    dnsServerIPAddress: domainController.outputs.privateIpAddress
    natGatewayName: natGatewayName
    natPublicIpName: natPublicIpName
  }
}


// Deploy AVD Host Pool
module avdHostPool 'modules/avdHostPool.bicep' = {
  name: 'avdHostPool'
  dependsOn: [ virtualNetworkDNS ]
  params: {
    //location: location
    hostPoolName: avdHostPoolName
    hostPoolFriendlyName: avdHostPoolName
    hostPoolType: 'Pooled'
    loadBalancerType: 'BreadthFirst'
    maxSessionLimit: avdmaxSessionLimit
    registrationInfoExpirationTime: avdRegistrationExpirationTime
    personalDesktopAssignmentType: 'Desktop'
    hostPoolDescription: 'AVDHostPool'
    avdworkspaceName: avdworkspaceName
    avdappGroupName: avdappGroupName
  }
}

// Deploy AVD Session Hosts
module avdSessionHosts 'modules/avdSessionHosts.bicep' = [for i in range(0, avdSessionHostCount): {
  name: 'avdsh${i}'
  params: {
    location: location
    vmName: '${avdSessionHostPrefix}${i}'
    subnetId: virtualNetwork.outputs.subnetId
    vmSize: avdSessionHostSize
    vmPublisher: avdSessionHostPublisher
    vmOffer: avdSessionHostOffer
    vmSku: avdSessionHostSku
    vmVersion: avdSessionHostVersion
    osDiskType: avdSessionHostStorageAccountType
    adminUsername: adminUsername
    adminPassword: adminPassword
    domainFQDN: domainFQDN
    domainJoinUser: adminUsername
    domainJoinPassword: adminPassword
    hostPoolId: avdHostPool.outputs.hostPoolId
    registrationInfoToken: avdHostPool.outputs.registrationInfoToken
    storageAccountName: storageAccountName
  }
}]
module storageModule './modules/storageAccount.bicep' = {
  name: 'storageDeployment'
  params: {
    location: location
    storageAccountName: storageAccountName
  }
}
