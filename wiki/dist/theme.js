try { document.documentElement.dataset.theme = localStorage.getItem('tempered-wiki-theme') || 'light'; } catch { document.documentElement.dataset.theme = 'light'; }
try { document.documentElement.dataset.font = localStorage.getItem('tempered-wiki-font') || 'normal'; } catch {}
