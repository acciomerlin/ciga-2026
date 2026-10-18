import * as THREE from "https://unpkg.com/three@0.160.0/build/three.module.js";

const canvas = document.querySelector("#stage");
const distanceEl = document.querySelector("#distance");
const speedEl = document.querySelector("#speed");
const sceneStateEl = document.querySelector("#sceneState");
const anchorStateEl = document.querySelector("#anchorState");
const messageEl = document.querySelector("#message");
const wakeFillEl = document.querySelector("#wakeFill");
const overlayEl = document.querySelector("#overlay");
const resultEl = document.querySelector("#result");

const TAU = Math.PI * 2;
const SIDE = 86;
const HALF = SIDE / 2;
const CORRIDOR_WIDTH = 16;
const CORNER_RADIUS = 14;
const PATH_STRAIGHT = SIDE - CORNER_RADIUS * 2;
const PATH_ARC = Math.PI * 0.5 * CORNER_RADIUS;
const PERIMETER = 4 * (PATH_STRAIGHT + PATH_ARC);
const INNER_HALF = HALF - CORRIDOR_WIDTH / 2;
const OUTER_HALF = HALF + CORRIDOR_WIDTH / 2;
const DREAM_COLORS = {
  red: new THREE.Color("#ff4d66"),
  blue: new THREE.Color("#55d9ff"),
  green: new THREE.Color("#91ffb6"),
};
const COLOR_ORDER = ["red", "blue", "green"];
const ZONE_SPAN = 178;
const REALITY_START = 60;
const REALITY_LENGTH = 50;
const LOOK_AHEAD = 58;
const REALITY_TOUCH_AHEAD = 5;
const REALITY_INTRUSION_AHEAD = LOOK_AHEAD + 32;
const RELEASE_STABILIZE_TIME = 3.2;

const tuning = {
  initialFlow: 7.2,
  speedGainPerMeter: 0.018,
  speedGainPerSecond: 0.18,
  maxFlow: 36,
  chainLength: 9.2,
  throwTime: 0.34,
  sinkTime: 0.46,
  reelTime: 0.35,
  realityWakeRate: 0.48,
  wakeRecoverRate: 0.22,
};

const LAB_CUTOUTS = [
  { name: "computer-row-strip", src: "../../web/assets/computer-lab-cutouts/computer-row-strip.png", width: 677, height: 248, scale: 5.8 },
  { name: "front-blue-crt-station", src: "../../web/assets/computer-lab-cutouts/front-blue-crt-station.png", width: 323, height: 518, scale: 2.2 },
  { name: "center-crt-station", src: "../../web/assets/computer-lab-cutouts/center-crt-station.png", width: 254, height: 337, scale: 2.0 },
  { name: "foreground-right-crt", src: "../../web/assets/computer-lab-cutouts/foreground-right-crt.png", width: 427, height: 385, scale: 2.5 },
  { name: "foreground-right-dark-screen", src: "../../web/assets/computer-lab-cutouts/foreground-right-dark-screen.png", width: 333, height: 257, scale: 2.4 },
  { name: "front-blue-crt-monitor", src: "../../web/assets/computer-lab-cutouts/front-blue-crt-monitor.png", width: 258, height: 194, scale: 2.2 },
  { name: "left-row-monitor", src: "../../web/assets/computer-lab-cutouts/left-row-monitor.png", width: 264, height: 197, scale: 2.2 },
  { name: "middle-left-monitor", src: "../../web/assets/computer-lab-cutouts/middle-left-monitor.png", width: 224, height: 180, scale: 2.0 },
  { name: "front-gray-chair", src: "../../web/assets/computer-lab-cutouts/front-gray-chair.png", width: 199, height: 290, scale: 1.45 },
  { name: "green-window-curtain", src: "../../web/assets/computer-lab-cutouts/green-window-curtain.png", width: 179, height: 266, scale: 1.8 },
  { name: "white-window-glow", src: "../../web/assets/computer-lab-cutouts/white-window-glow.png", width: 170, height: 245, scale: 1.8 },
  { name: "projector-screen", src: "../../web/assets/computer-lab-cutouts/projector-screen.png", width: 188, height: 175, scale: 2.0 },
  { name: "back-room-door-panels", src: "../../web/assets/computer-lab-cutouts/back-room-door-panels.png", width: 239, height: 200, scale: 2.2 },
  { name: "space-poster", src: "../../web/assets/computer-lab-cutouts/space-poster.png", width: 88, height: 152, scale: 1.25 },
  { name: "wall-notice-pair", src: "../../web/assets/computer-lab-cutouts/wall-notice-pair.png", width: 175, height: 115, scale: 1.55 },
  { name: "wall-speaker", src: "../../web/assets/computer-lab-cutouts/wall-speaker.png", width: 53, height: 70, scale: 0.72 },
  { name: "left-headphones", src: "../../web/assets/computer-lab-cutouts/left-headphones.png", width: 100, height: 203, scale: 1.05 },
  { name: "center-hanging-headphones", src: "../../web/assets/computer-lab-cutouts/center-hanging-headphones.png", width: 109, height: 163, scale: 1.05 },
  { name: "orange-control-panel", src: "../../web/assets/computer-lab-cutouts/orange-control-panel.png", width: 185, height: 119, scale: 1.55 },
];

const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.shadowMap.enabled = true;

const scene = new THREE.Scene();
scene.background = new THREE.Color("#101923");
scene.fog = new THREE.Fog("#101923", 16, 92);

const camera = new THREE.PerspectiveCamera(64, 1, 0.1, 180);
camera.rotation.order = "YXZ";

const clock = new THREE.Clock();
const tempVector = new THREE.Vector3();
const tempVectorB = new THREE.Vector3();
const resolvedZones = new Set();

const world = new THREE.Group();
scene.add(world);

const boatGroup = new THREE.Group();
scene.add(boatGroup);
boatGroup.add(camera);
camera.position.set(0, 1.45, 2.7);

const chainGroup = new THREE.Group();
scene.add(chainGroup);

const materials = {};
const anchorItems = [];
const decorBands = [];
const chainLinks = [];
const cutoutTextureCache = new Map();
const textureLoader = new THREE.TextureLoader();

const state = {
  mode: "playing",
  distance: 0,
  runSeconds: 0,
  flowSpeed: tuning.initialFlow,
  actualSpeed: tuning.initialFlow,
  wakePressure: 0,
  selectedAnchorIndex: 0,
  time: 0,
  anchor: null,
  flash: 0,
};

setupMaterials();
buildLighting();
buildCorridor();
buildBoat();
buildChain();
buildDecorBands();
buildWallCollageSetPieces();
resetRun();
resize();
requestAnimationFrame(loop);

