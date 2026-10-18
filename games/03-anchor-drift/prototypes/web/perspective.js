const canvas = document.querySelector("#game");
const ctx = canvas.getContext("2d");
const distanceEl = document.querySelector("#distance");
const anchorStateEl = document.querySelector("#anchorState");
const overlay = document.querySelector("#overlay");
const resultEl = document.querySelector("#result");
const restartButton = document.querySelector("#restart");

const TAU = Math.PI * 2;
const boatImage = new Image();
boatImage.decoding = "async";
boatImage.src = "../../web/assets/duck-boat-oblique-collage.png";

let dpr = 1;
let width = 0;
let height = 0;
let lastTime = 0;

const keys = new Set();
const tuning = {
  far: 88,
  horizon: 0.31,
  playerY: 0.83,
  speedStart: 18,
  speedGain: 0.0028,
  maxSpeed: 58,
  anchorHold: 0.82,
  anchorPull: 6.4,
  anchorThrow: 0.16,
  laneLimit: 1.05,
};

const state = {
  mode: "playing",
  distance: 0,
  speed: tuning.speedStart,
  lane: 0,
  laneVelocity: 0,
  anchor: null,
  obstacles: [],
  nextSpawn: 18,
  shake: 0,
};

function resize() {
  dpr = Math.min(window.devicePixelRatio || 1, 2);
  width = Math.max(320, window.innerWidth);
  height = Math.max(520, window.innerHeight);
  canvas.width = Math.floor(width * dpr);
  canvas.height = Math.floor(height * dpr);
  canvas.style.width = `${width}px`;
  canvas.style.height = `${height}px`;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
}

function reset() {
  state.mode = "playing";
  state.distance = 0;
  state.speed = tuning.speedStart;
  state.lane = 0;
  state.laneVelocity = 0;
  state.anchor = null;
  state.obstacles = [];
  state.nextSpawn = 14;
  state.shake = 0;
  overlay.classList.add("is-hidden");
  for (let i = 0; i < 9; i += 1) spawnObstacle(20 + i * 10);
  updateHud();
}

function spawnObstacle(z = tuning.far) {
  const lanes = [-0.72, 0, 0.72];
  const lane = lanes[Math.floor(Math.random() * lanes.length)] + rand(-0.08, 0.08);
  state.obstacles.push({
    z,
    lane,
    size: rand(0.8, 1.18),
    kind: Math.floor(rand(0, 4)),
    wobble: rand(0, TAU),
  });
}

function dropAnchor(side) {
  if (state.mode !== "playing" || state.anchor) return;
  state.anchor = {
    side,
    time: tuning.anchorHold,
    maxTime: tuning.anchorHold,
    throwTime: 0,
    depth: 12 + Math.abs(state.lane) * 4,
  };
}

function releaseAnchor() {
  if (!state.anchor) return;
  state.anchor = null;
  state.laneVelocity *= 0.68;
}

function update(dt) {
  if (state.mode !== "playing") return;
  state.speed = Math.min(tuning.maxSpeed, tuning.speedStart + state.distance * tuning.speedGain);
  state.distance += state.speed * dt;

  if (state.anchor) {
    state.anchor.time -= dt;
    state.anchor.throwTime += dt;
    const target = state.anchor.side * 0.9;
    state.laneVelocity += (target - state.lane) * tuning.anchorPull * dt;
    if (state.anchor.time <= 0) releaseAnchor();
  }

  state.laneVelocity += -state.lane * 1.15 * dt;
  state.laneVelocity *= Math.pow(0.9, dt * 8);
  state.lane += state.laneVelocity * dt;

  if (Math.abs(state.lane) > tuning.laneLimit) {
    gameOver("冲出长廊河道了。");
    return;
  }

  for (const obstacle of state.obstacles) {
    obstacle.z -= state.speed * dt;
    obstacle.wobble += dt * 2;
    if (obstacle.z < 3.2 && Math.abs(obstacle.lane - state.lane) < 0.28 + obstacle.size * 0.08) {
      gameOver("撞上迎面障碍了。");
      return;
    }
  }

  state.obstacles = state.obstacles.filter((obstacle) => obstacle.z > -8);
  state.nextSpawn -= state.speed * dt;
  if (state.nextSpawn <= 0) {
    spawnObstacle(tuning.far + rand(0, 8));
    state.nextSpawn = rand(7.5, 12.5);
  }
  state.shake = Math.max(0, state.shake - dt * 3);
  updateHud();
}

