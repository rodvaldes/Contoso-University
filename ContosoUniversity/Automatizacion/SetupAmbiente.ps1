#
# SetupAmbiente.ps1
#
<#
    .SYNOPSIS
    
	Crea  un ambiente para una aplicación website en Azure, incluyendo las bases
	de datos y el storage que el website requiere.
            
    .DESCRIPTION

	El script SetupAmbiente.ps1 automatiza el proceso de crear un website Windows Azure
	y su entorno, incluyendo una cuenta de storage para blobs y colas, una base de datos
	SQL Server, una base de datos de aplicación, y una base de datos de membresía.  


    Este script tb agrega variables de entorno ("AppSettings") y strings de conxión que le
	permite al website acceder a las cuentas de storage y base de datos.
    
    SetupAmbiente.ps1 requiere que Windows Azure Powershell esté instalado y configurado para 
	trabajar con la subscripción de Windows Azure. Para detalles. ver:  "How to install and configure 
    Windows Azure PowerShell" en 
    http://go.microsoft.com/fwlink/?LinkID=320552.

   
	También llama a los scripts auxiliares, New-AzureSql.ps1 y New-AzureStorage.ps1, los cuales deben estar 
	en el mismo escritorio que SetupAmbiente.ps1.

	Finalmente, el script genera el archivo website-environment.xml para el script de despliegue del website
	<Website_Name>.pubxml que Windows Azure necesita para despleguar el sitio. Guarda este archivo en el directorio 
	scripts.
           
    .PARAMETER  Name
    
	Especifica el nombre del sitio. Los nombres de Websites deben ser únicos en el dominio azurewebsites.net. 
	se debe proporcionar un string alfanumerico. Este parametro es case-INsensitive y es también utilizado para nombrar 
	recursos relacionados con el Website, como cuentas de storage. Este es un parametro requerido.

    .PARAMETER  Location

	Especifica la ubicación de Windows Azure. La ubicación debe soportar websites. 
	El valor por defecto es "West US".
	 

    Valores Validos :
    -- East Asia
    -- East US
    -- North Central US
    -- North Europe
    -- West Europe
    -- West US

    .PARAMETER  SqlDatabaseUserName
    
	Especifica un nombre de usuario para la base de datos SQL que el script crea para el web site. El script crea un unsuario
	con un nombre de usuario y password. El valor por defecto es "dbuser".
	
    .PARAMETER  SqlDatabasePassword

    Especifique una contraseña para el usuario de base de datos SQL en la cuenta que el
    script crea. Este parámetro es requerido por el script auxiliar
    que crea la base de datos . Si se omite este parámetro ,
    se le solicitara una contraseña al momento de que el script de base de datos ses llamado .

    .PARAMETER StartIPAddress

	La dirección de inicio del rango de direcciones IP en el SQL
    Regla de firewall Azure. Si omite este parámetro , la secuencia de comandos
    crea un rango de direcciones IP desde la dirección IP pública del
    máquina local.

    .PARAMETER EndIPAddress
    
	La última dirección del rango de direcciones IP en el SQL
    Regla de firewall Azure. Si omite este parámetro , la secuencia de comandos
    crea un rango de direcciones IP desde la dirección IP pública del
    máquina local .
    
    .INPUTS
    System.String

    .OUTPUTS

    .NOTES
    This script sets the $VerbosePreference variable to "Continue", so all 
    Verbose messages are displayed without using the Verbose common parameter. 
    It also sets the $ErrorActionPreference variable to "Stop" which stops the
    script when it generates non-terminating errors.

    This script calls the following helper scripts and expects them to be in 
    the same directory:
    -- New-AzureSql.ps1
    -- New-AzureStorage.ps1

    .EXAMPLE
    SetupAmbiente.ps1 -Name ContosoTesting -SqlDatabasePassword P@ssw0rd

    .EXAMPLE
    SetupAmbiente.ps1 -Name TestSite -Location "West Europe" -SqlDatabaseUserName AdminUser `
        -SqlDatabasePassword P@ssw0rd -StartIpAddress 216.142.28.0 -EndIPAddress 216.142.28.255
 
    .LINK
    New-AzureWebsite
    
    .LINK
    Set-AzureWebsite
    
    .LINK
    New-AzureSql.ps1
    
    .LINK
    New-AzureStorage.ps1

    .LINK
    Windows Azure Management Cmdlets (http://go.microsoft.com/fwlink/?LinkID=386337)

    .LINK
    How to install and configure Windows Azure PowerShell (http://go.microsoft.com/fwlink/?LinkID=320552)
#>


[CmdletBinding(PositionalBinding=$True)]
Param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[a-z0-9]*$")]
    [String]$Name,                             # required    needs to be alphanumeric    
    [String]$Location = "West US",             # optional    default to "West US", needs to be a location which all the services created here are available
    [String]$SqlDatabaseUserName = "dbuser",   # optional    default to "dbuser"
    [String]$SqlDatabasePassword,              # optional    optional, but required by a helper script. Set the value here or the helper script prompts you.
    [String]$StartIPAddress,                   # optional    start IP address of the range you want to whitelist in SQL Azure firewall will try to detect if not specified
    [String]$EndIPAddress                      # optional    end IP address of the range you want to whitelist in SQL Azure firewall will try to detect if not specified
    )

# Begin - Helper functions --------------------------------------------------------------------------------------------------------------------------


<#
    .SYNOPSIS 

	Crea un archivo xml de entorno para el despliegue del sitio.
            
    .DESCRIPTION

	La funcion New-EnvironmentXml crea y almacena en disco un archivo 
	website-environment.xml. Windows Azure requiere de este archivo para
	desplegar un website.

	New-EnvironmentXml requiere  de un archivo plantilla website-environment.template
	en el directorio del script.


    Este archivo está empaquetado con
    el script SetupAmbiente.ps1 . Si el archivo de plantilla
    no se encuentra, la función fallará.

    Esta función está diseñada como una función auxiliar para
    el guión SetupAmbiente.ps1.
	
	         
    .PARAMETER  EnvironmentName
    
	Especifica un nombre para el entorno web . Se debe proveer
    una cadena alfanumica . Es útil cuando el nombre
    del entorno está relacionado con el nombre del sitio web .
    
    SetupAmbiente.ps1 utiliza el nombre del sitio web
    como el valor por defecto este parámetro.

    .PARAMETER  WebsiteName
	
	Especifica el nombre de la página web para el que este
    se crea el entorno. Para obtener o verificar el
    nombre del sitio web , utilice el cmdlet  Get-AzureWebsite.
    
	
	.PARAMETER  Storage

    Especifica una tabla hash de los valores de la Cuenta de almacenamiento 
	sobre WindowsAzure . El script New- AzureStorage.ps1
    devuelve esta tabla hash.

    .PARAMETER  Sql

    Especifica una tabla hash de los valores sobre Windows
    Servidor de base de Azure y el miembro y la aplicación
    databasaes . El script New-AzureSql.ps1 devuelve este
    tabla de hash.

    .INPUTS
    System.String
    System.Collections.Hashtable

    .OUTPUTS
    None. This function creates and saves a
    website-environment.xml file to disk in the
    script directory.

    .EXAMPLE
    $sqlHash = .\New-AzureSql.ps1 -Password P@ssw0rd
    $storageHash = .\New-AzureStorage.ps1 -Name ContosoStorage
    
    New-EnvironmentXml -EnvironmentName MyWebSite -WebsiteName MyWebSite `
       -Storage $storageHash -Sql $sqlHash

    .LINK
    SetupAmbiente.ps1

    .LINK
    Get-AzureWebsite
