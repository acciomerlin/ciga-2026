const canvas = document.querySelector("#game");
const ctx = canvas.getContext("2d");

const distanceEl = document.querySelector("#distance");
const speedStateEl = document.querySelector("#speedState");
const bestEl = document.querySelector("#best");
const anchorStateEl = document.querySelector("#anchorState");
const livesStateEl = document.querySelector("#livesState");
const eraStateEl = document.querySelector("#eraState");
const eraCountdownEl = document.querySelector("#eraCountdown");
const eraFillEl = document.querySelector("#eraFill");
const eraTimelineTrackEl = document.querySelector("#eraTimelineTrack");
const eraBannerEl = document.querySelector("#eraBanner");
const eraBannerSigilEl = document.querySelector("#eraBannerSigil");
const eraBannerTitleEl = document.querySelector("#eraBannerTitle");
const legendEraLabelEl = document.querySelector("#legendEraLabel");
const legendObstacleAEl = document.querySelector("#legendObstacleA");
const legendObstacleBEl = document.querySelector("#legendObstacleB");
const legendShieldEl = document.querySelector("#legendShield");
const chargeFillEl = document.querySelector("#chargeFill");
const shellEl = document.querySelector(".shell");
const controlHintsEl = document.querySelector("#controlHints");
const overlay = document.querySelector("#overlay");
const overlayTitleEl = document.querySelector("#overlayTitle");
const overlayTipsEl = document.querySelector("#overlayTips");
const resultEl = document.querySelector("#result");
const startButton = document.querySelector("#startGame");
const restartButton = document.querySelector("#restart");

const TAU = Math.PI * 2;
const STORAGE_KEY = "anchor-drift-best-km";

const assetSources = {
  boat: "assets/duck-boat-oblique-collage.png",
  anchorPin: "assets/anchor-pin.png",
  stoneAnchor: "assets/stone-age-anchor.png",
  shield: "assets/shield-bead.png",
  bronzeShield: "assets/stone-age-shield-bronze.png",
  obstacles: "assets/obstacles-collage-sheet.png",
  historyCutouts: "assets/history-era-cutouts.png",
  stoneObstacleA: "assets/generation-stone-age-items/02-perforated_stone_axe.png",
  stoneObstacleB: "assets/generation-stone-age-items/04-stone_tool_fragments.png",
  eightyObstacleA: "assets/generation-80s-items/05-radio_cassette.png",
  eightyObstacleB: "assets/generation-80s-items/06-cassette_tape.png",
  ninetyObstacleA: "assets/generation-90s-items/00-bp_pager.png",
  ninetyObstacleB: "assets/generation-90s-items/11-ic_card_phone.png",
  qinObstacleA: "assets/object-items/qin_general_statue.png",
  qinObstacleB: "assets/object-items/qin_terracotta_column.png",
  bronzeObstacleA: "assets/object-items/bronze_ritual_vessel.png",
  bronzeObstacleB: "assets/object-items/bronze_sword.png",
  tangObstacleA: "assets/object-items/tang_sancai_camel.png",
  tangObstacleB: "assets/object-items/tang_phoenix_plate_masked.png",
  songObstacleA: "assets/object-items/song_porcelain_vase_masked.png",
  songObstacleB: "assets/object-items/song_porcelain_cutout.png",
  cutoutsStone: "assets/era-complete/stone-age-cutouts.png",
  cutoutsBronze: "assets/era-complete/xia-shang-zhou-cutouts.png",
  cutoutsQinHan: "assets/era-complete/qin-han-three-cutouts.png",
  cutoutsTang: "assets/era-complete/tang-cutouts.png",
  cutoutsSong: "assets/era-complete/song-cutouts.png",
  cutoutsMing: "assets/era-complete/ming-cutouts.png",
  cutoutsQing: "assets/era-complete/qing-cutouts.png",
  cutoutsRepublic: "assets/era-complete/republic-cutouts.png",
  cutoutsPrc: "assets/era-complete/prc-50-70-cutouts.png",
  cutouts80s: "assets/era-complete/80s-cutouts.png",
  cutouts90s: "assets/era-complete/90s-cutouts.png",
  cutouts00s: "assets/era-complete/00s-cutouts.png",
  cutouts10s: "assets/era-complete/10s-cutouts.png",
  cutouts20s: "assets/era-complete/20s-cutouts.png",
  cutoutsFuture: "assets/era-complete/future-cutouts.png",
  timelineTang: "assets/era-complete/tang-cutouts.png",
  timelineSong: "assets/era-complete/song-cutouts.png",
  timeline80s: "assets/era-complete/80s-cutouts.png",
  timeline90s: "assets/era-complete/90s-cutouts.png",
  bankTexture: "assets/paper-bank-texture.png",
  riverTexture: "assets/river-paper-texture.png",
};

const assets = Object.fromEntries(
  Object.entries(assetSources).map(([key, src]) => {
    const image = new Image();
    image.decoding = "async";
    image.src = src;
    return [key, image];
  }),
);

const tuning = {
  boatRadius: 0.42,
  minAnchorRadius: 2.45,
  maxAnchorRadius: 8.2,
  keyboardAnchorRadius: 4.35,
  keyboardAnchorHold: 1.15,
  maxChargeTime: 1.05,
  anchorCooldown: 0.16,
  minAnchorHold: 0.85,
  maxAnchorHold: 1.7,
  maxLives: 3,
  hitInvulnerability: 1.15,
  initialSpeed: 7.2,
  maxSpeed: 24,
  speedGainPerMeter: 0.0065,
  eraLength: 260,
  riverBaseHalfWidth: 9.0,
  riverWidthWave: 1.25,
  bankDecorRange: 8.8,
  chunkSize: 10,
  chunkRange: 5,
  lookAheadGenerate: 56,
  cleanupRadius: 108,
  safeSpawnRadius: 6.5,
  cameraLookAhead: 4.4,
  cameraEase: 7,
};

const projection = {
  skewX: 0.32,
  yScale: 0.72,
  originY: 0.62,
};

const boatSprite = {
  widthMeters: 3.18,
  facingAngleOffset: Math.PI * 0.11,
};

const historySheet = {
  columns: 4,
  rows: 3,
  count: 12,
};

const singleImageSheet = {
  columns: 1,
  rows: 1,
  count: 1,
};

const cutoutSheet = {
  columns: 5,
  rows: 1,
  count: 5,
};

let dpr = 1;
let width = 0;
let height = 0;
let scale = 42;
let bestKm = Number(localStorage.getItem(STORAGE_KEY) || 0);

const keys = new Set();

const state = {
  mode: "start",
  player: null,
  cameraX: 0,
  cameraY: 0,
  bankPatches: [],
  bankProps: [],
  obstacles: [],
  pickups: [],
  particles: [],
  generatedChunks: new Set(),
  anchor: null,
  cooldown: 0,
  boatMirrored: false,
  shield: false,
  lives: tuning.maxLives,
  invulnerableTime: 0,
  distanceMeters: 0,
  speed: tuning.initialSpeed,
  lastEraStep: 0,
  timelineIndex: -1,
  eraBannerTime: 0,
  lastTime: 0,
  shake: 0,
};

const eraTrack = [
  {
    name: "石器时代",
    omen: "青铜礼器",
    assetIndex: 0,
    obstacleImageKey: "cutoutsStone",
    obstacleImageKeys: ["stoneObstacleA", "stoneObstacleB"],
    anchorImageKey: "stoneAnchor",
    shieldImageKey: "bronzeShield",
    colors: ["#d94f35", "#f0cf8a", "#2c2b28", "#f7efe1"],
    motifs: ["pottery", "stone", "hut"],
  },
  {
    name: "青铜时代",
    omen: "帝国军阵",
    assetIndex: 1,
    obstacleImageKey: "cutoutsBronze",
    obstacleImageKeys: ["bronzeObstacleA", "bronzeObstacleB"],
    anchorImageKey: "stoneAnchor",
    shieldImageKey: "bronzeShield",
    colors: ["#156f68", "#b98945", "#26352d", "#e7d8a7"],
    motifs: ["ding", "oracle", "wall"],
  },
  {
    name: "秦汉帝国",
    omen: "雕版印刷",
    assetIndex: 2,
    obstacleImageKey: "cutoutsQinHan",
    obstacleImageKeys: ["qinObstacleA", "qinObstacleB"],
    colors: ["#a52525", "#20222b", "#d7b56d", "#ece0c4"],
    motifs: ["seal", "bamboo", "watchtower"],
  },
  {
    name: "唐",
    symbol: "TANG",
    omen: "宋代市井",
    assetIndex: 3,
    obstacleImageKey: "cutoutsTang",
    obstacleImageKeys: ["tangObstacleA", "tangObstacleB"],
    timelineImageKey: "timelineTang",
    colors: ["#c43b51", "#1b6f86", "#e6c76f", "#f3ead2"],
    motifs: ["pagoda", "lantern", "bridge"],
  },
  {
    name: "宋",
    symbol: "SONG",
    omen: "青花瓷器",
    assetIndex: 3,
    obstacleImageKey: "cutoutsSong",
    obstacleImageKeys: ["songObstacleA", "songObstacleB"],
    timelineImageKey: "timelineSong",
    colors: ["#245b73", "#d0a65a", "#8c3b32", "#efe4c8"],
    motifs: ["bridge", "lantern", "pagoda"],
  },
  {
    name: "明清宫坊",
    omen: "蒸汽机车",
    assetIndex: 4,
    obstacleImageKey: "cutoutsQing",
    colors: ["#c8232f", "#f0d483", "#104b75", "#f8f2df"],
    motifs: ["gate", "porcelain", "roof"],
  },
  {
    name: "近现代",
    omen: "80年代新潮物",
    assetIndex: 5,
    obstacleImageKey: "cutoutsRepublic",
    colors: ["#c93d35", "#f4de8c", "#1d1f2f", "#3b8ea5"],
    motifs: ["rail", "factory", "skyline"],
  },
  {
    name: "80年代",
    symbol: "80S",
    omen: "90年代电子潮",
    assetIndex: 6,
    obstacleImageKey: "cutouts80s",
    obstacleImageKeys: ["eightyObstacleA", "eightyObstacleB"],
    timelineImageKey: "timeline80s",
    colors: ["#d64131", "#f3cc75", "#1d5b72", "#f7efe1"],
    motifs: ["factory", "rail", "skyline"],
  },
  {
    name: "90年代",
    symbol: "90S",
    omen: "千禧网络",
    assetIndex: 7,
    obstacleImageKey: "cutouts90s",
    obstacleImageKeys: ["ninetyObstacleA", "ninetyObstacleB"],
    timelineImageKey: "timeline90s",
    colors: ["#245fd3", "#f1d34f", "#1b1d28", "#f55b59"],
    motifs: ["skyline", "factory", "rail"],
  },
  {
    name: "当代",
    omen: "无人机",
    assetIndex: 6,
    obstacleImageKey: "cutouts20s",
    colors: ["#2ac5c4", "#f8f6e8", "#1e222a", "#f15961"],
    motifs: ["factory", "skyline", "rail"],
  },
  {
    name: "近未来",
    omen: "赛博义眼",
    assetIndex: 7,
    obstacleImageKey: "cutoutsFuture",
    colors: ["#f15961", "#ffd475", "#171824", "#69edbe"],
    motifs: ["skyline", "factory", "rail"],
  },
  {
    name: "赛博未来",
    omen: "星际飞船",
    assetIndex: 8,
    obstacleImageKey: "cutoutsFuture",
    colors: ["#69edbe", "#ecf1f8", "#141a20", "#6b89ff"],
    motifs: ["skyline", "rail", "factory"],
  },
  {
    name: "星际时代",
    omen: "后人类晶体",
    assetIndex: 9,
    obstacleImageKey: "cutoutsFuture",
    colors: ["#6b89ff", "#fff5d8", "#0f1424", "#e94da1"],
    motifs: ["rail", "skyline", "factory"],
  },
  {
    name: "后人类",
    omen: "时间乱流",
    assetIndex: 10,
    obstacleImageKey: "cutoutsFuture",
    colors: ["#e94da1", "#e6fff5", "#1c1622", "#ffbe47"],
    motifs: ["factory", "skyline", "rail"],
  },
  {
    name: "时间乱流",
    omen: "随机时代混合",
    assetIndex: 11,
    obstacleImageKey: "cutoutsFuture",
    colors: ["#ffbe47", "#e7efff", "#0c111c", "#69edbe"],
    motifs: ["skyline", "factory", "rail"],
  },
];

