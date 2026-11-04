(() => {
  'use strict';
  const surfaceId = new URLSearchParams(location.search).get('surface');
  const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mz_computer';
  const post = (endpoint, payload) => fetch(`https://${resource}/${endpoint}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload),
  }).then(r => r.json()).catch(() => ({ ok: false }));
  const isText = el => el && (el.tagName === 'TEXTAREA' ||
    (el.tagName === 'INPUT' && ['text', 'password', 'search', 'email', 'url', 'tel'].includes(el.type)));

  // Legacy interactive DUI browser. Hybrid terminals do not load this page into
  // their world DUI; they use display.html and keep this bridge dormant.
  if (surfaceId) {
    document.documentElement.classList.add('world-surface');
    let fieldSequence = 0, applying = false;
    const fields = new WeakMap();
    const syncFocus = () => {
      if (applying) return;
      const el = document.activeElement;
      if (isText(el)) {
        if (!fields.has(el)) fields.set(el, String(++fieldSequence));
        post('surfaceFocus', { id: surfaceId, field: fields.get(el), value: el.value,
          start: el.selectionStart, finish: el.selectionEnd, multiline: el.tagName === 'TEXTAREA',
          maxLength: el.maxLength > 0 ? el.maxLength : 20000 });
      } else post('surfaceFocus', { id: surfaceId, field: null });
    };
    document.addEventListener('focusin', syncFocus);
    document.addEventListener('selectionchange', syncFocus);
    document.addEventListener('mouseup', () => setTimeout(syncFocus, 0));
    window.addEventListener('message', event => {
      const msg = event.data || {};
      const el = document.activeElement;
      if (msg.type === 'surface:text' && isText(el) && fields.get(el) === msg.field) {
        applying = true;
        el.value = String(msg.value).slice(0, el.maxLength > 0 ? el.maxLength : 20000);
        el.setSelectionRange(msg.start || 0, msg.finish || 0);
        el.dispatchEvent(new Event('input', { bubbles: true }));
        setTimeout(() => { applying = false; }, 0);
      } else if (msg.type === 'surface:key') {
        if (msg.key === 'Tab') {
          const focusable = [...document.querySelectorAll('button,input,textarea,select,[tabindex="0"]')]
            .filter(node => !node.disabled && node.getClientRects().length > 0);
          if (focusable.length) {
            const index = focusable.indexOf(el);
            focusable[(index + (msg.shift ? -1 : 1) + focusable.length) % focusable.length].focus();
          }
        } else {
          const keyEvent = new KeyboardEvent('keydown', { key: msg.key, bubbles: true, cancelable: true });
          (el || document.body).dispatchEvent(keyEvent);
          if (msg.key === 'Enter' && !keyEvent.defaultPrevented) {
            if (el?.tagName === 'BUTTON') el.click();
            else if (isText(el) && el.tagName !== 'TEXTAREA') el.form?.requestSubmit();
          }
        }
      }
    });
    return;
  }

  let activeId = null, mapping = null, pressed = false, field = null, multiline = false;
  let hybridId = null, hybridPoints = null;
  let tabTransition = null;
  let lastPoint = { x: 0.5, y: 0.5 }, pendingMove = null, queue = Promise.resolve();
  const proxy = document.createElement('textarea');
  proxy.className = 'surface-input-proxy';
  proxy.setAttribute('aria-label', 'Entrada do monitor 3D');
  proxy.setAttribute('autocomplete', 'off');
  proxy.spellcheck = false;
  proxy.tabIndex = -1;
  proxy.hidden = true;
  document.body.append(proxy);
  const hint = document.createElement('div');
  hint.className = 'surface-hint hidden';
  hint.innerHTML = '<span>MZ OS</span> <kbd>ESC</kbd> Sair do computador';
  document.body.append(hint);

  const HYBRID_WIDTH = 1280, HYBRID_HEIGHT = 720;
  const clearHybridProjection = () => {
    const html = document.documentElement;
    html.classList.remove('hybrid-projected');
    html.style.removeProperty('--hybrid-matrix');
  };

  const applyHybridProjection = points => {
    hybridPoints = Array.isArray(points) && points.length === 4 ? points : null;
    if (!hybridId || !hybridPoints || !window.MZHybridMath) { clearHybridProjection(); return; }
    const area = MZHybridMath.quadArea(hybridPoints, innerWidth, innerHeight);
    if (!Number.isFinite(area) || area < 1800) { clearHybridProjection(); return; }
    const matrix = MZHybridMath.cssMatrix(hybridPoints, HYBRID_WIDTH, HYBRID_HEIGHT, innerWidth, innerHeight);
    if (!matrix) { clearHybridProjection(); return; }
    const html = document.documentElement;
    html.style.setProperty('--hybrid-matrix', matrix.css);
    html.classList.add('hybrid-projected');
  };

  const stopHybrid = () => {
    hybridId = hybridPoints = null;
    document.documentElement.classList.remove('hybrid-interactive');
    clearHybridProjection();
    if (!activeId) hint.classList.add('hidden');
  };

  window.addEventListener('resize', () => { if (hybridId && hybridPoints) applyHybridProjection(hybridPoints); });

  const send = payload => {
    const id = activeId;
    if (!id) return;
    queue = queue.then(() => activeId === id ? post('surfaceInput', { ...payload, id }) : null);
  };
  const flushMove = () => {
    if (pendingMove) {
      send({ kind: 'pointer', event: 'move', ...pendingMove });
      pendingMove = null;
    }
  };
  const pointFor = event => mapping?.(event.clientX / innerWidth, event.clientY / innerHeight);
  const inside = p => p && p.x >= 0 && p.x <= 1 && p.y >= 0 && p.y <= 1;

  window.addEventListener('message', event => {
    const msg = event.data || {};
    if (msg.type === 'hybrid:start') {
      activeId = mapping = field = pendingMove = null;
      pressed = false;
      proxy.hidden = true;
      proxy.blur();
      document.documentElement.classList.remove('surface-controller');
      hybridId = msg.id;
      document.documentElement.classList.add('hybrid-interactive');
      hint.classList.remove('hidden');
      if (hybridPoints) applyHybridProjection(hybridPoints);
    } else if (msg.type === 'hybrid:stop') {
      if (!msg.id || msg.id === hybridId) stopHybrid();
    } else if (msg.type === 'computer:close') {
      stopHybrid();
    } else if (msg.id === hybridId && msg.type === 'hybrid:projection') {
      applyHybridProjection(msg.points);
    } else if (msg.type === 'surface:start') {
      stopHybrid();
      activeId = msg.id;
      proxy.hidden = false;
      document.documentElement.classList.add('surface-controller');
      hint.classList.remove('hidden');
    } else if (msg.type === 'surface:stop') {
      activeId = mapping = field = pendingMove = null;
      tabTransition = null;
      pressed = false;
      proxy.value = '';
      proxy.blur();
      proxy.hidden = true;
      if (!hybridId) hint.classList.add('hidden');
      document.documentElement.classList.remove('surface-controller');
    } else if (msg.id === activeId && msg.type === 'surface:projection') {
      mapping = MZScreenMath.projectiveMap(msg.points);
    } else if (msg.id === activeId && msg.type === 'surface:focus') {
      if (tabTransition && msg.field === tabTransition.previousField) return;
      const buffered = tabTransition ? proxy.value : '';
      tabTransition = null;
      field = msg.field;
      multiline = !!msg.multiline;
      proxy.value = field ? msg.value || '' : '';
      if (field) {
        proxy.maxLength = Math.min(20000, msg.maxLength || 20000);
        proxy.focus({ preventScroll: true });
        proxy.setSelectionRange(msg.start || 0, msg.finish || 0);
        if (buffered) {
          proxy.setRangeText(buffered, proxy.selectionStart, proxy.selectionEnd, 'end');
          syncText();
        }
      } else proxy.blur();
    }
  });

  document.addEventListener('mousemove', event => {
    if (!activeId) return;
    const point = pointFor(event);
    if (!inside(point) && !pressed) return;
    lastPoint = point || lastPoint;
    pendingMove = lastPoint;
    requestAnimationFrame(flushMove);
  });
  document.addEventListener('mousedown', event => {
    if (!activeId || event.button !== 0) return;
    event.preventDefault();
    const point = pointFor(event);
    if (!inside(point)) return;
    flushMove();
    pressed = true;
    lastPoint = point;
    send({ kind: 'pointer', event: 'down', ...point });
  });
  document.addEventListener('mouseup', event => {
    if (!activeId || event.button !== 0 || !pressed) return;
    flushMove();
    send({ kind: 'pointer', event: 'up', ...(pointFor(event) || lastPoint) });
    pressed = false;
  });
  document.addEventListener('wheel', event => {
    if (!activeId) return;
    event.preventDefault();
    const point = pointFor(event);
    if (inside(point)) send({ kind: 'pointer', event: 'wheel', ...point, delta: -event.deltaY });
  }, { passive: false });
  document.addEventListener('contextmenu', event => { if (activeId) event.preventDefault(); });
  const syncText = () => {
    if (activeId && field) send({ kind: 'text', field, value: proxy.value,
      start: proxy.selectionStart, finish: proxy.selectionEnd });
  };
  proxy.addEventListener('input', syncText);
  proxy.addEventListener('keyup', syncText);
  window.addEventListener('keydown', event => {
    if (!activeId) return;
    event.stopImmediatePropagation();
    if (['Escape', 'Tab', 'F3', 'F5'].includes(event.key) ||
      (event.key === 'Enter' && !multiline && !event.isComposing)) {
      event.preventDefault();
      if ((event.key === 'Tab' && field) || event.key === 'F3') {
        tabTransition = { previousField: field };
        field = null;
        proxy.value = '';
        proxy.focus({ preventScroll: true });
      }
      send({ kind: 'key', key: event.key, shift: event.shiftKey });
    }
  }, true);
})();
