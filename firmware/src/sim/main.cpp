// Desktop simulator — runs the REAL firmware core (src/core/) with no ESP32.
//
// Feeds IMU windows from a CSV in the ML pipeline's schema
// ({ax,ay,az,gx,gy,gz,label,window_id[,group]}) through ImuWindow ->
// crash_fusion -> SosStateMachine, and prints the exact BLE JSON payloads the
// firmware would notify. This is the fastest way to exercise crash detection
// + the 10 s cancel window against real data (e.g. ml/data/damoto_windows.csv)
// without buying anything.
//
//   cd firmware && pio run -e sim
//   .pio/build/sim/program --csv ../ml/data/damoto_windows.csv --verbose
//   .pio/build/sim/program --csv ../ml/data/synthetic/windows.csv --cancel-after 4
//
// The piezo channel does not exist in the ML CSVs, so it is SYNTHESISED: the
// piezo "fires" for a window whose peak |accel| exceeds --piezo-threshold
// (default 1.8 g). That mirrors "a hard mechanical shock happened"; the
// fusion stage's sustained-tilt check is still what separates a crash from a
// big pothole.
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

#include "build_config.h"
#include "core/ble_schema.h"
#include "core/crash_fusion.h"
#include "core/imu_window.h"
#include "core/link_monitor.h"
#include "core/sos_state_machine.h"

using namespace helmet;

namespace {

struct Row { float ax, ay, az, gx, gy, gz; std::string label; long window_id; };

std::vector<Row> LoadCsv(const std::string& path) {
  std::ifstream in(path);
  if (!in) { std::fprintf(stderr, "cannot open %s\n", path.c_str()); std::exit(2); }
  std::string line;
  std::getline(in, line);                       // header
  std::vector<std::string> cols;
  { std::stringstream ss(line); std::string c;
    while (std::getline(ss, c, ',')) cols.push_back(c); }
  auto idx = [&](const char* name) -> int {
    for (size_t i = 0; i < cols.size(); ++i) if (cols[i] == name) return (int)i;
    std::fprintf(stderr, "csv missing column '%s'\n", name); std::exit(2);
    return -1;  // unreachable
  };
  int iax = idx("ax"), iay = idx("ay"), iaz = idx("az");
  int igx = idx("gx"), igy = idx("gy"), igz = idx("gz");
  int ilab = idx("label"), iwid = idx("window_id");

  std::vector<Row> rows;
  while (std::getline(in, line)) {
    if (line.empty()) continue;
    std::vector<std::string> f; std::stringstream ss(line); std::string c;
    while (std::getline(ss, c, ',')) f.push_back(c);
    if ((int)f.size() <= iwid) continue;
    Row r;
    r.ax = std::stof(f[iax]); r.ay = std::stof(f[iay]); r.az = std::stof(f[iaz]);
    r.gx = std::stof(f[igx]); r.gy = std::stof(f[igy]); r.gz = std::stof(f[igz]);
    r.label = f[ilab]; r.window_id = std::stol(f[iwid]);
    rows.push_back(r);
  }
  return rows;
}

const char* Arg(int argc, char** argv, const char* key, const char* def) {
  for (int i = 1; i < argc - 1; ++i) if (!std::strcmp(argv[i], key)) return argv[i + 1];
  return def;
}
bool Flag(int argc, char** argv, const char* key) {
  for (int i = 1; i < argc; ++i) if (!std::strcmp(argv[i], key)) return true;
  return false;
}

}  // namespace