function setupMaterials() {
  materials.water = new THREE.MeshStandardMaterial({
    color: "#2f98b9",
    roughness: 0.38,
    metalness: 0.02,
    transparent: true,
    opacity: 0.72,
  });
  materials.bank = new THREE.MeshStandardMaterial({
    color: "#334148",
    roughness: 0.78,
    metalness: 0.02,
  });
  materials.wall = new THREE.MeshStandardMaterial({
    color: "#d9c3ff",
    map: makeWitchSchoolWallTexture(),
    roughness: 0.86,
    metalness: 0.0,
    emissive: "#1d0730",
    emissiveIntensity: 0.18,
  });
  materials.ceiling = new THREE.MeshStandardMaterial({
    color: "#7f5c94",
    map: makePuppetValanceTexture(),
    roughness: 0.72,
    metalness: 0.0,
    emissive: "#2b0b3d",
    emissiveIntensity: 0.16,
  });
  materials.boat = new THREE.MeshStandardMaterial({
    color: "#f6b23a",
    roughness: 0.48,
    metalness: 0.02,
  });
  materials.deck = new THREE.MeshStandardMaterial({
    color: "#2d2b2f",
    roughness: 0.8,
    metalness: 0.02,
  });
  materials.chain = new THREE.MeshStandardMaterial({
    color: "#c7d0d8",
    roughness: 0.28,
    metalness: 0.85,
  });
  materials.selected = new THREE.MeshStandardMaterial({
    color: "#fff3b0",
    roughness: 0.2,
    metalness: 0.45,
    emissive: "#ffcf6e",
    emissiveIntensity: 0.35,
  });
  materials.anchor = new THREE.MeshStandardMaterial({
    color: "#15191e",
    roughness: 0.35,
    metalness: 0.6,
  });
  for (const color of COLOR_ORDER) {
    materials[color] = new THREE.MeshStandardMaterial({
      color: DREAM_COLORS[color],
      roughness: 0.28,
      metalness: 0.08,
      emissive: DREAM_COLORS[color],
      emissiveIntensity: 0.16,
    });
  }
}

function buildLighting() {
  const ambient = new THREE.HemisphereLight("#cdd8ff", "#17202b", 1.2);
  scene.add(ambient);

  const key = new THREE.DirectionalLight("#ffffff", 2.2);
  key.position.set(-10, 16, 8);
  key.castShadow = true;
  key.shadow.mapSize.set(2048, 2048);
  scene.add(key);

  const deckLight = new THREE.PointLight("#8edcff", 2.1, 18);
  deckLight.position.set(0, 3.2, 0);
  boatGroup.add(deckLight);
}

function buildCorridor() {
  addBox(world, [SIDE + CORRIDOR_WIDTH, 0.08, CORRIDOR_WIDTH], [0, 0, -HALF], materials.water);
  addBox(world, [CORRIDOR_WIDTH, 0.08, SIDE + CORRIDOR_WIDTH], [HALF, 0, 0], materials.water);
  addBox(world, [SIDE + CORRIDOR_WIDTH, 0.08, CORRIDOR_WIDTH], [0, 0, HALF], materials.water);
  addBox(world, [CORRIDOR_WIDTH, 0.08, SIDE + CORRIDOR_WIDTH], [-HALF, 0, 0], materials.water);

  addBox(world, [INNER_HALF * 2, 0.42, INNER_HALF * 2], [0, -0.26, 0], materials.bank);
  addBox(world, [124, 0.42, 13], [0, -0.25, -OUTER_HALF - 6.4], materials.bank);
  addBox(world, [124, 0.42, 13], [0, -0.25, OUTER_HALF + 6.4], materials.bank);
  addBox(world, [13, 0.42, 124], [-OUTER_HALF - 6.4, -0.25, 0], materials.bank);
  addBox(world, [13, 0.42, 124], [OUTER_HALF + 6.4, -0.25, 0], materials.bank);

  addBox(world, [OUTER_HALF * 2, 4.0, 0.9], [0, 2.0, -OUTER_HALF], materials.wall);
  addBox(world, [OUTER_HALF * 2, 4.0, 0.9], [0, 2.0, OUTER_HALF], materials.wall);
  addBox(world, [0.9, 4.0, OUTER_HALF * 2], [-OUTER_HALF, 2.0, 0], materials.wall);
  addBox(world, [0.9, 4.0, OUTER_HALF * 2], [OUTER_HALF, 2.0, 0], materials.wall);

  addBox(world, [INNER_HALF * 2, 3.4, 0.9], [0, 1.7, -INNER_HALF], materials.wall);
  addBox(world, [INNER_HALF * 2, 3.4, 0.9], [0, 1.7, INNER_HALF], materials.wall);
  addBox(world, [0.9, 3.4, INNER_HALF * 2], [-INNER_HALF, 1.7, 0], materials.wall);
  addBox(world, [0.9, 3.4, INNER_HALF * 2], [INNER_HALF, 1.7, 0], materials.wall);

  for (let d = 0; d < PERIMETER; d += 8) {
    const p = pathAt(d);
    const beam = addBox(world, [CORRIDOR_WIDTH + 1.2, 0.32, 0.7], [p.position.x, 5.0, p.position.z], materials.ceiling);
    beam.rotation.y = yawForTangent(p.tangent);

    for (const side of [-1, 1]) {
      const normal = rightNormal(p.tangent).multiplyScalar(side * (CORRIDOR_WIDTH * 0.5 - 0.35));
      const pillar = addBox(world, [0.42, 4.5, 0.42], [p.position.x + normal.x, 2.15, p.position.z + normal.z], materials.ceiling);
      pillar.rotation.y = yawForTangent(p.tangent);
    }
  }
}

function buildBoat() {
  const hull = addBox(boatGroup, [2.35, 0.42, 3.5], [0, 0.35, 0.42], materials.boat);
  hull.castShadow = true;

  const deck = addBox(boatGroup, [2.0, 0.12, 2.3], [0, 0.68, -0.12], materials.deck);
  deck.castShadow = true;

  const bow = addBox(boatGroup, [1.35, 0.3, 0.65], [0, 0.82, -1.8], materials.boat);
  bow.castShadow = true;

  const colors = [
    { name: "red", x: -0.78, label: "RED" },
    { name: "blue", x: 0, label: "BLUE" },
    { name: "green", x: 0.78, label: "GREEN" },
  ];

  for (const item of colors) {
    const group = new THREE.Group();
    group.name = `${item.name}-anchor-object`;
    group.userData.anchorColor = item.name;
    group.position.set(item.x, 0.98, -0.54);

    const base = new THREE.Mesh(new THREE.CylinderGeometry(0.25, 0.31, 0.32, 18), materials[item.name]);
    base.castShadow = true;
    base.userData.anchorColor = item.name;
    group.add(base);

    const cap = new THREE.Mesh(new THREE.SphereGeometry(0.22, 18, 12), materials[item.name]);
    cap.position.y = 0.27;
    cap.castShadow = true;
    cap.userData.anchorColor = item.name;
    group.add(cap);

    const ring = new THREE.Mesh(new THREE.TorusGeometry(0.22, 0.025, 8, 18), materials.chain);
    ring.position.y = 0.52;
    ring.rotation.x = Math.PI * 0.5;
    ring.userData.anchorColor = item.name;
    group.add(ring);

    boatGroup.add(group);
    anchorItems.push({ color: item.name, group, ring });
  }
  updateAnchorSelectionVisual();
}

function buildChain() {
  const anchorCore = new THREE.Mesh(new THREE.SphereGeometry(0.22, 16, 10), materials.anchor);
  const stem = new THREE.Mesh(new THREE.BoxGeometry(0.13, 0.72, 0.13), materials.anchor);
  stem.position.y = 0.28;
  const flukeA = new THREE.Mesh(new THREE.BoxGeometry(0.68, 0.12, 0.18), materials.anchor);
  flukeA.position.set(-0.32, -0.1, 0);
  flukeA.rotation.z = -0.42;
  const flukeB = new THREE.Mesh(new THREE.BoxGeometry(0.68, 0.12, 0.18), materials.anchor);
  flukeB.position.set(0.32, -0.1, 0);
  flukeB.rotation.z = 0.42;
  chainGroup.add(anchorCore, stem, flukeA, flukeB);
  chainGroup.visible = false;
  chainGroup.userData.anchorParts = [anchorCore, stem, flukeA, flukeB];

  for (let i = 0; i < 28; i += 1) {
    const link = new THREE.Mesh(new THREE.TorusGeometry(0.18, 0.035, 8, 16), materials.chain);
    link.visible = false;
    chainGroup.add(link);
    chainLinks.push(link);
  }
}