function noise1(value, seed) {
  const x0 = Math.floor(value);
  const x1 = x0 + 1;
  const t = value - x0;
  const eased = t * t * (3 - 2 * t);
  return lerp(hashSigned(x0, seed), hashSigned(x1, seed), eased);
}

function hashSigned(value, seed) {
  const x = Math.sin(value * 127.1 + seed * 311.7) * 43758.5453123;
  return (x - Math.floor(x)) * 2 - 1;
}

function riverRawCenterX(y) {
  return (
    noise1(y * 0.028, 11) * 7.8 +
    noise1(y * 0.011, 37) * 9.6 +
    Math.sin(y * 0.015 + 1.35) * 3.2
  );
}

const riverOriginX = riverRawCenterX(0);

function riverCenterX(y) {
  return riverRawCenterX(y) - riverOriginX;
}

function riverHalfWidth(y) {
  return (
    tuning.riverBaseHalfWidth +
    noise1(y * 0.026, 71) * 1.9 +
    Math.sin(y * 0.017 + 0.8) * tuning.riverWidthWave
  );
}

function riverEdgeNoise(y, side) {
  return (
    noise1(y * 0.19, side < 0 ? 103 : 211) * 0.92 +
    Math.sin(y * 0.47 + side * 4.3) * 0.38 +
    Math.sin(y * 0.073 + side * 7.7) * 0.68
  );
}

function riverHalfWidthAt(y, side) {
  return Math.max(5.8, riverHalfWidth(y) + riverEdgeNoise(y, side));
}

function riverHalfWidthForX(x, y) {
  const center = riverCenterX(y);
  return riverHalfWidthAt(y, x < center ? -1 : 1);
}

function riverEdgeX(y, side) {
  return riverCenterX(y) + side * riverHalfWidthAt(y, side);
}

function riverDistance(x, y) {
  return Math.abs(x - riverCenterX(y));
}

function riverClearance(x, y) {
  return riverHalfWidthForX(x, y) - riverDistance(x, y);
}

function eraStepForY(y) {
  return Math.floor(Math.max(0, y) / tuning.eraLength);
}

function eraForY(y) {
  const step = eraStepForY(y);
  if (step < eraTrack.length) return { ...eraTrack[step], step, cycle: 0 };
  const loopIndex = (step - eraTrack.length) % eraTrack.length;
  const cycle = Math.floor((step - eraTrack.length) / eraTrack.length) + 1;
  const mixed = eraTrack[loopIndex];
  return {
    ...mixed,
    name: `时间乱流 ${cycle}.${loopIndex + 1}`,
    omen: "过去/未来随机拼接",
    step,
    cycle,
  };
}

function currentEraIndexForY(y) {
  return eraStepForY(y) % eraTrack.length;
}

function eraProgressForY(y) {
  const safeY = Math.max(0, y);
  const stepStart = eraStepForY(safeY) * tuning.eraLength;
  const progress = clamp((safeY - stepStart) / tuning.eraLength, 0, 1);
  return {
    progress,
    metersLeft: Math.max(0, tuning.eraLength - (safeY - stepStart)),
  };
}

function eraSymbolFor(era) {
  if (era.symbol) return era.symbol;
  const symbols = ["STONE", "BRONZE", "EMPIRE", "MARKET", "PORCELAIN", "STEAM", "SCREEN", "DRONE", "CYBER", "STAR", "POST", "TIME"];
  return symbols[(era.assetIndex ?? era.step ?? 0) % symbols.length];
}

function sheetMetaForKey(imageKey) {
  if (imageKey === "historyCutouts") return historySheet;
  if (imageKey && imageKey.startsWith("cutouts")) return cutoutSheet;
  return singleImageSheet;
}

function hazardEraForY(y) {
  return eraForY(y);
}

function nextEraForY(y) {
  return eraTrack[(currentEraIndexForY(y) + 1) % eraTrack.length];
}

function hazardAssetForY(y, salt = 0) {
  const era = hazardEraForY(y);
  if (era.obstacleImageKeys?.length) {
    const spriteCount = Math.min(2, era.obstacleImageKeys.length);
    const poolSeed = Math.floor(y / 18) + salt * 17 + eraStepForY(y) * 31;
    const imageIndex = Math.floor((hashSigned(poolSeed, 907) + 1) * 0.5 * spriteCount) % spriteCount;
    return {
      era,
      imageKey: era.obstacleImageKeys[imageIndex],
      spriteIndex: 0,
      sheet: singleImageSheet,
    };
  }
  const imageKey = era.obstacleImageKey || "historyCutouts";
  const sheet = sheetMetaForKey(imageKey);
  const spriteCount = Math.min(2, sheet.count);
  const poolSeed = Math.floor(y / 18) + salt * 17 + eraStepForY(y) * 31;
  const spriteIndex = Math.floor((hashSigned(poolSeed, 907) + 1) * 0.5 * spriteCount) % spriteCount;
  return { era, imageKey, spriteIndex, sheet };
}

function shieldAssetForY(y) {
  const era = nextEraForY(y);
  const imageKey = era.shieldImageKey || era.obstacleImageKeys?.[0] || era.obstacleImageKey || "shield";
  const sheet = sheetMetaForKey(imageKey);
  return { era, imageKey, spriteIndex: 0, sheet };
}

function anchorImageKeyForY(y) {
  return eraForY(y).anchorImageKey || "anchorPin";
}

function omenLabelForY(y) {
  const era = hazardEraForY(y);
  if (era) return `时代障碍：${era.name}`;
  return "时代乱流：随机混合";
}

function showEraBanner(era, y) {
  if (!eraBannerEl) return;
  if (eraBannerSigilEl) eraBannerSigilEl.textContent = eraSymbolFor(era);
  if (eraBannerTitleEl) eraBannerTitleEl.textContent = era.name;
  eraBannerEl.classList.remove("is-hidden");
  eraBannerEl.classList.add("is-active");
  state.eraBannerTime = 2.8;
}

function updateEraBanner(dt) {
  if (!eraBannerEl || state.eraBannerTime <= 0) return;
  state.eraBannerTime = Math.max(0, state.eraBannerTime - dt);
  if (state.eraBannerTime === 0) {
    eraBannerEl.classList.remove("is-active");
    eraBannerEl.classList.add("is-hidden");
  }
}

function updateEraTransition() {
  if (!state.player) return;
  const step = eraStepForY(state.player.y);
  if (step !== state.lastEraStep) {
    state.lastEraStep = step;
    showEraBanner(eraForY(state.player.y), state.player.y);
    state.shake = Math.max(state.shake, 0.18);
  }
}

function resize() {
  dpr = Math.min(window.devicePixelRatio || 1, 2);
  width = Math.max(320, window.innerWidth);
  height = Math.max(520, window.innerHeight);
  canvas.width = Math.floor(width * dpr);
  canvas.height = Math.floor(height * dpr);
  canvas.style.width = `${width}px`;
  canvas.style.height = `${height}px`;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  scale = Math.min(width / 24, height / 18);
}

function resetGame() {
  state.mode = "playing";
  state.player = {
    x: 0,
    y: 0,
    dirX: 0,
    dirY: 1,
    angle: 0,
  };
  state.cameraX = 0;
  state.cameraY = tuning.cameraLookAhead;
  state.bankPatches = [];
  state.bankProps = [];
  state.obstacles = [];
  state.pickups = [];
  state.particles = [];
  state.generatedChunks = new Set();
  state.anchor = null;
  state.cooldown = 0;
  state.boatMirrored = false;
  state.shield = false;
  state.lives = tuning.maxLives;
  state.invulnerableTime = 0;
  state.distanceMeters = 0;
  state.speed = tuning.initialSpeed;
  state.lastEraStep = eraStepForY(state.player.y);
  state.eraBannerTime = 0;
  state.shake = 0;
  overlay.classList.add("is-hidden");
  overlay.classList.remove("is-start", "is-gameover");
  if (startButton) startButton.hidden = true;
  if (restartButton) restartButton.hidden = false;
  if (eraBannerEl) {
    eraBannerEl.classList.add("is-hidden");
    eraBannerEl.classList.remove("is-active");
  }
  generateWorldAround();
  seedOpeningRun();
  updateModeUi();
  showEraBanner(eraForY(state.player.y), state.player.y);
  updateHud();
}

