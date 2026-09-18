/// ค้นคลิปความรู้บน YouTube จากคำค้น แล้วเปิดหน้าผลลัพธ์ที่ "เรียงให้แล้ว"
///
/// **ทำไมไม่ดึงรายชื่อคลิปมาแสดงในแอปเอง**: ยอดวิว/ยอดไลก์ต้องใช้ YouTube Data API
/// ซึ่งต้องสมัคร API key ผ่าน Google Cloud — เวอร์ชันนี้จึงส่งคำค้นพร้อม "พารามิเตอร์เรียงลำดับ"
/// ไปให้ YouTube จัดอันดับให้ ได้ผลเรียงตามยอดวิวจริงโดยไม่ต้องมี key และไม่มีโควตาจำกัด
///
/// ถ้าวันหนึ่งอยากได้รายชื่อ+ยอดวิวในแอป ให้เพิ่ม implementation ที่เรียก Data API
/// แล้วให้หน้าจอเรียกผ่านตัวกลางแทน `searchUrl` (แพตเทิร์นเดียวกับ `AuthService`)
library;

/// ลำดับการเรียงผลค้นหาของ YouTube
enum VideoSort { viewCount, relevance, uploadDate, rating }

extension VideoSortX on VideoSort {
  String get label => switch (this) {
        VideoSort.viewCount => 'ยอดดูมากที่สุด',
        VideoSort.relevance => 'ตรงกับคำค้นที่สุด',
        VideoSort.uploadDate => 'ใหม่ล่าสุด',
        VideoSort.rating => 'เรตติ้งดีที่สุด',
      };

  String get hint => switch (this) {
        VideoSort.viewCount => 'คลิปที่คนดูเยอะที่สุดก่อน',
        VideoSort.relevance => 'ให้ YouTube เลือกคลิปที่ตรงเรื่องที่สุด',
        VideoSort.uploadDate => 'ข้อมูลใหม่ เหมาะกับเรื่องที่เปลี่ยนเร็ว เช่น ภาษี/ดอกเบี้ย',
        VideoSort.rating => 'คลิปที่คนกดถูกใจในสัดส่วนสูง',
      };

  /// ค่าพารามิเตอร์ `sp` ของ YouTube = "เรียงแบบนี้ + เอาเฉพาะวิดีโอ"
  ///
  /// เป็นค่าที่ YouTube ใช้ในหน้าเว็บของตัวเอง (ไม่ใช่ API สาธารณะ) ถ้าวันหนึ่ง YouTube
  /// เปลี่ยนรูปแบบ ผลจะกลับไปเป็นการเรียงปกติ ไม่ได้พังทั้งหน้า
  String get filterParam => switch (this) {
        VideoSort.relevance => 'CAASAhAB',
        VideoSort.uploadDate => 'CAISAhAB',
        VideoSort.viewCount => 'CAMSAhAB',
        VideoSort.rating => 'CAESAhAB',
      };
}

/// ชุดคำค้นสำเร็จรูปของหัวข้อหนึ่ง เช่น "วิเคราะห์หุ้น"
class VideoTopic {
  final String label;

  /// คำค้นที่จะส่งให้ YouTube — เขียนให้เจาะจงกว่าชื่อหัวข้อ เพื่อไม่ให้ได้คลิปกว้างเกินไป
  final List<String> queries;

  const VideoTopic({required this.label, required this.queries});
}

class VideoSearch {
  VideoSearch._();

  /// หัวข้อที่ตรงกับโมดูลในแอป (การเงิน ประกัน สุขภาพ พัฒนาตนเอง)
  static const topics = <VideoTopic>[
    VideoTopic(label: 'การเงินส่วนบุคคล', queries: [
      'วางแผนการเงินส่วนบุคคล',
      'จัดการหนี้ ปลดหนี้',
      'วางแผนภาษีมนุษย์เงินเดือน',
    ]),
    VideoTopic(label: 'การออม', queries: [
      'วิธีออมเงิน เก็บเงินให้อยู่',
      'ออมเงินฉุกเฉิน 6 เดือน',
      'ดอกเบี้ยทบต้น ออมระยะยาว',
    ]),
    VideoTopic(label: 'วิเคราะห์หุ้น', queries: [
      'วิเคราะห์หุ้นพื้นฐานสำหรับมือใหม่',
      'อ่านงบการเงินบริษัท',
      'ประเมินมูลค่าหุ้น P/E',
    ]),
    VideoTopic(label: 'ลงทุน', queries: [
      'ลงทุนกองทุนรวมมือใหม่',
      'DCA ลงทุนแบบถัวเฉลี่ย',
      'จัดพอร์ตการลงทุน',
    ]),
    VideoTopic(label: 'ประกัน', queries: [
      'เลือกประกันชีวิตให้เหมาะกับตัวเอง',
      'ประกันสุขภาพ เลือกยังไง',
      'เทคนิคขายประกัน ตัวแทนมือใหม่',
    ]),
    VideoTopic(label: 'สุขภาพ', queries: [
      'กินอย่างไรให้สุขภาพดี โภชนาการพื้นฐาน',
      'ออกกำลังกายที่บ้าน มือใหม่',
      'นอนหลับให้มีคุณภาพ',
    ]),
    VideoTopic(label: 'พัฒนาตนเอง', queries: [
      'บริหารเวลา เพิ่มประสิทธิภาพ',
      'สร้างนิสัยใหม่ให้ติด',
      'พูดนำเสนออย่างมืออาชีพ',
    ]),
  ];

  /// ลิงก์หน้าผลค้นหาของ YouTube (เปิดในแอป YouTube เองถ้าเครื่องมีติดตั้ง)
  static Uri searchUrl(String query, {VideoSort sort = VideoSort.viewCount}) {
    final clean = query.trim();
    return Uri.https('www.youtube.com', '/results', {
      'search_query': clean,
      if (clean.isNotEmpty) 'sp': sort.filterParam,
    });
  }

  /// คำค้นทั้งหมดของทุกหัวข้อ (ใช้ทำรายการแนะนำตอนยังไม่ได้พิมพ์อะไร)
  static List<String> get allQueries => [for (final t in topics) ...t.queries];
}
