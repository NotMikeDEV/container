# Caddy web server.
```lua
require("templates/caddy")
```
## New Website
Use caddy:Website{} to configure a new website.
```lua
ExampleSite=caddy:Website{hostname='hostname', root='/path/to/docroot'}
```
caddy:Website returns a website object, you can call functions on this object to alter the behaviour of that website.
```lua
ExampleSite:AddRedirect{source='/source', target='/target', status=status}
ExampleSite:AddRewrite{source='/source', target='/target'}
```

## FastCGI
To plug in a FastCGI server call caddy:FastCGI{ext='ext',socket='/path/to/unix/socket'}
```lua
caddy:AddFastCGI{ext='php',socket='/var/run/php5-fpm.sock'}
```

## Example
```lua
require("templates/caddy")

ExampleSite=caddy:Website{hostname='example.com', root='/var/www'}
ExampleSite:AddRedirect{source='/redirectme', target='/ivebeenredirected', status=307}
ExampleSite:AddRewrite{source='/rewriteme', target='/'}
```
## Side effects of loading module
Loading the caddy module automatically exports */var/www* to the *docroot* directory and */root* to the *home* directory.

The caddy object is also exposed under the name *webserver*.