function showStartScreen() {
  state.mode = "start";
  state.anchor = null;
  state.cooldown = 0;
  keys.clear();
  if (overlayTitleEl) overlayTitleEl.textContent = "Anchor Drift";
  resultEl.textContent = "用左右锚把船甩过时代障碍，别让船撞到岸边或奇怪物件。";
  if (overlayTipsEl) overlayTipsEl.hidden = false;
  if (startButton) startButton.hidden = false;
  if (restartButton) restartButton.hidden = true;
  overlay.classList.remove("is-hidden", "is-gameover");
  overlay.classList.add("is-start");
  if (eraBannerEl) {
    eraBannerEl.classList.add("is-hidden");
    eraBannerEl.classList.remove("is-active");
  }
  updateHud();
}

function gameOver(reason) {
  if (state.mode !== "playing") return;
  state.mode = "gameover";
  state.anchor = null;
  const km = state.distanceMeters / 1000;
  if (km > bestKm) {
    bestKm = km;
    localStorage.setItem(STORAGE_KEY, String(bestKm));
  }
  if (overlayTitleEl) overlayTitleEl.textContent = "航线结束";
  resultEl.textContent = `${reason} 本次 ${formatKm(km)}，最高 ${formatKm(bestKm)}。`;
  if (overlayTipsEl) overlayTipsEl.hidden = true;
  if (startButton) startButton.hidden = true;
  if (restartButton) restartButton.hidden = false;
  overlay.classList.remove("is-start");
  overlay.classList.add("is-gameover");
  overlay.classList.remove("is-hidden");
  updateHud();
}

function formatKm(km) {
  return `${km.toFixed(2)} km`;
}

function cancelInputState() {
  state.anchor = null;
  state.cooldown = 0;
}

function updateModeUi() {
  shellEl.classList.remove("is-mouse-mode");
  controlHintsEl.innerHTML = `
    <kbd>A</kbd><span>左锚</span>
    <kbd>D</kbd><span>右锚</span>
    <kbd>Space</kbd><span>松锚 / 重开</span>
  `;
}

function updateLivesUi() {
  if (!livesStateEl) return;
  const lives = clamp(state.lives, 0, tuning.maxLives);
  livesStateEl.setAttribute("aria-label", `生命 ${lives}/${tuning.maxLives}`);
  if (livesStateEl.children.length !== tuning.maxLives) {
    livesStateEl.replaceChildren(
      ...Array.from({ length: tuning.maxLives }, () => {
        const heart = document.createElement("span");
        heart.className = "life-heart";
        heart.setAttribute("aria-hidden", "true");
        return heart;
      }),
    );
  }
  [...livesStateEl.children].forEach((heart, index) => {
    const isFull = index < lives;
    heart.classList.toggle("is-full", isFull);
    heart.classList.toggle("is-empty", !isFull);
  });
}

function updateTimelineUi(y) {
  if (!eraTimelineTrackEl) return;
  if (eraTimelineTrackEl.children.length !== eraTrack.length) {
    eraTimelineTrackEl.replaceChildren(
      ...eraTrack.map((era, index) => {
        const item = document.createElement("span");
        item.className = "timeline-era";
        const thumb = document.createElement("i");
        const label = document.createElement("b");
        thumb.setAttribute("aria-hidden", "true");
        label.textContent = era.name;
        item.append(thumb, label);
        return item;
      }),
    );
  }
  const step = eraStepForY(y);
  const activeIndex = currentEraIndexForY(y);
  [...eraTimelineTrackEl.children].forEach((item, index) => {
    const era = eraTrack[index];
    const thumb = item.querySelector("i");
    const image = assets[era.timelineImageKey || "historyCutouts"];
    if (thumb && image) thumb.style.backgroundImage = `url("${image.src}")`;
    item.classList.toggle("is-reached", step >= index);
    item.classList.toggle("is-active", index === activeIndex);
  });
  if (state.timelineIndex !== activeIndex) {
    state.timelineIndex = activeIndex;
    const activeItem = eraTimelineTrackEl.children[activeIndex];
    if (activeItem) {
      eraTimelineTrackEl.scrollTo({
        left: Math.max(0, activeItem.offsetLeft - eraTimelineTrackEl.clientWidth / 2 + activeItem.clientWidth / 2),
        behavior: "smooth",
      });
    }
  }
}

function setSheetIcon(el, imageKey, spriteIndex = 0, sheet = cutoutSheet) {
  if (!el) return;
  const image = assets[imageKey] || assets.historyCutouts;
  el.style.backgroundImage = image ? `url("${image.src}")` : "";
  if (sheet.columns === 1 && sheet.rows === 1) {
    el.style.backgroundSize = "contain";
    el.style.backgroundPosition = "center";
    return;
  }
  el.style.backgroundSize = `${sheet.columns * 100}% ${sheet.rows * 100}%`;
  const col = spriteIndex % sheet.columns;
  const row = Math.floor(spriteIndex / sheet.columns);
  const x = sheet.columns > 1 ? (col / (sheet.columns - 1)) * 100 : 50;
  const y = sheet.rows > 1 ? (row / (sheet.rows - 1)) * 100 : 50;
  el.style.backgroundPosition = `${x}% ${y}%`;
}

function updateRoundLegendUi(y) {
  if (!legendEraLabelEl && !legendObstacleAEl && !legendShieldEl) return;
  const currentEra = eraForY(y);
  const primary = { ...hazardAssetForY(y, 1), spriteIndex: 0 };
  const secondary = {
    ...primary,
    spriteIndex: Math.min(1, primary.sheet.count - 1),
  };
  const shield = shieldAssetForY(y);
  if (legendEraLabelEl) {
    legendEraLabelEl.textContent = `${currentEra.name} 障碍 / ${shield.era.name} 护盾`;
  }
  setSheetIcon(legendObstacleAEl, primary.imageKey, primary.spriteIndex, primary.sheet);
  setSheetIcon(legendObstacleBEl, secondary.imageKey, secondary.spriteIndex, secondary.sheet);
  setSheetIcon(legendShieldEl, shield.imageKey, shield.spriteIndex, shield.sheet);
}

function updateHud() {
  distanceEl.textContent = formatKm(state.distanceMeters / 1000);
  if (speedStateEl) speedStateEl.textContent = `速度 ${state.speed.toFixed(1)} m/s`;
  bestEl.textContent = formatKm(bestKm);
  const hudY = state.player ? state.player.y : state.distanceMeters;
  const era = eraForY(hudY);
  eraStateEl.textContent = era.name;
  if (chargeFillEl) chargeFillEl.style.width = "0%";
  updateLivesUi();
  const eraProgress = eraProgressForY(hudY);
  if (eraCountdownEl) eraCountdownEl.textContent = `距下个时代 ${Math.ceil(eraProgress.metersLeft)} m`;
  if (eraFillEl) eraFillEl.style.width = `${Math.round(eraProgress.progress * 100)}%`;
  updateTimelineUi(hudY);
  updateRoundLegendUi(hudY);

  if (state.mode === "start") {
    anchorStateEl.textContent = "START";
  } else if (state.mode === "gameover") {
    anchorStateEl.textContent = "WRECKED";
  } else if (state.anchor) {
    if (state.anchor.source === "keyboard") {
      const side = state.anchor.side === -1 ? "LEFT" : "RIGHT";
      anchorStateEl.textContent = `${side} ${state.anchor.timeLeft.toFixed(1)}s`;
    } else {
      anchorStateEl.textContent = `${state.anchor.radius.toFixed(1)}m ${state.anchor.timeLeft.toFixed(1)}s`;
    }
  } else if (state.cooldown > 0) {
    anchorStateEl.textContent = "RESET";
  } else {
    anchorStateEl.textContent = state.shield ? "SHIELD" : "READY";
  }
}

function dropKeyboardAnchor(side) {
  if (state.mode !== "playing" || state.anchor || state.cooldown > 0) return;
  const p = state.player;
  const rightX = p.dirY;
  const rightY = -p.dirX;
  const radius = tuning.keyboardAnchorRadius;
  const anchorX = p.x + rightX * side * radius;
  const anchorY = p.y + rightY * side * radius;
  const radialX = p.x - anchorX;
  const radialY = p.y - anchorY;
  const theta = Math.atan2(radialY, radialX);
  const tangentPlus = { x: -Math.sin(theta), y: Math.cos(theta) };
  const dotPlus = tangentPlus.x * p.dirX + tangentPlus.y * p.dirY;
  const angularSign = dotPlus >= 0 ? 1 : -1;
  const color = side === -1 ? "#78f7d1" : "#7db4ff";

  state.boatMirrored = side === 1;
  state.anchor = {
    x: anchorX,
    y: anchorY,
    theta,
    angularSign,
    radius,
    source: "keyboard",
    side,
    timeLeft: tuning.keyboardAnchorHold,
    maxTime: tuning.keyboardAnchorHold,
    charge: 0,
    color,
    imageKey: anchorImageKeyForY(p.y),
  };
  burst(anchorX, anchorY, color, 12, 0.1);
}

function anchorSideFromPlayer(player, anchorX, anchorY) {
  const rightX = player.dirY;
  const rightY = -player.dirX;
  const dotRight = (anchorX - player.x) * rightX + (anchorY - player.y) * rightY;
  return dotRight >= 0 ? 1 : -1;
}

function releaseAnchor() {
  if (!state.anchor) return;
  state.anchor = null;
  state.cooldown = tuning.anchorCooldown;
  burst(state.player.x, state.player.y, "#ffffff", 8, 0.12);
}

