export type NameserverT =
{
  id: number,
  nameserver: string
}

export type OsVariantT =
{
  variantId: string,
  longName: string
};

export type OsVariantsT =
[
  osVariant: OsVariantT
];

export type RefreshVirtualMachineListT = () => void;

export type SeedImageT =
{
  objectId: number,
  objectName: string,
  fileExtension: string,
  creationDate: string
};

export type SeedImagesT =
[
  seedImage: SeedImageT
];

export type SetIpCallbackT = (state: boolean) => void;

export type SshKeyT = 
{
  id: number,
  sshKey: string
};

export type VirtualMachineT =
{
  virtualMachineId: number,
  creationTimestamp: number,
  machineName: string,
  virtualDiskId: string,
  virtualCdromId: string,
  vCpuCount: number,
  virtualMemory: number,
  osVariant: string,
  networkSource: string,
  networkDevice: string,
  assignedToHost: string
};

export type VirtualMachinesT =
[
  virtualMachine: VirtualMachineT
];

export type VmHostT =
{
  hostId: number,
  hostName: string,
  status: string,
  lastUpdate: number,
  installedMemory: number,
  cpuCount: number,
  hypervisorVersion: number,
  libvirtVersion: number,
  machineType: string,
  osRelease: string
};

export type VmHostsT =
[
  vmHost: VmHostT
];