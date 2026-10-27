return {
  {
    'jake-stewart/multicursor.nvim', branch = '1.0',
    config = function()
      local mc = require('multicursor-nvim')
      mc.setup()
      -- Preserve the normal Escape mapping outside a multicursor session.
      mc.addKeymapLayer(function(set)
        set('n', '<Esc>', mc.clearCursors)
        -- A pending "cc" prefix makes multicursor replay the first replacement
        -- character twice. Keep its existing single-key change action immediate.
        set('x', 'c', 'c', {nowait = true, desc = 'Seçilen eşleşmeleri değiştir'})
      end)
    end,
  },
}