function update(dt) {
  if (state.mode !== "playing") {
    updateParticles(dt);
    return;
  }

  state.cooldown = Math.max(0, state.cooldown - dt);
  state.invulnerableTime = Math.max(0, state.invulnerableTime - dt);
  state.speed = Math.min(
    tuning.maxSpeed,
    tuning.initialSpeed + state.distanceMeters * tuning.speedGainPerMeter,
  );

  if (state.anchor) updateAnchored(dt);
  else updateFree(dt);

  state.distanceMeters += state.speed * dt;
  state.shake = Math.max(0, state.shake - dt * 4);

  updateCamera(dt);
  generateWorldAround();
  cleanupWorld();
  updatePickups();
  updateCollisions();
  updateEraTransition();
  updateEraBanner(dt);
  updateParticles(dt);
  updateHud();
}

function updateFree(dt) {
  const p = state.player;
  p.x += p.dirX * state.speed * dt;
  p.y += p.dirY * state.speed * dt;
  p.angle = Math.atan2(p.dirX, p.dirY);
  makeWake(p.x - p.dirX * 0.42, p.y - p.dirY * 0.42, 0.22);
}

function updateAnchored(dt) {
  const p = state.player;
  const a = state.anchor;
  const angularSpeed = state.speed / a.radius;
  a.theta += a.angularSign * angularSpeed * dt;
  a.timeLeft -= dt;

  p.x = a.x + Math.cos(a.theta) * a.radius;
  p.y = a.y + Math.sin(a.theta) * a.radius;

  const tangentX = -Math.sin(a.theta) * a.angularSign;
  const tangentY = Math.cos(a.theta) * a.angularSign;
  p.dirX = tangentX;
  p.dirY = tangentY;
  normalizeDir(p);
  p.angle = Math.atan2(p.dirX, p.dirY);

  makeWake(p.x - p.dirX * 0.36, p.y - p.dirY * 0.36, 0.38);

  if (a.timeLeft <= 0) {
    releaseAnchor();
    state.shake = Math.max(state.shake, 0.25);
  }
}

function normalizeDir(p) {
  const mag = Math.hypot(p.dirX, p.dirY) || 1;
  p.dirX /= mag;
  p.dirY /= mag;
}

function updateCamera(dt) {
  const p = state.player;
  const targetX = p.x + p.dirX * tuning.cameraLookAhead;
  const targetY = p.y + p.dirY * tuning.cameraLookAhead;
  const amount = 1 - Math.exp(-tuning.cameraEase * dt);
  state.cameraX = lerp(state.cameraX, targetX, amount);
  state.cameraY = lerp(state.cameraY, targetY, amount);
}

function generateWorldAround() {
  const p = state.player;
  const targets = [
    { x: p.x, y: p.y },
    { x: p.x + p.dirX * tuning.lookAheadGenerate, y: p.y + p.dirY * tuning.lookAheadGenerate },
    { x: state.cameraX, y: state.cameraY },
  ];

  for (const target of targets) {
    const baseX = Math.floor(target.x / tuning.chunkSize);
    const baseY = Math.floor(target.y / tuning.chunkSize);
    for (let cy = baseY - tuning.chunkRange; cy <= baseY + tuning.chunkRange; cy += 1) {
      for (let cx = baseX - tuning.chunkRange; cx <= baseX + tuning.chunkRange; cx += 1) {
        generateChunk(cx, cy);
      }
    }
  }
}

function generateChunk(cx, cy) {
  const key = `${cx},${cy}`;
  if (state.generatedChunks.has(key)) return;
  state.generatedChunks.add(key);

  const size = tuning.chunkSize;
  const centerX = (cx + 0.5) * size;
  const centerY = (cy + 0.5) * size;
  if (Math.hypot(centerX, centerY) < tuning.safeSpawnRadius * 1.4) return;

  const difficulty = clamp(state.distanceMeters / 900, 0, 1);
  const bankDistance = Math.abs(centerX - riverCenterX(centerY));
  const halfWidth = riverHalfWidthForX(centerX, centerY);
  const insideRiver = bankDistance < halfWidth - 0.25;
  const onBank = bankDistance > halfWidth - 0.65 && bankDistance < halfWidth + tuning.bankDecorRange;

  for (const side of [-1, 1]) {
    const edgeDistance = Math.abs(centerX - riverEdgeX(centerY, side));
    if (edgeDistance < size * 1.25 && Math.random() < 0.98) {
      const count = 2 + (Math.random() < 0.58 ? 1 : 0);
      for (let i = 0; i < count; i += 1) {
        const y = (cy + rand(0.02, 0.98)) * size;
        const edgeX = riverEdgeX(y, side);
        addBankPatch(edgeX + side * rand(-0.95, 3.4), y, side);
      }
    }
  }

  if (insideRiver) {
    const density = 0.72 + difficulty * 0.24;
    if (Math.random() < density) {
      const count =
        1 +
        (Math.random() < 0.52 + difficulty * 0.24 ? 1 : 0) +
        (Math.random() < 0.1 + difficulty * 0.18 ? 1 : 0);
      for (let i = 0; i < count; i += 1) {
        const x = (cx + rand(0.15, 0.85)) * size;
        const y = (cy + rand(0.15, 0.85)) * size;
        const localHalf = riverHalfWidthForX(x, y) - 1.15;
        if (riverDistance(x, y) > localHalf) continue;
        if (Math.hypot(x - state.player.x, y - state.player.y) < tuning.safeSpawnRadius) continue;
        addEraObstacle(x, y, rand(0.46, 0.98 + difficulty * 0.22), y, i);
      }
    }

    const shieldChance = 0.085 + difficulty * 0.075;
    if (Math.random() < shieldChance) {
      const x = (cx + rand(0.25, 0.75)) * size;
      const y = (cy + rand(0.25, 0.75)) * size;
      if (
        riverDistance(x, y) < riverHalfWidthForX(x, y) - 1.25 &&
        Math.hypot(x - state.player.x, y - state.player.y) > tuning.safeSpawnRadius
      ) {
        const shield = shieldAssetForY(y);
        state.pickups.push({
          x,
          y,
          r: 0.42,
          type: "shield",
          imageKey: shield.imageKey,
          spriteIndex: shield.spriteIndex,
          sheetColumns: shield.sheet.columns,
          sheetRows: shield.sheet.rows,
        });
      }
    }
  } else if (onBank && Math.random() < 0.42) {
    const side = centerX < riverCenterX(centerY) ? -1 : 1;
    const y = (cy + rand(0.08, 0.92)) * size;
    const bankX = riverEdgeX(y, side) + side * rand(1.0, tuning.bankDecorRange - 0.8);
    addHistoryProp(bankX, y, side);
  }
}

function seedOpeningRun() {
  const pattern = [
    { y: 12, lane: -0.52, r: 0.58 },
    { y: 17, lane: 0.36, r: 0.64 },
    { y: 23, lane: -0.1, r: 0.56 },
    { y: 29, lane: 0.58, r: 0.72 },
    { y: 36, lane: -0.48, r: 0.68 },
    { y: 45, lane: 0.16, r: 0.78 },
    { y: 54, lane: -0.64, r: 0.7 },
  ];

  for (let i = 0; i < pattern.length; i += 1) {
    const item = pattern[i];
    const center = riverCenterX(item.y);
    const half = Math.min(riverHalfWidthAt(item.y, -1), riverHalfWidthAt(item.y, 1)) - 2.1;
    addEraObstacle(center + item.lane * half, item.y, item.r, item.y, i);
  }
}

function makeRaggedPatchPoints() {
  const points = [];
  const count = Math.floor(rand(9, 14));
  for (let i = 0; i < count; i += 1) {
    const angle = (i / count) * TAU + rand(-0.12, 0.12);
    const radius = rand(0.74, 1.1);
    points.push({
      x: Math.cos(angle) * radius * 0.5,
      y: Math.sin(angle) * radius * 0.5,
    });
  }
  return points;
}

function addBankPatch(x, y, side) {
  const source = Math.random() < 0.84 ? "bankTexture" : "obstacles";
  const w = rand(2.7, 6.1);
  const h = rand(1.55, 4.6);
  state.bankPatches.push({
    x,
    y,
    side,
    source,
    spriteIndex: Math.floor(rand(0, 9)),
    cropX: rand(0.02, 0.58),
    cropY: rand(0.02, 0.58),
    cropW: rand(0.22, 0.4),
    cropH: rand(0.22, 0.4),
    w,
    h,
    hitRadius: Math.min(w, h) * rand(0.34, 0.46),
    alpha: rand(0.74, 0.96),
    rotation: rand(-0.55, 0.55) + side * rand(0.08, 0.3),
    points: makeRaggedPatchPoints(),
  });
}

function addHistoryProp(x, y, side) {
  const era = eraForY(y);
  const motif = era.motifs[Math.floor(rand(0, era.motifs.length))];
  const color = era.colors[Math.floor(rand(0, era.colors.length))];
  const accent = era.colors[Math.floor(rand(0, era.colors.length))];
  const paper = [];
  for (let i = 0; i < 4; i += 1) {
    paper.push({
      x: rand(-0.55, 0.55),
      y: rand(-0.55, 0.55),
      w: rand(0.18, 0.48),
      h: rand(0.14, 0.34),
      rotation: rand(-0.7, 0.7),
      color: era.colors[Math.floor(rand(0, era.colors.length))],
    });
  }
  state.bankProps.push({
    x,
    y,
    side,
    motif,
    color,
    accent,
    paper,
    scale: rand(0.78, 1.28),
    rotation: rand(-0.25, 0.25) + side * 0.08,
    eraName: era.name,
  });
}

function cleanupWorld() {
  const p = state.player;
  state.bankPatches = state.bankPatches.filter((o) => Math.hypot(o.x - p.x, o.y - p.y) < tuning.cleanupRadius);
  state.obstacles = state.obstacles.filter((o) => Math.hypot(o.x - p.x, o.y - p.y) < tuning.cleanupRadius);
  state.pickups = state.pickups.filter((o) => Math.hypot(o.x - p.x, o.y - p.y) < tuning.cleanupRadius);
  state.bankProps = state.bankProps.filter((o) => Math.hypot(o.x - p.x, o.y - p.y) < tuning.cleanupRadius);
  state.particles = state.particles.filter((p) => p.life > 0);
}

