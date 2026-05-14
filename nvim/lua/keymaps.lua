local map = vim.keymap.set

-- Save / quit
map("n", "<leader>w", "<cmd>w<CR>")
map("n", "<leader>q", "<cmd>q<CR>")

-- Scroll fast
map("n", "<C-j>", "10j")
map("n", "<C-k>", "10k")

-- Clipboard
map("n", "<leader>y", '"*y')
map("n", "<leader>Y", '"+y')

-- Move lines (insert / visual)
map("i", "<A-j>", "<Esc>:m .+1<CR>==gi")
map("i", "<A-k>", "<Esc>:m .-2<CR>==gi")
map("v", "<A-j>", ":m '>+1<CR>gv=gv")
map("v", "<A-k>", ":m '<-2<CR>gv=gv")

-- Move split panes
map("n", "<A-h>", "<C-W>H")
map("n", "<A-j>", "<C-W>J")
map("n", "<A-k>", "<C-W>K")
map("n", "<A-l>", "<C-W>L")

-- Navigate between splits
map("n", "<C-Left>",  "<C-w>h")
map("n", "<C-Down>",  "<C-w>j")
map("n", "<C-Up>",    "<C-w>k")
map("n", "<C-Right>", "<C-w>l")

-- Resize splits
map("n", "<leader><Up>",    "10<C-w>+")
map("n", "<leader><Down>",  "10<C-w>-")
map("n", "<leader><Right>", "10<C-w>>")
map("n", "<leader><Left>",  "10<C-w><")

-- Escape shortcuts
map("i", "ii", "<Esc>")
map("i", "jk", "<Esc>")
map("i", "kj", "<Esc>")

-- Indent and keep selection
map("v", ">", ">gv")
map("v", "<", "<gv")

-- Open file in vertical split
map("n", "gf", "<cmd>vert winc f<CR>")

-- Copy file path / directory to clipboard
map("n", "yf", function() vim.fn.setreg("+", vim.fn.expand("%:p")) end, { silent = true })
map("n", "yd", function() vim.fn.setreg("+", vim.fn.expand("%:p:h")) end, { silent = true })

-- File tree (nvim-tree, replaces NERDTree)
map("n", "dir", "<cmd>NvimTreeToggle<CR>")

-- Fuzzy find / search (telescope, replaces fzf.vim)
map("n", "<leader>m", "<cmd>Telescope find_files<CR>")
map("n", "<leader>M", "<cmd>Telescope live_grep<CR>")
map("n", "<leader>t", "<cmd>Telescope buffers<CR>")

-- Tab navigation
map("n", "<leader>a", "<cmd>-tabnext<CR>")
map("n", "<leader>z", "<cmd>+tabnext<CR>")

-- Transparency
map("n", "<leader>bc", "<cmd>TransparentToggle<CR>")

-- Copilot
map("n", "<leader>cc", "<cmd>CopilotChatToggle<CR>")
map("n", "<leader>cp", function() require("copilot.command").toggle() end)

-- Diagnostics navigation (replaces [g / ]g from CoC)
map("n", "[g", vim.diagnostic.goto_prev, { silent = true })
map("n", "]g", vim.diagnostic.goto_next, { silent = true })
