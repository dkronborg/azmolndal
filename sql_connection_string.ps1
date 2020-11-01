#sql connection string i powershell

$ServerName = "student08.database.windows.net"
$DatabaseName = "student08"
$userName = "serveradmin"
$password = "azureuser123!"

$connectionString = 'Data Source={0};database={1};User ID={2};Password={3}' -f $ServerName,$DatabaseName,$userName,$password
$sqlConnection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
$sqlConnection.Open()
$sqlConnection.Close()