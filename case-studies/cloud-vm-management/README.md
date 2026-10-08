# Cloud Services & Virtual Machine Management

> Refining how a large service-desk operation ran Azure virtual machines, storage and networking: consistent builds, PowerShell automation, and ITIL-aligned incident, problem and change management in ServiceNow.

**Category:** Infrastructure (professional) · **Status:** Completed · **Period:** Sep 2021 – May 2022 · **Role:** Senior Service Desk Officer, Kinetic IT

> Client details are omitted. This describes the shape of the work and what it changed.

## Objective

Refine the use of cloud services and virtual machines for improved operational efficiency and scalability, and lift the capability of the wider team.

## What was done

### Azure operations

- Management of **Azure virtual machines**, **storage accounts** and **network configuration** for an enterprise client: provisioning, sizing, disk and access management, and decommissioning.
- Consistent build and hand-over steps so machines left the queue in a known, documented state.

### Automation with PowerShell

Routine tasks were scripted so they were repeatable and auditable. Representative examples of the kind of automation involved (Az module):

```powershell
# VM power state and size per resource group → CSV for a morning report
Get-AzVM -Status |
  Select-Object Name, ResourceGroupName, PowerState, Location,
    @{n='Size';e={$_.HardwareProfile.VmSize}} |
  Export-Csv ".\vm-status-$(Get-Date -f yyyyMMdd).csv" -NoTypeInformation

# storage accounts that allow insecure transfer or public blob access
Get-AzStorageAccount |
  Where-Object { -not $_.EnableHttpsTrafficOnly -or $_.AllowBlobPublicAccess } |
  Select-Object StorageAccountName, ResourceGroupName, EnableHttpsTrafficOnly, AllowBlobPublicAccess
```

Other automation covered Active Directory account tasks for the service desk, bulk user changes, and report generation that previously took hours of clicking.

### Service management (ServiceNow / ITIL)

- Used **ServiceNow** to manage incident, problem and change processes, and maintained knowledge-base articles so first-line staff could resolve more without escalation.
- Applied **ITIL** best practice to improve service-management processes and drive continual service improvement.

### People

- Trained and mentored less experienced staff on cloud services and virtual machine management.

## Technologies

Microsoft Azure (Compute, Storage, Networking) · PowerShell / Az module · Active Directory · ServiceNow · Microsoft 365 · ITIL

## Outcome

Enhanced scalability and efficiency of the cloud services, improved operational performance, and reduced downtime, together with documented procedures and a more capable team.

## Skills demonstrated

Azure IaaS administration · PowerShell automation · ITIL service management · ServiceNow · knowledge management · mentoring

## Related

- [cloud-infrastructure](../../) — IaC templates and cloud examples
- [PowerShell-Scripts](https://github.com/Dstanfield-Creator/Powershell-Scripts) — sanitised AD tooling

---

**Author:** Danny Stanfield · Perth, WA  
**License:** MIT
