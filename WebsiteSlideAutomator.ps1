Import-Module Posh-SSH

$today = Get-Date
# Create a new PSCredential object to securly connect to the server w/o storing PW in plaintext
$user = "clarkstonlib1"
$file = "C:\automation\pw.txt"
$account = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, (Get-Content $file | ConvertTo-SecureString) 
# SSH is typically port 22 but our website uses 7822 for some reason
$sftp = New-SFTPSession -ComputerName cidlibrary.org -Credential $account -Port 7822 -AcceptKey 
$global:fullMessage = "Howdy team, your friendly neighborhood script here! Here's the latest from the website carousels:" 

# In charge of SFTP onto the website and removing all the expired slides and their associated .txt files
function Remove-OldSlides($filePath)
{
    try
    {
        Remove-SFTPItem -SFTPSession $sftp -Path $filePath
        write-log -logtext "Success!"
    }
    catch
    {
        Write-Log -logtext "Failed: Delete failed: " + $error[0]
        $global:fullMessage = Write-ErrorEmail -error "Failed: Delete failed: " + $error[0]
    }
}

# SFTPs to the website and transfers today's slides and their .txt files to the correct folder
function Add-NewSlides($localPath, $remotePath, $file)
{
    $fullLocalPath = $localPath + $file.Name
    try
    {
        Set-SFTPFile -SFTPSession $sftp -RemotePath $remotePath -LocalFile $fullLocalPath -ErrorAction Stop
        Write-Log -logtext "Success!"
        Remove-Item -Path $fullLocalPath
    }
    catch [Renci.SshNet.Common.SftpPermissionDeniedException]
    {
        Write-Log -logtext "Failed: SFTP Permission Denied. Does the file already exist? " + $error[0]
        $global:fullMessage = Write-ErrorEmail -error "Failed: SFTP Permission Denied. Does the file already exist?"
    }
    catch
    {
        Write-Log -logtext "Failed: " + $error[0]
        $global:fullMessage = Write-ErrorEmail -error "Failed: " + $error[0]
    }
    
}

# Helper: Parses the start date from the file name and determines if the file needs to be uploaded or not
function Read-StartDate($file)
{
    # Dates are contained within the file name in the format:
    # MMddyyyy_filename_MMddyyyy
    # With the leading date being the upload date and the trailing date being the removal date
    try
    {
        $splitString = $file.Name.split("_")
        $date = [DateTime]::ParseExact($splitString[0], "MMddyyyy", $null) 
        $niceFileName = $splitString[1]
        
        if($date -le $today)
        {
            Write-Log -LogText "File, $niceFileName, has live date of $date. Uploading..."
            return $true
        }
        else
        {
            Write-Log -LogText "File, $niceFileName, has live date of $date. Ignoring..."
            return $false
        }
    }
    catch
    {
        # Don't use the nice file name here because it likely won't exist, at least in the right form, if this catch is triggered
        Write-Log -logtext "Failed: File, $file, has invalid date time."
        $global:fullMessage = Write-ErrorEmail -error "Failed: File, $file, has invalid date time."
    }
}

# Helper: Parses the end date from the file name and determines if the file needs to be deleted or not
function Read-EndDate($file)
{
    # Dates are contained within the file name in the format:
    # MMddyyyy_filename_MMddyyyy
    # With the leading date being the upload date and the trailing date being the removal date

    # Get-SFTPChildItem returns some "extra" items for navigation that need to be scrubbed out
    if ($file.Name -ne "index.html" -and $file.Name -ne "." -and $file.name -ne "..")
    {
        # Split off the date and the file extension
        $splitString = $file.Name.split("_")
        $splitString = $splitString.split(".")
        $niceFileName = $splitString[1]
    
        try
        {
            $date = [DateTime]::ParseExact($splitString[2], "MMddyyyy", $null)
        
            if($date -le $today)
            {
                Write-Log -LogText "File, $niceFileName, has removal date of $date, removing..."
                return $true
            }
            else
            {
                Write-Log -LogText "File, $niceFileName, has removal date of $date, Ignoring..."
                return $false
            }
        }
        catch
        {
            Write-Log -LogText "Failed: End date time failed to parse for $file"  
            $global:fullMessage = Write-ErrorEmail -error -LogText "Failed: End date time failed to parse for $file"   
        }
    }

    
}

