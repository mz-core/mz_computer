// Inverse projective mapping: viewport quadrilateral -> monitor UV coordinates.
// Also exported for the Node regression tests; no browser globals are required.
((scope) => {
  function projectiveMap(points) {
    if (!Array.isArray(points) || points.length !== 4) return null;
    const uv = [[0, 0], [1, 0], [1, 1], [0, 1]];
    const matrix = [];
    points.forEach(({ x, y }, i) => {
      const [u, v] = uv[i];
      matrix.push([x, y, 1, 0, 0, 0, -u*x, -u*y, u]);
      matrix.push([0, 0, 0, x, y, 1, -v*x, -v*y, v]);
    });
    if (matrix.some(row => row.some(n => !Number.isFinite(n)))) return null;
    for (let col = 0; col < 8; col++) {
      let pivot = col;
      for (let row = col + 1; row < 8; row++) {
        if (Math.abs(matrix[row][col]) > Math.abs(matrix[pivot][col])) pivot = row;
      }
      if (Math.abs(matrix[pivot][col]) < 1e-10) return null;
      [matrix[col], matrix[pivot]] = [matrix[pivot], matrix[col]];
      const divisor = matrix[col][col];
      matrix[col] = matrix[col].map(n => n / divisor);
      for (let row = 0; row < 8; row++) {
        if (row === col) continue;
        const factor = matrix[row][col];
        matrix[row] = matrix[row].map((n, i) => n - factor * matrix[col][i]);
      }
    }
    const h = matrix.map(row => row[8]);
    return (x, y) => {
      const w = h[6]*x + h[7]*y + 1;
      if (Math.abs(w) < 1e-10) return null;
      const u = (h[0]*x + h[1]*y + h[2]) / w;
      const v = (h[3]*x + h[4]*y + h[5]) / w;
      return Number.isFinite(u) && Number.isFinite(v) ? { x: u, y: v } : null;
    };
  }
  scope.MZScreenMath = { projectiveMap };
  if (typeof module !== 'undefined') module.exports = scope.MZScreenMath;
})(globalThis);
