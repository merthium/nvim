local map = vim.keymap.set
local ide = require('custom.ide.actions')
require('custom.mouse').setup()
map('i', 'jk', '<Esc>', {desc = 'Normal mod'})
map('i', 'kj', '<Esc>', {desc = 'Normal mod'})
map('n', '<CR>', 'o', {desc = 'Altına yeni satır aç ve yaz'})
map({'n', 'x', 's', 'i'}, '<PageUp>', '<Cmd>normal! <C-y><CR>', {desc = 'Ekranı bir satır yukarı kaydır', silent = true})
map({'n', 'x', 's', 'i'}, '<PageDown>', '<Cmd>normal! <C-e><CR>', {desc = 'Ekranı bir satır aşağı kaydır', silent = true})
-- Reuse LazyVim's line/block movement, including indentation and insert mode.
map({'n', 'x', 'i'}, '<A-Up>', '<A-k>', {remap = true, desc = 'Satırı / seçimi yukarı taşı'})
map({'n', 'x', 'i'}, '<A-Down>', '<A-j>', {remap = true, desc = 'Satırı / seçimi aşağı taşı'})
map('n', '<C-d>', 'viw', {desc = 'Kelimeyi seç'})
map('x', '<C-d>', function() require('multicursor-nvim').matchAddCursor(1) end,
  {desc = 'Sonraki eşleşmeyi seçime ekle'})
map('n', 'cc', 'gcc', {remap = true, desc = 'Satırı yorum yap / yorumu kaldır'})
map('x', 'cc', 'gcgv', {remap = true, desc = 'Seçimi yorum yap / yorumu kaldır'})
map('n', '<leader><leader>', '<cmd>update<cr>', {desc = 'Kaydet'})
local function window_mode(direction)
  if direction then vim.cmd.wincmd(direction) end
  require('which-key').show({keys = '<C-w>', loop = true})
end
for direction, label in pairs({h = 'Sol', j = 'Alt', k = 'Üst', l = 'Sağ'}) do
  map('n', '<leader>' .. direction, function() window_mode(direction) end,
    {desc = label .. ' pencere; h/j/k/l ile devam et'})
  map({'n', 'i', 't'}, '<C-' .. direction .. '>', function() vim.cmd.wincmd(direction) end,
    {desc = label .. ' pencere', silent = true})
end
map('n', '<leader>w', function() window_mode() end, {desc = 'Pencere yönetimi; Esc ile çık'})
map('n', '<leader>n', '<cmd>enew<cr>', {desc = 'Yeni dosya'})
map('n', '<leader>bn', '<cmd>bnext<cr>', {desc = 'Sonraki dosya'})
map('n', '<leader>bp', '<cmd>bprevious<cr>', {desc = 'Önceki dosya'})
map('n', '<leader>bo', require('custom.workflow').open_recent, {desc = 'Projenin son dosyaları'})
-- Explicit system-clipboard access; nonrecursive RHS keeps these working even
-- though the old yank/put keys below are disabled.
map('n', '<C-c>', '"+yy', {desc = 'Satırı panoya kopyala'})
map('i', '<C-c>', '<C-o>"+yy', {desc = 'Satırı panoya kopyala'})
map('x', '<C-c>', '"+y', {desc = 'Seçimi panoya kopyala'})
map('s', '<C-c>', '<C-g>"+y', {desc = 'Seçimi panoya kopyala'})
map('n', '<C-v>', '"+p', {desc = 'Panodan yapıştır'})
map('x', '<C-v>', '"+P', {desc = 'Panoyu koruyarak seçimin üzerine yapıştır'})
map('s', '<C-v>', '<C-g>"+P', {desc = 'Panoyu koruyarak seçimin üzerine yapıştır'})
map('i', '<C-v>', '<C-r><C-p>+', {desc = 'Panodan metni aynen yapıştır'})
map('c', '<C-v>', '<C-r>+', {desc = 'Komut satırına yapıştır'})
for _, key in ipairs({'y', 'Y', 'p', 'P', 'gp', 'gP', '[p', ']p', '[P', ']P', '<leader>y', '<leader>p'}) do
  map({'n', 'x'}, key, '<Nop>', {desc = 'Kapalı: Ctrl+C / Ctrl+V kullan'})
end
for _, key in ipairs({'<C-Insert>', '<S-Insert>', '<MiddleMouse>'}) do
  map({'n', 'x', 's', 'i', 'c'}, key, '<Nop>', {desc = 'Kapalı: Ctrl+C / Ctrl+V kullan'})
