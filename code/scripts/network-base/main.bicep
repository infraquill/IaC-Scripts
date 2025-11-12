targetScope = 'resourceGroup'

@description('Location for regional resources')
param location string
@description('VNet name')
param vnetName string
@description('Address space for the VNet')
param vnetAddressPrefixes array
@description('Subnets definition including required system subnets')
param subnets object
@description('Tags applied to all resources')
param tags object = {}
@description('DNS Forwarders (on-prem or upstream)')
param dnsForwarders array = [
  { ipAddress: '1.1.1.1' }
  { ipAddress: '8.8.8.8' }
]
@description('Do you want Azure DDoS Network Protection?')
@allowed([ true, false ])
param enableDdos bool = true
@description('Public IP SKU')
@allowed([ 'Standard' ])
param publicIpSku string = 'Standard'
@description('Azure Firewall SKU Tier')
@allowed([ 'Basic', 'Standard', 'Premium' ])
param firewallTier string = 'Standard'
param publicIpPrefixLength int = 28

// Public IP Prefix
module pipPrefix 'br/public:avm/res/network/public-ip-prefix:<version>' = {
  name: 'pipPrefix'
  params: {
    name: '${vnetName}-pipfx'
    location: location
    properties: { prefixLength: publicIpPrefixLength }
    skuName: 'Standard'
    tags: tags
  }
}

// Public IPs
module bastionPip 'br/public:avm/res/network/public-ip-address:<version>' = {
  name: 'bastionPip'
  params: {
    name: '${vnetName}-pip-bastion'
    location: location
    sku: { name: publicIpSku }
    publicIPAllocationMethod: 'Static'
    publicIPPrefixResourceId: pipPrefix.outputs.resourceId
    tags: tags
  }
}

module firewallPip 'br/public:avm/res/network/public-ip-address:<version>' = {
  name: 'firewallPip'
  params: {
    name: '${vnetName}-pip-afw'
    location: location
    sku: { name: publicIpSku }
    publicIPAllocationMethod: 'Static'
    publicIPPrefixResourceId: pipPrefix.outputs.resourceId
    tags: tags
  }
}

// NSG
module appNsg 'br/public:avm/res/network/network-security-group:<version>' = {
  name: 'appNsg'
  params: {
    name: '${vnetName}-nsg-app'
    location: location
    securityRules: []
    tags: tags
  }
}

// VNet
module vnet 'br/public:avm/res/network/virtual-network:<version>' = {
  name: 'vnet'
  params: {
    name: vnetName
    location: location
    addressSpacePrefixes: vnetAddressPrefixes
    subnets: [
      { name: 'AzureFirewallSubnet', addressPrefix: subnets.AzureFirewallSubnet.addressPrefix }
      { name: 'AzureBastionSubnet', addressPrefix: subnets.AzureBastionSubnet.addressPrefix }
      { name: 'snet-dns-inbound', addressPrefix: subnets['snet-dns-inbound'].addressPrefix }
      { name: 'snet-dns-outbound', addressPrefix: subnets['snet-dns-outbound'].addressPrefix }
      { name: 'snet-app', addressPrefix: subnets['snet-app'].addressPrefix, networkSecurityGroupResourceId: appNsg.outputs.resourceId }
    ]
    tags: tags
  }
}

// NAT Gateway
module natGw 'br/public:avm/res/network/nat-gateway:<version>' = {
  name: 'natGw'
  params: {
    name: '${vnetName}-nat'
    location: location
    publicIpAddressResourceIds: [ firewallPip.outputs.resourceId ]
    tags: tags
  }
}

// DNS Private Resolver
module dnsResolver 'br/public:avm/res/network/dns-resolver:<version>' = {
  name: 'dnsResolver'
  params: {
    name: '${vnetName}-prvdr'
    location: location
    virtualNetworkResourceId: vnet.outputs.resourceId
    inboundEndpoints: [ { name: 'inbound', subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'snet-dns-inbound') } ]
    outboundEndpoints: [ { name: 'outbound', subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'snet-dns-outbound') } ]
    tags: tags
  }
}

// DNS Forwarding Ruleset
module dnsFrs 'br/public:avm/res/network/dns-forwarding-ruleset:<version>' = {
  name: 'dnsFrs'
  params: {
    name: '${vnetName}-frs'
    location: location
    outboundEndpointResourceIds: [ dnsResolver.outputs.outboundEndpointResourceIds[0] ]
    vnetLinks: [ { name: '${vnetName}-link', virtualNetworkResourceId: vnet.outputs.resourceId } ]
    forwardingRules: [ { name: 'default-forward', domainName: '.', targetDnsServers: dnsForwarders } ]
    tags: tags
  }
}

// DDoS
module ddos 'br/public:avm/res/network/ddos-protection-plan:<version>' = if (enableDdos) {
  name: 'ddosPlan'
  params: { name: '${vnetName}-ddos', location: location, tags: tags }
}

// Firewall Policy + Firewall
module afwPolicy 'br/public:avm/res/network/firewall-policy:<version>' = {
  name: 'afwPolicy'
  params: { name: '${vnetName}-afwp', location: location, skuTier: firewallTier, tags: tags }
}

module afw 'br/public:avm/res/network/firewall:<version>' = {
  name: 'afw'
  params: {
    name: '${vnetName}-afw'
    location: location
    firewallPolicyResourceId: afwPolicy.outputs.resourceId
    ipConfigurations: [
      { name: 'ipcfg', publicIPAddressResourceId: firewallPip.outputs.resourceId, subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AzureFirewallSubnet') }
    ]
    skuTier: firewallTier
    tags: tags
  }
}

// Bastion
module bastion 'br/public:avm/res/network/bastion-host:<version>' = {
  name: 'bastion'
  params: {
    name: '${vnetName}-bastion'
    location: location
    subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AzureBastionSubnet')
    publicIpAddressResourceId: bastionPip.outputs.resourceId
    sku: 'Standard'
    tags: tags
  }
}

// IP Groups
param ipGroups array = [ { name: '${vnetName}-ipg-trusted', addresses: [ '10.10.0.0/16', '203.0.113.10' ] } ]
var ipGroupModules = [for ipg in ipGroups: {
  name: ipg.name
  mod: { name: 'ipg-${ipg.name}', params: { name: ipg.name, location: location, ipAddresses: ipg.addresses, tags: tags } }
}]
module ipg 'br/public:avm/res/network/ip-group:<version>' = [for item in ipGroupModules: { name: item.name, params: item.mod.params }]

// Network Manager
module avnm 'br/public:avm/res/network/network-manager:<version>' = {
  name: 'avnm'
  scope: subscription()
  params: { name: '${vnetName}-avnm', scopeAccesses: [ 'Connectivity', 'SecurityAdmin' ], tags: tags }
}
