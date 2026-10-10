(() => {
  'use strict';

  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
  const canvas = $('#artboard');
  const ctx = canvas.getContext('2d');
  const stage = $('#stage');
  const paperWrap = $('#paperWrap');
  const toastNode = $('#toast');
  const STORAGE_KEY = 'animpro.preview.project.v1';
  const THEME_KEY = 'animpro.preview.theme';
  const toolSpecs = [
    { id: 'pencil', label: 'Pencil', icon: '✎' },
    { id: 'pen', label: 'Pen', icon: '╱' },
    { id: 'marker', label: 'Marker', icon: '▰' },
    { id: 'airbrush', label: 'Airbrush', icon: '◉' },
    { id: 'calligraphy', label: 'Calligraphy', icon: '𝓐' },
    { id: 'crayon', label: 'Crayon', icon: '✳' },
    { id: 'eraser', label: 'Eraser', icon: '▱' },
    { id: 'line', label: 'Line', icon: '／' },
    { id: 'rectangle', label: 'Rectangle', icon: '▭' },
    { id: 'ellipse', label: 'Ellipse', icon: '◯' },
    { id: 'hand', label: 'Pan canvas', icon: '✋' },
  ];
  const paletteColors = [
    '#252336', '#6c5ce7', '#00b894', '#fdcb6e', '#ff6b75',
    '#3685f4', '#7aab5b', '#fffdf8', '#8b6147', '#ee9db4',
  ];
  const uid = () => `f_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 7)}`;
  const clone = value => JSON.parse(JSON.stringify(value));

  function createInitialProject() {
    const layers = [
      { id: 'backdrop', name: 'Backdrop', kind: 'background', visible: true, locked: true, opacity: 1, blend: 'source-over' },
      { id: 'sprout', name: 'Sprout', kind: 'sprout', visible: true, locked: false, opacity: 1, blend: 'source-over' },
      { id: 'sketch', name: 'Pencil details', kind: 'ink', visible: true, locked: false, opacity: 1, blend: 'source-over' },
    ];
    const frames = Array.from({ length: 8 }, () => ({
      id: uid(), hold: 1,
      drawings: Object.fromEntries(layers.map(layer => [layer.id, []])),
    }));
    return {
      name: 'Morning, frame by frame',
      layers,
      frames,
      frameIndex: 4,
      activeLayerId: 'sprout',
      tool: 'pencil',
      color: '#252336',
      brushSize: 7,
      fps: 12,
      onion: true,
      mirror: false,
      grid: false,
      loop: true,
      zoom: 1,
      rotation: 0,
      panX: 0,
      panY: 0,
    };
  }

  let state = createInitialProject();
  try {
    const stored = JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null');
    if (stored && Array.isArray(stored.frames) && stored.frames.length > 0 && Array.isArray(stored.layers) && stored.layers.length > 0) {
      state = { ...state, ...stored };
      state.frameIndex = Math.max(0, Math.min(Number(state.frameIndex) || 0, state.frames.length - 1));
    }
  } catch (_) { /* A damaged preview save should never block the editor. */ }

  let history = [];
  let redoHistory = [];
  let clipboardFrame = null;
  let draft = null;
  let panGesture = null;
  let playbackTimer = null;
  let playbackReverse = false;
  let holdTicks = 0;
  let dragFrameIndex = null;
  let dragLayerId = null;
  let toastTimer = null;
  let sortByName = false;
  let selectedExportFormat = 'gif';
  let resizeTimer = null;
  const layerBuffers = new Map();

  function snapshot() {
    history.push(JSON.stringify({
      frames: state.frames,
      layers: state.layers,
      frameIndex: state.frameIndex,
      activeLayerId: state.activeLayerId,
    }));
    redoHistory = [];
    updateHistoryButtons();
  }

  function restoreSnapshot(data) {
    const parsed = JSON.parse(data);
    state.frames = parsed.frames;
    state.layers = parsed.layers;
    state.frameIndex = Math.max(0, Math.min(parsed.frameIndex, state.frames.length - 1));
    state.activeLayerId = state.layers.some(layer => layer.id === parsed.activeLayerId)
      ? parsed.activeLayerId : state.layers.at(-1)?.id;
    layerBuffers.clear();
    renderAll();
  }

  function undo() {
    if (!history.length) return;
    redoHistory.push(JSON.stringify({ frames: state.frames, layers: state.layers, frameIndex: state.frameIndex, activeLayerId: state.activeLayerId }));
    restoreSnapshot(history.pop());
    updateHistoryButtons();
  }

  function redo() {
    if (!redoHistory.length) return;
    history.push(JSON.stringify({ frames: state.frames, layers: state.layers, frameIndex: state.frameIndex, activeLayerId: state.activeLayerId }));
    restoreSnapshot(redoHistory.pop());
    updateHistoryButtons();
  }

  function saveLocal() {
    try {
      const { name, layers, frames, frameIndex, activeLayerId, tool, color, brushSize, fps, onion, mirror, grid, loop, zoom, rotation, panX, panY } = state;
      localStorage.setItem(STORAGE_KEY, JSON.stringify({ name, layers, frames, frameIndex, activeLayerId, tool, color, brushSize, fps, onion, mirror, grid, loop, zoom, rotation, panX, panY }));
      const status = $('.project-subtitle');
      if (status) status.innerHTML = '<span class="save-dot"></span> Saved locally <span class="metadata-divider">·</span> 1080 × 1080';
    } catch (_) {
      showToast('This browser could not store more local project data.');
    }
  }

  function showToast(message) {
    toastNode.textContent = message;
    toastNode.classList.add('is-visible');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastNode.classList.remove('is-visible'), 2400);
  }

  function activeLayer() {
    return state.layers.find(layer => layer.id === state.activeLayerId) || state.layers.at(-1);
  }

  function currentFrame() {
    return state.frames[state.frameIndex];
  }

  function colorWithAlpha(hex, alpha) {
    const value = hex.replace('#', '');
    const n = parseInt(value.length === 3 ? value.split('').map(c => c + c).join('') : value, 16);
    return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${alpha})`;
  }

  function drawCloud(context, x, y, scale = 1) {
    context.save();
    context.translate(x, y);
    context.scale(scale, scale);
    context.fillStyle = 'rgba(255,255,255,.73)';
    context.beginPath();
    context.moveTo(-82, 12);
    context.bezierCurveTo(-101, 11, -103, -11, -84, -20);
    context.bezierCurveTo(-79, -43, -51, -48, -37, -31);
    context.bezierCurveTo(-20, -55, 18, -45, 21, -20);
    context.bezierCurveTo(49, -29, 69, -12, 63, 7);
    context.bezierCurveTo(83, 15, 72, 33, 54, 33);
    context.lineTo(-73, 33);
    context.bezierCurveTo(-90, 33, -96, 23, -82, 12);
    context.fill();
    context.restore();
  }

  function drawBackground(context) {
    const sky = context.createLinearGradient(0, 0, 0, 1080);
    sky.addColorStop(0, '#c8e8e9');
    sky.addColorStop(.58, '#eff1dc');
    sky.addColorStop(1, '#fff1d9');
    context.fillStyle = sky;
    context.fillRect(0, 0, 1080, 1080);

    const sunGlow = context.createRadialGradient(814, 270, 12, 814, 270, 220);
    sunGlow.addColorStop(0, 'rgba(255,221,135,.48)');
    sunGlow.addColorStop(1, 'rgba(255,221,135,0)');
    context.fillStyle = sunGlow;
    context.fillRect(560, 0, 520, 550);
    context.beginPath();
    context.arc(818, 272, 72, 0, Math.PI * 2);
    context.fillStyle = '#f4c779';
    context.fill();
    context.beginPath();
    context.arc(818, 272, 58, 0, Math.PI * 2);
    context.fillStyle = '#ffdfa1';
    context.fill();

    drawCloud(context, 232, 290, .68);
    drawCloud(context, 495, 189, .42);
    drawCloud(context, 930, 487, .46);

    context.fillStyle = '#b7d3bb';
    context.beginPath();
    context.moveTo(0, 680);
    context.bezierCurveTo(190, 579, 298, 688, 462, 646);
    context.bezierCurveTo(662, 591, 825, 616, 1080, 555);
    context.lineTo(1080, 1080); context.lineTo(0, 1080); context.closePath(); context.fill();

    const hill = context.createLinearGradient(0, 700, 0, 1080);
    hill.addColorStop(0, '#87b998'); hill.addColorStop(1, '#659b7e');
    context.fillStyle = hill;
    context.beginPath();
    context.moveTo(0, 786);
    context.bezierCurveTo(160, 708, 333, 765, 479, 733);
    context.bezierCurveTo(689, 688, 847, 753, 1080, 686);
    context.lineTo(1080, 1080); context.lineTo(0, 1080); context.closePath(); context.fill();

    context.fillStyle = 'rgba(255,255,255,.24)';
    context.beginPath();
    context.moveTo(0, 859);
    context.bezierCurveTo(205, 789, 335, 853, 493, 818);
    context.bezierCurveTo(660, 781, 872, 830, 1080, 767);
    context.lineTo(1080, 793);
    context.bezierCurveTo(878, 860, 674, 816, 499, 850);
    context.bezierCurveTo(331, 885, 189, 822, 0, 889);
    context.closePath(); context.fill();

    for (const [x, y, s] of [[134, 906, .8], [255, 956, .58], [901, 913, .7], [987, 1002, .54], [356, 1004, .45]]) {
      context.save(); context.translate(x, y); context.scale(s, s);
      context.strokeStyle = 'rgba(247,239,204,.88)'; context.lineWidth = 5; context.lineCap = 'round';
      context.beginPath(); context.moveTo(0, 24); context.lineTo(0, -5); context.stroke();
      context.fillStyle = '#f2c77b';
      for (let petal = 0; petal < 5; petal++) {
        context.beginPath(); context.ellipse(0, -14, 5, 9, petal * Math.PI * 2 / 5, 0, Math.PI * 2); context.fill();
      }
      context.beginPath(); context.arc(0, -14, 4, 0, Math.PI * 2); context.fillStyle = '#b9864f'; context.fill();
      context.restore();
    }
  }

  function drawLeaf(context, x, y, angle, size, fill) {
    context.save();
    context.translate(x, y); context.rotate(angle); context.scale(size, size);
    context.beginPath();
    context.moveTo(0, 0);
    context.bezierCurveTo(5, -37, 61, -49, 82, -19);
    context.bezierCurveTo(61, 15, 16, 26, 0, 0);
    context.closePath();
    context.fillStyle = fill; context.fill();
    context.strokeStyle = colorWithAlpha('#317c65', .55); context.lineWidth = 2; context.stroke();
    context.beginPath(); context.moveTo(4, 1); context.quadraticCurveTo(41, -14, 73, -22);
    context.strokeStyle = colorWithAlpha('#f5fff5', .55); context.lineWidth = 2; context.stroke();
    context.restore();
  }

  function drawSprout(context, frameIndex, ghostColor = null) {
    const t = Math.max(0, Math.min(1, frameIndex / Math.max(1, state.frames.length - 1)));
    const baseY = 785;
    const plantHeight = 210 + 290 * t;
    const topY = baseY - plantHeight;
    const green = ghostColor || '#398e70';
    context.save();
    context.lineCap = 'round'; context.lineJoin = 'round';
    context.strokeStyle = ghostColor || '#478e70'; context.lineWidth = 17 - t * 2;
    context.beginPath(); context.moveTo(540, baseY);
    context.bezierCurveTo(529, baseY - plantHeight * .28, 568, topY + plantHeight * .18, 540, topY);
    context.stroke();

    const leafColor = ghostColor || '#72b594';
    const leafColor2 = ghostColor || '#5ba884';
    const leafCount = 1 + Math.floor(t * 2.4);
    drawLeaf(context, 540, baseY - plantHeight * .36, -.62, .77, leafColor2);
    if (leafCount >= 2) drawLeaf(context, 541, baseY - plantHeight * .57, 3.54, .72, leafColor);
    if (leafCount >= 3) drawLeaf(context, 544, baseY - plantHeight * .77, -.6, .54, leafColor2);
    if (t > .37) drawLeaf(context, 543, baseY - plantHeight * .9, 3.45, .42, leafColor);

    if (t > .47) {
      const flowerY = topY - 5;
      context.strokeStyle = ghostColor || '#669977'; context.lineWidth = 7;
      context.beginPath(); context.moveTo(540, topY + 15); context.lineTo(540, flowerY + 14); context.stroke();
      for (let petal = 0; petal < 6; petal++) {
        context.save(); context.translate(540, flowerY); context.rotate(petal * Math.PI / 3);
        context.beginPath(); context.ellipse(0, -21, 12, 22, 0, 0, Math.PI * 2);
        context.fillStyle = ghostColor || '#f295a5'; context.fill();
        if (!ghostColor) { context.strokeStyle = 'rgba(255,255,255,.5)'; context.lineWidth = 2; context.stroke(); }
        context.restore();
      }
      context.beginPath(); context.arc(540, flowerY, 10, 0, Math.PI * 2);
      context.fillStyle = ghostColor || '#f5c467'; context.fill();
    } else {
      context.beginPath(); context.ellipse(540, topY, 14 + t * 8, 22 + t * 7, -.2, 0, Math.PI * 2);
      context.fillStyle = ghostColor || '#98c97e'; context.fill();
    }
    context.restore();
  }

  function drawCheckerboard(context) {
    const cell = 54;
    for (let y = 0; y < 1080; y += cell) {
      for (let x = 0; x < 1080; x += cell) {
        context.fillStyle = ((x / cell + y / cell) % 2) ? '#f4f3f8' : '#eae9f0';
        context.fillRect(x, y, cell, cell);
      }
    }
  }

  function drawOneStroke(context, stroke) {
    if (!stroke.points?.length) return;
    const points = stroke.points;
    const first = points[0]; const last = points[points.length - 1];
    context.save();
    context.lineCap = 'round'; context.lineJoin = 'round';
    context.globalAlpha *= (stroke.opacity ?? 1);
    context.strokeStyle = stroke.color || '#252336'; context.fillStyle = stroke.color || '#252336';
    context.lineWidth = Math.max(1, (stroke.width || 5) * (stroke.tool === 'marker' ? 2.2 : 1));
    if (stroke.tool === 'eraser') context.globalCompositeOperation = 'destination-out';
    if (stroke.tool === 'marker') context.globalAlpha *= .38;
    if (stroke.tool === 'airbrush') context.filter = `blur(${Math.max(2, stroke.width * .55)}px)`;
    if (stroke.tool === 'crayon') context.globalAlpha *= .75;

    if (stroke.tool === 'line') {
      context.beginPath(); context.moveTo(first.x * 1080, first.y * 1080); context.lineTo(last.x * 1080, last.y * 1080); context.stroke();
    } else if (stroke.tool === 'rectangle') {
      context.strokeRect(first.x * 1080, first.y * 1080, (last.x - first.x) * 1080, (last.y - first.y) * 1080);
    } else if (stroke.tool === 'ellipse') {
      const x = (first.x + last.x) * 540; const y = (first.y + last.y) * 540;
      const rx = Math.abs(last.x - first.x) * 540; const ry = Math.abs(last.y - first.y) * 540;
      context.beginPath(); context.ellipse(x, y, Math.max(1, rx), Math.max(1, ry), 0, 0, Math.PI * 2); context.stroke();
    } else if (points.length === 1) {
      context.beginPath(); context.arc(first.x * 1080, first.y * 1080, context.lineWidth / 2, 0, Math.PI * 2); context.fill();
    } else {
      context.beginPath(); context.moveTo(first.x * 1080, first.y * 1080);
      for (let i = 1; i < points.length; i++) {
        const point = points[i];
        context.lineWidth = Math.max(1, (stroke.width || 5) * (point.pressure || 1) * (stroke.tool === 'calligraphy' ? 1.35 : 1));
        context.lineTo(point.x * 1080, point.y * 1080); context.stroke();
        context.beginPath(); context.moveTo(point.x * 1080, point.y * 1080);
      }
    }
    context.restore();
  }

  function drawStrokes(context, strokes) {
    for (const stroke of strokes || []) {
      drawOneStroke(context, stroke);
      if (state.mirror && stroke.tool !== 'eraser') {
        context.save(); context.translate(1080, 0); context.scale(-1, 1); drawOneStroke(context, stroke); context.restore();
      }
    }
  }

  function bufferFor(layer) {
    if (layerBuffers.has(layer.id)) return layerBuffers.get(layer.id);
    const offscreen = document.createElement('canvas'); offscreen.width = 1080; offscreen.height = 1080;
    const entry = { canvas: offscreen, context: offscreen.getContext('2d') };
    layerBuffers.set(layer.id, entry); return entry;
  }

  function renderFrame(targetContext, frameIndex, { onion = false, grid = false, includeDraft = false, transparent = false } = {}) {
    const frame = state.frames[frameIndex];
    if (!frame) return;
    const targetCanvas = targetContext.canvas;
    targetContext.save();
    targetContext.setTransform(1, 0, 0, 1, 0, 0);
    targetContext.clearRect(0, 0, targetCanvas.width, targetCanvas.height);
    targetContext.scale(targetCanvas.width / 1080, targetCanvas.height / 1080);

    const backdrop = state.layers.find(layer => layer.kind === 'background');
    if ((!backdrop || !backdrop.visible) && !transparent) drawCheckerboard(targetContext);

    for (const layer of state.layers) {
      if (!layer.visible || (transparent && layer.kind === 'background')) continue;
      if (onion && layer.kind === 'sprout') {
        if (frameIndex > 0) {
          targetContext.save(); targetContext.globalAlpha = .29 * layer.opacity;
          drawSprout(targetContext, frameIndex - 1, '#33a99c'); targetContext.restore();
        }
        if (frameIndex < state.frames.length - 1) {
          targetContext.save(); targetContext.globalAlpha = .19 * layer.opacity;
          drawSprout(targetContext, frameIndex + 1, '#df7189'); targetContext.restore();
        }
      }
      const buffer = bufferFor(layer);
      const layerContext = buffer.context;
      layerContext.setTransform(1, 0, 0, 1, 0, 0);
      layerContext.clearRect(0, 0, 1080, 1080);
      if (layer.kind === 'background') drawBackground(layerContext);
      if (layer.kind === 'sprout') drawSprout(layerContext, frameIndex);
      const strokes = frame.drawings?.[layer.id] || [];
      drawStrokes(layerContext, strokes);
      if (includeDraft && draft && layer.id === state.activeLayerId) {
        drawOneStroke(layerContext, draft);
        if (state.mirror && draft.tool !== 'eraser') {
          layerContext.save(); layerContext.translate(1080, 0); layerContext.scale(-1, 1); drawOneStroke(layerContext, draft); layerContext.restore();
        }
      }
      targetContext.save();
      targetContext.globalAlpha = Math.max(0, Math.min(1, layer.opacity));
      targetContext.globalCompositeOperation = layer.blend || 'source-over';
      targetContext.drawImage(buffer.canvas, 0, 0);
      targetContext.restore();
    }

    if (grid) {
      targetContext.save(); targetContext.strokeStyle = 'rgba(108,92,231,.15)'; targetContext.lineWidth = 2;
      for (let i = 1; i < 8; i++) {
        const p = i * 1080 / 8;
        targetContext.beginPath(); targetContext.moveTo(p, 0); targetContext.lineTo(p, 1080); targetContext.stroke();
        targetContext.beginPath(); targetContext.moveTo(0, p); targetContext.lineTo(1080, p); targetContext.stroke();
      }
      targetContext.restore();
    }
    if (state.mirror && frameIndex === state.frameIndex) {
      targetContext.save(); targetContext.strokeStyle = 'rgba(108,92,231,.55)'; targetContext.lineWidth = 2;
      targetContext.setLineDash([12, 10]); targetContext.beginPath(); targetContext.moveTo(540, 0); targetContext.lineTo(540, 1080); targetContext.stroke(); targetContext.restore();
    }
    targetContext.restore();
  }

  function renderCanvas() {
    renderFrame(ctx, state.frameIndex, { onion: state.onion, grid: state.grid, includeDraft: true });
  }

  function drawThumbnail(thumb, index) {
    const thumbContext = thumb.getContext('2d');
    renderFrame(thumbContext, index, { onion: false, grid: false, includeDraft: false });
  }

  function renderTimeline() {
    const strip = $('#framesStrip'); strip.replaceChildren();
    state.frames.forEach((frame, index) => {
      const tile = document.createElement('div');
      tile.className = `frame-tile${index === state.frameIndex ? ' is-selected' : ''}`;
      tile.draggable = true; tile.dataset.index = String(index); tile.title = `Frame ${index + 1} · drag to reorder`;
      const thumbWrap = document.createElement('div'); thumbWrap.className = 'frame-thumb';
      const thumb = document.createElement('canvas'); thumb.width = 108; thumb.height = 108; thumbWrap.append(thumb);
      drawThumbnail(thumb, index);
      const number = document.createElement('span'); number.className = 'frame-number'; number.textContent = String(index + 1).padStart(2, '0');
      tile.append(thumbWrap, number);
      if (frame.hold > 1) { const hold = document.createElement('span'); hold.className = 'frame-hold-badge'; hold.textContent = `${frame.hold}×`; tile.append(hold); }
      tile.addEventListener('click', () => selectFrame(index));
      tile.addEventListener('dragstart', event => { dragFrameIndex = index; tile.classList.add('dragging'); event.dataTransfer.effectAllowed = 'move'; });
      tile.addEventListener('dragend', () => tile.classList.remove('dragging'));
      tile.addEventListener('dragover', event => event.preventDefault());
      tile.addEventListener('drop', event => {
        event.preventDefault();
        const from = dragFrameIndex; const to = index;
        dragFrameIndex = null;
        if (from == null || from === to) return;
        snapshot();
        const selectedId = currentFrame().id;
        const [moved] = state.frames.splice(from, 1); state.frames.splice(to, 0, moved);
        state.frameIndex = state.frames.findIndex(item => item.id === selectedId);
        renderAll();
      });
      strip.append(tile);
    });
    $('#frameCount').innerHTML = `${String(state.frameIndex + 1).padStart(2, '0')} <span>/ ${String(state.frames.length).padStart(2, '0')}</span>`;
    $('#currentFrameMeta').textContent = `Frame ${String(state.frameIndex + 1).padStart(2, '0')} / ${String(state.frames.length).padStart(2, '0')}`;
    $('#holdSelect').value = String(currentFrame().hold || 1);
  }

  function renderLayers() {
    const list = $('#layerList'); list.replaceChildren();
    [...state.layers].reverse().forEach(layer => {
      const row = document.createElement('div');
      row.className = `layer-row${layer.id === state.activeLayerId ? ' is-active' : ''}${layer.visible ? '' : ' is-hidden'}`;
      row.dataset.id = layer.id; row.dataset.kind = layer.kind; row.draggable = true;
      row.innerHTML = `<span class="drag-grip" aria-hidden="true">⠿</span><button class="layer-action visibility-action" title="${layer.visible ? 'Hide' : 'Show'} layer">${layer.visible ? '◉' : '⊘'}</button><span class="layer-color"></span><span class="layer-name"></span><button class="layer-action lock-action" title="${layer.locked ? 'Unlock' : 'Lock'} layer">${layer.locked ? '▣' : '⌑'}</button><button class="layer-action layer-menu" title="Layer actions">···</button>`;
      $('.layer-name', row).textContent = layer.name;
      row.addEventListener('click', event => {
        if (event.target.closest('button')) return;
        if (layer.visible && !layer.locked) { state.activeLayerId = layer.id; renderLayers(); renderBrush(); updateMeta(); saveLocal(); }
      });
      $('.visibility-action', row).addEventListener('click', event => {
        event.stopPropagation(); snapshot(); layer.visible = !layer.visible;
        if (!layer.visible && state.activeLayerId === layer.id) state.activeLayerId = state.layers.find(item => item.visible && !item.locked)?.id || layer.id;
        renderAll();
      });
      $('.lock-action', row).addEventListener('click', event => {
        event.stopPropagation(); snapshot(); layer.locked = !layer.locked;
        if (layer.locked && state.activeLayerId === layer.id) state.activeLayerId = state.layers.find(item => item.visible && !item.locked)?.id || layer.id;
        renderAll();
      });
      $('.layer-menu', row).addEventListener('click', event => {
        event.stopPropagation();
        const action = window.prompt(`Layer actions for “${layer.name}”\nEnter R to rename or D to delete:`, 'R');
        if (action?.toLowerCase() === 'r') {
          const name = window.prompt('Layer name', layer.name);
          if (name?.trim()) { snapshot(); layer.name = name.trim(); renderAll(); }
        } else if (action?.toLowerCase() === 'd') {
          deleteLayer(layer.id);
        }
      });
      row.addEventListener('dragstart', event => { dragLayerId = layer.id; row.classList.add('dragging'); event.dataTransfer.effectAllowed = 'move'; });
      row.addEventListener('dragend', () => row.classList.remove('dragging'));
      row.addEventListener('dragover', event => event.preventDefault());
      row.addEventListener('drop', event => {
        event.preventDefault();
        const fromId = dragLayerId; const toId = layer.id; dragLayerId = null;
        if (!fromId || fromId === toId) return;
        snapshot();
        const topFirst = [...state.layers].reverse();
        const fromIndex = topFirst.findIndex(item => item.id === fromId);
        const toIndex = topFirst.findIndex(item => item.id === toId);
        const [moved] = topFirst.splice(fromIndex, 1); topFirst.splice(toIndex, 0, moved);
        state.layers = topFirst.reverse(); renderAll();
      });
      list.append(row);
    });
    const selected = activeLayer();
    if (selected) {
      $('#layerOpacity').value = String(Math.round(selected.opacity * 100));
      $('#opacityValue').textContent = `${Math.round(selected.opacity * 100)}%`;
      $('#layerOpacity').style.setProperty('--range-progress', `${Math.round(selected.opacity * 100)}%`);
      $('#blendMode').value = selected.blend || 'source-over';
    }
  }

  function buttonForTool(tool, compact = false) {
    const button = document.createElement('button');
    button.className = `tool-button${state.tool === tool.id ? ' is-active' : ''}`;
    button.type = 'button'; button.title = tool.label; button.setAttribute('aria-label', tool.label);
    button.textContent = tool.icon;
    if (!compact) { const tip = document.createElement('span'); tip.className = 'tool-tip'; tip.textContent = tool.label; button.append(tip); }
    button.addEventListener('click', () => { state.tool = tool.id; updateToolState(); renderBrush(); updateMeta(); saveLocal(); });
    return button;
  }

  function renderBrush() {
    const rail = $('#toolStack'); rail.replaceChildren();
    toolSpecs.forEach(tool => rail.append(buttonForTool(tool, false)));
    const grid = $('#brushGrid'); grid.replaceChildren();
    toolSpecs.filter(tool => tool.id !== 'hand').forEach(tool => grid.append(buttonForTool(tool, true)));
    const palette = $('#palette'); palette.replaceChildren();
    paletteColors.forEach(color => {
      const swatch = document.createElement('button'); swatch.type = 'button';
      swatch.className = `palette-swatch${state.color.toLowerCase() === color.toLowerCase() ? ' is-selected' : ''}`;
      swatch.style.background = color; swatch.title = color; swatch.setAttribute('aria-label', `Color ${color}`);
      swatch.addEventListener('click', () => setColor(color)); palette.append(swatch);
    });
    $('#brushSize').value = String(state.brushSize); $('#brushSizeValue').textContent = String(state.brushSize);
    $('#brushSize').style.setProperty('--range-progress', `${((state.brushSize - 1) / 47) * 100}%`);
    $('#brushPreviewDot').style.background = state.color;
    $('#railColor').style.background = state.color;
    $('#colorReadout').style.background = state.color;
    $('#colorHex').textContent = state.color.toUpperCase();
    $('#customColor').value = state.color;
  }

  function updateToolState() {
    $$('.tool-button').forEach(button => {
      const active = button.getAttribute('aria-label') === (toolSpecs.find(item => item.id === state.tool)?.label || '');
      button.classList.toggle('is-active', active);
    });
    paperWrap.classList.toggle('hand-tool', state.tool === 'hand');
  }

  function updateMeta() {
    const layer = activeLayer();
    $('#activeLayerLabel').textContent = layer?.name || 'Drawing';
    $('#onionToggle').classList.toggle('is-active', state.onion);
    $('#mirrorToggle').classList.toggle('is-active', state.mirror);
    $('#gridToggle').classList.toggle('is-active', state.grid);
    $('#loopToggle').classList.toggle('is-active', state.loop);
    $('#fpsSelect').value = String(state.fps);
    $('#playButton').textContent = playbackTimer ? 'Ⅱ' : '▶';
    $('#playButton').title = playbackTimer ? 'Pause' : 'Play';
  }

  function updateHistoryButtons() {
    $('#undoButton').disabled = !history.length;
    $('#redoButton').disabled = !redoHistory.length;
    $('#undoButton').style.opacity = history.length ? '1' : '.45';
    $('#redoButton').style.opacity = redoHistory.length ? '1' : '.45';
  }

  function setColor(color) {
    state.color = color.toLowerCase(); renderBrush(); saveLocal();
  }

  function renderAll() {
    renderCanvas(); renderTimeline(); renderLayers(); renderBrush(); updateMeta(); updateToolState(); updateHistoryButtons(); updateTransform(); saveLocal();
  }

  function selectFrame(index) {
    if (index < 0 || index >= state.frames.length) return;
    state.frameIndex = index; holdTicks = 0;
    renderCanvas(); renderTimeline(); updateMeta(); saveLocal();
  }

  function ensureFrameLayers(frame) {
    for (const layer of state.layers) if (!frame.drawings[layer.id]) frame.drawings[layer.id] = [];
  }

  function addFrame(duplicate = false) {
    snapshot();
    const next = duplicate ? clone(currentFrame()) : { id: uid(), hold: 1, drawings: Object.fromEntries(state.layers.map(layer => [layer.id, []])) };
    next.id = uid(); ensureFrameLayers(next);
    state.frames.splice(state.frameIndex + 1, 0, next); state.frameIndex++;
    renderAll();
  }

  function deleteCurrentFrame() {
    if (state.frames.length <= 1) { showToast('Keep at least one frame in your animation.'); return; }
    snapshot(); state.frames.splice(state.frameIndex, 1); state.frameIndex = Math.min(state.frameIndex, state.frames.length - 1); renderAll();
  }

  function deleteLayer(layerId) {
    if (state.layers.length <= 1) { showToast('Keep at least one layer.'); return; }
    const layer = state.layers.find(item => item.id === layerId);
    if (!layer || !window.confirm(`Delete “${layer.name}” and its drawings?`)) return;
    snapshot(); state.layers = state.layers.filter(item => item.id !== layerId);
    for (const frame of state.frames) delete frame.drawings[layerId];
    layerBuffers.delete(layerId);
    if (state.activeLayerId === layerId) state.activeLayerId = state.layers.find(item => item.visible && !item.locked)?.id || state.layers.at(-1).id;
    renderAll();
  }

  function addLayer() {
    const name = window.prompt('Name your new layer', `Layer ${state.layers.length}`);
    if (!name?.trim()) return;
    snapshot();
    const layer = { id: uid(), name: name.trim(), kind: 'ink', visible: true, locked: false, opacity: 1, blend: 'source-over' };
    state.layers.push(layer); for (const frame of state.frames) frame.drawings[layer.id] = [];
    state.activeLayerId = layer.id; renderAll();
  }

  function setFrameHold(value) {
    snapshot(); currentFrame().hold = Number(value); renderTimeline(); saveLocal();
  }

  function stopPlayback() {
    if (playbackTimer) clearInterval(playbackTimer);
    playbackTimer = null; holdTicks = 0; updateMeta();
  }

  function setPlaying(reverse = false) {
    if (playbackTimer) { clearInterval(playbackTimer); playbackTimer = null; holdTicks = 0; updateMeta(); return; }
    playbackReverse = reverse; holdTicks = 0;
    playbackTimer = setInterval(() => {
      holdTicks++;
      if (holdTicks < (currentFrame().hold || 1)) return;
      holdTicks = 0;
      let next = state.frameIndex + (playbackReverse ? -1 : 1);
      if (next < 0 || next >= state.frames.length) {
        if (state.loop) next = playbackReverse ? state.frames.length - 1 : 0;
        else { clearInterval(playbackTimer); playbackTimer = null; updateMeta(); return; }
      }
      state.frameIndex = next; renderCanvas(); renderTimeline(); updateMeta();
    }, Math.max(16, 1000 / state.fps));
    updateMeta();
  }

  function updateTransform() {
    paperWrap.style.transform = `translate(${state.panX}px, ${state.panY}px) scale(${state.zoom}) rotate(${state.rotation}deg)`;
    $('#zoomReset').textContent = `${Math.round(state.zoom * 100)}%`;
  }

  function fitCanvas() {
    const rect = stage.getBoundingClientRect();
    const size = Math.max(120, Math.min(rect.width - 70, rect.height - 48, window.innerHeight * .72));
    paperWrap.style.width = `${size}px`;
    updateTransform(); renderCanvas();
  }

  function eventToPoint(event) {
    // CSS transforms change the visual width; account for the logical canvas center/scale.
    const rect = paperWrap.getBoundingClientRect();
    const centerX = rect.left + rect.width / 2; const centerY = rect.top + rect.height / 2;
    const dx = event.clientX - centerX; const dy = event.clientY - centerY;
    const angle = -state.rotation * Math.PI / 180;
    const x = dx * Math.cos(angle) - dy * Math.sin(angle);
    const y = dx * Math.sin(angle) + dy * Math.cos(angle);
    const width = paperWrap.offsetWidth; const height = paperWrap.offsetHeight;
    return {
      x: Math.max(0, Math.min(1, (x / state.zoom + width / 2) / width)),
      y: Math.max(0, Math.min(1, (y / state.zoom + height / 2) / height)),
      pressure: event.pointerType === 'pen' ? Math.max(.08, event.pressure || .5) : 1,
      orientation: event.tiltY || 0,
    };
  }

  function canvasPointerDown(event) {
    event.preventDefault();
    canvas.setPointerCapture?.(event.pointerId);
    if (state.tool === 'hand') {
      panGesture = { x: event.clientX, y: event.clientY, panX: state.panX, panY: state.panY };
      return;
    }
    const layer = activeLayer();
    if (!layer || !layer.visible || layer.locked) { showToast('Choose a visible, unlocked layer to draw.'); return; }
    const point = eventToPoint(event);
    draft = { tool: state.tool, color: state.color, width: state.brushSize, points: [point], opacity: 1 };
    renderCanvas();
  }

  function canvasPointerMove(event) {
    if (panGesture) {
      state.panX = panGesture.panX + event.clientX - panGesture.x;
      state.panY = panGesture.panY + event.clientY - panGesture.y;
      updateTransform(); return;
    }
    if (!draft) return;
    const point = eventToPoint(event); const last = draft.points.at(-1);
    if (Math.abs(last.x - point.x) + Math.abs(last.y - point.y) > .0002) draft.points.push(point);
    renderCanvas();
  }

  function canvasPointerUp() {
    if (panGesture) { panGesture = null; saveLocal(); return; }
    if (!draft) return;
    const layer = activeLayer();
    if (layer && !layer.locked) {
      snapshot();
      const frame = currentFrame(); ensureFrameLayers(frame);
      const points = draft.points;
      if (['line', 'rectangle', 'ellipse'].includes(draft.tool) && points.length > 1) draft.points = [points[0], points.at(-1)];
      frame.drawings[layer.id].push(clone(draft));
    }
    draft = null; renderAll();
  }

  function openProjects() {
    stopPlayback(); $('#projectsScreen').classList.remove('hidden'); renderProjectCards();
  }

  function closeProjects() { $('#projectsScreen').classList.add('hidden'); fitCanvas(); }

  const projectCards = [
    { title: 'Morning, frame by frame', subtitle: '8 frames · 12 fps', kind: 'sample' },
    { title: 'Cloud watching', subtitle: '12 frames · 8 fps', kind: 'sample' },
    { title: 'Color garden', subtitle: '6 frames · 15 fps', kind: 'sample' },
  ];
  try {
    const savedCards = JSON.parse(localStorage.getItem('animpro.preview.cards') || 'null');
    if (Array.isArray(savedCards)) projectCards.splice(0, projectCards.length, ...savedCards);
  } catch (_) { /* ignore preview-only home metadata */ }

  function renderProjectCards() {
    const grid = $('#projectGrid'); grid.replaceChildren();
    const query = ($('#projectSearch').value || '').trim().toLowerCase();
    let cards = projectCards.filter(card => card.title.toLowerCase().includes(query));
    if (sortByName) cards = [...cards].sort((a, b) => a.title.localeCompare(b.title));
    for (const card of cards) {
      const item = document.createElement('article'); item.className = 'project-card';
      const preview = document.createElement('canvas'); preview.className = 'project-preview'; preview.width = 360; preview.height = 268;
      const previewContext = preview.getContext('2d');
      previewContext.save(); previewContext.scale(360 / 1080, 268 / 1080); drawBackground(previewContext); drawSprout(previewContext, 5); previewContext.restore();
      const info = document.createElement('div'); info.className = 'project-info';
      const copy = document.createElement('div'); copy.className = 'project-info-copy';
      const title = document.createElement('strong'); title.textContent = card.title;
      const sub = document.createElement('small'); sub.textContent = card.subtitle;
      const arrow = document.createElement('span'); arrow.className = 'open-arrow'; arrow.textContent = '↗';
      copy.append(title, sub); info.append(copy, arrow); item.append(preview, info);
      item.addEventListener('click', () => {
        state.name = card.title;
        if (card.title !== 'Morning, frame by frame' && !state.name.startsWith('Untitled')) {
          state.name = card.title;
        }
        $('.project-title').innerHTML = `${escapeHtml(state.name)} <span class="edit-mark">✎</span>`;
        closeProjects(); renderAll();
      });
      grid.append(item);
    }
    const newCard = document.createElement('button'); newCard.className = 'project-card new-card'; newCard.type = 'button';
    newCard.innerHTML = '<span class="new-card-content"><span class="new-card-plus">＋</span><span>Start a new animation</span></span>';
    newCard.addEventListener('click', createProject); grid.append(newCard);
  }

  function escapeHtml(text) {
    return String(text).replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]);
  }

  function createProject() {
    const name = window.prompt('Name your animation', 'Untitled animation');
    if (!name?.trim()) return;
    stopPlayback();
    state = createInitialProject();
    state.name = name.trim();
    state.frames = [{ id: uid(), hold: 1, drawings: Object.fromEntries(state.layers.map(layer => [layer.id, []])) }];
    state.frameIndex = 0;
    state.activeLayerId = 'sketch';
    layerBuffers.clear(); history = []; redoHistory = [];
    projectCards.unshift({ title: state.name, subtitle: '1 frame · 12 fps', kind: 'sample' });
    localStorage.setItem('animpro.preview.cards', JSON.stringify(projectCards));
    $('.project-title').innerHTML = `${escapeHtml(state.name)} <span class="edit-mark">✎</span>`;
    closeProjects(); renderAll(); showToast('New local animation created.');
  }

  function exportPngSample() {
    const size = Number($('#exportResolution').value) || 1080;
    const output = document.createElement('canvas'); output.width = size; output.height = size;
    renderFrame(output.getContext('2d'), state.frameIndex, {
      onion: false, grid: false, includeDraft: false, transparent: $('#transparentBg').checked,
    });
    const link = document.createElement('a');
    link.href = output.toDataURL('image/png');
    link.download = `${state.name.toLowerCase().replace(/[^a-z0-9]+/g, '-')}-frame-${state.frameIndex + 1}.png`;
    link.click();
    return link.download;
  }

  // Wire the drawing tool rail and canvas.
  toolSpecs.forEach(tool => $('#toolStack').append(buttonForTool(tool, false)));
  toolSpecs.filter(tool => tool.id !== 'hand').forEach(tool => $('#brushGrid').append(buttonForTool(tool, true)));
  canvas.addEventListener('pointerdown', canvasPointerDown);
  canvas.addEventListener('pointermove', canvasPointerMove);
  canvas.addEventListener('pointerup', canvasPointerUp);
  canvas.addEventListener('pointercancel', canvasPointerUp);
  canvas.addEventListener('lostpointercapture', canvasPointerUp);

  // Timeline and frame editing.
  $('#previousFrame').addEventListener('click', () => selectFrame(state.frameIndex - 1));
  $('#playButton').addEventListener('click', () => playbackTimer ? setPlaying() : setPlaying(false));
  $('#reverseButton').addEventListener('click', () => { if (playbackTimer) { clearInterval(playbackTimer); playbackTimer = null; } setPlaying(true); });
  $('#loopToggle').addEventListener('click', () => { state.loop = !state.loop; updateMeta(); saveLocal(); });
  $('#fpsSelect').addEventListener('change', event => {
    state.fps = Number(event.target.value);
    if (playbackTimer) { clearInterval(playbackTimer); playbackTimer = null; setPlaying(playbackReverse); }
    updateMeta(); saveLocal();
  });
  $('#copyFrame').addEventListener('click', () => { clipboardFrame = clone(currentFrame()); showToast('Frame copied.'); });
  $('#pasteFrame').addEventListener('click', () => {
    if (!clipboardFrame) { showToast('Copy a frame before pasting.'); return; }
    snapshot(); const pasted = clone(clipboardFrame); pasted.id = uid(); ensureFrameLayers(pasted); state.frames[state.frameIndex] = pasted; renderAll();
  });
  $('#duplicateFrame').addEventListener('click', () => addFrame(true));
  $('#addFrame').addEventListener('click', () => addFrame(false));
  $('#deleteFrame').addEventListener('click', deleteCurrentFrame);
  $('#holdSelect').addEventListener('change', event => setFrameHold(event.target.value));

  // Layers and brush controls.
  $('#addLayer').addEventListener('click', addLayer);
  $('#showInspector').addEventListener('click', () => {
    const opened = $('#inspector').classList.toggle('mobile-open');
    $('#showInspector').classList.toggle('is-active', opened);
  });
  $$('.inspector-tab').forEach(tab => tab.addEventListener('click', () => {
    $$('.inspector-tab').forEach(item => item.classList.toggle('is-active', item === tab));
    $$('.inspector-content').forEach(panel => panel.classList.toggle('hidden', panel.id !== tab.dataset.tab));
  }));
  $('#layerOpacity').addEventListener('pointerdown', snapshot);
  $('#layerOpacity').addEventListener('input', event => {
    const layer = activeLayer(); if (!layer) return;
    layer.opacity = Number(event.target.value) / 100; $('#opacityValue').textContent = `${event.target.value}%`;
    event.target.style.setProperty('--range-progress', `${event.target.value}%`); renderCanvas(); saveLocal();
  });
  $('#blendMode').addEventListener('change', event => { const layer = activeLayer(); if (layer) { snapshot(); layer.blend = event.target.value; renderCanvas(); saveLocal(); } });
  $('#brushSize').addEventListener('input', event => {
    state.brushSize = Number(event.target.value); $('#brushSizeValue').textContent = String(state.brushSize);
    event.target.style.setProperty('--range-progress', `${((state.brushSize - 1) / 47) * 100}%`); saveLocal();
  });
  $('#customColor').addEventListener('input', event => setColor(event.target.value));
  $('#eyedropper').addEventListener('click', async () => {
    if ('EyeDropper' in window) {
      try { const result = await new EyeDropper().open(); setColor(result.sRGBHex); }
      catch (_) { /* Escape cancels the eyedropper. */ }
    } else showToast('Canvas eyedropper is not available in this browser.');
  });
  $('#copyColor').addEventListener('click', async () => {
    try { await navigator.clipboard.writeText(state.color); showToast('Color copied.'); }
    catch (_) { showToast(state.color.toUpperCase()); }
  });

  // Canvas overlays, pan / zoom / rotation.
  $('#onionToggle').addEventListener('click', () => { state.onion = !state.onion; renderCanvas(); updateMeta(); saveLocal(); });
  $('#mirrorToggle').addEventListener('click', () => { state.mirror = !state.mirror; renderCanvas(); updateMeta(); saveLocal(); });
  $('#gridToggle').addEventListener('click', () => { state.grid = !state.grid; renderCanvas(); updateMeta(); saveLocal(); });
  $('#zoomIn').addEventListener('click', () => { state.zoom = Math.min(2.5, +(state.zoom + .1).toFixed(2)); updateTransform(); saveLocal(); });
  $('#zoomOut').addEventListener('click', () => { state.zoom = Math.max(.5, +(state.zoom - .1).toFixed(2)); updateTransform(); saveLocal(); });
  $('#zoomReset').addEventListener('click', () => { state.zoom = 1; state.panX = 0; state.panY = 0; state.rotation = 0; updateTransform(); saveLocal(); });
  $('#rotateCanvas').addEventListener('click', () => { state.rotation = (state.rotation + 90) % 360; updateTransform(); saveLocal(); });

  // Project title, home, and theme.
  $('#renameProject').addEventListener('click', () => {
    const name = window.prompt('Animation name', state.name);
    if (name?.trim()) { state.name = name.trim(); $('.project-title').innerHTML = `${escapeHtml(state.name)} <span class="edit-mark">✎</span>`; saveLocal(); }
  });
  $('#openProjects').addEventListener('click', openProjects);
  $('#createProject').addEventListener('click', createProject);
  $('#projectSearch').addEventListener('input', renderProjectCards);
  $('#sortProjects').addEventListener('click', () => { sortByName = !sortByName; $('#sortProjects').textContent = sortByName ? '↕ A–Z' : '↕ Recent'; renderProjectCards(); });
  $('#themeToggle').addEventListener('click', toggleTheme);
  $('#themeToggleHome').addEventListener('click', toggleTheme);
  function toggleTheme() {
    const next = document.body.dataset.theme === 'dark' ? 'light' : 'dark';
    document.body.dataset.theme = next; localStorage.setItem(THEME_KEY, next);
    const icon = next === 'dark' ? '☾' : '☼'; $('#themeToggle').textContent = icon; $('#themeToggleHome').textContent = icon;
  }
  const savedTheme = localStorage.getItem(THEME_KEY);
  if (savedTheme === 'dark') document.body.dataset.theme = 'dark';
  const themeIcon = document.body.dataset.theme === 'dark' ? '☾' : '☼';
  $('#themeToggle').textContent = themeIcon; $('#themeToggleHome').textContent = themeIcon;

  // Export modal: browser preview writes a PNG sample; GIF rendering lives in Flutter.
  $('#openExport').addEventListener('click', () => {
    $('#exportStatus').textContent = '';
    $('#exportDialog').showModal();
  });
  $$('.format-card').forEach(card => card.addEventListener('click', () => {
    if (card.classList.contains('format-disabled')) { showToast('Video formats need a native media encoder.'); return; }
    selectedExportFormat = card.dataset.format;
    $$('.format-card').forEach(item => item.classList.toggle('is-selected', item === card));
  }));
  $('#startExport').addEventListener('click', () => {
    if (selectedExportFormat === 'gif') {
      $('#exportStatus').textContent = 'GIF encoding is included in the Flutter app source. This lightweight browser preview can export a PNG sample.';
      showToast('Open the Flutter project to render a GIF.');
      return;
    }
    const filename = exportPngSample();
    $('#exportStatus').textContent = `Downloaded ${filename} · current frame preview`;
    showToast('PNG downloaded.');
  });

  // Keyboard shortcuts remain local and intentionally simple.
  window.addEventListener('keydown', event => {
    const target = event.target;
    const typing = target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement || target instanceof HTMLSelectElement;
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'z') {
      if (typing) return;
      event.preventDefault(); event.shiftKey ? redo() : undo();
    } else if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'y') {
      if (typing) return; event.preventDefault(); redo();
    } else if (event.code === 'Space' && !typing) {
      event.preventDefault(); state.tool = 'hand'; updateToolState(); renderBrush();
    } else if (event.key === 'Escape' && !$('#exportDialog').open) {
      state.tool = 'pencil'; updateToolState(); renderBrush();
      $('#inspector').classList.remove('mobile-open'); $('#showInspector').classList.remove('is-active');
    }
  });
  window.addEventListener('keyup', event => {
    if (event.code === 'Space' && state.tool === 'hand') { state.tool = 'pencil'; updateToolState(); renderBrush(); }
  });
  window.addEventListener('resize', () => {
    clearTimeout(resizeTimer); resizeTimer = setTimeout(fitCanvas, 90);
  });

  $('.project-title').innerHTML = `${escapeHtml(state.name)} <span class="edit-mark">✎</span>`;
  renderAll(); fitCanvas(); renderProjectCards();
  window.setInterval(saveLocal, 30000);
})();