function gameOver(reason) {
  state.mode = "gameover";
  state.anchor = null;
  resultEl.textContent = `${reason} 本次 ${(state.distance / 1000).toFixed(2)} km。`;
  overlay.classList.remove("is-hidden");
  updateHud();
}

function updateHud() {
  distanceEl.textContent = `${(state.distance / 1000).toFixed(2)} km`;
  if (state.mode === "gameover") {
    anchorStateEl.textContent = "WRECKED";
  } else if (state.anchor) {
    anchorStateEl.textContent = `${state.anchor.side < 0 ? "LEFT" : "RIGHT"} ${state.anchor.time.toFixed(1)}s`;
  } else {
    anchorStateEl.textContent = "READY";
  }
}

function perspective(z) {
  const t = clamp(1 - z / tuning.far, 0, 1);
  const eased = Math.pow(t, 1.72);
  const horizon = height * tuning.horizon;
  const bottom = height * 1.04;
  const y = lerp(horizon, bottom, eased);
  const roadHalf = lerp(width * 0.055, width * 0.52, Math.pow(t, 1.15));
  const scale = lerp(0.08, 1.9, Math.pow(t, 1.8));
  return { t, y, roadHalf, scale };
}

function pointAt(lane, z) {
  const p = perspective(z);
  return {
    x: width * 0.5 + lane * p.roadHalf,
    y: p.y,
    scale: p.scale,
    roadHalf: p.roadHalf,
    t: p.t,
  };
}

function draw() {
  const shakeX = rand(-1, 1) * state.shake * 10;
  const shakeY = rand(-1, 1) * state.shake * 10;
  ctx.clearRect(0, 0, width, height);
  ctx.save();
  ctx.translate(shakeX, shakeY);
  drawCorridor();
  drawObstacles();
  drawAnchor();
  drawBoat();
  ctx.restore();
}

function drawCorridor() {
  const horizon = height * tuning.horizon;
  const vanishing = { x: width * 0.5, y: horizon };

  const sky = ctx.createLinearGradient(0, 0, 0, height);
  sky.addColorStop(0, "#536a50");
  sky.addColorStop(0.38, "#122726");
  sky.addColorStop(1, "#05100f");
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, width, height);

  ctx.fillStyle = "rgba(170, 205, 183, 0.4)";
  for (const side of [-1, 1]) {
    ctx.beginPath();
    ctx.moveTo(vanishing.x, vanishing.y);
    ctx.lineTo(side < 0 ? 0 : width, height * 0.2);
    ctx.lineTo(side < 0 ? 0 : width, height);
    ctx.lineTo(width * 0.5 + side * width * 0.54, height);
    ctx.closePath();
    ctx.fill();
  }

  ctx.fillStyle = "#294544";
  ctx.beginPath();
  for (let i = 0; i <= 28; i += 1) {
    const z = tuning.far * (1 - i / 28);
    const p = perspective(z);
    const x = width * 0.5 - p.roadHalf;
    if (i === 0) ctx.moveTo(x, p.y);
    else ctx.lineTo(x, p.y);
  }
  for (let i = 28; i >= 0; i -= 1) {
    const z = tuning.far * (1 - i / 28);
    const p = perspective(z);
    ctx.lineTo(width * 0.5 + p.roadHalf, p.y);
  }
  ctx.closePath();
  ctx.fill();

  drawTiles();
  drawPillars();
  drawCeiling();

  const glow = ctx.createRadialGradient(vanishing.x, vanishing.y, 0, vanishing.x, vanishing.y, width * 0.35);
  glow.addColorStop(0, "rgba(235, 255, 235, 0.82)");
  glow.addColorStop(0.08, "rgba(180, 238, 210, 0.22)");
  glow.addColorStop(1, "rgba(180, 238, 210, 0)");
  ctx.fillStyle = glow;
  ctx.fillRect(0, 0, width, height);
}