#>
Function New-EnvironmentXml
{
    Param(
        [String]$EnvironmentName,
        [String]$WebsiteName,
        [System.Collections.Hashtable]$Storage,
        [System.Collections.Hashtable]$Sql
    )

    [String]$template = Get-Content $scriptPath\website-environment.template
    
    $xml = $template -f $EnvironmentName, $WebsiteName, `
                        $Storage.AccountName, $Storage.AccessKey, $Storage.ConnectionString, `
                        ([String]$Sql.Server).Trim(), $Sql.UserName, $Sql.Password, `
                        $Sql.AppDatabase.Name, $Sql.AppDatabase.ConnectionString, `
                        $Sql.MemberDatabase.Name, $Sql.MemberDatabase.ConnectionString
    
    $xml | Out-File -Encoding utf8 -FilePath $scriptPath\website-environment.xml
}

<#
    .SYNOPSIS 

	Crea el archivo pubxml que es usado para el despliegue del sitio.

    .DESCRIPTION

	La función New-PublishXml crea y guarda
    en el disco el archivo <website_name>.pubxml . El archivo incluye
    los valores de los publishsettings  para el sitio web. Windows
    Azure requiere un archivo pubxml para desplegar una página web.

    New-PublishXml requiere un archivo pubxml.template en el
    directorio de script. Este archivo está empaquetado con el
    script SetupAmbiente.ps1. Si el archivo de plantilla
    no se encuentra, la función fallará.

    Esta función está diseñada como una función auxiliar para
    el guión SetupAmbiente.ps1 .
        

    .PARAMETER  WebsiteName
    
	Especifica el nombre de la página web para el que este
     se crea medio ambiente.  Para obtener o de verificar la
     nombre del sitio web, utilice la página web cmdlet Get-Azure.

    .INPUTS
    System.String

    .OUTPUTS
    None. This function creates and saves a
    <WebsiteName>.xml file to disk in the
    script directory.

    .EXAMPLE
    New-PublishXml -WebsiteName MyWebSite

    .LINK
    SetupAmbiente.ps1

    .LINK
    Get-AzureWebsite
