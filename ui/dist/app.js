(() => {
  "use strict";

  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [
    ...root.querySelectorAll(selector),
  ];
  const resourceName =
    typeof GetParentResourceName === "function"
      ? GetParentResourceName()
      : "mz_computer";
  const surfaceId = new URLSearchParams(location.search).get('surface');

  const root = $("#computer-root");
  const osRoot = $("#os-root");
  const bootScreen = $("#boot-screen");
  const authScreen = $("#auth-screen");
  const desktop = $("#desktop");
  const authForm = $("#auth-form");
  const usernameInput = $("#username");
  const passwordInput = $("#password");
  const confirmWrap = $("#confirm-wrap");
  const confirmInput = $("#password-confirm");
  const authSubmit = $("#auth-submit");
  const authToggle = $("#auth-toggle");
  const authError = $("#auth-error");
  const authSubtitle = $("#auth-subtitle");
  const authWarning = $("#auth-warning");
  const desktopIcons = $("#desktop-icons");
  const launcher = $("#launcher");
  const launcherApps = $("#launcher-apps");
  const launcherUser = $("#launcher-user");
  const notificationCenter = $("#notification-center");
  const notificationList = $("#notification-list");
  const notificationBadge = $("#notification-badge");
  const taskbarApps = $("#taskbar-apps");
  const windowLayer = $("#window-layer");
  const toastStack = $("#toast-stack");

  const state = {
    open: false,
    epoch: 0,
    authMode: "login",
    device: null,
    bootstrap: null,
    apps: [],
    settings: {
      theme: "dark",
      scale: 1,
      sounds: true,
      wallpaper: "midnight",
      pinned: [],
    },
    notifications: [],
    windows: new Map(),
    z: 120,
    bootTimer: null,
    browserHistory: [],
    browserHistoryIndex: -1,
  };

  const glyphs = {
    globe: 'globe', note: 'notebook-pen', folder: 'folder', settings: 'settings',
    info: 'info', home: 'house', help: 'info', grid: 'layout-grid',
    bank: 'landmark', landmark: 'landmark', briefcase: 'briefcase-business',
    app: 'layout-grid', bell: 'bell', search: 'search', user: 'user-round',
    power: 'power', wifi: 'wifi', 'log-out': 'log-out', 'user-round': 'user-round',
    minus: 'minus', maximize: 'maximize-2', close: 'x', back: 'chevron-left',
    refresh: 'refresh-cw', plus: 'plus', save: 'save', trash: 'trash-2',
    arrow: 'arrow-right', shield: 'shield-check'
  };

  const errors = {
    AUTH_INVALID_CREDENTIALS: "Usuário ou senha inválidos.",
    AUTH_RATE_LIMITED: "Muitas tentativas. Aguarde um pouco.",
    AUTH_ACCOUNT_LOCKED:
      "Conta temporariamente bloqueada por tentativas inválidas.",
    AUTH_ACCOUNT_DISABLED: "Esta conta está desativada.",
    ACCOUNT_EXISTS:
      "Este usuário já existe ou seu personagem já possui uma conta.",
    VALIDATION_FAILED: "Confira os dados informados.",
    SESSION_INVALID: "Sua sessão não é mais válida.",
    SESSION_EXPIRED: "Sua sessão expirou.",
    DEVICE_BUSY: "Este computador já está sendo usado.",
    DEVICE_UNAVAILABLE: "Este dispositivo não está disponível.",
    DEVICE_TOO_FAR: "Você se afastou do computador.",
    APP_FORBIDDEN: "Você não possui permissão para acessar este conteúdo.",
    EXTERNAL_URL_BLOCKED: "A MZ Net não permite acesso à internet real.",
    SITE_NOT_FOUND: "Site não encontrado na MZ Net.",
    LIMIT_REACHED: "Você atingiu o limite permitido.",
    CONFLICT:
      "O conteúdo foi alterado em outra sessão. Recarregue e tente novamente.",
    NOT_READY: "O MZ OS ainda está inicializando.",
    INTERNAL_ERROR: "Ocorreu um erro interno no MZ OS.",
    IDENTITY_UNAVAILABLE:
      "Não foi possível identificar seu personagem. Tente novamente após o carregamento.",
  };

  function escapeHtml(value) {
    return String(value ?? "").replace(
      /[&<>"']/g,
      (ch) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        })[ch],
    );
  }

  function icon(name) {
    return `<i class="lucide" aria-hidden="true" style="--icon:url('assets/icons/${glyphs[name] || glyphs.app}.svg')"></i>`;
  }
  $$('[data-icon]').forEach(el => {
    el.style.setProperty('--icon', `url('assets/icons/${glyphs[el.dataset.icon] || glyphs.app}.svg')`);
  });
  function errorText(code) {
    return errors[code] || String(code || "Erro desconhecido.");
  }

  const allowedNuiEndpoints = new Set(["ready", "request", "close", "surfaceReady", "surfaceVisible"]);

  async function nui(endpoint, payload = {}) {
    if (!allowedNuiEndpoints.has(endpoint)) {
      throw new Error("Blocked NUI endpoint");
    }
    const response = await fetch(`https://${resourceName}/${endpoint}`, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=UTF-8" },
      body: JSON.stringify(payload),
    });
    return response.json();
  }

  async function request(action, payload = {}) {
    const epoch = state.epoch;
    try {
      const result = await nui("request", { action, payload });
      return state.open && state.epoch === epoch ? result : { ok: false, error: 'COMPUTER_CLOSED' };
    } catch (err) {
      return { ok: false, error: "INTERNAL_ERROR" };
    }
  }

  function showToast(title, message, duration = 4200) {
    const toast = document.createElement("div");
    toast.className = "toast";
    const strong = document.createElement("strong");
    strong.textContent = title || "MZ OS";
    const p = document.createElement("p");
    p.textContent = message || "";
    toast.append(strong, p);
    toastStack.appendChild(toast);
    setTimeout(() => toast.remove(), duration);
  }

  function setScreen(name) {
    bootScreen.classList.toggle("hidden", name !== "boot");
    authScreen.classList.toggle("hidden", name !== "auth");
    desktop.classList.toggle("hidden", name !== "desktop");
  }

  function applyDevice(device) {
    state.device = device || {};
  }

  function applySettings(settings) {
    state.settings = { ...state.settings, ...(settings || {}) };
    const light = state.settings.theme === "light";
    osRoot.classList.toggle("light", light);
    osRoot.classList.toggle("theme-dark", !light);
    desktop.classList.remove(
      "wallpaper-midnight",
      "wallpaper-ocean",
      "wallpaper-ember",
    );
    desktop.classList.add(
      `wallpaper-${["midnight", "ocean", "ember"].includes(state.settings.wallpaper) ? state.settings.wallpaper : "midnight"}`,
    );
    const scale = Math.max(
      0.85,
      Math.min(1.15, Number(state.settings.scale) || 1),
    );
    osRoot.style.zoom = String(scale);
    osRoot.style.width = `${100 / scale}%`;
    osRoot.style.height = `${100 / scale}%`;
  }

  function updateClock() {
    const now = new Date();
    const time = now.toLocaleTimeString("pt-BR", {
      hour: "2-digit",
      minute: "2-digit",
    });
    const date = now.toLocaleDateString("pt-BR", {
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
    });
    $("#lock-time").textContent = time;
    $("#lock-date").textContent = date;
    $("#taskbar-time").textContent = time;
    $("#taskbar-date").textContent = date;
    $("#desktop-time").textContent = time;
    $("#desktop-weekday").textContent = now.toLocaleDateString('pt-BR', { weekday:'long', day:'numeric', month:'long' });
    $("#lock-date").textContent = now.toLocaleDateString('pt-BR', { weekday:'long', day:'numeric', month:'long' });
  }
  setInterval(updateClock, 1000);
  updateClock();

  function setAuthMode(mode) {
    state.authMode = mode === "create" ? "create" : "login";
    const creating = state.authMode === "create";
    confirmWrap.classList.toggle("hidden", !creating);
    authSubmit.textContent = creating ? "Criar conta" : "Entrar";
    authToggle.textContent = creating
      ? "Já tenho uma conta"
      : "Criar uma conta";
    authSubtitle.textContent = creating
      ? "Crie sua identidade digital na cidade"
      : "Entre na sua conta digital";
    authError.textContent = "";
    passwordInput.value = "";
    confirmInput.value = "";
  }

  async function prepareAuth() {
    if (!state.open) return;
    setScreen("auth");
    closeAllWindows();
    launcher.classList.add('hidden');
    notificationCenter.classList.add('hidden');
    $('#power-menu').classList.add('hidden');
    passwordInput.value = confirmInput.value = '';
    state.bootstrap = null;
    authError.textContent = "";
    authSubmit.disabled = true;
    const ctx = await request("auth.context");
    if (!state.open || ctx.error === 'COMPUTER_CLOSED') return;
    authSubmit.disabled = false;
    if (!ctx.ok) {
      authError.textContent = errorText(ctx.error);
      return;
    }
    if (ctx.data?.suggestedUsername)
      usernameInput.value = ctx.data.suggestedUsername;
    if (ctx.data?.warning) authWarning.textContent = ctx.data.warning;
    setAuthMode(ctx.data?.hasPersonalAccount ? "login" : "create");
    setTimeout(() => usernameInput.focus(), 50);
  }

  async function loadDesktop() {
    const result = await request("os.bootstrap");
    if (!state.open || result.error === 'COMPUTER_CLOSED') return;
    if (!result.ok) {
      authError.textContent = errorText(result.error);
      await prepareAuth();
      return;
    }
    state.bootstrap = result.data;
    state.apps = Array.isArray(result.data.apps) ? result.data.apps : [];
    state.notifications = Array.isArray(result.data.notifications)
      ? result.data.notifications
      : [];
    applySettings(result.data.settings || {});
    launcherUser.textContent = result.data.account?.username || "";
    $('#desktop-greeting').textContent = `Olá, ${result.data.account?.username || 'visitante'}. Seu espaço está pronto.`;
    $('#desktop-network').textContent = result.data.network?.name || 'MZ Net';
    renderApps();
    renderNotifications();
    setScreen("desktop");
  }

  authToggle.addEventListener("click", () =>
    setAuthMode(state.authMode === "login" ? "create" : "login"),
  );
  authForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    authError.textContent = "";
    const username = usernameInput.value.trim();
    const password = passwordInput.value;
    if (state.authMode === "create" && password !== confirmInput.value) {
      authError.textContent = "As senhas não coincidem.";
      return;
    }
    authSubmit.disabled = true;
    authSubmit.textContent =
      state.authMode === "create" ? "Criando…" : "Entrando…";
    const result = await request(
      state.authMode === "create" ? "auth.create" : "auth.login",
      { username, password },
    );
    passwordInput.value = "";
    confirmInput.value = "";
    authSubmit.disabled = false;
    authSubmit.textContent =
      state.authMode === "create" ? "Criar conta" : "Entrar";
    if (!result.ok) {
      authError.textContent = errorText(result.error);
      return;
    }
    await loadDesktop();
  });

  function renderApps() {
    desktopIcons.replaceChildren();
    launcherApps.replaceChildren();
    const visible = state.apps.filter((app) => app.visibility !== "hidden");
    for (const app of visible) {
      const d = document.createElement("button");
      d.className = "desktop-icon";
      d.dataset.appId = app.id;
      d.innerHTML = `<span class="app-glyph" data-app="${escapeHtml(app.id)}">${icon(app.icon)}</span><span>${escapeHtml(app.name)}</span>`;
      d.title = app.name;
      d.addEventListener("dblclick", () => openApp(app));
      d.addEventListener("click", (e) => {
        $$('.desktop-icon').forEach(el => el.classList.toggle('selected', el === d));
        if (e.detail === 0) openApp(app); // Enter / Space / assistive activation.
      });
      desktopIcons.appendChild(d);

      const l = document.createElement("button");
      l.className = "launcher-app";
      l.innerHTML = `<span class="app-glyph" data-app="${escapeHtml(app.id)}">${icon(app.icon)}</span><span>${escapeHtml(app.name)}</span>`;
      l.dataset.search = app.name.toLocaleLowerCase('pt-BR');
      l.addEventListener("click", () => {
        launcher.classList.add("hidden");
        openApp(app);
      });
      launcherApps.appendChild(l);
    }
    $('#app-count').textContent = `${visible.length} instalados`;
    filterApps();
  }

  function filterApps() {
    const query = $('#app-search').value.trim().toLocaleLowerCase('pt-BR');
    let count = 0;
    $$('.launcher-app').forEach(el => {
      const visible = el.dataset.search.includes(query);
      el.classList.toggle('hidden', !visible);
      if (visible) count++;
    });
    $('#app-search-empty').classList.toggle('hidden', count > 0);
  }
  $('#app-search').addEventListener('input', filterApps);
  $('#app-search').addEventListener('keydown', event => {
    if (event.key === 'Enter') {
      event.preventDefault();
      $('.launcher-app:not(.hidden)')?.click();
    }
  });

  function showLauncher(search = false) {
    launcher.classList.remove('hidden');
    notificationCenter.classList.add('hidden');
    $('#power-menu').classList.add('hidden');
    if (search) $('#app-search').focus();
  }
  $('#search-button').addEventListener('click', () => showLauncher(true));

  function focusWindow(win) {
    if (!win) return;
    state.z += 1;
    win.el.style.zIndex = String(state.z);
    win.el.classList.remove("minimized");
    win.el.style.display = "flex";
    for (const item of state.windows.values())
      item.task.classList.toggle("active", item === win);
  }

  function closeWindow(id) {
    const win = state.windows.get(id);
    if (!win) return;
    win.dispose?.();
    win.el.remove();
    win.task.remove();
    state.windows.delete(id);
  }

  function closeAllWindows() {
    for (const id of [...state.windows.keys()]) closeWindow(id);
  }

  function makeDraggable(win, titlebar) {
    const controller = new AbortController();
    let dragging = false,
      startX = 0,
      startY = 0,
      startLeft = 0,
      startTop = 0;
    titlebar.addEventListener("mousedown", (e) => {
      if (e.target.closest("button") || win.classList.contains("maximized"))
        return;
      dragging = true;
      startX = e.clientX;
      startY = e.clientY;
      startLeft = win.offsetLeft;
      startTop = win.offsetTop;
      focusWindow(state.windows.get(win.dataset.windowId));
      e.preventDefault();
    });
    window.addEventListener("mousemove", (e) => {
      if (!dragging) return;
      const maxLeft = Math.max(0, windowLayer.clientWidth - win.offsetWidth);
      const maxTop = Math.max(0, windowLayer.clientHeight - 34);
      const left = Math.max(
        0,
        Math.min(maxLeft, startLeft + (e.clientX - startX) / state.settings.scale),
      );
      const top = Math.max(0, Math.min(maxTop, startTop + (e.clientY - startY) / state.settings.scale));
      win.style.left = `${left}px`;
      win.style.top = `${top}px`;
    }, { signal: controller.signal });
    window.addEventListener("mouseup", () => {
      dragging = false;
    }, { signal: controller.signal });
    titlebar.addEventListener('dblclick', event => {
      if (!event.target.closest('button')) win.classList.toggle('maximized');
    });
    return () => controller.abort();
  }

  function createWindow(app, options = {}) {
    const existing = state.windows.get(app.id);
    if (existing) {
      focusWindow(existing);
      return existing;
    }
    const el = document.createElement("section");
    el.className = "os-window";
    el.dataset.windowId = app.id;
    const offset = state.windows.size * 14;
    el.style.left = `calc(14% + ${offset}px)`;
    el.style.top = `calc(10% + ${offset}px)`;
    if (options.width) el.style.width = options.width;
    if (options.height) el.style.height = options.height;
    el.innerHTML = `
      <header class="window-titlebar">
        <span class="app-glyph">${icon(app.icon)}</span>
        <span class="window-title">${escapeHtml(app.name)}</span>
        <div class="window-controls">
          <button data-win="min" aria-label="Minimizar">${icon('minus')}</button>
          <button data-win="max" aria-label="Maximizar">${icon('maximize')}</button>
          <button data-win="close" class="close" aria-label="Fechar">${icon('close')}</button>
        </div>
      </header>
      <div class="window-content"></div>`;
    windowLayer.appendChild(el);

    const task = document.createElement("button");
    task.className = "taskbar-button taskbar-app";
    task.innerHTML = `${icon(app.icon)}<span>${escapeHtml(app.name)}</span>`;
    task.title = app.name;
    task.setAttribute('aria-label', app.name);
    taskbarApps.appendChild(task);

    const win = {
      id: app.id,
      app,
      el,
      task,
      content: $(".window-content", el),
    };
    state.windows.set(app.id, win);
    el.addEventListener("mousedown", () => focusWindow(win));
    $('[data-win="close"]', el).addEventListener("click", () =>
      closeWindow(app.id),
    );
    $('[data-win="min"]', el).addEventListener("click", () => {
      el.style.display = "none";
      task.classList.remove("active");
    });
    $('[data-win="max"]', el).addEventListener("click", () =>
      el.classList.toggle("maximized"),
    );
    task.addEventListener("click", () => {
      if (el.style.display === "none") focusWindow(win);
      else if (task.classList.contains("active")) {
        el.style.display = "none";
        task.classList.remove("active");
      } else focusWindow(win);
    });
    win.dispose = makeDraggable(el, $(".window-titlebar", el));
    focusWindow(win);
    return win;
  }

  function findApp(id) {
    return state.apps.find(app => app.id === id);
  }

  function openApp(appOrId) {
    const app = typeof appOrId === "string" ? findApp(appOrId) : appOrId;
    if (!app || !state.bootstrap) return;
    if (app.entryType === "site") {
      const browser = findApp("browser");
      if (browser) openBrowser(browser, `mz://${app.entryKey}`);
      return;
    }
    const existing = state.windows.get(app.id);
    if (existing) { focusWindow(existing); return; }
    switch (app.entryKey) {
      case 'profile':
        openProfile(app);
        break;
      case "browser":
        openBrowser(app);
        break;
      case "notes":
        openContentApp(app, "notes");
        break;
      case "files":
        openContentApp(app, "documents");
        break;
      case "settings":
        openSettings(app);
        break;
      case "about":
        openAbout(app);
        break;
      default:
        showToast(
          "Aplicativo indisponível",
          "Este aplicativo não possui uma interface interna carregada.",
        );
    }
  }

  async function navigateBrowser(win, address, pushHistory = true) {
    const addressInput = $(".browser-address", win.content);
    const page = $(".browser-page", win.content);
    addressInput.value = address || "mz://home";
    page.innerHTML = '<div class="empty-state">Carregando…</div>';
    const result = await request("browser.navigate", {
      address: addressInput.value,
    });
    if (!result.ok) {
      page.innerHTML = `<div class="blocked-page"><div class="danger-icon">⊘</div><h3>Navegação bloqueada</h3><p>${escapeHtml(errorText(result.error))}</p><p class="security-note">A MZ Net existe somente dentro do jogo.</p></div>`;
      return;
    }
    if (pushHistory) {
      state.browserHistory = state.browserHistory.slice(
        0,
        state.browserHistoryIndex + 1,
      );
      state.browserHistory.push(addressInput.value);
      state.browserHistoryIndex = state.browserHistory.length - 1;
    }
    if (result.data.kind === "site") renderSitePage(win, result.data.site);
    else renderSearchPage(win, result.data.query, result.data.results || []);
  }

  function renderSitePage(win, site) {
    const page = $(".browser-page", win.content);
    const alias =
      Array.isArray(site.aliases) && site.aliases[0]
        ? site.aliases[0]
        : `${site.id}.mz`;
    page.innerHTML = `<div class="site-hero"><span class="app-glyph">${icon(site.icon)}</span><h2>${escapeHtml(site.title)}</h2><p>${escapeHtml(site.description || "")}</p><p>${escapeHtml(site.content || "")}</p><small>${escapeHtml(alias)}</small></div>`;
    $(".browser-address", win.content).value = site.url || `mz://${site.id}`;
  }

  function renderSearchPage(win, query, results) {
    const page = $(".browser-page", win.content);
    page.innerHTML = "";
    const hero = document.createElement("div");
    hero.className = "site-hero";
    const h = document.createElement("h2");
    h.textContent = `Pesquisa: ${query || ""}`;
    const p = document.createElement("p");
    p.textContent = results.length
      ? `${results.length} resultado(s) na MZ Net.`
      : "Nenhum serviço interno encontrado.";
    hero.append(h, p);
    page.appendChild(hero);
    for (const site of results) {
      const button = document.createElement("button");
      button.className = "search-result";
      const alias =
        Array.isArray(site.aliases) && site.aliases[0]
          ? site.aliases[0]
          : `${site.id}.mz`;
      button.innerHTML = `<strong>${escapeHtml(site.title)}</strong><span>${escapeHtml(alias)}</span><p>${escapeHtml(site.description || "")}</p>`;
      button.addEventListener("click", () =>
        navigateBrowser(win, `mz://${site.id}`),
      );
      page.appendChild(button);
    }
  }

  function openBrowser(app, initialAddress) {
    const win = createWindow(app, { width: "76%", height: "76%" });
    if (!win.content.dataset.ready) {
      win.content.dataset.ready = "1";
      win.content.innerHTML = `<div class="browser">
        <div class="browser-toolbar">
          <button data-browser="back" title="Voltar" aria-label="Voltar">${icon('back')}</button>
          <button data-browser="home" title="Início" aria-label="Início">${icon('home')}</button>
          <button data-browser="refresh" title="Atualizar" aria-label="Atualizar">${icon('refresh')}</button>
          <input class="browser-address" maxlength="180" spellcheck="false" value="mz://home" aria-label="Endereço da MZ Net">
          <button data-browser="go" aria-label="Ir">${icon('arrow')}</button>
        </div>
        <div class="browser-page"></div>
      </div>`;
      const input = $(".browser-address", win.content);
      $('[data-browser="refresh"]', win.content).addEventListener('click', () => navigateBrowser(win, input.value, false));
      input.addEventListener("keydown", (e) => {
        if (e.key === "Enter") navigateBrowser(win, input.value);
      });
      $('[data-browser="go"]', win.content).addEventListener("click", () =>
        navigateBrowser(win, input.value),
      );
      $('[data-browser="home"]', win.content).addEventListener("click", () =>
        navigateBrowser(win, "mz://home"),
      );
      $('[data-browser="back"]', win.content).addEventListener("click", () => {
        if (state.browserHistoryIndex > 0) {
          state.browserHistoryIndex -= 1;
          navigateBrowser(
            win,
            state.browserHistory[state.browserHistoryIndex],
            false,
          );
        }
      });
      navigateBrowser(win, initialAddress || "mz://home");
    } else if (initialAddress) navigateBrowser(win, initialAddress);
  }

  async function openContentApp(app, kind) {
    const win = createWindow(app, { width: "72%", height: "74%" });
    win.content.innerHTML = `<div class="split-app">
      <aside class="item-list">
        <div class="list-toolbar"><button class="small-button" data-content="new">${icon('plus')} Novo</button><button class="small-button" data-content="refresh" aria-label="Atualizar">${icon('refresh')}</button></div>
        <div class="content-items"><div class="empty-state">Carregando…</div></div>
      </aside>
      <main class="editor">
        <input class="editor-title" maxlength="120" placeholder="Título">
        <textarea class="editor-body" maxlength="${kind === 'notes' ? 10000 : 20000}" placeholder="Escreva aqui…" aria-label="Conteúdo"></textarea>
        <div class="editor-actions"><button class="small-button danger" data-content="delete">${icon('trash')} Excluir</button><button class="small-button" data-content="save">${icon('save')} Salvar</button></div>
      </main>
    </div>`;
    const api = kind === "notes" ? "notes" : "documents";
    const itemsEl = $(".content-items", win.content);
    const titleEl = $(".editor-title", win.content);
    const bodyEl = $(".editor-body", win.content);
    let items = [],
      current = null;

    function select(item) {
      current = item;
      titleEl.value = item?.title || "";
      bodyEl.value = item?.content || "";
      $$(".content-list-item", itemsEl).forEach((el) =>
        el.classList.toggle(
          "active",
          String(el.dataset.id) === String(item?.id),
        ),
      );
    }
    function render() {
      itemsEl.replaceChildren();
      if (!items.length) {
        const e = document.createElement("div");
        e.className = "empty-state";
        e.textContent = "Nenhum conteúdo ainda.";
        itemsEl.appendChild(e);
        return;
      }
      for (const item of items) {
        const b = document.createElement("button");
        b.className = "content-list-item";
        b.dataset.id = item.id;
        const strong = document.createElement("strong");
        strong.textContent = item.title;
        const span = document.createElement("span");
        span.textContent = item.updated_at || item.created_at || "";
        b.append(strong, span);
        b.addEventListener("click", () => select(item));
        itemsEl.appendChild(b);
      }
      if (current)
        select(items.find((x) => String(x.id) === String(current.id)) || null);
    }
    async function load() {
      const r = await request(`${api}.list`);
      if (!r.ok) {
        showToast(app.name, errorText(r.error));
        return;
      }
      items = Array.isArray(r.data) ? r.data : [];
      render();
      if (!current && items[0]) select(items[0]);
    }
    $('[data-content="refresh"]', win.content).addEventListener("click", load);
    $('[data-content="new"]', win.content).addEventListener(
      "click",
      async () => {
        const r = await request(`${api}.create`, {
          title: kind === "notes" ? "Nova nota" : "Novo documento",
          content: "",
        });
        if (!r.ok) {
          showToast(app.name, errorText(r.error));
          return;
        }
        items.unshift(r.data);
        render();
        select(r.data);
        titleEl.focus();
        titleEl.select();
      },
    );
    $('[data-content="save"]', win.content).addEventListener(
      "click",
      async () => {
        if (!current) {
          showToast(app.name, "Crie ou selecione um item primeiro.");
          return;
        }
        const r = await request(`${api}.update`, {
          id: current.id,
          title: titleEl.value,
          content: bodyEl.value,
          revision: current.revision,
        });
        if (!r.ok) {
          showToast(app.name, errorText(r.error));
          if (r.error === "CONFLICT") load();
          return;
        }
        const idx = items.findIndex((x) => String(x.id) === String(current.id));
        if (idx >= 0) items[idx] = r.data;
        current = r.data;
        render();
        showToast(app.name, "Salvo.");
      },
    );
    $('[data-content="delete"]', win.content).addEventListener(
      "click",
      async () => {
        if (!current) return;
        const r = await request(`${api}.delete`, { id: current.id });
        if (!r.ok) {
          showToast(app.name, errorText(r.error));
          return;
        }
        items = items.filter((x) => String(x.id) !== String(current.id));
        current = null;
        titleEl.value = "";
        bodyEl.value = "";
        render();
        if (items[0]) select(items[0]);
      },
    );
    load();
  }

  function openSettings(app) {
    const win = createWindow(app, { width: "55%", height: "66%" });
    const s = state.settings;
    win.content.innerHTML = `<div class="settings-page">
      <div class="setting-group"><h3>Aparência</h3>
        <div class="setting-row"><span>Tema</span><input id="set-theme" type="hidden"><div class="choice-group" data-setting="theme"><button data-value="dark">Escuro</button><button data-value="light">Claro</button></div></div>
        <div class="setting-row"><span>Papel de parede</span><input id="set-wallpaper" type="hidden"><div class="choice-group" data-setting="wallpaper"><button data-value="midnight">Noite</button><button data-value="ocean">Oceano</button><button data-value="ember">Aurora</button></div></div>
        <div class="setting-row"><span>Escala</span><input id="set-scale" type="range" min="0.85" max="1.15" step="0.05"></div>
      </div>
      <div class="setting-group"><h3>Sistema</h3><div class="setting-row"><span>Sons do MZ OS</span><input id="set-sounds" type="checkbox"></div></div>
      <button class="primary" id="save-settings">Salvar configurações</button>
    </div>`;
    $("#set-theme", win.content).value = s.theme || "dark";
    $("#set-wallpaper", win.content).value = s.wallpaper || "midnight";
    $("#set-scale", win.content).value = String(s.scale || 1);
    $("#set-sounds", win.content).checked = s.sounds !== false;
    $$('.choice-group', win.content).forEach(group => {
      const input = $(`#set-${group.dataset.setting}`, win.content);
      const update = () => $$('button', group).forEach(b => b.setAttribute('aria-pressed', String(b.dataset.value === input.value)));
      $$('button', group).forEach(button => button.addEventListener('click', () => {
        input.value = button.dataset.value;
        update();
      }));
      update();
    });
    $("#save-settings", win.content).addEventListener("click", async () => {
      const settings = {
        ...state.settings,
        theme: $("#set-theme", win.content).value,
        wallpaper: $("#set-wallpaper", win.content).value,
        scale: Number($("#set-scale", win.content).value),
        sounds: $("#set-sounds", win.content).checked,
      };
      const r = await request("settings.save", { settings });
      if (!r.ok) {
        showToast("Configurações", errorText(r.error));
        return;
      }
      applySettings(r.data);
      showToast("Configurações", "Preferências salvas.");
    });
  }

  async function openProfile(app) {
    const win = createWindow(app, { width: '57%', height: '71%' });
    win.content.innerHTML = '<div class="empty-state">Carregando seu perfil…</div>';
    const result = await request('profile.get');
    if (!win.el.isConnected) return;
    if (!result.ok) {
      win.content.innerHTML = `<div class="empty-state">${escapeHtml(errorText(result.error))}</div>`;
      return;
    }
    const p = result.data || {};
    const name = `${p.firstname || ''} ${p.lastname || ''}`.trim() || 'Cidadão';
    win.content.innerHTML = `<div class="profile-page">
      <div class="profile-hero"><div class="profile-avatar">${icon('user')}</div><div><h2>${escapeHtml(name)}</h2><p>Seu perfil na cidade</p></div></div>
      <div class="meta-table">
        <div class="meta-row"><span>Registro do cidadão</span><strong>${escapeHtml(p.citizenid || '—')}</strong></div>
        <div class="meta-row"><span>Telefone</span><strong>${escapeHtml(p.phone || 'Não informado')}</strong></div>
        <div class="meta-row"><span>Conta digital</span><strong>${escapeHtml(state.bootstrap?.account?.username || '—')}</strong></div>
        <div class="meta-row"><span>Dispositivo</span><strong>${escapeHtml(state.device?.label || 'Computador')}</strong></div>
      </div>
      <p class="profile-footnote">${icon('shield')} Informações do seu personagem nesta sessão.</p>
    </div>`;
  }

  function openAbout(app) {
    const win = createWindow(app, { width: "50%", height: "58%" });
    const b = state.bootstrap || {};
    const d = b.device || state.device || {};
    win.content.innerHTML = `<div class="about-page"><div class="about-card"><div class="mz-mark">MZ</div><div><h2>MZ OS</h2><p>Seu espaço digital na cidade.</p></div></div><div class="meta-table">
      <div class="meta-row"><span>Versão</span><strong>${escapeHtml(b.version || "1.0.0")}</strong></div>
      <div class="meta-row"><span>Dispositivo</span><strong>${escapeHtml(d.label || d.type || "Computador")}</strong></div>
      <div class="meta-row"><span>Serial</span><strong>${escapeHtml(d.serial || "—")}</strong></div>
      <div class="meta-row"><span>Rede</span><strong>${escapeHtml(b.network?.name || "MZ Net")}</strong></div>
      <div class="meta-row"><span>Tela</span><strong>${(document.documentElement.classList.contains('world-surface') || document.documentElement.classList.contains('hybrid-interactive')) ? 'Monitor 3D' : 'Notebook'}</strong></div>
    </div></div>`;
  }

  function renderNotifications() {
    notificationList.replaceChildren();
    const unread = state.notifications.filter(
      (n) => Number(n.is_read) === 0,
    ).length;
    notificationBadge.textContent = String(unread);
    notificationBadge.classList.toggle("hidden", unread === 0);
    if (!state.notifications.length) {
      const e = document.createElement("div");
      e.className = "empty-state";
      e.textContent = "Nenhuma notificação.";
      notificationList.appendChild(e);
      return;
    }
    for (const n of state.notifications) {
      const item = document.createElement("div");
      item.className = "notification-item";
      const strong = document.createElement("strong");
      strong.textContent = n.title;
      const p = document.createElement("p");
      p.textContent = n.message;
      item.append(strong, p);
      item.addEventListener("click", async () => {
        if (Number(n.is_read) === 0) {
          const r = await request("notifications.read", { id: n.id });
          if (r.ok) {
            n.is_read = 1;
            renderNotifications();
          }
        }
      });
      notificationList.appendChild(item);
    }
  }

  $("#start-button").addEventListener("click", () => {
    if (launcher.classList.contains('hidden')) showLauncher();
    else launcher.classList.add('hidden');
  });
  $("#notification-button").addEventListener("click", () => {
    notificationCenter.classList.toggle("hidden");
    launcher.classList.add("hidden");
  });
  $('[data-action="close-notifications"]').addEventListener("click", () =>
    notificationCenter.classList.add("hidden"),
  );
  $("#power-button").addEventListener("click", async () => {
    $('#power-menu').classList.toggle('hidden');
    launcher.classList.add('hidden');
    notificationCenter.classList.add('hidden');
  });
  $$('[data-action="shutdown"]').forEach(el => el.addEventListener('click', () => nui('close')));
  $$('[data-action="lock"]').forEach(el => el.addEventListener('click', async () => {
    el.disabled = true;
    const result = await request('auth.logout');
    el.disabled = false;
    if (result.ok && state.open) await prepareAuth();
    else if (state.open) showToast('Sessão', errorText(result.error));
  }));
  $('[data-action="profile"]').addEventListener('click', () => {
    launcher.classList.add('hidden');
    openApp('profile');
  });
  $('#show-desktop').addEventListener('click', () => {
    const visible = [...state.windows.values()].some(win => win.el.style.display !== 'none');
    for (const win of state.windows.values()) {
      if (visible) { win.el.style.display = 'none'; win.task.classList.remove('active'); }
      else focusWindow(win);
    }
  });
  $("#clock-button").addEventListener("click", () =>
    notificationCenter.classList.toggle("hidden"),
  );

  async function openComputer(message) {
    clearTimeout(state.bootTimer);
    state.epoch++;
    state.open = true;
    state.bootstrap = null;
    state.apps = [];
    state.notifications = [];
    closeAllWindows();
    $('#app-search').value = '';
    $('#power-menu').classList.add('hidden');
    toastStack.replaceChildren();
    root.classList.remove("is-hidden");
    root.style.display = "flex";
    root.style.visibility = "visible";
    root.style.opacity = "1";
    root.style.pointerEvents = "auto";
    root.setAttribute("aria-hidden", "false");
    applyDevice(message.device || {});
    applySettings({ theme: "dark", scale: 1, wallpaper: "midnight" });
    setScreen("boot");
    const delay = Math.max(250, Number(message.ui?.bootDurationMs) || 1100);
    state.bootTimer = setTimeout(prepareAuth, delay);
    if (surfaceId) {
      const epoch = state.epoch;
      // Allow style/layout and a paint opportunity before Lua commits the 3D
      // display. A closed/replaced session must never acknowledge a stale open.
      requestAnimationFrame(() => requestAnimationFrame(() => {
        if (state.open && state.epoch === epoch && root.getBoundingClientRect().width > 0) {
          nui('surfaceVisible', { id: surfaceId }).catch(() => {});
        }
      }));
    }
  }

  function closeComputerVisual() {
    clearTimeout(state.bootTimer);
    state.epoch++;
    state.open = false;
    closeAllWindows();
    launcher.classList.add("hidden");
    notificationCenter.classList.add("hidden");
    $('#power-menu').classList.add('hidden');
    state.bootstrap = null;
    state.apps = [];
    state.notifications = [];
    state.browserHistory = [];
    state.browserHistoryIndex = -1;
    toastStack.replaceChildren();
    root.classList.add("is-hidden");
    root.style.display = "none";
    root.style.visibility = "hidden";
    root.style.opacity = "0";
    root.style.pointerEvents = "none";
    root.setAttribute("aria-hidden", "true");
    setScreen("boot");
    passwordInput.value = "";
    confirmInput.value = "";
  }

  window.addEventListener("message", async (event) => {
    const msg = event.data || {};
    if (msg.type === "computer:open") openComputer(msg);
    else if (msg.type === "computer:close") closeComputerVisual();
    else if (msg.type === "auth:forceLogout" && state.open) {
      showToast(
        "Sessão encerrada",
        msg.reason === "DEVICE_TOO_FAR"
          ? "Você se afastou do computador."
          : "Sua sessão foi encerrada.",
      );
      await prepareAuth();
    } else if (msg.type === "notification:push" && msg.notification) {
      state.notifications.unshift(msg.notification);
      renderNotifications();
      showToast(msg.notification.title, msg.notification.message);
    } else if (msg.type === "app:open" && state.open) openApp(msg.appId);
    else if (msg.type === "toast") showToast("MZ OS", msg.message || "");
  });

  window.addEventListener("keydown", async (event) => {
    if (!state.open) return;
    if (event.key === 'F3' && state.bootstrap) {
      event.preventDefault();
      showLauncher(true);
      return;
    }
    if (event.key === 'F5') {
      event.preventDefault();
      const win = [...state.windows.values()].find(w => w.task.classList.contains('active'));
      if (win) $('[data-browser="refresh"]', win.content)?.click();
      return;
    }
    if (event.key === "Escape") {
      event.preventDefault();
      if (!$('#power-menu').classList.contains('hidden')) {
        $('#power-menu').classList.add('hidden');
        return;
      }
      if (!notificationCenter.classList.contains("hidden")) {
        notificationCenter.classList.add("hidden");
        return;
      }
      if (!launcher.classList.contains("hidden")) {
        launcher.classList.add("hidden");
        return;
      }
      await nui("close");
    }
  });

  document.addEventListener("mousedown", (event) => {
    if (
      !event.target.closest("#launcher") &&
      !event.target.closest("#start-button") &&
      !event.target.closest("#search-button")
    )
      launcher.classList.add("hidden");
    if (!event.target.closest('#power-menu') && !event.target.closest('#power-button')) $('#power-menu').classList.add('hidden');
  });

  // FiveM keeps the NUI page mounted as soon as the resource starts.
  // Hard-hide it before announcing readiness so a transparent idle page never paints a fullscreen canvas.
  document.documentElement.style.background = "transparent";
  document.body.style.background = "transparent";
  closeComputerVisual();
  if (surfaceId) nui('surfaceReady', { id: surfaceId }).catch(() => {});
  else nui("ready").catch(() => {});
})();