function buildDecorBands() {
  for (let i = 0; i < 22; i += 1) {
    const group = new THREE.Group();
    const panelMaterial = new THREE.MeshStandardMaterial({
      color: "#ffffff",
      map: makeStagePaperTexture(i),
      roughness: 0.45,
      metalness: 0.02,
      transparent: true,
      opacity: 0.68,
      emissive: "#000000",
      emissiveIntensity: 0.0,
      depthWrite: false,
    });
    const signMaterial = new THREE.MeshBasicMaterial({
      map: makeSignTexture("DREAM", "#ff4d66"),
      transparent: true,
    });

    const left = new THREE.Mesh(new THREE.BoxGeometry(0.22, 2.8, 4.0), panelMaterial);
    const right = left.clone();
    left.position.set(-CORRIDOR_WIDTH * 0.5 + 0.52, 2.25, 0);
    right.position.set(CORRIDOR_WIDTH * 0.5 - 0.52, 2.25, 0);

    const top = new THREE.Mesh(new THREE.BoxGeometry(CORRIDOR_WIDTH - 1, 0.25, 3.8), panelMaterial);
    top.position.set(0, 4.56, 0);

    const sign = new THREE.Mesh(new THREE.PlaneGeometry(4.2, 0.9), signMaterial);
    sign.position.set(0, 3.85, -0.08);
    sign.rotation.x = 0;

    const leftAsset = LAB_CUTOUTS[(i * 3 + 1) % LAB_CUTOUTS.length];
    const rightAsset = LAB_CUTOUTS[(i * 5 + 4) % LAB_CUTOUTS.length];
    const leftCutout = makeCutoutStageGroup(leftAsset, leftAsset.scale * (1.12 + pseudo01(i, 5) * 0.58), {
      strings: true,
      stringHeight: 1.0 + pseudo01(i, 6) * 0.7,
      tint: i % 3 === 0 ? "#ffd3f6" : "#d6ffef",
    });
    leftCutout.position.set(-CORRIDOR_WIDTH * 0.5 + 0.92, 2.36 + pseudoSigned(i, 7) * 0.34, -0.78 + pseudoSigned(i, 8) * 1.1);
    leftCutout.rotation.y = Math.PI * 0.5;

    const rightCutout = makeCutoutStageGroup(rightAsset, rightAsset.scale * (1.12 + pseudo01(i, 9) * 0.6), {
      strings: true,
      stringHeight: 0.9 + pseudo01(i, 10) * 0.8,
      tint: i % 3 === 1 ? "#c9dcff" : "#fff1a8",
    });
    rightCutout.position.set(CORRIDOR_WIDTH * 0.5 - 0.92, 2.28 + pseudoSigned(i, 11) * 0.34, 0.78 + pseudoSigned(i, 12) * 1.14);
    rightCutout.rotation.y = -Math.PI * 0.5;

    const stageCurtain = makeCutoutStageGroup(LAB_CUTOUTS[(i * 7 + 2) % LAB_CUTOUTS.length], 1.1 + pseudo01(i, 13) * 0.8, {
      opacity: 0.82,
      tint: "#f2d3ff",
    });
    stageCurtain.position.set(-2.4 + pseudoSigned(i, 14) * 3.2, 4.23, 0.02);
    stageCurtain.rotation.z = pseudoSigned(i, 15) * 0.08;

    group.add(left, right, top, sign, leftCutout, rightCutout, stageCurtain);
    world.add(group);
    decorBands.push({ group, panelMaterial, signMaterial, sign });
  }
}

function buildWallCollageSetPieces() {
  const roomSpacing = 9.4;
  let roomIndex = 0;
  for (let d = 5.4; d < PERIMETER; d += roomSpacing) {
    for (const side of [-1, 1]) {
      const p = pathAt(d + pseudoSigned(roomIndex, 21) * 0.65);
      const room = makeSideRoom(roomIndex, side);
      room.position.set(p.position.x, 0, p.position.z);
      room.rotation.y = yawForTangent(p.tangent);
      world.add(room);
      roomIndex += 1;
    }
  }
}

function makeSideRoom(index, side) {
  const room = new THREE.Group();
  room.name = `side-room-${index}-${side < 0 ? "left" : "right"}`;

  const width = 5.0 + pseudo01(index, 31) * 1.55;
  const depth = 1.35 + pseudo01(index, 32) * 0.46;
  const height = 3.05 + pseudo01(index, 33) * 0.48;
  const backX = side * (CORRIDOR_WIDTH * 0.5 - 0.18);
  const bayX = side * (CORRIDOR_WIDTH * 0.5 - depth * 0.5 - 0.38);
  const midY = 0.72 + height * 0.5;
  const wallpaper = makeRoomWallpaperMaterial(index);
  const frame = makeRoomFrameMaterial(index);
  const shadow = makeRoomShadowMaterial(index);

  addLocalBox(room, [0.14, height, width], [backX, midY, 0], wallpaper);
  addLocalBox(room, [depth, height + 0.26, 0.16], [bayX, midY, -width * 0.5], frame);
  addLocalBox(room, [depth, height + 0.26, 0.16], [bayX, midY, width * 0.5], frame);
  addLocalBox(room, [depth + 0.12, 0.18, width + 0.28], [bayX, 0.56, 0], frame);
  addLocalBox(room, [depth + 0.12, 0.22, width + 0.28], [bayX, 0.88 + height, 0], frame);

  const innerGlow = new THREE.PointLight(index % 3 === 0 ? "#ff75d6" : index % 3 === 1 ? "#80ffe9" : "#ffe86d", 0.75, 5.2);
  innerGlow.position.set(side * (CORRIDOR_WIDTH * 0.5 - 0.72), 2.5, pseudoSigned(index, 34) * width * 0.16);
  room.add(innerGlow);

  const doorway = makeRoomPosterPlane(2.2 + pseudo01(index, 35) * 1.0, 1.62 + pseudo01(index, 36) * 0.45, side, makeRoomShadowTexture(index));
  doorway.position.set(side * (CORRIDOR_WIDTH * 0.5 - 0.29), 2.02, pseudoSigned(index, 37) * width * 0.11);
  room.add(doorway);

  const primary = LAB_CUTOUTS[(index * 5 + 1) % LAB_CUTOUTS.length];
  const primaryWidth = Math.min(width * 0.72, primary.scale * (1.35 + pseudo01(index, 38) * 0.48));
  const primaryCutout = makeRoomCutout(primary, primaryWidth, side, {
    opacity: 0.96,
    tint: index % 3 === 0 ? "#ffe6fb" : index % 3 === 1 ? "#d6fbff" : "#fff8bf",
  });
  primaryCutout.position.set(side * (CORRIDOR_WIDTH * 0.5 - 0.36), 1.95 + pseudoSigned(index, 39) * 0.18, pseudoSigned(index, 40) * width * 0.1);
  room.add(primaryCutout);

  const rowAsset = LAB_CUTOUTS[0];
  const rowCutout = makeRoomCutout(rowAsset, Math.min(width * 0.86, rowAsset.scale * 0.92), side, {
    opacity: 0.78,
    tint: "#cdeeff",
  });
  rowCutout.position.set(side * (CORRIDOR_WIDTH * 0.5 - 0.34), 1.08, 0);
  room.add(rowCutout);

  const poster = LAB_CUTOUTS[(index * 7 + 13) % LAB_CUTOUTS.length];
  const posterCutout = makeRoomCutout(poster, Math.min(width * 0.26, poster.scale * 0.8), side, {
    strings: true,
    stringHeight: 0.56,
    opacity: 0.94,
    tint: "#fff0c9",
  });
  posterCutout.position.set(side * (CORRIDOR_WIDTH * 0.5 - 0.28), 2.8, -width * 0.32);
  posterCutout.rotation.z += pseudoSigned(index, 41) * 0.1;
  room.add(posterCutout);

  const small = LAB_CUTOUTS[(index * 11 + 16) % LAB_CUTOUTS.length];
  const smallCutout = makeRoomCutout(small, Math.min(width * 0.22, small.scale * 0.7), side, {
    strings: true,
    stringHeight: 0.72,
    opacity: 0.9,
    tint: "#e8ffd8",
  });
  smallCutout.position.set(side * (CORRIDOR_WIDTH * 0.5 - 0.3), 2.9, width * 0.34);
  smallCutout.rotation.z += pseudoSigned(index, 42) * 0.08;
  room.add(smallCutout);

  const roomLabel = makeRoomPosterPlane(1.25, 0.38, side, makeRoomLabelTexture(index));
  roomLabel.position.set(side * (CORRIDOR_WIDTH * 0.5 - 0.24), 3.92, 0);
  room.add(roomLabel);

  addLocalBox(room, [depth * 0.74, height * 0.78, 0.05], [bayX, midY - 0.06, -width * 0.18], shadow);
  return room;
}

