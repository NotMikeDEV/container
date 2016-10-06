# ownCloud web based file server.
```lua
require("templates/owncloud")
```
## New ownCloud instance
Use owncloud:Instance{} to install a new owncloud instance.
```lua
ExampleSite=owncloud:Instance{hostname='hostname'}
```
Optional parameter *root = "/path/to/owncloud"*.
## Dependencies
The ownCloud module only installs the ownCloud application, you must also set up a web server and optional mysql server for it to be of any use.
## Example
```lua
require("templates/caddy")
require("templates/php")
require("templates/mysql")
require("templates/owncloud")

mysql.password="supersecretsecurepassword1xkcd"
request_IP("192.0.2.1", {nat=true})
request_IP("2001:db8:1", {nat=true})
local ExampleSite = caddy:AddWebsite(owncloud:Instance{hostname='owncloud.example.com'})
```
Note the mixed usage of {} and () syntax.
## Side effects of loading module
The owncloud module automatically exports */owncloud* as *owncloud*, and new owncloud instances are created under there by default.