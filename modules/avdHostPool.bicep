//@description('Location for AVD host pool')
//param location string
@description('Name of the AVD host pool')
param hostPoolName string
@description('Friendly name for the host pool')
param hostPoolFriendlyName string
@description('Host pool type: Pooled or Personal')
param hostPoolType string = 'Pooled'
@description('Load balancer type: BreadthFirst or DepthFirst')
param loadBalancerType string = 'BreadthFirst'
@description('Maximum session limit per session host')
param maxSessionLimit int = 16
@description('Expiration time for session host registration (ISO8601 string)')
param registrationInfoExpirationTime string
@description('Assignment type for personal desktops, one of Automatic or Direct')
param personalDesktopAssignmentType string
@description('Description of the host pool')
param hostPoolDescription string = 'AVDHostPool'
//param location string


@description('Name des AVD-Workspaces')
param avdworkspaceName string

@description('Friendly Name für den Workspace')
param workspaceFriendlyName string = 'AVD Workspace'

@description('Name der Desktop-App-Gruppe')
param avdappGroupName string

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = {
  name: hostPoolName
  location: 'westeurope'
  properties: {
    hostPoolType: hostPoolType
    loadBalancerType: loadBalancerType
    maxSessionLimit: maxSessionLimit
    description: hostPoolDescription
    friendlyName: hostPoolFriendlyName
    preferredAppGroupType: personalDesktopAssignmentType
    startVMOnConnect: true
    registrationInfo: {
      expirationTime: registrationInfoExpirationTime
      registrationTokenOperation: 'Update'
    }
  }
}

// AppGroup create

resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2023-09-05' = {
  name: avdappGroupName
  location: 'westeurope'
  properties: {
    hostPoolArmPath: hostPool.id
    applicationGroupType: 'Desktop'
  }
}

// Workspace create
resource workspace 'Microsoft.DesktopVirtualization/workspaces@2025-03-01-preview' = {
  name: avdworkspaceName
  location: 'westeurope'
  properties: {
    friendlyName: workspaceFriendlyName
    description: 'Arbeitsbereich für Azure Virtual Desktop'
    applicationGroupReferences: [
      appGroup.id
    ]
    publicNetworkAccess: 'Enabled'
  }
}

output workspaceId string = workspace.id
output hostPoolId string = hostPool.id
output registrationToken string = first(hostPool.listRegistrationTokens().value).token
output registrationInfoToken string = first(hostPool.listRegistrationTokens().value).token