function updatePickups() {
  const p = state.player;
  for (const pickup of state.pickups) {
    if (Math.hypot(p.x - pickup.x, p.y - pickup.y) < tuning.boatRadius + pickup.r) {
      const hitX = pickup.x;
      const hitY = pickup.y;
      pickup.x = 99999;
      state.shield = true;
      burst(hitX, hitY, "#78f7d1", 18, 0.2);
    }
  }
}

function addCollageRock(x, y, r) {
  const palette = [
    "#f3df9f",
    "#e84f5f",
    "#107b7e",
    "#1b2545",
    "#f7f1dc",
    "#d6a93a",
    "#222222",
  ];
  const pointCount = Math.floor(rand(7, 11));
  const points = [];
  for (let i = 0; i < pointCount; i += 1) {
    const angle = (i / pointCount) * TAU + rand(-0.12, 0.12);
    points.push({
      x: Math.cos(angle) * rand(0.62, 1.08),
      y: Math.sin(angle) * rand(0.62, 1.08),
    });
  }

  const pieces = [];
  const pieceCount = Math.floor(rand(4, 7));
  for (let i = 0; i < pieceCount; i += 1) {
    const localPoints = [];
    const sides = Math.floor(rand(3, 6));
    for (let j = 0; j < sides; j += 1) {
      const angle = (j / sides) * TAU + rand(-0.18, 0.18);
      localPoints.push({
        x: Math.cos(angle) * rand(0.18, 0.44),
        y: Math.sin(angle) * rand(0.18, 0.44),
      });
    }
    pieces.push({
      x: rand(-0.36, 0.36),
      y: rand(-0.36, 0.36),
      rotation: rand(0, TAU),
      color: palette[Math.floor(rand(0, palette.length))],
      points: localPoints,
    });
  }

  const dots = [];
  for (let i = 0; i < 10; i += 1) {
    dots.push({ x: rand(-0.5, 0.5), y: rand(-0.5, 0.5), s: rand(0.025, 0.055) });
  }

  state.obstacles.push({
    x,
    y,
    r,
    rotation: rand(0, TAU),
    spriteIndex: Math.floor(rand(0, 9)),
    points,
    pieces,
    dots,
  });
}

function addEraObstacle(x, y, r, sourceY, salt = 0) {
  const hazard = hazardAssetForY(sourceY, salt);
  state.obstacles.push({
    x,
    y,
    r,
    kind: "era",
    assetIndex: hazard.era.assetIndex,
    imageKey: hazard.imageKey,
    rotation: rand(-0.7, 0.7),
    spriteIndex: hazard.spriteIndex,
    sheetColumns: hazard.sheet.columns,
    sheetRows: hazard.sheet.rows,
  });
}

function takeDamage(reason, x, y, color = "#ff6e6e") {
  if (state.invulnerableTime > 0) return false;
  state.lives -= 1;
  state.anchor = null;
  state.invulnerableTime = tuning.hitInvulnerability;
  state.shake = 0.65;
  burst(x, y, color, 32, 0.5);
  if (state.lives <= 0) {
    gameOver(reason);
    return true;
  }
  updateHud();
  return false;
}

function clearSafeZone(x, y, radius = 9.5) {
  const farAway = 99999;
  state.obstacles.forEach((item) => {
    if (Math.hypot(item.x - x, item.y - y) < radius) item.x = farAway;
  });
  state.bankPatches.forEach((item) => {
    if (Math.hypot(item.x - x, item.y - y) < radius) item.x = farAway;
  });
  state.pickups.forEach((item) => {
    if (Math.hypot(item.x - x, item.y - y) < radius * 0.62) item.x = farAway;
  });
}

function rescueToRiver() {
  const p = state.player;
  const rescueY = p.y + Math.max(2.2, state.speed * 0.22);
  const center = riverCenterX(rescueY);
  const half = Math.min(riverHalfWidthAt(rescueY, -1), riverHalfWidthAt(rescueY, 1));
  p.x = center + clamp(p.x - center, -half * 0.18, half * 0.18);
  p.y = rescueY;
  if (p.dirY < 0.35) {
    p.dirY = 0.85;
    normalizeDir(p);
  }
  p.angle = Math.atan2(p.dirX, p.dirY);
  state.anchor = null;
  state.cooldown = tuning.anchorCooldown;
  state.cameraX = p.x;
  state.cameraY = p.y + tuning.cameraLookAhead;
  clearSafeZone(p.x, p.y);
  burst(p.x, p.y, "#78f7d1", 18, 0.24);
}

function updateCollisions() {
  const p = state.player;
  if (riverClearance(p.x, p.y) < tuning.boatRadius * 0.2) {
    takeDamage("驶出河道了。", p.x, p.y, "#7db4ff");
    if (state.mode === "playing") rescueToRiver();
    return;
  }

  for (const patch of state.bankPatches) {
    const hitDistance = tuning.boatRadius + patch.hitRadius;
    if (Math.hypot(p.x - patch.x, p.y - patch.y) < hitDistance) {
      patch.x = 99999;
      takeDamage("撞上河岸拼贴了。", p.x, p.y, "#e9c46a");
      return;
    }
  }

  for (const rock of state.obstacles) {
    const hitDistance = tuning.boatRadius + rock.r * 0.82;
    if (Math.hypot(p.x - rock.x, p.y - rock.y) < hitDistance) {
      if (state.shield) {
        const hitX = rock.x;
        const hitY = rock.y;
        state.shield = false;
        rock.x = 99999;
        state.shake = 0.45;
        burst(hitX, hitY, "#ffcf6e", 28, 0.42);
        return;
      }
      rock.x = 99999;
      takeDamage(rock.kind === "era" ? "撞上时代障碍了。" : "撞上障碍物了。", p.x, p.y);
      return;
    }
  }
}

function updateParticles(dt) {
  for (const particle of state.particles) {
    particle.life -= dt;
    particle.x += particle.vx * dt;
    particle.y += particle.vy * dt;
    particle.vx *= 0.985;
    particle.vy *= 0.985;
  }
}

function burst(x, y, color, count, power) {
  for (let i = 0; i < count; i += 1) {
    const angle = Math.random() * TAU;
    const speed = rand(power * 4, power * 13);
    state.particles.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      life: rand(0.25, 0.62),
      startLife: 0.62,
      r: rand(0.035, 0.09),
      color,
    });
  }
}

function makeWake(x, y, chance) {
  if (Math.random() > chance) return;
  const p = state.player;
  const sideX = p.dirY;
  const sideY = -p.dirX;
  state.particles.push({
    x: x + sideX * rand(-0.22, 0.22),
    y: y + sideY * rand(-0.22, 0.22),
    vx: -p.dirX * rand(0.8, 1.8) + sideX * rand(-0.35, 0.35),
    vy: -p.dirY * rand(0.8, 1.8) + sideY * rand(-0.35, 0.35),
    life: rand(0.36, 0.8),
    startLife: 0.8,
    r: rand(0.04, 0.11),
    color: "rgba(220, 250, 255, 0.72)",
  });
}

function draw() {
  ctx.clearRect(0, 0, width, height);
  const shakeX = rand(-1, 1) * state.shake * 9;
  const shakeY = rand(-1, 1) * state.shake * 9;
  ctx.save();
  ctx.translate(shakeX, shakeY);
  drawLandscape();
  drawBankProps();
  drawPickups();
  drawRocks();
  drawAnchor();
  drawParticles();
  drawBoat();
  ctx.restore();
}

function assetReady(image) {
  return image && image.complete && image.naturalWidth > 0;
}

function drawImageCentered(image, x, y, widthPx, heightPx, rotation = 0, alpha = 1) {
  if (!assetReady(image)) return false;
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(rotation);
  ctx.globalAlpha = clamp(ctx.globalAlpha * alpha, 0, 1);
  ctx.drawImage(image, -widthPx * 0.5, -heightPx * 0.5, widthPx, heightPx);
  ctx.restore();
  return true;
}

function drawTiledImage(image, tileSize, alpha = 1, drift = 0.12) {
  if (!assetReady(image)) return false;
  const offsetX = mod(-state.cameraX * scale * drift, tileSize) - tileSize;
  const offsetY = mod(state.cameraY * scale * drift, tileSize) - tileSize;
  ctx.save();
  ctx.globalAlpha = clamp(ctx.globalAlpha * alpha, 0, 1);
  for (let y = offsetY; y < height + tileSize; y += tileSize) {
    for (let x = offsetX; x < width + tileSize; x += tileSize) {
      ctx.drawImage(image, x, y, tileSize, tileSize);
    }
  }
  ctx.restore();
  return true;
}

function traceRiverPath(leftBank, rightBank) {
  ctx.beginPath();
  leftBank.forEach((point, index) => {
    if (index === 0) ctx.moveTo(point.x, point.y);
    else ctx.lineTo(point.x, point.y);
  });
  for (let i = rightBank.length - 1; i >= 0; i -= 1) {
    ctx.lineTo(rightBank[i].x, rightBank[i].y);
  }
  ctx.closePath();
}

