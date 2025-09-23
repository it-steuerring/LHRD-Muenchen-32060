# variables
$SubscriptionId = (Get-AzSubscription).Id
$SubscriptionRoleName = "Storage File Data SMB Share Contributor"
$GroupSubId = (Get-AzADGroup -DisplayName AvdProfileAccess).Id
$GroupWksId = (Get-AzADGroup -DisplayName AvdAccess).Id
$WorkspaceName        = "avd-workspace-prod-01"
$WorkspaceRG          = "rg-avd-prod-01"
$WorkspaceRoleName    = "Desktop Virtualization User"  

# Set the context to the subscription
Set-AzContext -SubscriptionId $SubscriptionId

# permission for avd service principal
$parameters = @{
    RoleDefinitionName = "Desktop Virtualization Power On Off Contributor"
    ApplicationId = "9cdead84-a844-4324-93f2-b2e6bb768d07"
    Scope = "/subscriptions/$SubscriptionId"
}

New-AzRoleAssignment @parameters

# permission for avd profiles
New-AzRoleAssignment `
  -ObjectId $GroupSubId `
  -RoleDefinitionName $SubscriptionRoleName `
  -Scope "/subscriptions/$SubscriptionId"

#permission for avd access
$parameters = @{
    ObjectId = $GroupWksId
    ResourceName = 'avd-appgroup-prod-01'
    ResourceGroupName = 'rg-avd-prod-01'
    RoleDefinitionName = 'Desktop Virtualization User'
    ResourceType = 'Microsoft.DesktopVirtualization/applicationGroups'
}

New-AzRoleAssignment @parameters