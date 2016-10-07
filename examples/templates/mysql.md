# MySQL server.
```lua
require("templates/mysql")
```
You can change the root password using:
```lua
mysql.password="changeme"
```
## API
use mysql:Database{database='name'} to create a database if it doesn't exist, and return a Database Object.
```lua
local myDatabase = mysql:Database{='mydatabase'}:Grant{user='mike', password='thisisasecurepasswordxkcd'};
```
The returned Database object has a single function of :Grant{} which creates a user and grants them access to that database.
```lua
myDatabase:Grant{user='mike', password='thisisasecurepasswordxkcd'};
```
## Other
The mysql data directory is automatically exported as *mysql*.