function drawLandscape() {
  ctx.fillStyle = "#151716";
  ctx.fillRect(0, 0, width, height);
  drawTiledImage(assets.bankTexture, Math.max(440, scale * 9.2), 0.76, 0.08);

  const step = scale * 2.8;
  const offsetX = mod(-state.cameraX * scale, step) - step;
  const offsetY = mod(state.cameraY * scale, step) - step;

  ctx.strokeStyle = "rgba(240, 205, 130, 0.045)";
  ctx.lineWidth = 1;
  for (let y = offsetY; y < height + step; y += step) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.bezierCurveTo(width * 0.28, y + 13, width * 0.66, y - 12, width, y + 6);
    ctx.stroke();
  }

  ctx.strokeStyle = "rgba(236, 76, 76, 0.035)";
  for (let x = offsetX; x < width + step; x += step) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.bezierCurveTo(x + 12, height * 0.25, x - 10, height * 0.7, x + 8, height);
    ctx.stroke();
  }

  const leftBank = [];
  const rightBank = [];
  const visibleTop = state.cameraY + height * 0.78 / (scale * projection.yScale);
  const visibleBottom = state.cameraY - height * 0.72 / (scale * projection.yScale);
  const samples = 96;

  for (let i = 0; i <= samples; i += 1) {
    const y = lerp(visibleTop + 4, visibleBottom - 4, i / samples);
    leftBank.push(worldToScreen(riverEdgeX(y, -1), y));
    rightBank.push(worldToScreen(riverEdgeX(y, 1), y));
  }

  const riverGradient = ctx.createLinearGradient(0, 0, 0, height);
  riverGradient.addColorStop(0, "#0f3c48");
  riverGradient.addColorStop(0.52, "#092b35");
  riverGradient.addColorStop(1, "#061923");

  ctx.fillStyle = riverGradient;
  traceRiverPath(leftBank, rightBank);
  ctx.fill();

  ctx.save();
  traceRiverPath(leftBank, rightBank);
  ctx.clip();
  if (!drawTiledImage(assets.riverTexture, Math.max(360, scale * 7.8), 0.9, 0.16)) {
    ctx.fillStyle = riverGradient;
    ctx.fillRect(0, 0, width, height);
  }
  ctx.fillStyle = "rgba(7, 38, 50, 0.36)";
  ctx.fillRect(0, 0, width, height);
  drawRiverCurrent();
  ctx.restore();

  drawBankPatches();
}

function drawBankPatches() {
  const bankImage = assets.bankTexture;
  const fragmentImage = assets.obstacles;
  if (!assetReady(bankImage)) return;

  for (const patch of state.bankPatches) {
    const pos = worldToScreen(patch.x, patch.y);
    const patchW = patch.w * scale;
    const patchH = patch.h * scale * projection.yScale;
    if (!isOnScreen(pos, Math.max(patchW, patchH))) continue;

    const image = patch.source === "obstacles" && assetReady(fragmentImage) ? fragmentImage : bankImage;
    let sx = patch.cropX * image.naturalWidth;
    let sy = patch.cropY * image.naturalHeight;
    let sw = patch.cropW * image.naturalWidth;
    let sh = patch.cropH * image.naturalHeight;

    if (image === fragmentImage) {
      const cellW = image.naturalWidth / 3;
      const cellH = image.naturalHeight / 3;
      sx = (patch.spriteIndex % 3) * cellW;
      sy = Math.floor(patch.spriteIndex / 3) * cellH;
      sw = cellW;
      sh = cellH;
    }

    ctx.save();
    ctx.translate(pos.x, pos.y);
    ctx.rotate(patch.rotation);
    ctx.globalAlpha = patch.alpha;
    ctx.shadowColor = "rgba(0, 0, 0, 0.34)";
    ctx.shadowBlur = 13;
    ctx.shadowOffsetX = 7;
    ctx.shadowOffsetY = 9;
    ctx.beginPath();
    tracePatchPolygon(patch.points, patchW, patchH);
    ctx.save();
    ctx.clip();
    ctx.drawImage(image, sx, sy, sw, sh, -patchW * 0.5, -patchH * 0.5, patchW, patchH);
    ctx.restore();
    ctx.shadowColor = "transparent";
    ctx.strokeStyle = patch.side < 0 ? "rgba(244, 215, 142, 0.72)" : "rgba(236, 76, 88, 0.58)";
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.restore();
  }
}

function tracePatchPolygon(points, widthPx, heightPx) {
  points.forEach((point, index) => {
    const x = point.x * widthPx;
    const y = point.y * heightPx;
    if (index === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  });
  ctx.closePath();
}

function drawRiverCurrent() {
  const step = scale * 2.2;
  const offsetY = mod(state.cameraY * scale * 0.58, step) - step;
  ctx.strokeStyle = "rgba(220, 250, 255, 0.08)";
  ctx.lineWidth = 1;
  for (let y = offsetY; y < height + step; y += step) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.bezierCurveTo(width * 0.25, y + 18, width * 0.72, y - 10, width, y + 9);
    ctx.stroke();
  }
}

function drawBankLine(points, color) {
  ctx.strokeStyle = "rgba(0, 0, 0, 0.62)";
  ctx.lineWidth = 7;
  ctx.beginPath();
  points.forEach((point, index) => {
    if (index === 0) ctx.moveTo(point.x, point.y);
    else ctx.lineTo(point.x, point.y);
  });
  ctx.stroke();

  ctx.strokeStyle = color;
  ctx.lineWidth = 3;
  ctx.setLineDash([14, 8, 5, 8]);
  ctx.beginPath();
  points.forEach((point, index) => {
    if (index === 0) ctx.moveTo(point.x, point.y);
    else ctx.lineTo(point.x, point.y);
  });
  ctx.stroke();
  ctx.setLineDash([]);
}

function drawBankProps() {
  for (const prop of state.bankProps) {
    const pos = worldToScreen(prop.x, prop.y);
    if (!isOnScreen(pos, 120)) continue;
    ctx.save();
    ctx.translate(pos.x, pos.y);
    ctx.rotate(prop.rotation);
    ctx.scale(prop.scale * scale, prop.scale * scale * projection.yScale);

    for (const paper of prop.paper) {
      ctx.save();
      ctx.translate(paper.x, paper.y);
      ctx.rotate(paper.rotation);
      ctx.fillStyle = paper.color;
      ctx.globalAlpha = 0.92;
      ctx.fillRect(-paper.w * 0.5, -paper.h * 0.5, paper.w, paper.h);
      ctx.globalAlpha = 1;
      ctx.restore();
    }

    drawHistoryMotif(prop);
    ctx.restore();
  }
}

function drawHistoryMotif(prop) {
  ctx.lineJoin = "round";
  ctx.lineCap = "round";
  ctx.strokeStyle = "#05090c";
  ctx.lineWidth = 0.07;
  ctx.fillStyle = prop.color;

  switch (prop.motif) {
    case "pottery":
      drawPottery(prop);
      break;
    case "stone":
      drawStoneTool(prop);
      break;
    case "hut":
      drawHut(prop);
      break;
    case "ding":
      drawDing(prop);
      break;
    case "oracle":
      drawOracleBone(prop);
      break;
    case "wall":
      drawWall(prop);
      break;
    case "seal":
      drawSeal(prop);
      break;
    case "bamboo":
      drawBamboo(prop);
      break;
    case "watchtower":
      drawWatchtower(prop);
      break;
    case "pagoda":
      drawPagoda(prop);
      break;
    case "bridge":
      drawBridge(prop);
      break;
    case "lantern":
      drawLantern(prop);
      break;
    case "gate":
      drawGate(prop);
      break;
    case "porcelain":
      drawPorcelain(prop);
      break;
    case "roof":
      drawRoof(prop);
      break;
    case "rail":
      drawRail(prop);
      break;
    case "factory":
      drawFactory(prop);
      break;
    case "skyline":
      drawSkyline(prop);
      break;
    default:
      drawStoneTool(prop);
  }
}

function drawPottery(prop) {
  ctx.fillStyle = prop.color;
  ctx.beginPath();
  ctx.ellipse(0, 0.1, 0.58, 0.44, 0, 0, TAU);
  ctx.fill();
  ctx.stroke();
  ctx.strokeStyle = prop.accent;
  ctx.lineWidth = 0.06;
  ctx.beginPath();
  ctx.arc(-0.18, 0.02, 0.18, 0, TAU);
  ctx.arc(0.2, 0.02, 0.16, 0, TAU);
  ctx.moveTo(-0.42, -0.08);
  ctx.quadraticCurveTo(0, -0.34, 0.42, -0.08);
  ctx.stroke();
}

function drawStoneTool(prop) {
  ctx.fillStyle = prop.color;
  ctx.beginPath();
  ctx.moveTo(-0.48, 0.34);
  ctx.lineTo(0.12, -0.52);
  ctx.lineTo(0.54, 0.22);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();
  ctx.strokeStyle = prop.accent;
  ctx.beginPath();
  ctx.moveTo(0.1, -0.38);
  ctx.lineTo(-0.08, 0.2);
  ctx.stroke();
}

function drawHut(prop) {
  ctx.fillStyle = prop.accent;
  ctx.beginPath();
  ctx.moveTo(-0.62, 0.02);
  ctx.lineTo(0, -0.52);
  ctx.lineTo(0.62, 0.02);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = prop.color;
  ctx.fillRect(-0.42, 0.02, 0.84, 0.48);
  ctx.strokeRect(-0.42, 0.02, 0.84, 0.48);
}

function drawDing(prop) {
  ctx.fillStyle = prop.color;
  ctx.fillRect(-0.45, -0.18, 0.9, 0.48);
  ctx.strokeRect(-0.45, -0.18, 0.9, 0.48);
  ctx.beginPath();
  ctx.arc(-0.28, -0.2, 0.16, Math.PI, TAU);
  ctx.arc(0.28, -0.2, 0.16, Math.PI, TAU);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(-0.28, 0.3);
  ctx.lineTo(-0.42, 0.62);
  ctx.moveTo(0.28, 0.3);
  ctx.lineTo(0.42, 0.62);
  ctx.stroke();
  ctx.strokeStyle = prop.accent;
  ctx.lineWidth = 0.05;
  ctx.beginPath();
  ctx.moveTo(-0.32, 0.02);
  ctx.quadraticCurveTo(0, -0.16, 0.32, 0.02);
  ctx.stroke();
}

function drawOracleBone(prop) {
  ctx.fillStyle = "#eadbb8";
  ctx.beginPath();
  ctx.moveTo(-0.48, -0.28);
  ctx.quadraticCurveTo(0, -0.58, 0.46, -0.22);
  ctx.quadraticCurveTo(0.25, 0.5, -0.34, 0.48);
  ctx.quadraticCurveTo(-0.62, 0.04, -0.48, -0.28);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();
  ctx.strokeStyle = prop.color;
  ctx.lineWidth = 0.055;
  for (let i = 0; i < 4; i += 1) {
    const x = -0.22 + i * 0.14;
    ctx.beginPath();
    ctx.moveTo(x, -0.18);
    ctx.lineTo(x + 0.08, 0.18);
    ctx.stroke();
  }
}