#>
Function New-PublishXml
{
    Param(
        [Parameter(Mandatory = $true)]
        [String]$WebsiteName
    )
    
    # Get the current subscription
    $s = Get-AzureSubscription -Current -ExtendedDetails
    if (!$s) {throw "Cannot get Windows Azure subscription. Failure in $s = Get-AzureSubscription -Current –ExtendedDetails in New-PublishXml in SetupAmbiente.ps1"}

    $thumbprint = $s.Certificate.Thumbprint
    if (!$thumbprint) {throw "Cannot get subscription cert thumbprint. Failure in $s = Get-AzureSubscription -Current –ExtendedDetails in New-PublishXml in SetupAmbiente.ps1"}
    
    # Get the certificate of the current subscription from your local cert store
    $cert = Get-ChildItem Cert:\CurrentUser\My\$thumbprint
    if (!$cert) {throw "Cannot find subscription cert in Cert: drive. Failure in New-PublishXml in SetupAmbiente.ps1"}

    $website = Get-AzureWebsite -Name $WebsiteName
    if (!$website) {throw "Cannot get Windows Azure website: $WebsiteName. Failure in Get-AzureWebsite in New-PublishXml in SetupAmbiente.ps1"}
    
    # Compose the REST API URI from which you will get the publish settings info
    $uri = "https://management.core.windows.net:8443/{0}/services/WebSpaces/{1}/sites/{2}/publishxml" -f `
        $s.SubscriptionId, $website.WebSpace, $Website.Name

    # Get the publish settings info from the REST API
    $publishSettings = Invoke-RestMethod -Uri $uri -Certificate $cert -Headers @{"x-ms-version" = "2013-06-01"}
    if (!$publishSettings) {throw "Cannot get Windows Azure website publishSettings. Failure in Invoke-RestMethod in New-PublishXml in SetupAmbiente.ps1"}

    # Save the publish settings info into a .publishsettings file
    # and read the content as xml
    $publishSettings.InnerXml > $scriptPath\$WebsiteName.publishsettings
    [Xml]$xml = Get-Content $scriptPath\$WebsiteName.publishsettings
    if (!$xml) {throw "Cannot get website publishSettings XML for $WebsiteName website. Failure in Get-Content in New-PublishXml in SetupAmbiente.ps1"}

    # Get the publish xml template and generate the .pubxml file
    [String]$template = Get-Content $scriptPath\pubxml.template
    ($template -f $website.HostNames[0], $xml.publishData.publishProfile.publishUrl.Get(0), $WebsiteName) `
        | Out-File -Encoding utf8 ("{0}\{1}.pubxml" -f $scriptPath, $WebsiteName)
}