function makeRoomCutout(asset, width, side, options = {}) {
  const cutout = makeCutoutStageGroup(asset, width, options);
  cutout.rotation.y = -side * Math.PI * 0.5;
  cutout.renderOrder = 9;
  return cutout;
}

function resetRun() {
  resolvedZones.clear();
  state.mode = "playing";
  state.distance = 0;
  state.runSeconds = 0;
  state.flowSpeed = tuning.initialFlow;
  state.actualSpeed = tuning.initialFlow;
  state.wakePressure = 0;
  state.selectedAnchorIndex = 0;
  state.anchor = null;
  state.flash = 0;
  chainGroup.visible = false;
  updateAnchorSelectionVisual();
  overlayEl.classList.add("is-hidden");
  setMessage("A/D 选择船上物件，Space 抛锚；有锚时 Space 随时收锚。");
  updateHud();
}

function loop() {
  const dt = Math.min(clock.getDelta(), 0.033);
  state.time += dt;
  update(dt);
  render();
  requestAnimationFrame(loop);
}

function update(dt) {
  if (state.mode !== "playing") {
    return;
  }

  state.runSeconds += dt;
  state.flowSpeed = Math.min(
    tuning.maxFlow,
    tuning.initialFlow +
      state.distance * tuning.speedGainPerMeter +
      state.runSeconds * tuning.speedGainPerSecond,
  );
  state.actualSpeed = state.flowSpeed;

  updateAnchor(dt);
  updateBoatMotion(dt);
  updateRealityPressure(dt);
  updateBoatTransform();
  updateDecorBands();
  updateSceneMood(dt);
  updateHud();
}

function updateBoatMotion(dt) {
  if (state.anchor?.phase === "stopped") {
    state.actualSpeed = 0;
    return;
  }

  const prevDistance = state.distance;
  const desiredDistance = state.distance + state.flowSpeed * dt;
  let nextDistance = desiredDistance;

  if (state.anchor?.phase === "hooked") {
    const hook = state.anchor.hookPosition;
    const desiredPos = pathAt(desiredDistance).position;
    if (horizontalDistance(hook, desiredPos) >= state.anchor.chainLength) {
      nextDistance = solveTensionDistance(prevDistance, desiredDistance, hook, state.anchor.chainLength);
      state.anchor.phase = "stopped";
      state.anchor.stabilize = 0;
      state.actualSpeed = 0;
      if (state.anchor.targetColor && state.anchor.color !== state.anchor.targetColor) {
        state.anchor.wrongColorWarned = true;
        setMessage(`${colorName(state.anchor.color)}锚钉不住${colorName(state.anchor.targetColor)}现实。按 Space 收回重抛。`);
      } else {
        setMessage("锁链张紧，船被水流拽停。等前方现实恢复成梦境后再收锚。");
      }
    }
  }

  state.distance = nextDistance;
}

function updateAnchor(dt) {
  if (!state.anchor) {
    chainGroup.visible = false;
    return;
  }

  const anchor = state.anchor;
  anchor.timer += dt;

  if (anchor.phase === "throwing") {
    const t = clamp(anchor.timer / tuning.throwTime, 0, 1);
    anchor.visualPosition.lerpVectors(anchor.startPosition, anchor.waterPosition, easeOutCubic(t));
    anchor.visualPosition.y += Math.sin(t * Math.PI) * 0.85;
    if (t >= 1) {
      anchor.phase = "sinking";
      anchor.timer = 0;
    }
  } else if (anchor.phase === "sinking") {
    const t = clamp(anchor.timer / tuning.sinkTime, 0, 1);
    anchor.visualPosition.lerpVectors(anchor.waterPosition, anchor.hookPosition, easeInOut(t));
    if (t >= 1) {
      anchor.phase = "hooked";
      anchor.timer = 0;
      setMessage("锚沉底钩住了。船还会继续被水流推，直到锁链拉满。");
    }
  } else if (anchor.phase === "stopped") {
    anchor.stabilize += dt;
    if (anchor.targetColor && anchor.color !== anchor.targetColor) {
      if (!anchor.wrongColorWarned) {
        anchor.wrongColorWarned = true;
        setMessage(`${colorName(anchor.color)}锚钉不住${colorName(anchor.targetColor)}现实。按 Space 收回重抛。`);
      }
      return;
    }
    if (!anchor.resolved && anchor.stabilize >= RELEASE_STABILIZE_TIME) {
      anchor.resolved = true;
      if (anchor.zoneIndex !== null) {
        resolvedZones.add(anchor.zoneIndex);
        setMessage("前方已经恢复成梦境。按 Space 收锚继续航行。");
      } else {
        setMessage("锚已经稳定。按 Space 收锚继续航行。");
      }
    }
  } else if (anchor.phase === "reeling") {
    const t = clamp(anchor.timer / tuning.reelTime, 0, 1);
    const itemPos = getSelectedItemWorldPosition(anchor.color);
    anchor.visualPosition.lerpVectors(anchor.reelStart, itemPos, easeInOut(t));
    if (t >= 1) {
      state.anchor = null;
      chainGroup.visible = false;
      updateAnchorSelectionVisual();
      setMessage("锚已收回，继续顺着水流航行。");
      return;
    }
  }

  updateChainVisual();
}

