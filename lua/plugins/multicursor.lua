return {
  {
    'jake-stewart/multicursor.nvim', branch = '1.0',
    config = function()
      local mc = require('multicursor-nvim')
      mc.setup()
      -- Preserve the normal Escape mapping outside a multicursor session.
      mc.addKeymapLayer(function(set)
        set('n', '<Esc>', mc.clearCursors)
      end)
    end,
  },
}
