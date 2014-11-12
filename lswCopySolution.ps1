
# =================================================================
# Script to copy and rename a LightSwitch project
# Easiest, drop this into the root of the solution and run from there
#
# Not the most beautiful code in the world...but is successful
# and is easy to follow for those that want to learn
#
# Note - You should delete any *.suo files from your master
#        Definitely from the new solution
#
# ITG - 11/10/2014 @ 630p
#
# http://blog.ofAnITGuy.com
# http://lightswitch.codewriting.tips
#
# =================================================================

$helpSource = @"
Location of the solution to copy?

Provide a valid drive path to the folder that contains
the root of your solution.  This folder will be 
the one that contains the *.sln file.

Defaults to the folder where the script was launched.

"@

$helpNewSolutionParent = @"

==================================================================
Parent folder for the new solution folder?

Provide a valid drive path to the parent folder 
for the new solution.  

Defaults to the parent folder of the solution being copied.

"@

$helpNewSolutionName = @"

==================================================================
Name for the new solution?

Defaults to the source solution with the addition 
of the word "Copy".  This will also be the folder 
name for the new solution.

"@

$helpNewClientName = @"

==================================================================
Name for the new HTML Client?

Defaults to the name of the client in the original solution.

"@

$helpNewIISPort = @"

==================================================================
IIS Port for localhost in the new solution?

Defaults to the port that is used in the original solution.

"@


clear

# What is the location for the source, defaults to current
Write-Host $helpSource
$sourceSolutionFolder = Read-Host -Prompt "Default: $PWD  "
if (!($sourceSolutionFolder)) { $sourceSolutionFolder = $PWD.Path }