# Master function: Calls all the other functions and contains the local and remote working paths
function Set-Slideshow($localPath, $remotePath)
{
    $files = Get-ChildItem -Path $localPath
    # Each slide has a text document associated with it. So if 4 files are in the folder, there are only 2 remaining slides
    $remainingFiles = $files.Count/2

    Write-Log -logtext ("There are " + $remainingFiles.ToString() + " slides reamining in this folder")
     
    foreach ($file in $files)
    {
        # If the date is today or earlier, we upload the file
        if(Read-StartDate -File $file) 
        {
            Add-NewSlides -LocalPath $localPath -RemotePath $remotePath -File $file
        }
    }
     
    $remoteFiles = Get-SFTPChildItem -SFTPSession $sftp -Path $remotePath
    foreach ($remoteFile in $remoteFiles)
    {
        if(Read-EndDate -file $remoteFile)
        {
            $global:fullPath = $remotePath + $remoteFile.Name
            Remove-OldSlides -filePath $fullPath
        } 
    }
    
    
}

# Email Remaining Slides
function Get-RemainingSlides ($remotePath)
{
    $remainingSlides = Get-SFTPChildItem -SFTPSession $sftp -Path $remotePath
    # Get-SFTPChildItem will return ., .., and index.html, in addition to all the slides, we don't care about those three
    # In addition, each slide is paired with a text document. So if 7 files are found, 3 of them will be the ., .., and index files
    # and 2 of them will be text documents linking to the 2 remaining slides. So subtract 3 and divide by 2 to figure out how many slides
    # we actually have left. 
    $realRemaining = ($remainingSlides.Count - 3)/2 
    Write-Log -logtext ("There are: " + $realRemaining.ToString() + " Slides in " + $remotePath)
    $global:fullMessage = Write-ErrorEmail -message ($realRemaining.ToString() + " slides left in " + $remotePath)
}

function Write-Log($logtext)
{
    # Date in yy.mm.dd format for file name
    $friendlyDate = Get-Date -UFormat %y.%m.%d
    $logPath = "\\itlfile\Library\IT Department\WebsiteSigns\Logs\$friendlyDate-log.txt"

    # Creates the file if non-existant, appends if the file is there
    Add-Content -Path $logPath -Value $logtext       
}

function Write-ErrorEmail($message)
{
    $global:fullMessage = $fullMessage + "`n" + $message
    return $fullMessage
}

function Submit-ErrorEmail
{
    $from = "tech@cidlibrary.org"
    $to = "webmaster@cidlibrary.org"
    $cc = "mcnamarac@cidlibrary.org", "bowersc@cidlibrary.org"
    $subject = "Website Slideshows: Daily Update"
    $Body =  $global:fullMessage
    $Server = "smtp.office365.com"
    $Port = "587"
    $pwfile = "C:\automation\pw2.txt"
    $EmailCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $from, `
    (Get-Content $pwfile | ConvertTo-SecureString)

    Send-MailMessage -From $from -To $to -Cc $cc -Subject $subject -Body $Body -SmtpServer $server -Port $port -Credential $EmailCredential -UseSsl 
}

##################################################################################################

Write-Log -logtext " "
Write-Log -logtext "Starting Homepage Upload/Removal"
Write-Log -logtext " "
Set-Slideshow -LocalPath "\\itlfile\Library\IT Department\WebsiteSigns\Homepage\" -RemotePath "/home/clarkstonlib1/public_html/images/Carousel/autoload/"
Get-RemainingSlides -remotePath "/home/clarkstonlib1/public_html/images/Carousel/autoload/"
Write-Log -logtext " "
Write-Log -logtext "Starting Adult Upload/Removal"
Write-Log -logtext " "
Set-Slideshow -LocalPath "\\itlfile\Library\IT Department\WebsiteSigns\Adults\" -RemotePath "/home/clarkstonlib1/public_html/images/Adult/slides/"
Get-RemainingSlides -remotePath "/home/clarkstonlib1/public_html/images/Adult/slides/"
Write-Log -logtext " "
Write-Log -logtext "Starting Kids Upload/Removal"
Write-Log -logtext " "
Set-Slideshow -LocalPath "\\itlfile\Library\IT Department\WebsiteSigns\Kids\" -RemotePath "/home/clarkstonlib1/public_html/images/childrens/slides/"
Get-RemainingSlides -remotePath "/home/clarkstonlib1/public_html/images/childrens/slides/"
Write-Log -logtext " "
Write-Log -logtext "Starting Teen Upload/Removal"
Write-Log -logtext " "
Set-Slideshow -LocalPath "\\itlfile\Library\IT Department\WebsiteSigns\Teens\" -RemotePath "/home/clarkstonlib1/public_html/images/teen/slides/"
Get-RemainingSlides -remotePath "/home/clarkstonlib1/public_html/images/teen/slides/"

Remove-SFTPSession -SFTPSession $sftp 
Submit-ErrorEmail