param([Parameter(Mandatory = $true)][string]$Path)
$ErrorActionPreference = 'Stop'

# This development tool handles only directory permissions, never key material.
$targetPath = [IO.Path]::GetFullPath($Path)
for ($ancestor = $targetPath; $ancestor; $ancestor = [IO.Path]::GetDirectoryName($ancestor)) {
    if (([IO.Directory]::Exists($ancestor) -or [IO.File]::Exists($ancestor)) -and
        ([IO.File]::GetAttributes($ancestor) -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'Linked session directory is not supported'
    }
}
[void][IO.Directory]::CreateDirectory($targetPath)
$ownerSid = [Security.Principal.WindowsIdentity]::GetCurrent().User
$systemSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
$acl = [Security.AccessControl.DirectorySecurity]::new()
$acl.SetOwner($ownerSid)
$acl.SetAccessRuleProtection($true, $false)
$inheritance = [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
foreach ($identity in @($ownerSid, $systemSid)) {
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
        $identity, 'FullControl', $inheritance, 'None', 'Allow'))
}
[IO.Directory]::SetAccessControl($targetPath, $acl)
