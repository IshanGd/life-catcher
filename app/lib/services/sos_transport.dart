import '../models/sos_dispatch.dart';

/// The two relay channels 01_REQUIREMENTS.md specifies: "use the phone's
/// own GPS + data/SMS to notify the emergency contact." [SosRelay] tries
/// both and treats either succeeding as the SOS having gone out
/// (SosDispatchRecord.anyChannelSucceeded) -- they're redundant paths, not
/// a both-required pipeline.
///
/// A real implementation needs platform-specific work this environment
/// can't do (no Android/iOS toolchain, no backend): the data channel would
/// call a backend API or platform push service; the SMS channel needs a
/// native plugin with SEND_SMS permission (Android) or a carrier gateway.
/// Both stay mocked here.
abstract class SosTransport {
  Future<SosChannelResult> sendViaData(SosDispatchPayload payload);
  Future<SosChannelResult> sendViaSms(SosDispatchPayload payload);
}

class MockSosTransport implements SosTransport {
  MockSosTransport({
    this.dataChannelFails = false,
    this.smsChannelFails = false,
    this.delay = const Duration(milliseconds: 500),
  });

  final bool dataChannelFails;
  final bool smsChannelFails;
  final Duration delay;

  final List<SosDispatchPayload> sentViaData = [];
  final List<SosDispatchPayload> sentViaSms = [];

  @override
  Future<SosChannelResult> sendViaData(SosDispatchPayload payload) async {
    await Future.delayed(delay);
    if (dataChannelFails) return const SosChannelResult(ok: false, errorMessage: 'No data connectivity');
    sentViaData.add(payload);
    return const SosChannelResult(ok: true);
  }

  @override
  Future<SosChannelResult> sendViaSms(SosDispatchPayload payload) async {
    await Future.delayed(delay);
    if (smsChannelFails) return const SosChannelResult(ok: false, errorMessage: 'SMS send failed');
    sentViaSms.add(payload);
    return const SosChannelResult(ok: true);
  }
}
