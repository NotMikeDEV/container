readme = "README.md"
file = {'module', 'container.lua'}
examples = {
	'examples/basic-vm.lua',
	'examples/docs_www.lua',
	'examples/proxy.lua',
	'examples/owncloud.lua',
	'examples/wordpress.lua',
	'examples/tinc-router.lua',
	'examples/tinc-vm.lua',
	'examples/nat64-gateway.lua',
}
prettify_files=true
kind_names={topic='Manual',script='Programs'}
custom_tags = {
	{ 'optional', title='optional', hidden = true },
}
custom_display_name_handler = function(item, default_handler)
  if item.tags.note then
    return default_handler(item) .. ' [optional]'
  end
  return default_handler(item)
end

