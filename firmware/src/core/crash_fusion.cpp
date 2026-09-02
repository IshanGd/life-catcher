#include "core/crash_fusion.h"

#include <algorithm>
#include <cmath>

namespace helmet::core {

using helmet::schema::EventType;
using namespace helmet::schema;   // kSrc* bits
using namespace fusion_thresholds;

static int Clamp0100(float v) {
  return static_cast<int>(std::lround(std::clamp(v, 0.0f, 100.0f)));
}

// sqrt(ax_second_half^2 + ay_second_half^2): how far the sustained gravity
// vector has swung off the upright (-az) axis. High == bike lying over.
static float SustainedTilt(const WindowFeatures& f) {
  return std::sqrt(f.ax_second_half_mean * f.ax_second_half_mean +
                   f.ay_second_half_mean * f.ay_second_half_mean);
}

FusionResult Classify(const WindowFeatures& f, bool piezo_confirmed) {
  FusionResult r;
  if (!f.full) return r;   // need a complete window to decide anything

  const bool big_impact =
      (f.amag_max >= kImpactAmagG) || (f.jerk_absmax >= kImpactJerkGs);
  const float tilt = SustainedTilt(f);
  const bool tipped_over =
      (tilt >= kSustainedTiltG) ||
      (std::fabs(f.az_second_half_mean) <= kUprightAzAbsG) ||
      (f.g_recovery_ratio <= kGyroSettledRatio);

  // --- IMU side of the crash decision --------------------------------
  const bool imu_says_crash = big_impact && tipped_over;

  // --- fused crash (ADR-4): IMU AND piezo -------------------------
  if (imu_says_crash && piezo_confirmed) {
    r.event_type   = EventType::kCrashImpact;
    r.confirmed_by = static_cast<uint8_t>(kSrcMpu6050 | kSrcPiezo);
    r.is_emergency = true;
    float sev = 45.0f
              + 12.0f * (f.amag_max - kImpactAmagG)
              + 25.0f * tilt
              + 15.0f * (kGyroSettledRatio - std::min(f.g_recovery_ratio,
                                                      kGyroSettledRatio));
    r.severity_score = Clamp0100(sev);
    return r;
  }

  // IMU looks like a crash but the piezo did NOT confirm -> per ADR-4 this is
  // NOT an emergency. Surface it as a (non-emergency) harsh_brake/pothole so
  // the event feed and ride scoring still see it, and so the app could show
  // "possible impact, unconfirmed" if it chooses.
  if (imu_says_crash && !piezo_confirmed) {
    r.event_type   = EventType::kPotholeBump;
    r.confirmed_by = kSrcMpu6050;
    r.severity_score = Clamp0100(20.0f + 10.0f * (f.amag_max - kImpactAmagG));
    return r;
  }

  // --- harsh braking: sustained forward decel, disturbance ramps up --
  if (std::fabs(f.ax_mean) >= kBrakeDecelG &&
      f.g_recovery_ratio >= kBrakeRatioMin && !big_impact) {
    r.event_type   = EventType::kHarshBrake;
    r.confirmed_by = kSrcMpu6050;
    r.severity_score = Clamp0100(15.0f + 60.0f * (std::fabs(f.ax_mean) - kBrakeDecelG));
    return r;
  }

  // --- pothole / bump: a spike that recovers -------------------------
  if (f.amag_max >= kPotholeAmagG && !tipped_over) {
    r.event_type   = EventType::kPotholeBump;
    r.confirmed_by = kSrcMpu6050;
    r.severity_score = Clamp0100(10.0f + 15.0f * (f.amag_max - kPotholeAmagG));
    return r;
  }

  r.event_type = EventType::kNormalRiding;
  return r;
}

}  // namespace helmet::core
