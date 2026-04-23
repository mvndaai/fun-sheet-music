import 'package:flutter/material.dart';

// ── Staff geometry constants ─────────────────────────────────────────────────

/// Vertical distance (px) between adjacent staff lines.
const double kLS = 12.0;

/// Note-head y semi-axis (fits within one staff space).
const double kNRy = kLS * 0.44; // ≈ 5.3 px

/// Note-head x semi-axis (wider than height so labels fit).
const double kNRx = kLS * 0.78; // ≈ 9.4 px

/// Stem length.
const double kStem = kLS * 3.4;

/// Horizontal space reserved at the start of each row for the treble clef.
const double kClefW = 44.0;

/// Pixels above the top staff line (head-room for high notes + ledger lines).
const double kTopMargin = kLS * 3.2;

/// Height of the staff proper (4 × line-spacing).
const double kStaffH = kLS * 4;

/// Pixels below the bottom staff line (room for low notes + note labels).
const double kBotMargin = kLS * 3.5;

/// Total pixel height of one staff row.
const double kRowH = kTopMargin + kStaffH + kBotMargin;

// ── Treble-clef pitch → staff-position mapping ───────────────────────────────

/// Diatonic ordinal of each note step (C = 0 … B = 6).
const Map<String, int> kDiatonic = {
  'C': 0,
  'D': 1,
  'E': 2,
  'F': 3,
  'G': 4,
  'A': 5,
  'B': 6,
};

/// Returns the treble-clef staff position for a note.
int staffPos(String step, int octave) =>
    octave * 7 + (kDiatonic[step] ?? 0) - 30; // 30 = diatonic value of E4

/// Converts a staff position to the y-coordinate within a painter row.
double posToY(int pos) => kTopMargin + kStaffH - pos * kLS / 2;