function updateRealityPressure(dt) {
  const currentScene = sceneAt(state.distance + REALITY_TOUCH_AHEAD);
  const incomingScene = nextRealityAhead(REALITY_INTRUSION_AHEAD);
  const threatScene =
    currentScene.kind === "reality" ? { ...currentScene, offset: REALITY_TOUCH_AHEAD } : incomingScene;
  const hasProtectiveAnchor =
    threatScene &&
    state.anchor &&
    state.anchor.zoneIndex === threatScene.zoneIndex &&
    state.anchor.color === threatScene.color &&
    ["hooked", "stopped", "reeling"].includes(state.anchor.phase);

  if (threatScene && !hasProtectiveAnchor) {
    const proximity =
      currentScene.kind === "reality"
        ? 1
        : clamp(1 - threatScene.offset / REALITY_INTRUSION_AHEAD, 0, 1);
    const intrusionPower = proximity * proximity;
    const wrongAnchorLeak =
      state.anchor &&
      state.anchor.zoneIndex === threatScene.zoneIndex &&
      state.anchor.color !== threatScene.color &&
      ["hooked", "stopped", "reeling"].includes(state.anchor.phase);
    const leakRate = tuning.realityWakeRate * (0.1 + intrusionPower * 0.85 + (wrongAnchorLeak ? 0.35 : 0));
    state.wakePressure = clamp(state.wakePressure + leakRate * dt, 0, 1.1);
    if (state.wakePressure >= 1) {
      gameOver("没有把梦钉住，现实把船追上了。");
    }
  } else {
    state.wakePressure = clamp(state.wakePressure - tuning.wakeRecoverRate * dt, 0, 1);
  }

  if (!state.anchor && incomingScene) {
    const meters = Math.max(0, Math.round(incomingScene.offset));
    setMessage(`现实正在从前方突入，约 ${meters}m 后贴脸。选择${colorName(incomingScene.color)}物件抛锚。`);
  }
}

function updateBoatTransform() {
  const p = pathAt(state.distance);
  const bob = Math.sin(state.time * (state.anchor?.phase === "stopped" ? 2.0 : 3.1)) * 0.07;
  const turnLean = p.curve * clamp(state.flowSpeed / tuning.maxFlow, 0, 1) * 0.11;
  boatGroup.position.set(p.position.x, 0.38 + bob, p.position.z);
  boatGroup.rotation.y = yawForTangent(p.tangent);
  boatGroup.rotation.z = -turnLean;
  camera.rotation.y = 0;
  camera.rotation.x = -0.04;
}

function updateChainVisual() {
  if (!state.anchor) return;
  chainGroup.visible = true;

  const itemPos = getSelectedItemWorldPosition(state.anchor.color);
  const anchorPos = state.anchor.visualPosition;
  chainGroup.userData.anchorParts.forEach((part) => {
    part.position.copy(anchorPos);
  });
  chainGroup.userData.anchorParts[1].position.y += 0.28;
  chainGroup.userData.anchorParts[2].position.x -= 0.32;
  chainGroup.userData.anchorParts[2].position.y -= 0.1;
  chainGroup.userData.anchorParts[3].position.x += 0.32;
  chainGroup.userData.anchorParts[3].position.y -= 0.1;

  const span = tempVector.subVectors(anchorPos, itemPos);
  const length = span.length();
  const direction = span.normalize();
  const count = Math.min(chainLinks.length, Math.max(3, Math.floor(length / 0.42)));

  for (let i = 0; i < chainLinks.length; i += 1) {
    const link = chainLinks[i];
    link.visible = i < count;
    if (!link.visible) continue;
    const t = (i + 1) / (count + 1);
    link.position.lerpVectors(itemPos, anchorPos, t);
    link.lookAt(tempVectorB.copy(link.position).add(direction));
    link.rotation.z += (i % 2) * Math.PI * 0.5;
  }
}

function updateDecorBands() {
  for (let i = 0; i < decorBands.length; i += 1) {
    const band = decorBands[i];
    const offset = 12 + i * 7.8;
    const p = pathAt(state.distance + offset);
    const info = sceneAt(state.distance + offset);
    band.group.position.set(p.position.x, 0, p.position.z);
    band.group.rotation.y = yawForTangent(p.tangent);

    if (band.group.userData.kind !== info.kind || band.group.userData.color !== info.color) {
      band.group.userData.kind = info.kind;
      band.group.userData.color = info.color;
      if (info.kind === "reality") {
        band.panelMaterial.color.set("#d8dde2");
        band.panelMaterial.emissive.set("#f5f8ff");
        band.panelMaterial.emissiveIntensity = 0.24;
        band.signMaterial.map = makeSignTexture("REALITY", "#e8edf3");
        band.signMaterial.needsUpdate = true;
      } else {
        band.panelMaterial.color.copy(DREAM_COLORS[info.color]);
        band.panelMaterial.emissive.copy(DREAM_COLORS[info.color]);
        band.panelMaterial.emissiveIntensity = 0.22;
        band.signMaterial.map = makeSignTexture(`${info.color.toUpperCase()} DREAM`, `#${DREAM_COLORS[info.color].getHexString()}`);
        band.signMaterial.needsUpdate = true;
      }
    }
  }
}

function updateSceneMood(dt) {
  const ahead = sceneAt(state.distance + LOOK_AHEAD);
  const target = ahead.kind === "reality" ? new THREE.Color("#d9dee5") : DREAM_COLORS[ahead.color];
  const bgTarget = target.clone().lerp(new THREE.Color("#07090f"), ahead.kind === "reality" ? 0.4 : 0.62);
  scene.background.lerp(bgTarget, dt * 1.4);
  scene.fog.color.lerp(bgTarget, dt * 1.4);
}

function chooseAnchorObject(color) {
  if (state.mode !== "playing" || state.anchor) return;
  const target = nextRealityAhead(86);
  const targetColor = target ? target.color : null;
  const targetZoneIndex = target ? target.zoneIndex : null;

  const start = getSelectedItemWorldPosition(color);
  const water = start.clone();
  water.y = 0.08;
  const hook = start.clone();
  hook.y = -0.58;

  state.anchor = {
    color,
    zoneIndex: targetZoneIndex,
    targetColor,
    phase: "throwing",
    timer: 0,
    stabilize: 0,
    resolved: false,
    wrongColorWarned: false,
    chainLength: tuning.chainLength,
    startPosition: start,
    waterPosition: water,
    hookPosition: hook,
    visualPosition: start.clone(),
    reelStart: start.clone(),
  };
  updateAnchorSelectionVisual();

  if (!target) {
    setMessage(`${colorName(color)}锚抛下去了。前方暂时没有现实，这只是一次停船。`);
  } else if (color !== target.color) {
    state.wakePressure = clamp(state.wakePressure + 0.15, 0, 1);
    setMessage(`${colorName(color)}锚抛下去了，但这个现实段需要${colorName(target.color)}锚，会钉不住。`);
  } else {
    setMessage(`${colorName(color)}锚抛下去了。锚先落水，再沉底钩住。`);
  }
}

function releaseAnchor() {
  if (!state.anchor) return;
  if (state.anchor.phase === "reeling") return;
  const wasResolved = state.anchor.resolved;
  state.anchor.phase = "reeling";
  state.anchor.timer = 0;
  state.anchor.reelStart = state.anchor.visualPosition.clone();
  if (wasResolved) {
    setMessage("锚开始收回。");
  } else if (state.anchor.targetColor) {
    setMessage("你提前收回了锚，前方现实没有被修复。");
  } else {
    setMessage("锚开始收回。");
  }
}

function throwSelectedAnchor() {
  chooseAnchorObject(getSelectedAnchorColor());
}

function moveAnchorSelection(direction) {
  if (state.mode !== "playing" || state.anchor || anchorItems.length === 0) return;
  state.selectedAnchorIndex = mod(state.selectedAnchorIndex + direction, anchorItems.length);
  updateAnchorSelectionVisual();
  setMessage(`已选择${colorName(getSelectedAnchorColor())}物件。Space 抛锚。`);
}

function getSelectedAnchorColor() {
  return anchorItems[state.selectedAnchorIndex]?.color || "red";
}