function Get-MissingFiles
{
    $Path = Split-Path $MyInvocation.PSCommandPath
    $files = dir $Path | foreach {$_.Name}
    $required= 'New-AzureSql.ps1',
               'New-AzureStorage.ps1',
               'SetupAmbiente.ps1',
               'pubxml.template',
               'website-environment.template'

    foreach ($r in $required)
    {            
        if ($r -notin $files)
        {
            [PSCustomObject]@{"Name"=$r; "Error"="Missing"}
        }
    }
}


# End - Helper funtions -----------------------------------------------------------------------------------------------------------------------------


# Begin - Actual script -----------------------------------------------------------------------------------------------------------------------------

# Ajuste el nivel de salida de detallado y hacer la parada de la escritura en caso de error

$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

# Obtener el tiempo en que se inicia la ejecución del script.

$startTime = Get-Date
Write-Verbose "Checking for required files."
$missingFiles = Get-MissingFiles
if ($missingFiles) {$missingFiles; throw "Required files missing from WebSite subdirectory. Download and upzip the package and try again."}

# Ejecutar website Get-Azure sólo para verificar que las credenciales Azure en la sesión PS no han caducado (expirará 12 horas)
# Si las credenciales estan incorrectas, el cmdlet lanza un error de terminación que se detiene la secuencia de comandos.

Write-Verbose "Verifying that Windows Azure credentials in the Windows PowerShell session have not expired."
Get-AzureWebsite | Out-Null


Write-Verbose "[Start] creating Windows Azure website environment: $Name"
# Get the directory of the current script
$scriptPath = Split-Path -parent $PSCommandPath

# Definir los nombres de sitio web, cuenta de almacenamiento, base de datos SQL Azure y base de datos SQL Azure regla de firewall del servidor.

$Name = $Name.ToLower()
$storageAccountName = $Name + "storage"
$sqlAppDatabaseName = "appdb"
$sqlMemberDatabaseName = "memberdb"
$sqlDatabaseServerFirewallRuleName = $Name + "rule"

Write-Verbose "Creating a Windows Azure website: $Name"
# Crear un nuevo sitio web.
#    El website se exporta mediante cmdlet New-Azure  por el módulo de Azure.
$website = New-AzureWebsite -Name $Name -Location $Location -Verbose
if (!$website) {throw "Error: Website was not created. Terminating the script unsuccessfully. Fix the errors that New-AzureWebsite returned and try again."}

Write-Verbose "Creating a Windows Azure storage account: $storageAccountName"
# Crear una nueva cuenta de almacenamiento.
$storage = & "$scriptPath\New-AzureStorage.ps1" -Name $storageAccountName -Location $Location
if (!$storage) {throw "Error: Storage account was not created. Terminating the script unsuccessfully. Fix the errors that New-AzureStorage.ps1 script returned and try again."}

Write-Verbose "Creating a Windows Azure database server and databases"
# Crear una base de datos SQL Azure de servidores, aplicaciones y bases de datos de membresía.
$sql = & "$scriptPath\New-AzureSql.ps1" `
    -AppDatabaseName $sqlAppDatabaseName `
    -MemberDatabaseName $sqlMemberDatabaseName `
    -UserName $SqlDatabaseUserName `
    -Password $SqlDatabasePassword `
    -FirewallRuleName $sqlDatabaseServerFirewallRuleName `
    -StartIPAddress $StartIPAddress `
    -EndIPAddress $EndIPAddress `
    -Location $Location
