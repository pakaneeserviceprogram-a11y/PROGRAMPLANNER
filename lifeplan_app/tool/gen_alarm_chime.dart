// สร้างไฟล์เสียงแจ้งเตือนใหม่ด้วย:
//   dart run tool/gen_alarm_chime.dart android/app/src/main/res/raw/alarm_chime.wav

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// สร้างเสียงแจ้งเตือน (chime 3 โน้ต เล่นซ้ำ 2 รอบ) เป็นไฟล์ WAV 16-bit mono 44.1kHz
void main(List<String> args) {
  const rate = 44100;
  const noteSeconds = 0.30;
  const gapSeconds = 0.02;
  // A5 - C#6 - E6 (A major triad) ไล่ขึ้น ฟังแล้วสดใสไม่บาดหู
  const notes = <double>[880.0, 1108.73, 1318.51];

  final samples = <double>[];

  void appendNote(double freq, double seconds, double peak) {
    final n = (rate * seconds).round();
    for (var i = 0; i < n; i++) {
      final t = i / rate;
      // ซองเสียงแบบระฆัง: ขึ้นเร็ว (5ms) แล้วค่อย ๆ จางแบบ exponential
      final attack = (t / 0.005).clamp(0.0, 1.0);
      final decay = exp(-4.0 * t / seconds);
      // ใส่ฮาร์โมนิกที่ 2 เบา ๆ ให้เสียงมีเนื้อแบบระฆังจริง
      final wave = sin(2 * pi * freq * t) + 0.25 * sin(4 * pi * freq * t);
      samples.add(peak * attack * decay * wave / 1.25);
    }
  }

  void appendSilence(double seconds) {
    final n = (rate * seconds).round();
    for (var i = 0; i < n; i++) {
      samples.add(0);
    }
  }

  for (var round = 0; round < 2; round++) {
    for (final f in notes) {
      appendNote(f, noteSeconds, 0.72);
      appendSilence(gapSeconds);
    }
    if (round == 0) appendSilence(0.16);
  }
  // ปิดท้ายด้วยโน้ตล่างยาว ๆ ให้เสียงจบอย่างนุ่มนวล
  appendNote(notes.first, 0.55, 0.55);
  appendSilence(0.05);

  final pcm = Int16List(samples.length);
  for (var i = 0; i < samples.length; i++) {
    pcm[i] = (samples[i].clamp(-1.0, 1.0) * 32767).round();
  }

  final dataBytes = pcm.buffer.asUint8List();
  final header = BytesBuilder();
  void str(String s) => header.add(s.codeUnits);
  void u32(int v) => header.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) => header.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

  str('RIFF');
  u32(36 + dataBytes.length);
  str('WAVE');
  str('fmt ');
  u32(16); // PCM chunk size
  u16(1); // PCM
  u16(1); // mono
  u32(rate);
  u32(rate * 2); // byte rate
  u16(2); // block align
  u16(16); // bits per sample
  str('data');
  u32(dataBytes.length);

  final out = File(args.first);
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(header.toBytes() + dataBytes);
  stdout.writeln('wrote ${out.path} (${out.lengthSync()} bytes, '
      '${(samples.length / rate).toStringAsFixed(2)}s)');
}