function updateAnchorSelectionVisual() {
  for (let i = 0; i < anchorItems.length; i += 1) {
    const item = anchorItems[i];
    const selected = i === state.selectedAnchorIndex && !state.anchor;
    item.ring.material = selected ? materials.selected : materials.chain;
    item.group.scale.setScalar(selected ? 1.12 : 1.0);
  }
}

function gameOver(reason) {
  state.mode = "gameover";
  state.anchor = null;
  chainGroup.visible = false;
  updateAnchorSelectionVisual();
  resultEl.textContent = `${reason} 本次 ${(state.distance / 1000).toFixed(2)} km。`;
  overlayEl.classList.remove("is-hidden");
  updateHud();
}

function updateHud() {
  const ahead = sceneAt(state.distance + LOOK_AHEAD);
  distanceEl.textContent = `${(state.distance / 1000).toFixed(2)} km`;
  speedEl.textContent = `${state.flowSpeed.toFixed(1)} m/s`;
  sceneStateEl.textContent = ahead.kind === "reality" ? `REALITY / ${colorName(ahead.color)}` : `${colorName(ahead.color)} DREAM`;

  if (state.mode === "gameover") {
    anchorStateEl.textContent = "WOKE";
  } else if (!state.anchor) {
    anchorStateEl.textContent = "READY";
  } else if (state.anchor.phase === "throwing") {
    anchorStateEl.textContent = "THROWING";
  } else if (state.anchor.phase === "sinking") {
    anchorStateEl.textContent = "SINKING";
  } else if (state.anchor.phase === "hooked") {
    anchorStateEl.textContent = "TENSION";
  } else if (state.anchor.phase === "stopped") {
    const wrongColorStopped = state.anchor.targetColor && state.anchor.color !== state.anchor.targetColor;
    if (wrongColorStopped) {
      anchorStateEl.textContent = "WRONG";
    } else {
      const holdLeft = Math.max(0, RELEASE_STABILIZE_TIME - state.anchor.stabilize);
      anchorStateEl.textContent = state.anchor.resolved ? "CAN REEL" : `HOLD ${holdLeft.toFixed(1)}s`;
    }
  } else {
    anchorStateEl.textContent = "REELING";
  }

  wakeFillEl.style.width = `${Math.round(clamp(state.wakePressure, 0, 1) * 100)}%`;
}

function render() {
  renderer.render(scene, camera);
}

function pathAt(distance) {
  let d = mod(distance, PERIMETER);
  const r = CORNER_RADIUS;
  const straight = PATH_STRAIGHT;
  const arc = PATH_ARC;

  if (d < straight) {
    return {
      position: new THREE.Vector3(-HALF + r + d, 0, -HALF),
      tangent: new THREE.Vector3(1, 0, 0),
      curve: 0,
    };
  }

  d -= straight;
  if (d < arc) {
    return arcPath(HALF - r, -HALF + r, -Math.PI * 0.5, d / arc);
  }

  d -= arc;
  if (d < straight) {
    return {
      position: new THREE.Vector3(HALF, 0, -HALF + r + d),
      tangent: new THREE.Vector3(0, 0, 1),
      curve: 0,
    };
  }

  d -= straight;
  if (d < arc) {
    return arcPath(HALF - r, HALF - r, 0, d / arc);
  }

  d -= arc;
  if (d < straight) {
    return {
      position: new THREE.Vector3(HALF - r - d, 0, HALF),
      tangent: new THREE.Vector3(-1, 0, 0),
      curve: 0,
    };
  }

  d -= straight;
  if (d < arc) {
    return arcPath(-HALF + r, HALF - r, Math.PI * 0.5, d / arc);
  }

  d -= arc;
  if (d < straight) {
    return {
      position: new THREE.Vector3(-HALF, 0, HALF - r - d),
      tangent: new THREE.Vector3(0, 0, -1),
      curve: 0,
    };
  }

  d -= straight;
  return arcPath(-HALF + r, -HALF + r, Math.PI, d / arc);
}

function arcPath(centerX, centerZ, startAngle, t) {
  const angle = startAngle + t * Math.PI * 0.5;
  const tangent = new THREE.Vector3(-Math.sin(angle), 0, Math.cos(angle)).normalize();
  return {
    position: new THREE.Vector3(
      centerX + Math.cos(angle) * CORNER_RADIUS,
      0,
      centerZ + Math.sin(angle) * CORNER_RADIUS,
    ),
    tangent,
    curve: 1,
  };
}

function sceneAt(distance) {
  const zoneIndex = Math.floor(distance / ZONE_SPAN);
  const local = distance - zoneIndex * ZONE_SPAN;
  const color = COLOR_ORDER[mod(zoneIndex, COLOR_ORDER.length)];
  const reality =
    local >= REALITY_START &&
    local <= REALITY_START + REALITY_LENGTH &&
    !resolvedZones.has(zoneIndex);
  return {
    kind: reality ? "reality" : "dream",
    color,
    zoneIndex,
    local,
  };
}

function nextRealityAhead(range) {
  for (let offset = 0; offset <= range; offset += 2) {
    const info = sceneAt(state.distance + offset);
    if (info.kind === "reality") {
      return { ...info, offset };
    }
  }
  return null;
}

function solveTensionDistance(a, b, hook, chainLength) {
  let lo = a;
  let hi = b;
  for (let i = 0; i < 16; i += 1) {
    const mid = (lo + hi) * 0.5;
    const pos = pathAt(mid).position;
    if (horizontalDistance(hook, pos) > chainLength) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return hi;
}

function getSelectedItemWorldPosition(color) {
  const target = anchorItems.find((item) => item.color === color);
  if (!target) return boatGroup.getWorldPosition(new THREE.Vector3());
  return target.group.getWorldPosition(new THREE.Vector3());
}

function yawForTangent(tangent) {
  return Math.atan2(-tangent.x, -tangent.z);
}

function rightNormal(tangent) {
  return new THREE.Vector3(-tangent.z, 0, tangent.x);
}

function horizontalDistance(a, b) {
  const dx = a.x - b.x;
  const dz = a.z - b.z;
  return Math.sqrt(dx * dx + dz * dz);
}

function addLocalBox(parent, size, position, material) {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(size[0], size[1], size[2]), material);
  mesh.position.set(position[0], position[1], position[2]);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  parent.add(mesh);
  return mesh;
}

function makeRoomWallpaperMaterial(index) {
  const colors = ["#f19adf", "#91f4ff", "#ffe86d", "#c9a0ff", "#a1ffc5"];
  return new THREE.MeshStandardMaterial({
    color: colors[index % colors.length],
    map: makeStagePaperTexture(index + 100),
    roughness: 0.88,
    metalness: 0.0,
    emissive: index % 2 === 0 ? "#34103f" : "#0a2d38",
    emissiveIntensity: 0.18,
  });
}

function makeRoomFrameMaterial(index) {
  const colors = ["#15091d", "#23103b", "#10283a", "#3b1434"];
  return new THREE.MeshStandardMaterial({
    color: colors[index % colors.length],
    roughness: 0.78,
    metalness: 0.02,
    emissive: index % 3 === 0 ? "#5b124f" : "#0d4351",
    emissiveIntensity: 0.12,
  });
}

function makeRoomShadowMaterial(index) {
  return new THREE.MeshStandardMaterial({
    color: index % 2 === 0 ? "#10051b" : "#071522",
    roughness: 0.95,
    metalness: 0.0,
    transparent: true,
    opacity: 0.38,
    depthWrite: false,
  });
}

