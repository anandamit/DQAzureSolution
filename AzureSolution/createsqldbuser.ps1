Param(
  [string]$dbUserName,
  [string]$dbPassword,
  [string]$mrsdbUserName,
  [string]$mrsdbPassword,
  [string]$stagedbUserName,
  [string]$stagedbPassword
)

function writeLog {
    Param([string] $log)
    $dateAndTime = Get-Date
    "$dateAndTime : $log" | Out-File -Append C:\Informatica\Archive\scripts\createdbusers.log
}

function waitTillDatabaseIsAlive {
    $connectionString = "Data Source=localhost;Integrated Security=true;Initial Catalog=model;Connect Timeout=3;"
    $sqlConn = new-object ("Data.SqlClient.SqlConnection") $connectionString
    $sqlConn.Open()

    $tryCount = 0
    while($sqlConn.State -ne "Open" -And $tryCount -lt 100) {
        $dateAndTime = Get-Date
        writeLog "Attempt $tryCount"

	    Start-Sleep -s 30
	    $sqlConn.Open()
	    $tryCount++
    }

    if ($sqlConn.State -eq 'Open') {
	    $sqlConn.Close();
	    writeLog "Connection to MSSQL Server succeed"
    } else {
        writeLog "Connection to MSSQL Server failed"
        exit 255
    }
}

function executeSQLStatement {
    Param([String] $sqlStatement)

    $errorFlag = 1
    $tryCount = 0

    $error.clear()

    while($errorFlag -ne 0 -And $tryCount -lt 30) {
        sleep 1
        $tryCount++
        try {
            Invoke-Sqlcmd -ServerInstance '(local)' -Database 'model' -Query $sqlStatement
            $errorFlag = $error.Count
        } catch {
            $errorFlag = $error.Count
        } finally {
			if($errorFlag -ne 0) {
				writeLog "Error: $error"
				$error.clear()
			}
		}
    }

    if($errorFlag -eq 1 -And $tryCount -eq 3) {
        writeLog "User creation failed"
		exit 255
    } else {
		writeLog "Statement execution passed"
	}
}

$error.clear()
netsh advfirewall firewall add rule name="Informatica_DQ_MMSQL" dir=in action=allow profile=any localport=1433 protocol=TCP
mkdir -Path C:\Informatica\Archive\scripts 2> $null

writeLog "Creating user: $dbUserName"

$newLogin = "CREATE LOGIN " + $dbUserName +  " WITH PASSWORD = '" + ($dbPassword -replace "'","''") + "'"
$newUser = "CREATE USER " + $dbUserName + " FOR LOGIN " + $dbUserName + " WITH DEFAULT_SCHEMA = " + $dbUserName
$updateUserRole = "ALTER ROLE db_datareader ADD MEMBER " + $dbUserName + ";" + 
                        "ALTER ROLE db_datawriter ADD MEMBER " + $dbUserName + ";" + 
                        "ALTER ROLE db_ddladmin ADD MEMBER " + $dbUserName
$newSchema = "CREATE SCHEMA " + $dbUserName + " AUTHORIZATION " + $dbUserName

waitTillDatabaseIsAlive
executeSQLStatement $newLogin
executeSQLStatement $newUser
executeSQLStatement $updateUserRole
executeSQLStatement $newSchema

writeLog "Creating user for MRS: $mrsdbUserName"
$newLoginmrs = "CREATE LOGIN " + $mrsdbUserName +  " WITH PASSWORD = '" + ($mrsdbPassword -replace "'","''") + "'"
$newUsermrs = "CREATE USER " + $mrsdbUserName + " FOR LOGIN " + $mrsdbUserName + " WITH DEFAULT_SCHEMA = " + $mrsdbUserName
$updateUserRolemrs = "ALTER ROLE db_datareader ADD MEMBER " + $mrsdbUserName + ";" + 
                        "ALTER ROLE db_datawriter ADD MEMBER " + $mrsdbUserName + ";" + 
                        "ALTER ROLE db_ddladmin ADD MEMBER " + $mrsdbUserName
$newSchemamrs = "CREATE SCHEMA " + $mrsdbUserName + " AUTHORIZATION " + $mrsdbUserName
executeSQLStatement $newLoginmrs
executeSQLStatement $newUsermrs
executeSQLStatement $updateUserRolemrs
executeSQLStatement $newSchemamrs

writeLog "Creating user for STAGE: $stagedbUserName"
$newLoginstage = "CREATE LOGIN " + $stagedbUserName +  " WITH PASSWORD = '" + ($stagedbPassword -replace "'","''") + "'"
$newUserstage = "CREATE USER " + $stagedbUserName + " FOR LOGIN " + $stagedbUserName + " WITH DEFAULT_SCHEMA = " + $stagedbUserName
$updateUserRolestage = "ALTER ROLE db_datareader ADD MEMBER " + $stagedbUserName + ";" + 
                        "ALTER ROLE db_datawriter ADD MEMBER " + $stagedbUserName + ";" + 
                        "ALTER ROLE db_ddladmin ADD MEMBER " + $stagedbUserName
$newSchemastage = "CREATE SCHEMA " + $stagedbUserName + " AUTHORIZATION " + $stagedbUserName
executeSQLStatement $newLoginstage
executeSQLStatement $newUserstage
executeSQLStatement $updateUserRolestage
executeSQLStatement $newSchemastage