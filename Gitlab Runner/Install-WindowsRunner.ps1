function Install-WindowsRunner {
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = "High")]
        PARAM(
            # Runner Token from your project
            [Parameter(Mandatory = $true,
                ValueFromPipeline = $false,
                Position = 0)]
            [string]$RunnerToken,
            # The Gitlab URL
            [Parameter(Mandatory = $true,
                ValueFromPipeline = $false,
                Position = 1)]
            [string]$RunnerURL = 'https://gitlab.com/',
            # Name of the Runner agent displayed in gitlab
            [Parameter(Mandatory = $true,
                ValueFromPipeline = $false,
                Position = 2)]
            [string]$RunnerName

        )

    ## first setup choco for bootstrapping
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'));
    ## install git as runner needs git installed without credential manager
    choco install git /NoCredentialManager -y 
    ## Location for installation files for runner account
    $InstallDir = 'C:\Gitlab'
    if(!(test-path $InstallDir -ErrorAction SilentlyContinue)){
        mkdir $InstallDir
    }
    Set-Location $InstallDir
    ## download the .exe for 64bit and rename to gitlab-runner.exe
    try{
        invoke-webrequest -uri 'https://gitlab-ci-multi-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-ci-multi-runner-windows-amd64.exe' -OutFile 'gitlab-runner.exe' -ErrorAction Stop
    }
    catch {
        ## download failed, throw terminating error
        write-error $_ -ErrorAction Stop 
    }
    ## if download was successful execute the installation
    if(test-path "$InstallDir\gitlab-runner.exe" -ErrorAction SilentlyContinue){
        try{
            $Env:REGISTRATION_TOKEN         = $RunnerToken
            $Env:CI_SERVER_URL              = $RunnerURL
            $Env:RUNNER_TAG_LIST            = 'windows'
            $Env:RUNNER_NAME                = $RunnerName
            $Env:RUNNER_EXECUTOR            = 'shell'
            $Env:RUNNER_SHELL               = 'powershell'
            $Env:CONFIG_FILE                = "$InstallDir\config.toml"
            $Env:REGISTER_RUN_UNTAGGED      = 'false'
            $Env:RUNNER_REQUEST_CONCURRENCY = 1
            $Env:RUNNER_BUILDS_DIR          = ''
            $Env:RUNNER_CACHE_DIR           = ''
            .\gitlab-runner.exe register --non-interactive
        }
        catch {
            ## installation of runner returns a none 0 exit code; however, error message states success. suppress error by checking error message
            $RunnerSuccess = "Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded"
            if($_ -contains $RunnerSuccess) {
                write-output $RunnerSuccess 
            }
            else {
                write-error -Message $_
            } 
        }
        .\gitlab-runner.exe install
        .\gitlab-runner.exe start
    }
    else {
        write-error "gitlab-runner.exe did not get downloaded" -ErrorAction Stop
    }
    
    

}# close function