function makeRoomPosterPlane(width, height, side, texture) {
  const mesh = new THREE.Mesh(
    new THREE.PlaneGeometry(width, height),
    new THREE.MeshBasicMaterial({
      map: texture,
      transparent: true,
      alphaTest: 0.02,
      side: THREE.DoubleSide,
      depthWrite: false,
    }),
  );
  mesh.rotation.y = -side * Math.PI * 0.5;
  mesh.renderOrder = 8;
  return mesh;
}

function makeRoomShadowTexture(index) {
  if (!makeRoomShadowTexture.cache) makeRoomShadowTexture.cache = new Map();
  if (makeRoomShadowTexture.cache.has(index)) return makeRoomShadowTexture.cache.get(index);

  const c = document.createElement("canvas");
  c.width = 256;
  c.height = 384;
  const ctx = c.getContext("2d");
  ctx.clearRect(0, 0, c.width, c.height);
  ctx.fillStyle = "rgba(8, 4, 18, 0.72)";
  roundRect(ctx, 24, 34, 208, 302, 20);
  ctx.fill();
  ctx.strokeStyle = index % 2 === 0 ? "#ff8adf" : "#80ffe9";
  ctx.globalAlpha = 0.72;
  ctx.lineWidth = 7;
  roundRect(ctx, 24, 34, 208, 302, 20);
  ctx.stroke();
  ctx.globalAlpha = 0.24;
  ctx.fillStyle = "#fff7c7";
  for (let y = 62; y < 318; y += 28) {
    ctx.fillRect(48 + Math.sin(y + index) * 8, y, 160, 4);
  }

  const texture = new THREE.CanvasTexture(c);
  texture.colorSpace = THREE.SRGBColorSpace;
  makeRoomShadowTexture.cache.set(index, texture);
  return texture;
}

function makeRoomLabelTexture(index) {
  if (!makeRoomLabelTexture.cache) makeRoomLabelTexture.cache = new Map();
  if (makeRoomLabelTexture.cache.has(index)) return makeRoomLabelTexture.cache.get(index);

  const c = document.createElement("canvas");
  c.width = 384;
  c.height = 128;
  const ctx = c.getContext("2d");
  ctx.clearRect(0, 0, c.width, c.height);
  ctx.fillStyle = "rgba(9, 5, 18, 0.9)";
  roundRect(ctx, 12, 18, 360, 92, 12);
  ctx.fill();
  ctx.strokeStyle = index % 2 === 0 ? "#ff8adf" : "#7fffe8";
  ctx.lineWidth = 5;
  roundRect(ctx, 12, 18, 360, 92, 12);
  ctx.stroke();
  ctx.fillStyle = "#fff4cb";
  ctx.font = "800 34px ui-sans-serif, system-ui, sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(`ROOM ${String((index * 7) % 1000).padStart(3, "0")}`, c.width / 2, c.height / 2 + 4);

  const texture = new THREE.CanvasTexture(c);
  texture.colorSpace = THREE.SRGBColorSpace;
  makeRoomLabelTexture.cache.set(index, texture);
  return texture;
}

function makeCutoutStageGroup(asset, width, options = {}) {
  const height = width * (asset.height / asset.width);
  const group = new THREE.Group();
  group.name = `stage-cutout-${asset.name}`;

  const plane = new THREE.Mesh(
    new THREE.PlaneGeometry(width, height),
    makeCutoutMaterial(asset, options),
  );
  plane.position.z = 0.025;
  plane.renderOrder = 6;
  group.add(plane);

  if (options.strings) {
    addPuppetStrings(group, width, height, options.stringHeight || 1.1);
  }

  return group;
}

function makeCutoutMaterial(asset, options = {}) {
  return new THREE.MeshBasicMaterial({
    map: getCutoutTexture(asset),
    transparent: true,
    alphaTest: 0.04,
    opacity: options.opacity ?? 0.94,
    color: options.tint || "#ffffff",
    side: THREE.DoubleSide,
    depthWrite: false,
  });
}

function getCutoutTexture(asset) {
  if (cutoutTextureCache.has(asset.name)) return cutoutTextureCache.get(asset.name);

  const texture = textureLoader.load(asset.src, (loaded) => {
    loaded.colorSpace = THREE.SRGBColorSpace;
    loaded.minFilter = THREE.LinearFilter;
    loaded.magFilter = THREE.NearestFilter;
    loaded.anisotropy = Math.min(4, renderer.capabilities.getMaxAnisotropy());
    loaded.needsUpdate = true;
  });
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.NearestFilter;
  texture.anisotropy = Math.min(4, renderer.capabilities.getMaxAnisotropy());
  cutoutTextureCache.set(asset.name, texture);
  return texture;
}

function addPuppetStrings(group, width, height, extraHeight) {
  const material = new THREE.LineBasicMaterial({
    color: "#1a0824",
    transparent: true,
    opacity: 0.58,
    depthWrite: false,
  });
  const yTop = height * 0.5 + extraHeight;
  const yBottom = height * 0.5 - 0.02;
  for (const x of [-width * 0.28, width * 0.26]) {
    const geometry = new THREE.BufferGeometry().setFromPoints([
      new THREE.Vector3(x + width * 0.04, yTop, 0.035),
      new THREE.Vector3(x, yBottom, 0.035),
    ]);
    const line = new THREE.Line(geometry, material);
    line.renderOrder = 7;
    group.add(line);
  }
}

function makeWitchSchoolWallTexture() {
  const c = document.createElement("canvas");
  c.width = 1024;
  c.height = 1024;
  const ctx = c.getContext("2d");
  const gradient = ctx.createLinearGradient(0, 0, c.width, c.height);
  gradient.addColorStop(0, "#25113b");
  gradient.addColorStop(0.36, "#4d2869");
  gradient.addColorStop(0.7, "#243e54");
  gradient.addColorStop(1, "#0d101c");
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, c.width, c.height);

  ctx.globalAlpha = 0.5;
  for (let x = -80; x < c.width + 80; x += 64) {
    ctx.fillStyle = x % 128 === 0 ? "#ff7bd8" : "#55ffe0";
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x + 42, 0);
    ctx.lineTo(x - 30, c.height);
    ctx.lineTo(x - 88, c.height);
    ctx.closePath();
    ctx.fill();
  }

  ctx.globalAlpha = 0.18;
  ctx.strokeStyle = "#f8e9ff";
  ctx.lineWidth = 2;
  for (let x = 0; x <= c.width; x += 52) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x + Math.sin(x * 0.1) * 16, c.height);
    ctx.stroke();
  }
  for (let y = 0; y <= c.height; y += 44) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(c.width, y + Math.cos(y * 0.08) * 12);
    ctx.stroke();
  }

  ctx.globalAlpha = 0.72;
  for (let i = 0; i < 34; i += 1) {
    const x = pseudo01(i, 41) * c.width;
    const y = pseudo01(i, 42) * c.height;
    const r = 12 + pseudo01(i, 43) * 28;
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(pseudoSigned(i, 44) * 0.8);
    ctx.fillStyle = i % 3 === 0 ? "#ffe96b" : i % 3 === 1 ? "#ff8adf" : "#7fffe8";
    drawPaperStar(ctx, 0, 0, r, 5 + (i % 3));
    ctx.restore();
  }

  ctx.globalAlpha = 0.46;
  ctx.strokeStyle = "#100817";
  ctx.lineWidth = 9;
  for (let i = 0; i < 10; i += 1) {
    const x = pseudo01(i, 51) * c.width;
    const y = 90 + pseudo01(i, 52) * (c.height - 180);
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(pseudoSigned(i, 53) * 0.24);
    roundRect(ctx, -70, -46, 140, 92, 8);
    ctx.stroke();
    ctx.restore();
  }

  ctx.globalAlpha = 0.28;
  ctx.fillStyle = "#fff7d1";
  for (let y = 0; y < c.height; y += 96) {
    ctx.fillRect(0, y + 38, c.width, 9);
  }

  const texture = new THREE.CanvasTexture(c);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.repeat.set(2.25, 1.1);
  return texture;
}