end
map({'i', 'c'}, '<C-r>', '<Nop>', {desc = 'Kapalı: Ctrl+V kullan'})
map('t', '<Esc>', '<C-\\><C-n>', {desc = 'Terminalden normal moda'})
-- Window controls use Space in normal mode; Escape leaves terminal input.
local function close_window()
  if vim.api.nvim_win_get_config(0).relative == '' and #vim.api.nvim_list_tabpages() == 1 then
    local editors = 0
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_config(win).relative == '' then editors = editors + 1 end
    end
    if editors == 1 then
      vim.notify('Son pencere açık kalır. Neovim’den çıkmak için :q kullan.')
      return
    end
  end
  vim.cmd.close()
end
map('n', '<leader>q', close_window, {desc = 'Bu pencereyi kapat', silent = true, nowait = true})
map({'n', 'i', 't'}, 'q', require('custom.mouse').q, {expr = true, desc = 'Fare üzerindeki dosya ağacını kapat', silent = true, nowait = true})
map('n', 'Q', 'q', {desc = 'Makro kaydet'})
map('n', '<C-w>q', close_window, {desc = 'Bu pencereyi kapat', silent = true})
map('n', '<leader>t', function() require('custom.ide.tasks').toggle_output() end,
  {desc = 'Çıktı panelini aç / kapat', silent = true})
map('n', '<leader>+', '<cmd>resize +3<cr>', {desc = 'Pencereyi uzat', silent = true})
map('n', '<leader>-', '<cmd>resize -3<cr>', {desc = 'Pencereyi kısalt', silent = true})
map('n', '<leader>0', function() Snacks.zen.zoom() end, {desc = 'Pencereyi büyüt / geri al'})
map({'n', 'x'}, '<C-Left>', 'b', {desc = 'Önceki kelime'})
map({'n', 'x'}, '<C-Right>', 'w', {desc = 'Sonraki kelime'})
map('i', '<C-Left>', '<C-o>b')
map('i', '<C-Right>', '<C-o>w')
map({'n', 'x'}, '<C-Up>', '{', {desc = 'Önceki blok sınırına git'})
map({'n', 'x'}, '<C-Down>', '}', {desc = 'Sonraki blok sınırına git'})
map('i', '<C-Up>', '<C-o>{', {desc = 'Önceki blok sınırına git'})
map('i', '<C-Down>', '<C-o>}', {desc = 'Sonraki blok sınırına git'})
map('s', '<C-Up>', '<C-g>{<C-g>', {desc = 'Önceki blok sınırına git'})
map('s', '<C-Down>', '<C-g>}<C-g>', {desc = 'Sonraki blok sınırına git'})
map({'i', 'c'}, '<C-BS>', '<C-w>')
map('n', '<leader>cI', ide.info, {desc = 'Bu dosyanın IDE ve araç durumu'})
map('n', '<leader>rn', ide.rename, {desc = 'Sembolü yeniden adlandır'})
map('n', '<F2>', ide.rename, {desc = 'Sembolü yeniden adlandır'})
map({'n', 'x'}, '<F4>', ide.code_action, {desc = 'Kod eylemi / refactoring'})
map('n', 'gO', ide.symbols, {desc = 'Dosyada fonksiyon / sembol bul'})
map('n', '<leader>cs', ide.symbols, {desc = 'Dosyada fonksiyon / sembol bul'})
map('n', '<leader>cS', ide.workspace_symbols, {desc = 'Projede sembol bul'})
map('n', '<leader>co', ide.outline, {desc = 'Dosya taslağını aç / kapat'})
map('n', 'gl', ide.diagnostics, {desc = 'Bu satırın hata açıklaması'})
map({'n', 't'}, '<F7>', ide.terminal, {desc = 'Proje terminalini aç / kapat'})
map('n', '<leader>xq', function() Snacks.picker.qflist() end, {desc = 'Derleme hataları'})
map('n', '<leader>cg', ide.grep, {desc = 'Projede metin ara'})
map('n', '<leader>/', ide.grep, {desc = 'Projede metin ara'})
map('n', '<leader>ff', ide.files, {desc = 'Projede dosya bul'})
map('n', '<leader>mm', function() vim.ui.open('https://exercism.org/tracks') end,
  {desc = 'Exercism: soruları tarayıcıda aç'})
map('n', '<leader>mf', function() Snacks.picker.files({cwd = vim.fn.expand('~/code/exercism')}) end,
  {desc = 'Exercism: alıştırma dosyaları'})

-- Search/navigation follow the same project root as build and debug.
map('n', '<leader>fp', function() Snacks.picker.projects() end, {desc = 'Proje aç / değiştir'})
map('n', '<leader>fr', function() Snacks.picker.recent({cwd = require('custom.ide.project').root(), filter = {cwd = true}}) end,
  {desc = 'Projenin son dosyaları'})