if (!$sql) {throw "Error: The database server or databases were not created. Terminating the script unsuccessfully. Failures occurred in New-AzureSql.ps1."}

Write-Verbose "[Start] Adding settings to website: $Name"
# Configurar las opciones de aplicación para la cuenta de almacenamiento y NewRelic
$appSettings = @{ `
    "StorageAccountName" = $storageAccountName; `
    "StorageAccountAccessKey" = $storage.AccessKey; `
    "COR_ENABLE_PROFILING" = "1"; `
    "COR_PROFILER" = "{71DA0A04-7777-4EC6-9643-7D28B46A8A41}"; `
    "COR_PROFILER_PATH" = "C:\Home\site\wwwroot\newrelic\NewRelic.Profiler.dll"; `
    "NEWRELIC_HOME" = "C:\Home\site\wwwroot\newrelic" `
}

# Configurar cadenas de conexión para appdb y db member de ASP.NET
$connectionStrings = ( `
    @{Name = $sqlAppDatabaseName; Type = "SQLAzure"; ConnectionString = $sql.AppDatabase.ConnectionString}, `
    @{Name = "DefaultConnection"; Type = "SQLAzure"; ConnectionString = $sql.MemberDatabase.ConnectionString}
)

Write-Verbose "Adding connection strings and storage account name/key to the new $Name website."
# Añadir la cadena de conexión y  nombre/llave (name/key) de cuenta de almacenamiento de la página web.
$error.clear()
Set-AzureWebsite -Name $Name -AppSettings $appSettings -ConnectionStrings $connectionStrings
if ($error) {throw "Error: Call to Set-AzureWebsite with database connection strings failed."}


# Reinicie el sitio Web para que New Relic se enganche a la aplicación.
$error.clear()
Restart-AzureWebsite -Name $Name
if ($error) {throw "Error: Call to Restart-AzureWebsite to make the relic effective failed."}

Write-Verbose "[Finish] Adding settings to website: $Name"
Write-Verbose "[Finish] creating Windows Azure environment: $Name"

# Escribe la información entorno a un archivo XML de manera que la secuencia de comandos de despliegue puede consumir.
Write-Verbose "[Begin] writing environment info to website-environment.xml"
New-EnvironmentXml -EnvironmentName $Name -WebsiteName $Name -Storage $storage -Sql $sql

if (!(Test-path $scriptPath\website-environment.xml))
{
    throw "The script did not generate a website-environment.xml file that is required to deploy the website. Try to rerun the New-EnvironmentXml function in the New-AzureWebisteEnv.ps1 script."
}
else 
{
    Write-Verbose "$scriptPath\website-environment.xml"
    Write-Verbose "[Finish] writing environment info to website-environment.xml"
}

# Generar el archivo .pubxml que será utilizado por webdeploy más tarde
Write-Verbose "[Begin] generating $Name.pubxml file"
New-PublishXml -Website $Name
if (!(Test-path $scriptPath\$Name.pubxml))
{
    throw "The script did not generate a $Name.pubxml file that is required for deployment. Try to rerun the New-PublishXml function in the New-AzureWebisteEnv.ps1 script."
}
else 
{
    Write-Verbose "$scriptPath\$Name.pubxml"
    Write-Verbose "[Finish] generating $Name.pubxml file"
}

Write-Verbose "Script is complete."
# Marca la hora de finalización de la ejecución del script.
$finishTime = Get-Date
# Salida del tiempo consumido en segundos.
$TotalTime = ($finishTime - $startTime).TotalSeconds
Write-Output "Total time used (seconds): $TotalTime"

# End - Actual script ------------------------------------------------------------------------------------------------------------------------------- -