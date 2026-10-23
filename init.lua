-- LazyVim is the IDE foundation; local customizations live under lua/config and lua/plugins.
require('config.lazy')

-- Personal tools initialize before the first source buffer is opened.
require('custom.workflow').setup()
require('custom.ide.new_project').setup()
require('custom.csharp').setup()
require('custom.kernel')
