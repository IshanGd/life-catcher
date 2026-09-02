// Sensor-fusion event classifier (ADR-4: never a single-sensor emergency).
//
// PROVISIONAL. These are hand-set thresholds over the window features, not
// the trained model. They exist so the Phase 2 prototype can bring up the
// full crash -> cancel-window -> BLE path end to end. They MUST be:
//   1. re-tuned against controlled drop-test / real-ride data (Phase 1/2), and
//   2. replaced by the ported Random Forest (ADR-3) once ml/README.md shows a
//      trustworthy crash model — at which point this file becomes the piezo
//      fusion gate around the model output, not the classifier itself.
// Until then: no code path here may declare `crash_impact` without the piezo.
//
// Framework-agnostic; host-tested in test/test_crash_fusion/.
#pragma once

#include <cstdint>

#include "core/ble_schema.h"
#include "core/imu_window.h"

namespace helmet::core {

struct FusionResult {
  helmet::schema::EventType event_type = helmet::schema::EventType::kNormalRiding;
  int      severity_score = 0;                 // 0..100
  uint8_t  confirmed_by   = helmet::schema::kSrcNone;
  bool     is_emergency   = false;             // true only for a fused crash
};

// Provisional thresholds (accel g, gyro deg/s). Named so a tuning pass is a
// one-place edit. See the file header.
namespace fusion_thresholds {
constexpr float kImpactAmagG        = 2.2f;   // |accel| peak that looks like a hit
constexpr float kImpactJerkGs       = 60.0f;  // |d|accel||/dt
constexpr float kSustainedTiltG     = 0.55f;  // sqrt(ax2h^2+ay2h^2): gravity off-axis
constexpr float kUprightAzAbsG      = 0.7f;   // |az_second_half| below this == tipped
constexpr float kGyroSettledRatio   = 0.35f;  // g_recovery_ratio below this == settled
constexpr float kBrakeDecelG        = 0.35f;  // sustained forward |ax_mean|
constexpr float kBrakeRatioMin      = 1.30f;  // g_recovery_ratio (disturbance ramps up)
constexpr float kPotholeAmagG       = 1.8f;   // spike big enough to log as a bump
}  // namespace fusion_thresholds

// `piezo_confirmed` == the piezo saw an impact within cfg::kFusionPairWindowMs
// of this window. Pure function: same inputs -> same result.
FusionResult Classify(const WindowFeatures& f, bool piezo_confirmed);

}  // namespace helmet::core