int main(int argc, char** argv) {
  const char* csv = Arg(argc, argv, "--csv", "");
  const float piezo_thr = std::stof(Arg(argc, argv, "--piezo-threshold", "1.8"));
  const int cancel_after = std::atoi(Arg(argc, argv, "--cancel-after", "-1"));
  const bool verbose = Flag(argc, argv, "--verbose");
  if (!csv[0]) { std::fprintf(stderr, "usage: program --csv <windows.csv> "
                              "[--piezo-threshold G] [--cancel-after SEC] [--verbose]\n");
                 return 2; }

  auto rows = LoadCsv(csv);
  std::printf("loaded %zu samples from %s\n", rows.size(), csv);

  core::ImuWindow window;
  core::SosStateMachine sos;
  core::LinkMonitor link;

  uint32_t now = 0;                 // simulated ms
  long cur_wid = rows.empty() ? -1 : rows[0].window_id;
  int windows_done = 0, crashes = 0, cancels = 0, confirms = 0;
  bool cancel_scheduled = false;
  uint32_t cancel_at = 0;

  auto flush_events = [&]() {
    schema::EventPayload e;
    while (sos.PopOutgoing(e)) {
      std::printf("t=%6u ms  EVENT   %s\n", now, schema::Serialize(e).c_str());
      if (e.cancelled) ++cancels;
      if (e.confirmed) ++confirms;
    }
  };

  // Classify the window currently held and (maybe) arm the SOS.
  auto run_window = [&](long wid) {
    core::WindowFeatures f = window.Compute();
    bool piezo = f.full && (f.amag_max >= piezo_thr);
    core::FusionResult r = core::Classify(f, piezo);

    if (verbose) {
      float tilt = std::sqrt(f.ax_second_half_mean * f.ax_second_half_mean +
                             f.ay_second_half_mean * f.ay_second_half_mean);
      std::printf("t=%6u ms  win %-5ld amag_max=%.2f g_rec=%.2f tilt2h=%.2f "
                  "piezo=%d -> %s\n", now, wid, f.amag_max, f.g_recovery_ratio,
                  tilt, piezo ? 1 : 0, schema::ToString(r.event_type));
    }

    if (r.is_emergency &&
        sos.Trigger(r.event_type, r.confirmed_by, r.severity_score, now)) {
      ++crashes;
      std::printf("t=%6u ms  *** CRASH FUSION -> SOS armed (sev %d), "
                  "%d s cancel window ***\n", now, r.severity_score,
                  (int)(cfg::kSosCancelWindowMs / 1000));
      if (cancel_after >= 0) {
        cancel_scheduled = true;
        cancel_at = now + (uint32_t)cancel_after * 1000;
      }
    }
    flush_events();
  };

  // Advance the simulated clock by one window's worth (2 s) in 100 ms steps,
  // ticking the SOS state machine and firing any scheduled driver cancel.
  auto advance_one_window = [&]() {
    const uint32_t end = now + (uint32_t)(cfg::kImuWindowSeconds * 1000);
    while (now < end) {
      now += 100;
      if (cancel_scheduled && now >= cancel_at) {
        cancel_scheduled = false;
        if (sos.Cancel(now, "driver"))
          std::printf("t=%6u ms  (simulated driver cancel)\n", now);
      }
      sos.Tick(now);
      sos.Acknowledge();     // auto-ack a dispatched SOS so the sim keeps going
      link.Update(true, true, now);
      flush_events();
    }
  };

  for (size_t i = 0; i < rows.size(); ++i) {
    if (rows[i].window_id != cur_wid) {
      run_window(cur_wid);
      ++windows_done;
      advance_one_window();
      window.Clear();
      cur_wid = rows[i].window_id;
    }
    window.Push({rows[i].ax, rows[i].ay, rows[i].az,
                 rows[i].gx, rows[i].gy, rows[i].gz});
  }
  run_window(cur_wid);
  ++windows_done;
  // let any SOS armed on the last window play out its full 10 s window
  for (int k = 0; k < 6 && sos.state() != core::SosState::kIdle; ++k)
    advance_one_window();
  advance_one_window();
  flush_events();

  std::printf("\n--- summary ---\n");
  std::printf("windows processed : %d\n", windows_done);
  std::printf("crash SOS armed   : %d\n", crashes);
  std::printf("  -> cancelled    : %d\n", cancels);
  std::printf("  -> confirmed    : %d  (would dispatch SOS)\n", confirms);
  return 0;
}