function drawWall(prop) {
  ctx.fillStyle = prop.color;
  for (let i = 0; i < 4; i += 1) {
    ctx.fillRect(-0.58 + i * 0.3, -0.28, 0.18, 0.18);
  }
  ctx.fillRect(-0.64, -0.1, 1.28, 0.5);
  ctx.strokeRect(-0.64, -0.1, 1.28, 0.5);
}

function drawSeal(prop) {
  ctx.fillStyle = "#c8232f";
  ctx.fillRect(-0.48, -0.48, 0.96, 0.96);
  ctx.strokeRect(-0.48, -0.48, 0.96, 0.96);
  ctx.strokeStyle = "#f7efe1";
  ctx.lineWidth = 0.06;
  ctx.beginPath();
  ctx.moveTo(-0.22, -0.24);
  ctx.lineTo(-0.22, 0.24);
  ctx.lineTo(0.22, 0.24);
  ctx.moveTo(0.06, -0.24);
  ctx.lineTo(0.28, -0.24);
  ctx.lineTo(0.28, 0.08);
  ctx.stroke();
}

function drawBamboo(prop) {
  ctx.strokeStyle = prop.color;
  ctx.lineWidth = 0.1;
  for (let i = 0; i < 5; i += 1) {
    const x = -0.42 + i * 0.21;
    ctx.beginPath();
    ctx.moveTo(x, -0.5);
    ctx.lineTo(x, 0.5);
    ctx.stroke();
  }
  ctx.strokeStyle = "#05090c";
  ctx.lineWidth = 0.04;
  ctx.beginPath();
  ctx.moveTo(-0.55, -0.2);
  ctx.lineTo(0.55, -0.2);
  ctx.moveTo(-0.55, 0.18);
  ctx.lineTo(0.55, 0.18);
  ctx.stroke();
}

function drawWatchtower(prop) {
  ctx.fillStyle = prop.color;
  ctx.fillRect(-0.28, -0.18, 0.56, 0.7);
  ctx.strokeRect(-0.28, -0.18, 0.56, 0.7);
  drawEave(-0.5, -0.18, 1.0, prop.accent);
  drawEave(-0.42, -0.48, 0.84, prop.accent);
}

function drawPagoda(prop) {
  ctx.fillStyle = prop.color;
  ctx.fillRect(-0.18, -0.42, 0.36, 0.9);
  ctx.strokeRect(-0.18, -0.42, 0.36, 0.9);
  drawEave(-0.58, -0.3, 1.16, prop.accent);
  drawEave(-0.46, -0.02, 0.92, prop.accent);
  drawEave(-0.34, 0.24, 0.68, prop.accent);
}

function drawEave(x, y, w, color) {
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(x, y);
  ctx.lineTo(x + w * 0.5, y - 0.16);
  ctx.lineTo(x + w, y);
  ctx.lineTo(x + w - 0.1, y + 0.12);
  ctx.lineTo(x + 0.1, y + 0.12);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();
}

function drawBridge(prop) {
  ctx.strokeStyle = prop.color;
  ctx.lineWidth = 0.12;
  ctx.beginPath();
  ctx.arc(0, 0.34, 0.54, Math.PI, TAU);
  ctx.stroke();
  ctx.strokeStyle = "#05090c";
  ctx.lineWidth = 0.05;
  ctx.beginPath();
  ctx.moveTo(-0.62, 0.34);
  ctx.lineTo(0.62, 0.34);
  ctx.stroke();
}

function drawLantern(prop) {
  ctx.fillStyle = "#c8232f";
  ctx.beginPath();
  ctx.ellipse(0, 0, 0.38, 0.52, 0, 0, TAU);
  ctx.fill();
  ctx.stroke();
  ctx.strokeStyle = prop.accent;
  ctx.lineWidth = 0.05;
  ctx.beginPath();
  ctx.moveTo(0, -0.5);
  ctx.lineTo(0, 0.5);
  ctx.moveTo(-0.28, 0);
  ctx.lineTo(0.28, 0);
  ctx.stroke();
}

function drawGate(prop) {
  drawEave(-0.68, -0.5, 1.36, prop.accent);
  ctx.fillStyle = prop.color;
  ctx.fillRect(-0.5, -0.32, 0.18, 0.84);
  ctx.fillRect(0.32, -0.32, 0.18, 0.84);
  ctx.fillRect(-0.5, -0.25, 1, 0.18);
  ctx.strokeRect(-0.5, -0.32, 0.18, 0.84);
  ctx.strokeRect(0.32, -0.32, 0.18, 0.84);
}

function drawPorcelain(prop) {
  ctx.fillStyle = "#f8f2df";
  ctx.beginPath();
  ctx.ellipse(0, 0.06, 0.42, 0.56, 0, 0, TAU);
  ctx.fill();
  ctx.stroke();
  ctx.strokeStyle = "#104b75";
  ctx.lineWidth = 0.055;
  ctx.beginPath();
  ctx.arc(0, 0.0, 0.22, 0, TAU);
  ctx.moveTo(-0.3, -0.14);
  ctx.quadraticCurveTo(0, -0.35, 0.3, -0.14);
  ctx.stroke();
}

function drawRoof(prop) {
  drawEave(-0.72, -0.24, 1.44, prop.color);
  drawEave(-0.5, 0.08, 1.0, prop.accent);
}

function drawRail(prop) {
  ctx.strokeStyle = prop.color;
  ctx.lineWidth = 0.06;
  ctx.beginPath();
  ctx.moveTo(-0.5, -0.58);
  ctx.lineTo(-0.18, 0.58);
  ctx.moveTo(0.5, -0.58);
  ctx.lineTo(0.18, 0.58);
  ctx.stroke();
  for (let i = 0; i < 5; i += 1) {
    const y = -0.42 + i * 0.22;
    ctx.beginPath();
    ctx.moveTo(-0.42 + i * 0.03, y);
    ctx.lineTo(0.42 - i * 0.03, y);
    ctx.stroke();
  }
}

function drawFactory(prop) {
  ctx.fillStyle = prop.color;
  ctx.fillRect(-0.56, -0.02, 1.12, 0.5);
  ctx.strokeRect(-0.56, -0.02, 1.12, 0.5);
  ctx.fillRect(-0.42, -0.48, 0.16, 0.46);
  ctx.fillRect(0.2, -0.58, 0.16, 0.56);
  ctx.strokeRect(-0.42, -0.48, 0.16, 0.46);
  ctx.strokeRect(0.2, -0.58, 0.16, 0.56);
  ctx.fillStyle = prop.accent;
  ctx.beginPath();
  ctx.arc(-0.34, -0.58, 0.12, Math.PI, TAU);
  ctx.arc(0.28, -0.7, 0.12, Math.PI, TAU);
  ctx.fill();
}

function drawSkyline(prop) {
  ctx.fillStyle = prop.color;
  const heights = [0.72, 0.48, 0.86, 0.58, 0.68];
  for (let i = 0; i < heights.length; i += 1) {
    const x = -0.56 + i * 0.27;
    ctx.fillRect(x, 0.46 - heights[i], 0.18, heights[i]);
    ctx.strokeRect(x, 0.46 - heights[i], 0.18, heights[i]);
  }
  ctx.strokeStyle = prop.accent;
  ctx.lineWidth = 0.04;
  ctx.beginPath();
  ctx.moveTo(-0.72, 0.46);
  ctx.lineTo(0.72, 0.46);
  ctx.stroke();
}

function drawRocks() {
  const sheet = assets.obstacles;
  const eraSheet = assets.historyCutouts;
  for (const rock of state.obstacles) {
    const pos = worldToScreen(rock.x, rock.y);
    if (!isOnScreen(pos, rock.r * scale + 80)) continue;
    const radius = rock.r * scale;

    if (rock.kind === "era") {
      ctx.save();
      ctx.translate(pos.x, pos.y);
      ctx.rotate(rock.rotation);

      const rockSheet = assets[rock.imageKey] || eraSheet;
      const sheetColumns = rock.sheetColumns || historySheet.columns;
      const sheetRows = rock.sheetRows || historySheet.rows;
      if (assetReady(rockSheet)) {
        const cellW = rockSheet.naturalWidth / sheetColumns;
        const cellH = rockSheet.naturalHeight / sheetRows;
        const spriteIndex = rock.spriteIndex ?? rock.assetIndex ?? 0;
        const col = spriteIndex % sheetColumns;
        const row = Math.floor(spriteIndex / sheetColumns);
        const size = radius * 4.25;
        ctx.shadowColor = "rgba(0, 0, 0, 0.36)";
        ctx.shadowBlur = 12;
        ctx.shadowOffsetX = 7;
        ctx.shadowOffsetY = 8;
        ctx.drawImage(rockSheet, col * cellW, row * cellH, cellW, cellH, -size * 0.5, -size * 0.5, size, size);
      } else {
        ctx.fillStyle = "rgba(255, 207, 110, 0.72)";
        ctx.strokeStyle = "rgba(255, 252, 234, 0.9)";
        ctx.lineWidth = 4;
        ctx.beginPath();
        ctx.arc(0, 0, radius * 1.25, 0, TAU);
        ctx.fill();
        ctx.stroke();
      }

      ctx.restore();
      continue;
    }

    if (assetReady(sheet)) {
      const cellW = sheet.naturalWidth / 3;
      const cellH = sheet.naturalHeight / 3;
      const spriteIndex = rock.spriteIndex ?? 0;
      const col = spriteIndex % 3;
      const row = Math.floor(spriteIndex / 3);
      const size = radius * 3.55;
      ctx.save();
      ctx.translate(pos.x, pos.y);
      ctx.rotate(rock.rotation);
      ctx.shadowColor = "rgba(0, 0, 0, 0.36)";
      ctx.shadowBlur = 12;
      ctx.shadowOffsetX = 7;
      ctx.shadowOffsetY = 8;
      ctx.drawImage(sheet, col * cellW, row * cellH, cellW, cellH, -size * 0.5, -size * 0.5, size, size);
      ctx.restore();
      continue;
    }

    ctx.save();
    ctx.translate(pos.x, pos.y);
    ctx.rotate(rock.rotation);

    ctx.fillStyle = "rgba(0, 0, 0, 0.32)";
    ctx.beginPath();
    drawLocalPolygon(rock.points, radius * 1.08, 5, 7);
    ctx.fill();

    for (const piece of rock.pieces) {
      ctx.save();
      ctx.translate(piece.x * radius, piece.y * radius);
      ctx.rotate(piece.rotation);
      ctx.fillStyle = piece.color;
      ctx.strokeStyle = "rgba(8, 12, 16, 0.72)";
      ctx.lineWidth = 2;
      ctx.beginPath();
      drawLocalPolygon(piece.points, radius * 1.45, 0, 0);
      ctx.fill();
      ctx.stroke();
      ctx.restore();
    }

    ctx.strokeStyle = "#06131b";
    ctx.lineWidth = 3;
    ctx.beginPath();
    drawLocalPolygon(rock.points, radius, 0, 0);
    ctx.stroke();

    ctx.fillStyle = "rgba(255, 255, 255, 0.42)";
    for (const dot of rock.dots) {
      ctx.beginPath();
      ctx.arc(dot.x * radius, dot.y * radius, dot.s * radius, 0, TAU);
      ctx.fill();
    }

    ctx.restore();
  }
}

