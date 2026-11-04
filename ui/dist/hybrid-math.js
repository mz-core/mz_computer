(function (root, factory) {
  const api = factory();
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.MZHybridMath = api;
})(typeof window !== 'undefined' ? window : globalThis, function () {
  'use strict';

  const finitePoint = p => p && Number.isFinite(Number(p.x)) && Number.isFinite(Number(p.y));

  function solveLinear(matrix, vector) {
    const n = vector.length;
    const a = matrix.map((row, i) => row.map(Number).concat(Number(vector[i])));
    for (let col = 0; col < n; col++) {
      let pivot = col;
      for (let row = col + 1; row < n; row++) {
        if (Math.abs(a[row][col]) > Math.abs(a[pivot][col])) pivot = row;
      }
      if (Math.abs(a[pivot][col]) < 1e-10) return null;
      [a[col], a[pivot]] = [a[pivot], a[col]];
      const div = a[col][col];
      for (let j = col; j <= n; j++) a[col][j] /= div;
      for (let row = 0; row < n; row++) {
        if (row === col) continue;
        const factor = a[row][col];
        if (!factor) continue;
        for (let j = col; j <= n; j++) a[row][j] -= factor * a[col][j];
      }
    }
    return a.map(row => row[n]);
  }

  // points are TL, TR, BR, BL in normalized screen coordinates.
  function homography(points, sourceWidth, sourceHeight, viewportWidth, viewportHeight) {
    if (!Array.isArray(points) || points.length !== 4 || !points.every(finitePoint)) return null;
    const w = Number(sourceWidth), h = Number(sourceHeight), vw = Number(viewportWidth), vh = Number(viewportHeight);
    if (!(w > 0 && h > 0 && vw > 0 && vh > 0)) return null;
    const src = [[0, 0], [w, 0], [w, h], [0, h]];
    const dst = points.map(p => [Number(p.x) * vw, Number(p.y) * vh]);
    const A = [], b = [];
    for (let i = 0; i < 4; i++) {
      const [x, y] = src[i], [X, Y] = dst[i];
      A.push([x, 0, y, 0, 1, 0, -X * x, -X * y]); b.push(X);
      A.push([0, x, 0, y, 0, 1, -Y * x, -Y * y]); b.push(Y);
    }
    const s = solveLinear(A, b);
    if (!s || !s.every(Number.isFinite)) return null;
    const [a, b1, c, d, e, f, g, h1] = s;
    return { a, b: b1, c, d, e, f, g, h: h1 };
  }

  function mapPoint(H, x, y) {
    if (!H) return null;
    const q = H.g * x + H.h * y + 1;
    if (Math.abs(q) < 1e-10) return null;
    return { x: (H.a * x + H.c * y + H.e) / q, y: (H.b * x + H.d * y + H.f) / q };
  }

  function cssMatrix(points, sourceWidth, sourceHeight, viewportWidth, viewportHeight) {
    const H = homography(points, sourceWidth, sourceHeight, viewportWidth, viewportHeight);
    if (!H) return null;
    const m = [
      H.a, H.b, 0, H.g,
      H.c, H.d, 0, H.h,
      0, 0, 1, 0,
      H.e, H.f, 0, 1,
    ];
    return { homography: H, values: m, css: `matrix3d(${m.map(v => Number(v.toFixed(12))).join(',')})` };
  }

  function quadArea(points, viewportWidth = 1, viewportHeight = 1) {
    if (!Array.isArray(points) || points.length !== 4 || !points.every(finitePoint)) return 0;
    let area = 0;
    for (let i = 0; i < 4; i++) {
      const a = points[i], b = points[(i + 1) % 4];
      area += (Number(a.x) * viewportWidth) * (Number(b.y) * viewportHeight)
        - (Number(b.x) * viewportWidth) * (Number(a.y) * viewportHeight);
    }
    return Math.abs(area) * 0.5;
  }

  return { homography, mapPoint, cssMatrix, quadArea };
});