function drawTiles() {
  ctx.strokeStyle = "rgba(210, 230, 207, 0.2)";
  ctx.lineWidth = 1;
  for (let z = 5; z < tuning.far; z += 5) {
    const p = perspective(z);
    ctx.beginPath();
    ctx.moveTo(width * 0.5 - p.roadHalf, p.y);
    ctx.lineTo(width * 0.5 + p.roadHalf, p.y);
    ctx.stroke();
  }
  for (let lane = -0.8; lane <= 0.81; lane += 0.2) {
    const near = pointAt(lane, 3);
    const far = pointAt(lane, tuning.far);
    ctx.beginPath();
    ctx.moveTo(near.x, near.y);
    ctx.lineTo(far.x, far.y);
    ctx.stroke();
  }
}

function drawPillars() {
  for (let z = 8; z < tuning.far; z += 10) {
    const p = perspective(z);
    for (const side of [-1, 1]) {
      const x = width * 0.5 + side * p.roadHalf * 1.08;
      const pillarW = lerp(8, 70, p.t);
      const pillarH = lerp(34, height * 0.42, p.t);
      const topY = p.y - pillarH;
      const grd = ctx.createLinearGradient(x - pillarW * 0.5, topY, x + pillarW * 0.5, p.y);
      grd.addColorStop(0, "#8ea082");
      grd.addColorStop(0.52, "#465b51");
      grd.addColorStop(1, "#263835");
      ctx.fillStyle = grd;
      ctx.fillRect(x - pillarW * 0.5, topY, pillarW, pillarH);
      ctx.fillStyle = "rgba(16, 22, 20, 0.55)";
      ctx.fillRect(x - pillarW * 0.72, p.y - pillarW * 0.28, pillarW * 1.44, pillarW * 0.22);
      ctx.fillRect(x - pillarW * 0.68, topY - pillarW * 0.16, pillarW * 1.36, pillarW * 0.18);
    }
  }
}

function drawCeiling() {
  for (let z = 7; z < tuning.far; z += 10) {
    const p = perspective(z);
    const beamY = p.y - lerp(50, height * 0.48, p.t);
    const beamW = p.roadHalf * 2.35;
    const beamH = lerp(4, 34, p.t);
    ctx.fillStyle = "rgba(50, 64, 50, 0.86)";
    ctx.fillRect(width * 0.5 - beamW * 0.5, beamY, beamW, beamH);
    ctx.fillStyle = "rgba(210, 255, 220, 0.22)";
    ctx.fillRect(width * 0.5 - beamW * 0.48, beamY + beamH * 0.2, beamW * 0.96, Math.max(1, beamH * 0.08));
  }
}

function drawObstacles() {
  const sorted = [...state.obstacles].sort((a, b) => b.z - a.z);
  for (const obstacle of sorted) {
    const p = pointAt(obstacle.lane, obstacle.z);
    if (p.t <= 0 || p.y > height + 120) continue;
    const size = 32 * obstacle.size * p.scale;
    ctx.save();
    ctx.translate(p.x, p.y - size * 0.25);
    ctx.rotate(Math.sin(obstacle.wobble) * 0.16);
    ctx.globalAlpha = clamp(p.t * 1.4, 0, 1);
    ctx.shadowColor = "rgba(0, 0, 0, 0.35)";
    ctx.shadowBlur = size * 0.18;
    ctx.shadowOffsetX = size * 0.08;
    ctx.shadowOffsetY = size * 0.12;
    if (obstacle.kind === 0) drawPopupObstacle(size);
    else if (obstacle.kind === 1) drawCdObstacle(size);
    else if (obstacle.kind === 2) drawBottleObstacle(size);
    else drawRockObstacle(size);
    ctx.restore();
  }
}