map({'n', 'x'}, '<leader>sw', function() Snacks.picker.grep_word({cwd = require('custom.ide.project').root()}) end,
  {desc = 'Kelimeyi / seçimi projede ara'})
map('n', '<leader>sR', function() Snacks.picker.resume() end, {desc = 'Son aramaya dön'})
map('n', '<C-u>', '<C-u>zz', {desc = 'Yarım sayfa yukarı; imleci ortala'})
map('n', 'n', 'nzzzv', {desc = 'Sonraki eşleşmeyi ortala'})
map('n', 'N', 'Nzzzv', {desc = 'Önceki eşleşmeyi ortala'})

require('custom.ide.tasks').setup()
require('custom.ide.debug').keys()
require('custom.ide.ui').setup()
map('n', '<leader>e', function() require('custom.ide.ui').explorer(false) end, {desc = 'Proje dosyaları'})
map({'n', 'i'}, '<C-s>', function() require('custom.ide.ui').action(2) end, {desc = 'Kaydet'})
map('n', '<C-p>', ide.files, {desc = 'Projede dosya bul'})
map('n', '<leader>:', function() Snacks.picker.keymaps() end, {desc = 'Komutları ara'})
vim.api.nvim_create_user_command('IDEInfo', ide.info, {})

local function help()
  Snacks.win({
    text = table.concat({
      'Space Space      Kaydet',
      'Ctrl s / Ctrl p  Kaydet / dosya bul',
      'Page Up / Down   Ekranı bir satır yukarı / aşağı kaydır',
      'Ctrl ↑ / ↓       Önceki / sonraki blok sınırına git',
      'Alt ↑ / ↓        Satırı / seçili bloğu taşı',
      'Ctrl d           Kelimeyi seç; tekrar bas: eşleşme ekle',
      'c → yaz → Esc Esc  Seçilen eşleşmeleri değiştir ve çık',
      'Ctrl c / Ctrl v  Kopyala / panoyu koruyarak yapıştır',
      'cc               Satırı / seçimi yorum yap veya kaldır',
      'Enter (normal)   Altına yeni satır aç ve yaz',
      'F6 / Space rr    Derle ve çalıştır',
      'F7               Proje terminalini aç / kapat',
      'Space t / rl     Çıktı panelini aç / kapat',
      'Space q          Bulunduğun pencereyi kapat',
      'Ctrl h/j/k/l     Sol / alt / üst / sağ pencere',
      'Space h/j/k/l    Geç; h/j/k/l ile tekrarla; Esc çık',
      'Space + / -      Pencereyi uzat / kısalt',
      'Space 0          Pencereyi büyüt / geri al',
      'Shift-F6 / Space rx  Programı durdur',
      'Space rb / rB    Derle / derleme önizlemesi',
      'Space e          Dosya ağacını aç / kapat',
      'Space ff / fp    Dosya bul / proje aç',
      'Space ba / bh    Dosyayı sabitle / sabit dosyalar',
      'Space 1–5        Sabit dosyaya git',
      'Space sw / sR    Kelimeyi ara / son aramaya dön',
      '-                Klasörü düzenle (Oil)',
      'Space / / cg     Projede metin ara',
      'F2 / Space rn    Sembolü yeniden adlandır',
      'F4               Kod eylemi / refactoring',
      'gO / Space cs    Dosya sembolleri (C#: gO)',
      'Space cS / co    Proje sembolleri / dosya taslağı',
      'gl / Space cI    Satır hatası / dil araçlarının durumu',
      'Space cf         Kodu biçimlendir',
      'Space xq         Derleme hataları',
      'F5 / F9          Debug / breakpoint',
      'Ctrl+n / Space cn  Yeni proje (C++ / OpenGL dahil)',
      'Space ri / rt    Bağımlılıkları kur / test et',
      'Space bs / br    Oturumu kaydet / geri aç',
      'Space mm / mf    Exercism: site / dosyalar',
      '',
      'Çıktıda i: giriş yaz  |  Esc: normal mod  |  q: kapat',
    }, '\n'),
    width = 62, height = 0.85, border = 'single', title = ' Neovim · Günlük tuşlar ',
    bo = {modifiable = false}, wo = {wrap = false},
    keys = {q = 'close', ['<Esc>'] = 'close'},
  })
end
vim.api.nvim_create_user_command('KolayTuslar', help, {})
map('n', '<leader>?', help, {desc = 'Günlük tuşlar'})
