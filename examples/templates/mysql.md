# MySQL server.
```lua
require("templates/mysql")
```
The only configurable parameter for this module is the default root password.
```lua
mysql.password="changeme"
```
The mysql data directory is automatically exported as *mysql*.