# Make sure path exists and has the right files
if ((Test-Path $sourceSolutionFolder) -and ((Get-ChildItem -Path $sourceSolutionFolder -filter *.sln).Count -eq 1) -and ((Get-ChildItem -Path $sourceSolutionFolder -Recurse -include *.lsxtproj, *.csproj, *.jsproj).Count -eq 3)) {

    try {

        # Find the path to the parent container 
        cd ..
        $parentContainer = $PWD.Path
        cd $sourceSolutionFolder


        # =================================================================
        # Lets go find out the original app information
        # =================================================================

        # Original project name
        $fileName = Get-ChildItem -Recurse -Filter "*.lsxtproj" | Select-String "RootNamespace" | Select-Object -ExpandProperty Path
    
        if ($fileName -and (Test-Path $fileName)) {

            [xml]$xmlContent = Get-Content $fileName
            $origProjectName = $xmlContent.GetElementsByTagName("RootNamespace")[0].innerText
        }

        # Original client name
        $fileName = Get-ChildItem -Recurse -Filter "*.jsproj" | Select-String "ClientProjectName" | Select-Object -ExpandProperty Path

        if ($fileName -and (Test-Path $fileName)) {

            [xml]$xmlContent = Get-Content $fileName
            $origClientName = $xmlContent.GetElementsByTagName("ClientProjectName")[0].innerText
        }

        # Original IIS Port
        $fileName = Get-ChildItem -Recurse -Filter "*.csproj" | Select-String "IISUrl" | Select-Object -ExpandProperty Path

        if ($fileName -and (Test-Path $fileName)) {

            [xml]$xmlContent = Get-Content $fileName
            $origIISPort = ($xmlContent.GetElementsByTagName("IISUrl")[0].innerText).split(':')[2].Replace('/', '')
        }


        # Clean up our junk
        if ($xmlContent) { Remove-Variable -name xmlContent }
        if ($fileName) { Remove-Variable -name fileName }


        # =================================================================
        # Ask user for target data
        # =================================================================

        # What is the location for the new solution
        $newSolutionParentFolder = $parentContainer
	    Write-Host $helpNewSolutionParent
        $consoleInput = Read-Host -Prompt "Default: $newSolutionParentFolder  "

        if ($consoleInput) { $newSolutionParentFolder = $consoleInput }


        # What is the name for the new solution
        $continue = $false
        $newSolutionName = $origProjectName + "Copy"

	    Write-Host $helpNewSolutionName
        while(-not $continue) {
            $continue = $true

            $consoleInput = Read-Host -Prompt "Default: $newSolutionName  "
        
            if ($consoleInput) {$newSolutionName = $consoleInput}

            $newSolutionFolder = "$newSolutionParentFolder\$newSolutionName"
            # Does the folder exist... if so, do not continue
            if (Test-Path $newSolutionFolder) { 
                $continue = $false
                Write-Host "`n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                Write-Host "`nThe folder $newSolutionName already exists, `nEither use a different solution name or delete the folder`n"
            }

        }

        # What is the new client name
        $newClientName = $origClientName
	    Write-Host $helpNewClientName
        $consoleInput = Read-Host -Prompt "Default: $newClientName  "

        if ($consoleInput) { $newClientName = $consoleInput }

        # What local port for IIS
        $newIISPort = $origIISPort
	    Write-Host $helpNewIISPort
        $consoleInput = Read-Host -Prompt "Default: $newIISPort  "

        if ($consoleInput) { $newIISPort = $consoleInput }

        Write-Host "`n`n==================================================================`n"

        # Clean up more junk
        Remove-Variable -name consoleInput

        # =================================================================
        # Copy the Source to the Target folder
        # =================================================================
        Write-Host "`n`nCopying source to new solution folder..."

        $origFileCount = (Get-ChildItem -recurse -Force).Count

        Copy-Item $sourceSolutionFolder $newSolutionFolder -Recurse -Force | Wait-Process

        # Make sure we don't move forward until the folder has been created and all files copied
        while ( -not ((Get-ChildItem -Path $newSolutionFolder -recurse -Force).Count -eq $origFileCount))
                {
                Start-Sleep -s 2
                }

        # Change to the new solution location
        cd $newSolutionFolder


        # =================================================================
        # Lets setup some utilitarian variables
        # =================================================================

        $rootPath = $pwd.path + '\' -replace '\\', '\\'

        $origClientFolder = $origProjectName + '.' + $origClientName
        $origServerFolder = $origProjectName + '.Server'

        $newClientFolder = "$newSolutionName.$origClientName"
        $newServerFolder = "$newSolutionName.Server"

        $clientRemovePath = $rootPath + $newClientFolder
        $serverRemovePath = $rootPath + $newServerFolder


        # =================================================================
        # Delete the folders that are not needed
        # =================================================================
        Write-Host "`nRemoving unnecessary folders from new solution... "

        # Get the first level of folders to delete
        $items = Get-ChildItem -force -Recurse -Include bin | Sort-Object $_.FullName -Descending   
        foreach ($item in $items) { Remove-Item $item -Recurse -Force }

        # Now second levels
        $items = Get-ChildItem -Force -Recurse -Include _Pvt_Extensions, obj, bld, GeneratedArtifacts, *.user, ModelManifest.xml
        foreach ($item in $items) { Remove-Item $item -Recurse -Force }
	
	    # Get Git files
	    $items = Get-ChildItem -Force -Filter .git* 
	    forEach ($item in $items) { Remove-Item $item -Recurse -Force }

	    # Finally any suo files
	    $items = Get-ChildItem -Force -Filter *.suo 
	    forEach ($item in $items) { Remove-Item $item -Recurse -Force }

        # Clean up our junk
        Remove-Variable -name items


        # =================================================================
        # Replace the old project name with then new name (ie: Project)
        # =================================================================
        Write-Host "`nUpdating files with the new project name..."

        # Get all the files that match our orig solution name
        $files = Get-ChildItem $(get-location) -filter *$origProjectName* -Recurse | Sort-Object -Descending -Property FullName

        # Change the folder and filenames to the new solution name
        foreach($file in $files) {
            if (Test-Path $file.FullName) {
                $newName = $file.name -replace $origProjectName, $newSolutionName

                # Make sure we don't attempt to rename to its current name
                if (!($newName -eq $file.Name)) { 
                    Rename-Item -Path $file.FullName -NewName $newName -force
                }
            }
        }

        # Clear our the files variable
        Clear-Variable -name files
    

        # Get all the files that have our original name within its contents
        $files = Get-ChildItem -recurse | Select-String -pattern $origProjectName | group path | select name

        # Loop over all the matching files, replace original with new
        foreach($file in $files) 
        { 
            if (test-path $file.Name) {
	            # Replace all the name occurances, save back to original file
	            ((Get-Content $file.Name) -creplace $origProjectName, $newSolutionName) | set-content $file.Name 
            }
        }

        # Clear our the files variable
        Clear-Variable -name files
        if ($newName) { Remove-Variable -name newName }


        # =================================================================
        # Replace the old project client name with new name  (ie: Project.HTMLClient)
        # =================================================================
        Write-Host "`nUpdating files with the new client name... "

        $folderToChange = $newClientFolder
        $folderToAdd = $newSolutionName + '.' + $newClientName

        # Get all the files that match our solution name
        $files = Get-ChildItem $(get-location) -filter *$folderToChange* -Recurse | Sort-Object -Descending -Property FullName

        # Change the folder and filenames to the new solution name
        foreach($file in $files) {
            if (Test-Path $file.FullName) {
                $newName = $file.Name -replace $folderToChange, $folderToAdd

                # Make sure we don't attempt to rename to its current name
                if (!($newName -eq $file.Name)) { 
                    Rename-Item -Path $file.FullName -NewName $newName -force
                }
            }
        }

        # Get all the files that has our original name in its body
        $files = Get-ChildItem -recurse | Select-String -pattern $folderToChange | group path | select name

        # Loop over all the matching files, replace original with new
        foreach($file in $files) 
        { 
            if (Test-Path $file.Name) {
	            # Replace all the name occurances, save back to original file
	            ((Get-Content $file.Name) -creplace $folderToChange, $folderToAdd) | set-content $file.Name 
            }
        }

        # Clear our the files variable
        Clear-Variable -name files
        Remove-Variable -name folderToChange, folderToAdd
        if ($newName) { Remove-Variable -name newName }


        # =================================================================
        # Update our client project file with new name
        # =================================================================
        Write-Host "`nUpdating the client project file... "

        $file = Get-ChildItem -Recurse -filter "$newSolutionName.$newClientName.jsproj"

        if ($file) {
            [xml]$xmlContents = Get-Content $file.FullName

            $xmlElements = $xmlContents.GetElementsByTagName('ClientProjectName')
		    foreach($el in $xmlElements) { 
			    $el.set_InnerText($newClientName)
		    }
		
            $xmlElements = $xmlContents.GetElementsByTagName('LightSwitchDisplayName')
		    foreach($el in $xmlElements) { 
			    $el.set_InnerText($newClientName)
		    }
		
		    $xmlContents.Save($file.FullName)
		
		    Clear-Variable -Name xmlContents
		    Clear-Variable -Name xmlElements
        }

        # Clean up
        Clear-Variable -name file


        # =================================================================
        # Update the default htm file on the server, our refresh tag
        # =================================================================
        Write-Host "`nUpdating server side default.htm... "

        $file = Get-ChildItem -Recurse -filter "default.htm" | Select-String "refresh" | Select-Object -ExpandProperty Path

        if ($file) {
            [string]$content = Get-Content $file

            $replaceTarget = "url=/$origClientName"
            $replaceWith = "url=/$newClientName"
            $content = $content -replace $replaceTarget, $replaceWith

            set-content -Value $content -Path $file

            # Clean up
            Clear-Variable -name replaceTarget
		    Clear-Variable -name replaceWith
		    Clear-Variable -name content
        }

        # Clean up
        Clear-Variable -name file

    
        # =================================================================
        # Update our server project web.config
        # =================================================================
        Write-Host "`nUpdating server side web.config... "

        $file = Get-ChildItem -Recurse -filter "web.config" | Select-String "DefaultClientName" | Select-Object -ExpandProperty Path

        if ($file) {
            $conxString = ''
		    [xml]$xmlContents = Get-Content $file
		
		    $xmlElements = $xmlContents.SelectNodes('/configuration/appSettings/add') | 
			    Where-Object { $_.key -eq 'Microsoft.LightSwitch.DefaultClientName' }

		    foreach($el in $xmlElements) { 
			    $el.SetAttribute("value", $newClientName) 
		    }
		
		    $xmlElements = $xmlContents.SelectNodes('/configuration/connectionStrings/add') | 
			    Where-Object { ($_.connectionString).contains("localhost:$origIISPort") }
		
		    forEach($el in $xmlElements) {
			    $conxString = $el.connectionString -replace $origIISPort, $newIISPort
			    $el.SetAttribute("connectionString", $conxString)
		    }
		
		    $xmlContents.Save($file)        

            # Clean up
            Clear-Variable -name xmlContents
		    Clear-Variable -Name xmlElements
		    Remove-Variable -Name conxString
        }

        # Clean up
        Clear-Variable -name file

    
        # =================================================================
        # Update our server project file, remove the IIS port, becomes dynamic
        # =================================================================
        Write-Host "`nUpdating server IIS Port..."

        $file = Get-ChildItem -Recurse -filter "*.csproj" | Select-String "localhost:$origIISPort" | Select-Object -ExpandProperty Path

        if ($file) {
		    $newUrl = ''
            [xml]$xmlContents = Get-Content $file

            $xmlElements = $xmlContents.GetElementsByTagName('IISUrl')
		
		    foreach($el in $xmlElements) { 
			    $newUrl = ($el.'#text').replace($origIISPort, $newIISPort)
			    $el.set_InnerText($newUrl)
		    }

            $xmlContents.Save($file)
		
		    Clear-Variable -Name xmlContents
		    Clear-Variable -Name xmlElements
		    Remove-Variable -Name newUrl

        }
	
	    Clear-Variable -Name file


        # =================================================================
        # We are done... drop out leaving user in the new solution folder
        # =================================================================
        Read-Host -Prompt "`nDone... press any key to exit"

    } catch {

        $errorDetails = ($_).CategoryInfo
        $errorException = ($_).Exception.Message

        Write-Host "`n`n==================================================================`n"
        Write-host "`n`nThere was a problem as noted below... `n`n$errorException"
    }

} else {

    Write-Host "`n`n==================================================================`n"
    Write-Host "`nSource is not a valid solution... Location must contain the *.sln file"

}