function makePuppetValanceTexture() {
  const c = document.createElement("canvas");
  c.width = 512;
  c.height = 256;
  const ctx = c.getContext("2d");
  ctx.fillStyle = "#1a0b24";
  ctx.fillRect(0, 0, c.width, c.height);
  for (let x = -40; x < c.width + 40; x += 74) {
    ctx.fillStyle = x % 148 === 0 ? "#8e2a70" : "#214967";
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.quadraticCurveTo(x + 36, 70, x + 72, 0);
    ctx.lineTo(x + 72, c.height);
    ctx.quadraticCurveTo(x + 34, c.height - 48, x, c.height);
    ctx.closePath();
    ctx.fill();
  }
  ctx.strokeStyle = "rgba(255, 239, 150, 0.58)";
  ctx.lineWidth = 4;
  for (let x = 16; x < c.width; x += 48) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x + Math.sin(x) * 8, c.height);
    ctx.stroke();
  }
  const texture = new THREE.CanvasTexture(c);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.repeat.set(1.4, 1);
  return texture;
}

function makeStagePaperTexture(index) {
  if (!makeStagePaperTexture.cache) makeStagePaperTexture.cache = new Map();
  if (makeStagePaperTexture.cache.has(index)) return makeStagePaperTexture.cache.get(index);

  const c = document.createElement("canvas");
  c.width = 384;
  c.height = 384;
  const ctx = c.getContext("2d");
  const colors = ["#ff8adf", "#60ffe5", "#fff07a", "#c9a6ff", "#7ba8ff"];
  ctx.fillStyle = "#180c20";
  ctx.fillRect(0, 0, c.width, c.height);
  ctx.globalAlpha = 0.82;
  for (let i = 0; i < 18; i += 1) {
    ctx.fillStyle = colors[(i + index) % colors.length];
    ctx.save();
    ctx.translate(pseudo01(index * 19 + i, 61) * c.width, pseudo01(index * 19 + i, 62) * c.height);
    ctx.rotate(pseudoSigned(index * 19 + i, 63) * 0.7);
    const w = 38 + pseudo01(index * 19 + i, 64) * 110;
    const h = 22 + pseudo01(index * 19 + i, 65) * 72;
    ctx.fillRect(-w * 0.5, -h * 0.5, w, h);
    ctx.restore();
  }
  ctx.globalAlpha = 0.26;
  ctx.strokeStyle = "#ffffff";
  ctx.lineWidth = 2;
  for (let x = 0; x < c.width; x += 32) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, c.height);
    ctx.stroke();
  }
  for (let y = 0; y < c.height; y += 32) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(c.width, y);
    ctx.stroke();
  }
  const texture = new THREE.CanvasTexture(c);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.repeat.set(1.2, 1.2);
  makeStagePaperTexture.cache.set(index, texture);
  return texture;
}

function drawPaperStar(ctx, x, y, radius, points) {
  ctx.beginPath();
  for (let i = 0; i < points * 2; i += 1) {
    const angle = -Math.PI * 0.5 + (i / (points * 2)) * TAU;
    const r = i % 2 === 0 ? radius : radius * 0.38;
    const px = x + Math.cos(angle) * r;
    const py = y + Math.sin(angle) * r;
    if (i === 0) ctx.moveTo(px, py);
    else ctx.lineTo(px, py);
  }
  ctx.closePath();
  ctx.fill();
}

function pseudo01(index, salt = 0) {
  const n = Math.sin(index * 127.1 + salt * 311.7) * 43758.5453123;
  return n - Math.floor(n);
}

function pseudoSigned(index, salt = 0) {
  return pseudo01(index, salt) * 2 - 1;
}

function addBox(parent, size, position, material) {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(size[0], size[1], size[2]), material);
  mesh.position.set(position[0], position[1], position[2]);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  parent.add(mesh);
  return mesh;
}

function makeSignTexture(text, color) {
  const key = `${text}-${color}`;
  if (!makeSignTexture.cache) {
    makeSignTexture.cache = new Map();
  }
  if (makeSignTexture.cache.has(key)) return makeSignTexture.cache.get(key);

  const c = document.createElement("canvas");
  c.width = 512;
  c.height = 128;
  const ctx = c.getContext("2d");
  ctx.clearRect(0, 0, c.width, c.height);
  ctx.fillStyle = "rgba(5, 8, 12, 0.78)";
  roundRect(ctx, 10, 10, 492, 108, 20);
  ctx.fill();
  ctx.strokeStyle = color;
  ctx.lineWidth = 5;
  roundRect(ctx, 10, 10, 492, 108, 20);
  ctx.stroke();
  ctx.fillStyle = color;
  ctx.font = "800 42px ui-sans-serif, system-ui, sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(text, c.width / 2, c.height / 2 + 3);

  const texture = new THREE.CanvasTexture(c);
  texture.colorSpace = THREE.SRGBColorSpace;
  makeSignTexture.cache.set(key, texture);
  return texture;
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

function colorName(color) {
  if (color === "red") return "红色";
  if (color === "blue") return "蓝色";
  return "绿色";
}

function setMessage(text) {
  messageEl.textContent = text;
}

function mod(value, divisor) {
  return ((value % divisor) + divisor) % divisor;
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function easeOutCubic(t) {
  return 1 - Math.pow(1 - t, 3);
}

function easeInOut(t) {
  return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) * 0.5;
}

function resize() {
  const width = Math.max(320, window.innerWidth);
  const height = Math.max(520, window.innerHeight);
  renderer.setSize(width, height, false);
  camera.aspect = width / height;
  camera.updateProjectionMatrix();
}

window.addEventListener("resize", resize);

window.addEventListener("keydown", (event) => {
  if (event.code === "KeyA") {
    event.preventDefault();
    moveAnchorSelection(-1);
    return;
  }

  if (event.code === "KeyD") {
    event.preventDefault();
    moveAnchorSelection(1);
    return;
  }

  if (event.code === "Space") {
    event.preventDefault();
    if (state.mode === "gameover") {
      resetRun();
    } else if (state.anchor) {
      releaseAnchor();
    } else {
      throwSelectedAnchor();
    }
  }
});

window.anchorPrototype = {
  choose: chooseAnchorObject,
  release: releaseAnchor,
  state() {
    return {
      distance: state.distance,
      runSeconds: state.runSeconds,
      flowSpeed: state.flowSpeed,
      anchorPhase: state.anchor?.phase || "ready",
      anchorResolved: Boolean(state.anchor?.resolved),
      selectedAnchorColor: getSelectedAnchorColor(),
      anchorColor: state.anchor?.color || null,
      targetColor: state.anchor?.targetColor || null,
      wakePressure: state.wakePressure,
      current: sceneAt(state.distance + REALITY_TOUCH_AHEAD),
      ahead: sceneAt(state.distance + LOOK_AHEAD),
      intrusion: nextRealityAhead(REALITY_INTRUSION_AHEAD),
      realityTouchAhead: REALITY_TOUCH_AHEAD,
      message: messageEl.textContent,
    };
  },
};