function drawPopupObstacle(size) {
  ctx.fillStyle = "rgba(232, 255, 249, 0.82)";
  ctx.strokeStyle = "rgba(96, 220, 195, 0.9)";
  ctx.lineWidth = Math.max(2, size * 0.04);
  ctx.fillRect(-size * 0.58, -size * 0.38, size * 1.16, size * 0.76);
  ctx.strokeRect(-size * 0.58, -size * 0.38, size * 1.16, size * 0.76);
  ctx.fillStyle = "rgba(68, 126, 160, 0.42)";
  ctx.fillRect(-size * 0.58, -size * 0.38, size * 1.16, size * 0.16);
}

function drawCdObstacle(size) {
  const grd = ctx.createRadialGradient(0, 0, size * 0.1, 0, 0, size * 0.48);
  grd.addColorStop(0, "#f6fff9");
  grd.addColorStop(0.45, "#77c9ff");
  grd.addColorStop(0.75, "#ffb96e");
  grd.addColorStop(1, "#e8fff7");
  ctx.fillStyle = grd;
  ctx.beginPath();
  ctx.arc(0, 0, size * 0.48, 0, TAU);
  ctx.fill();
  ctx.fillStyle = "#284547";
  ctx.beginPath();
  ctx.arc(0, 0, size * 0.12, 0, TAU);
  ctx.fill();
}

function drawBottleObstacle(size) {
  ctx.fillStyle = "#0b8f54";
  ctx.strokeStyle = "rgba(235, 255, 238, 0.8)";
  ctx.lineWidth = Math.max(2, size * 0.04);
  ctx.beginPath();
  ctx.moveTo(-size * 0.14, -size * 0.62);
  ctx.lineTo(size * 0.14, -size * 0.62);
  ctx.lineTo(size * 0.24, size * 0.44);
  ctx.quadraticCurveTo(0, size * 0.58, -size * 0.24, size * 0.44);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = "#f5fff1";
  ctx.fillRect(-size * 0.22, size * 0.08, size * 0.44, size * 0.18);
}

function drawRockObstacle(size) {
  ctx.fillStyle = "rgba(225, 230, 218, 0.88)";
  ctx.strokeStyle = "rgba(20, 28, 26, 0.7)";
  ctx.lineWidth = Math.max(2, size * 0.04);
  ctx.beginPath();
  ctx.ellipse(0, 0, size * 0.55, size * 0.34, 0.2, 0, TAU);
  ctx.fill();
  ctx.stroke();
}

function drawBoat() {
  const p = pointAt(state.lane, 1.8);
  const y = height * tuning.playerY;
  const x = p.x;
  const w = Math.min(width, height) * 0.12;
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(state.laneVelocity * 0.12);
  ctx.fillStyle = "rgba(0, 0, 0, 0.34)";
  ctx.beginPath();
  ctx.ellipse(0, w * 0.22, w * 0.38, w * 0.18, 0, 0, TAU);
  ctx.fill();
  if (boatImage.complete && boatImage.naturalWidth) {
    const h = w / (boatImage.naturalWidth / boatImage.naturalHeight);
    ctx.drawImage(boatImage, -w * 0.5, -h * 0.55, w, h);
  } else {
    ctx.fillStyle = "#f7f3df";
    ctx.beginPath();
    ctx.moveTo(0, -w * 0.45);
    ctx.lineTo(w * 0.38, w * 0.34);
    ctx.quadraticCurveTo(0, w * 0.5, -w * 0.38, w * 0.34);
    ctx.closePath();
    ctx.fill();
  }
  ctx.restore();
}

function drawAnchor() {
  if (!state.anchor) return;
  const boat = pointAt(state.lane, 1.8);
  const boatPos = { x: boat.x, y: height * tuning.playerY };
  const a = state.anchor;
  const sidePoint = pointAt(a.side * 1.04, a.depth);
  const anchorPos = { x: sidePoint.x, y: sidePoint.y - sidePoint.scale * 28 };
  const ratio = clamp(a.throwTime / tuning.anchorThrow, 0, 1);
  const ease = 1 - Math.pow(1 - ratio, 3);
  const head = {
    x: lerp(boatPos.x, anchorPos.x, ease),
    y: lerp(boatPos.y, anchorPos.y, ease),
  };
  drawChainLinks(boatPos, head, a.side < 0 ? "#78f7d1" : "#7db4ff");
  drawAnchorGlyph(head.x, head.y, 22 + 9 * (1 - ratio), a.side < 0 ? "#78f7d1" : "#7db4ff");
}

