import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Coefficients produced by [TpsWarper.solve].
/// Call [eval] to map any UV point → screen-space [Offset].
class TpsSolution {
  const TpsSolution({
    required this.srcPoints,
    required this.weightsX,
    required this.affineX,
    required this.weightsY,
    required this.affineY,
  });

  /// Source UV control points [0,1]×[0,1] used during the solve.
  final List<Offset> srcPoints;

  final List<double> weightsX; // n TPS weights for the x mapping
  final List<double> affineX;  // [a0, a1, a2] affine terms for x
  final List<double> weightsY;
  final List<double> affineY;

  /// Evaluate the TPS at UV coordinates (u, v) → screen-space position.
  Offset eval(double u, double v) {
    double x = affineX[0] + affineX[1] * u + affineX[2] * v;
    double y = affineY[0] + affineY[1] * u + affineY[2] * v;
    for (int i = 0; i < srcPoints.length; i++) {
      final double du = u - srcPoints[i].dx;
      final double dv = v - srcPoints[i].dy;
      final double r2 = du * du + dv * dv;
      if (r2 < 1e-10) continue;
      final double phi = r2 * math.log(r2);
      x += weightsX[i] * phi;
      y += weightsY[i] * phi;
    }
    return Offset(x, y);
  }
}

/// Thin-Plate Spline warper.
///
/// Usage:
///   final solution = TpsWarper.solve(uvPoints, screenPoints);
///   if (solution != null) {
///     final vertices = TpsWarper.buildMesh(solution, image);
///     canvas.drawVertices(vertices, BlendMode.srcOver, paint..shader = shader);
///   }
class TpsWarper {
  TpsWarper._();

  // ── Solve ─────────────────────────────────────────────────────────────────

  /// Solve TPS from [src] UV points to [dst] screen points.
  /// Both lists must have the same length (≥ 3).
  /// Returns null if the configuration is degenerate (collinear points, etc.).
  static TpsSolution? solve(List<Offset> src, List<Offset> dst) {
    assert(src.length == dst.length && src.length >= 3);
    final int n = src.length;
    final int m = n + 3; // system size: n weights + 3 affine terms

    // Build augmented matrix [L | bx | by] where L is the (m×m) TPS matrix.
    // We solve both x and y in one Gaussian elimination pass.
    final List<List<double>> aug = List.generate(m, (i) {
      final List<double> row = List<double>.filled(m + 2, 0.0);

      if (i < n) {
        // K block row i: φ(||src[i] - src[j]||²) for j=0..n-1
        for (int j = 0; j < n; j++) {
          if (i != j) {
            final double du = src[i].dx - src[j].dx;
            final double dv = src[i].dy - src[j].dy;
            final double r2 = du * du + dv * dv;
            row[j] = r2 * math.log(r2);
          }
        }
        // P block: [1, u, v]
        row[n]     = 1.0;
        row[n + 1] = src[i].dx;
        row[n + 2] = src[i].dy;
        // RHS
        row[m]     = dst[i].dx;
        row[m + 1] = dst[i].dy;
      } else {
        // Pᵀ block rows (orthogonality constraints), RHS = 0
        final int pi = i - n; // 0, 1, or 2
        for (int j = 0; j < n; j++) {
          row[j] = switch (pi) {
            0 => 1.0,
            1 => src[j].dx,
            2 => src[j].dy,
            _ => 0.0,
          };
        }
      }
      return row;
    });

    // Gaussian elimination with partial pivoting
    for (int col = 0; col < m; col++) {
      // Find pivot row
      int maxRow = col;
      double maxVal = aug[col][col].abs();
      for (int row = col + 1; row < m; row++) {
        final double v = aug[row][col].abs();
        if (v > maxVal) { maxVal = v; maxRow = row; }
      }
      if (maxVal < 1e-10) return null; // singular / degenerate

      // Swap rows
      final List<double> tmp = aug[col];
      aug[col] = aug[maxRow];
      aug[maxRow] = tmp;

      // Eliminate below
      final double pivot = aug[col][col];
      for (int row = col + 1; row < m; row++) {
        final double factor = aug[row][col] / pivot;
        if (factor == 0.0) continue;
        for (int c = col; c < m + 2; c++) {
          aug[row][c] -= factor * aug[col][c];
        }
      }
    }

    // Back-substitution (produces both x and y solutions simultaneously)
    final List<double> solX = List<double>.filled(m, 0.0);
    final List<double> solY = List<double>.filled(m, 0.0);
    for (int i = m - 1; i >= 0; i--) {
      solX[i] = aug[i][m];
      solY[i] = aug[i][m + 1];
      for (int j = i + 1; j < m; j++) {
        solX[i] -= aug[i][j] * solX[j];
        solY[i] -= aug[i][j] * solY[j];
      }
      solX[i] /= aug[i][i];
      solY[i] /= aug[i][i];
    }

    return TpsSolution(
      srcPoints: List<Offset>.unmodifiable(src),
      weightsX: solX.sublist(0, n),
      affineX: solX.sublist(n),
      weightsY: solY.sublist(0, n),
      affineY: solY.sublist(n),
    );
  }

  // ── Mesh build ────────────────────────────────────────────────────────────

  /// Build a GPU-ready indexed triangle mesh by evaluating [solution] at a
  /// [cols]×[rows] grid of UV samples.
  ///
  /// Returns a [ui.Vertices] object and the [ui.ImageShader] paint to draw it.
  /// Caller is responsible for calling `canvas.drawVertices(verts, BlendMode.srcOver, paint)`.
  ///
  /// Grid size trade-off:
  ///   cols=16, rows=10 → 160 quads → 320 triangles → < 0.2 ms on any device.
  ///   Increase to 24×16 for higher deformation accuracy if needed.
  static (ui.Vertices, Paint) buildMesh({
    required TpsSolution solution,
    required ui.Image img,
    int cols = 16,
    int rows = 10,
  }) {
    final int vCols = cols + 1;
    final int vRows = rows + 1;
    final int vertexCount = vCols * vRows;
    final int indexCount = cols * rows * 6; // 2 triangles × 3 indices per quad

    final Float32List positions = Float32List(vertexCount * 2);
    final Float32List texCoords = Float32List(vertexCount * 2);
    final Uint16List indices    = Uint16List(indexCount);

    // Evaluate TPS at every grid vertex
    for (int r = 0; r < vRows; r++) {
      for (int c = 0; c < vCols; c++) {
        final double u = c / cols;
        final double v = r / rows;
        final Offset screen = solution.eval(u, v);
        final int base = (r * vCols + c) * 2;
        positions[base]     = screen.dx;
        positions[base + 1] = screen.dy;
        texCoords[base]     = u * img.width;
        texCoords[base + 1] = v * img.height;
      }
    }

    // Index list: two CCW triangles per quad
    int ii = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final int tl = r * vCols + c;
        final int tr = tl + 1;
        final int bl = tl + vCols;
        final int br = bl + 1;
        indices[ii++] = tl; indices[ii++] = tr; indices[ii++] = bl;
        indices[ii++] = tr; indices[ii++] = br; indices[ii++] = bl;
      }
    }

    final ui.Vertices verts = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texCoords,
      indices: indices,
    );

    final ui.ImageShader shader = ui.ImageShader(
      img,
      TileMode.clamp,
      TileMode.clamp,
      Matrix4.identity().storage,
    );
    final Paint paint = Paint()
      ..shader = shader
      ..filterQuality = FilterQuality.high;

    return (verts, paint);
  }
}