function drawLocalPolygon(points, radius, offsetX, offsetY) {
  for (let i = 0; i < points.length; i += 1) {
    const x = points[i].x * radius + offsetX;
    const y = points[i].y * radius + offsetY;
    if (i === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  }
  ctx.closePath();
}

function drawPickups() {
  for (const pickup of state.pickups) {
    const pos = worldToScreen(pickup.x, pickup.y);
    if (!isOnScreen(pos, 60)) continue;
    const pulse = 1 + Math.sin(performance.now() * 0.006) * 0.08;
    ctx.save();
    ctx.translate(pos.x, pos.y);
    ctx.scale(pulse, pulse);
    ctx.strokeStyle = "#78f7d1";
    ctx.fillStyle = "rgba(120, 247, 209, 0.16)";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(0, 0, pickup.r * scale, 0, TAU);
    ctx.fill();
    ctx.stroke();

    const shieldImage = assets[pickup.imageKey] || assets.shield;
    if (assetReady(shieldImage)) {
      const size = pickup.r * scale * 5.2;
      ctx.shadowColor = "rgba(120, 247, 209, 0.42)";
      ctx.shadowBlur = 14;
      const sheetColumns = pickup.sheetColumns || 1;
      const sheetRows = pickup.sheetRows || 1;
      if (sheetColumns > 1 || sheetRows > 1) {
        const cellW = shieldImage.naturalWidth / sheetColumns;
        const cellH = shieldImage.naturalHeight / sheetRows;
        const spriteIndex = pickup.spriteIndex || 0;
        const col = spriteIndex % sheetColumns;
        const row = Math.floor(spriteIndex / sheetColumns);
        ctx.drawImage(shieldImage, col * cellW, row * cellH, cellW, cellH, -size * 0.5, -size * 0.5, size, size);
      } else {
        ctx.drawImage(shieldImage, -size * 0.5, -size * 0.5, size, size);
      }
      ctx.restore();
      continue;
    }

    ctx.fillStyle = "#eafffb";
    ctx.beginPath();
    ctx.moveTo(0, -pickup.r * scale * 0.68);
    ctx.lineTo(pickup.r * scale * 0.55, 0);
    ctx.lineTo(0, pickup.r * scale * 0.68);
    ctx.lineTo(-pickup.r * scale * 0.55, 0);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }
}

function drawAnchor() {
  if (!state.anchor) return;
  const a = state.anchor;
  const p = state.player;
  const anchorPos = worldToScreen(a.x, a.y);
  const boatPos = worldToScreen(p.x, p.y);

  ctx.strokeStyle = a.timeLeft < 0.28 ? "#ffcf6e" : "rgba(229, 255, 252, 0.88)";
  ctx.lineWidth = 2.5;
  ctx.beginPath();
  ctx.moveTo(anchorPos.x, anchorPos.y);
  ctx.lineTo(boatPos.x, boatPos.y);
  ctx.stroke();

  const anchorImage = assets[a.imageKey] || assets.anchorPin;
  if (assetReady(anchorImage)) {
    const ropeAngle = Math.atan2(boatPos.y - anchorPos.y, boatPos.x - anchorPos.x);
    const size = scale * (1.64 + a.charge * 0.38);
    drawImageCentered(anchorImage, anchorPos.x, anchorPos.y, size, size, ropeAngle + Math.PI * 0.5);
  } else {
    ctx.fillStyle = a.color || "#ffcf6e";
    ctx.strokeStyle = "#07151c";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(anchorPos.x, anchorPos.y, 7 + a.charge * 4, 0, TAU);
    ctx.fill();
    ctx.stroke();
  }

  const ratio = clamp(a.timeLeft / a.maxTime, 0, 1);
  ctx.strokeStyle = "rgba(255, 255, 255, 0.55)";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.arc(anchorPos.x, anchorPos.y, 14, -Math.PI / 2, -Math.PI / 2 + TAU * ratio);
  ctx.stroke();
}

function drawBoat() {
  if (!state.player) return;
  const p = state.player;
  const pos = worldToScreen(p.x, p.y);
  const facingOffset = state.boatMirrored
    ? -boatSprite.facingAngleOffset
    : boatSprite.facingAngleOffset;

  ctx.save();
  ctx.translate(pos.x, pos.y);
  ctx.rotate(worldDirectionToScreenAngle(p.dirX, p.dirY) + facingOffset);
  if (state.boatMirrored) ctx.scale(-1, 1);

  if (assetReady(assets.boat)) {
    const drawW = scale * boatSprite.widthMeters;
    const drawH = drawW / (assets.boat.naturalWidth / assets.boat.naturalHeight);
    ctx.fillStyle = "rgba(0, 0, 0, 0.24)";
    ctx.beginPath();
    ctx.ellipse(0, drawH * 0.18, drawW * 0.28, drawH * 0.22, 0, 0, TAU);
    ctx.fill();
    if (state.shield) {
      ctx.strokeStyle = "rgba(120, 247, 209, 0.82)";
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.ellipse(0, 0, drawW * 0.44, drawH * 0.5, 0, 0, TAU);
      ctx.stroke();
    }
    ctx.shadowColor = "rgba(0, 0, 0, 0.28)";
    ctx.shadowBlur = 10;
    ctx.shadowOffsetX = 5;
    ctx.shadowOffsetY = 7;
    ctx.drawImage(assets.boat, -drawW * 0.5, -drawH * 0.5, drawW, drawH);
    ctx.restore();
    return;
  }

  ctx.fillStyle = "rgba(0, 0, 0, 0.24)";
  ctx.beginPath();
  ctx.ellipse(0, 8, 16, 24, 0, 0, TAU);
  ctx.fill();

  ctx.fillStyle = state.shield ? "#8fffe0" : "#f5f6eb";
  ctx.strokeStyle = state.shield ? "#78f7d1" : "#22313a";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(0, -24);
  ctx.lineTo(14, 16);
  ctx.quadraticCurveTo(0, 26, -14, 16);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  ctx.fillStyle = "#da5050";
  ctx.beginPath();
  ctx.moveTo(0, -20);
  ctx.lineTo(7, 10);
  ctx.lineTo(-7, 10);
  ctx.closePath();
  ctx.fill();

  ctx.fillStyle = "rgba(13, 44, 57, 0.92)";
  ctx.fillRect(-5, 3, 10, 11);
  ctx.restore();
}

function drawParticles() {
  for (const particle of state.particles) {
    const pos = worldToScreen(particle.x, particle.y);
    if (!isOnScreen(pos, 80)) continue;
    const alpha = clamp(particle.life / particle.startLife, 0, 1);
    ctx.globalAlpha = alpha;
    ctx.fillStyle = particle.color;
    ctx.beginPath();
    ctx.arc(pos.x, pos.y, particle.r * scale, 0, TAU);
    ctx.fill();
    ctx.globalAlpha = 1;
  }
}

function worldToScreen(x, y) {
  const projected = projectWorldDelta(x - state.cameraX, y - state.cameraY);
  return {
    x: width * 0.5 + projected.x,
    y: height * projection.originY + projected.y,
  };
}

function projectWorldDelta(x, y) {
  return {
    x: (x + y * projection.skewX) * scale,
    y: -y * scale * projection.yScale,
  };
}

function worldDirectionToScreenAngle(x, y) {
  const projected = projectWorldDelta(x, y);
  return Math.atan2(projected.x, -projected.y);
}

function isOnScreen(pos, padding) {
  return (
    pos.x > -padding &&
    pos.x < width + padding &&
    pos.y > -padding &&
    pos.y < height + padding
  );
}

function loop(time) {
  if (!state.lastTime) state.lastTime = time;
  const dt = Math.min((time - state.lastTime) / 1000, 0.033);
  state.lastTime = time;
  update(dt);
  draw();
  requestAnimationFrame(loop);
}

function rand(min, max) {
  return min + Math.random() * (max - min);
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function lerp(from, to, amount) {
  return from + (to - from) * clamp(amount, 0, 1);
}

function mod(value, size) {
  return ((value % size) + size) % size;
}

window.addEventListener("resize", resize);

window.addEventListener("keydown", (event) => {
  const key = event.code;
  if (["KeyA", "KeyD", "Space", "Enter", "KeyR"].includes(key)) {
    event.preventDefault();
  }
  if (keys.has(key)) return;
  keys.add(key);

  if (state.mode === "start" && (key === "Space" || key === "Enter")) {
    resetGame();
    return;
  }

  if (state.mode === "gameover" && (key === "Space" || key === "Enter" || key === "KeyR")) {
    resetGame();
    return;
  }

  if (key === "KeyA") dropKeyboardAnchor(-1);
  if (key === "KeyD") dropKeyboardAnchor(1);
  if (key === "Space") releaseAnchor();
});

window.addEventListener("keyup", (event) => {
  keys.delete(event.code);
});

startButton?.addEventListener("click", resetGame);
restartButton.addEventListener("click", resetGame);

resize();
updateModeUi();
resetGame();
showStartScreen();
requestAnimationFrame(loop);