function drawChainLinks(from, to, color) {
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  const length = Math.hypot(dx, dy);
  if (length < 8) return;
  const angle = Math.atan2(dy, dx);
  const spacing = clamp(width * 0.016, 12, 21);
  const count = Math.max(2, Math.ceil(length / spacing));
  ctx.save();
  ctx.shadowColor = "rgba(0, 0, 0, 0.42)";
  ctx.shadowBlur = 8;
  ctx.shadowOffsetY = 4;
  for (let i = 0; i <= count; i += 1) {
    const t = i / count;
    const x = lerp(from.x, to.x, t);
    const y = lerp(from.y, to.y, t);
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(angle + (i % 2 ? Math.PI * 0.5 : 0));
    ctx.strokeStyle = "rgba(4, 8, 10, 0.7)";
    ctx.lineWidth = Math.max(4, spacing * 0.28);
    ctx.beginPath();
    ctx.ellipse(0, 0, spacing * 0.76, spacing * 0.32, 0, 0, TAU);
    ctx.stroke();
    ctx.strokeStyle = "rgba(232, 236, 232, 0.95)";
    ctx.lineWidth = Math.max(2.5, spacing * 0.18);
    ctx.beginPath();
    ctx.ellipse(0, 0, spacing * 0.76, spacing * 0.32, 0, 0, TAU);
    ctx.stroke();
    ctx.strokeStyle = color;
    ctx.globalAlpha = 0.3;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.ellipse(0, 0, spacing * 0.8, spacing * 0.36, 0, 0, TAU);
    ctx.stroke();
    ctx.restore();
  }
  ctx.restore();
}

function drawAnchorGlyph(x, y, size, color) {
  ctx.save();
  ctx.translate(x, y);
  ctx.fillStyle = color;
  ctx.strokeStyle = "#06131b";
  ctx.lineWidth = Math.max(2, size * 0.08);
  ctx.beginPath();
  ctx.arc(0, 0, size * 0.23, 0, TAU);
  ctx.fill();
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(0, -size * 0.48);
  ctx.lineTo(0, size * 0.46);
  ctx.moveTo(-size * 0.34, -size * 0.16);
  ctx.lineTo(size * 0.34, -size * 0.16);
  ctx.moveTo(-size * 0.48, size * 0.24);
  ctx.quadraticCurveTo(0, size * 0.7, size * 0.48, size * 0.24);
  ctx.stroke();
  ctx.restore();
}

function loop(time) {
  if (!lastTime) lastTime = time;
  const dt = Math.min((time - lastTime) / 1000, 0.033);
  lastTime = time;
  update(dt);
  draw();
  requestAnimationFrame(loop);
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function lerp(from, to, amount) {
  return from + (to - from) * clamp(amount, 0, 1);
}

function rand(min, max) {
  return min + Math.random() * (max - min);
}

window.addEventListener("resize", resize);
window.addEventListener("keydown", (event) => {
  if (["KeyA", "KeyD", "Space", "Enter", "KeyR"].includes(event.code)) event.preventDefault();
  if (keys.has(event.code)) return;
  keys.add(event.code);
  if (state.mode === "gameover" && ["Space", "Enter", "KeyR"].includes(event.code)) {
    reset();
    return;
  }
  if (event.code === "KeyA") dropAnchor(-1);
  if (event.code === "KeyD") dropAnchor(1);
  if (event.code === "Space") releaseAnchor();
});
window.addEventListener("keyup", (event) => keys.delete(event.code));
restartButton.addEventListener("click", reset);

resize();
reset();
requestAnimationFrame(loop);
