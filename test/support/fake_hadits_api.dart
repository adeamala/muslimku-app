import 'package:muslimku/core/network/api_service.dart';

/// MyQuran stand-in for the Hadits tab: 42 Arbain hadiths (No. 16 is the real
/// "Janganlah Engkau Marah"), Bulughul Maram 1–1597 and the 9 perawi.
///
/// Counts requests and how many run at the same time; [offline] makes every
/// request fail, [failBulughul] makes single Bulughul Maram numbers fail.
class FakeHaditsApi extends ApiService {
  FakeHaditsApi({this.offline = false, this.delay = Duration.zero});

  bool offline;

  /// Time each request takes (zero answers in a microtask).
  Duration delay;
  final Set<int> failBulughul = {};
  final List<String> requests = [];
  int maxInFlight = 0;
  int _inFlight = 0;

  static const arbain16 =
      'Dari Abu Hurairah radhiyallahu ‘anhu bahwasanya ada seseorang yang '
      'berkata kepada Nabi shallallahu ‘alaihi wa sallam: ”Berilah aku '
      'nasihat.” Beliau shallallahu ‘alaihi wa sallam bersabda: ”Janganlah '
      'engkau marah.” Diapun mengulanginya beberapa kali, beliau shallallahu '
      '‘alaihi wa sallam bersabda: ”Janganlah engkau marah.” (HR. Al Bukhari).';

  static Map<String, dynamic> arbainJson(int n) => {
    'no': '$n',
    'judul': switch (n) {
      1 => 'Amalan Bergantung pada Niat',
      2 => 'Rukun Islam, Iman, dan Ihsan',
      4 => 'Takdir Setiap Manusia sudah Tertulis',
      16 => 'Janganlah Engkau Marah',
      17 => 'Berbuat Baik dalam Segala Hal',
      _ => 'Hadits Arbain $n',
    },
    'arab': 'نص الحديث $n',
    'indo': n == 16
        ? arbain16
        : 'Rasulullah bersabda: ”Isi hadits nomor $n.” '
              '(HR. ${n.isEven ? 'Muslim' : 'Al Bukhari dan Muslim'})',
  };

  static Map<String, dynamic> bulughulJson(int n) => {
    'no': n,
    'ar': 'وَعَنْ أَبِي هُرَيْرَةَ <b>$n</b>',
    'id':
        'Hadis No. $n   \r  Dari Abu Hurairah bahwa Rasulullah bersabda: '
        '"Isi Bulughul Maram nomor $n."',
  };

  static const perawiList = [
    {'name': 'Abu Dawud', 'slug': 'abu-dawud', 'total': 4419},
    {'name': 'Ahmad', 'slug': 'ahmad', 'total': 4305},
    {'name': 'Bukhari', 'slug': 'bukhari', 'total': 6638},
    {'name': 'Darimi', 'slug': 'darimi', 'total': 2949},
    {'name': 'Ibnu Majah', 'slug': 'ibnu-majah', 'total': 4285},
    {'name': 'Malik', 'slug': 'malik', 'total': 1587},
    {'name': 'Muslim', 'slug': 'muslim', 'total': 4930},
    {'name': 'Nasai', 'slug': 'nasai', 'total': 5364},
    {'name': 'Tirmidzi', 'slug': 'tirmidzi', 'total': 3625},
  ];

  Future<T> _hit<T>(String path, T Function() answer) async {
    requests.add(path);
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    try {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      } else {
        await Future<void>.value();
      }
      if (offline) throw Exception('SocketException: offline');
      return answer();
    } finally {
      _inFlight--;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAllHadithArbain() => _hit(
    'hadits/arbain/semua',
    () => [for (var n = 1; n <= 42; n++) arbainJson(n)],
  );

  @override
  Future<Map<String, dynamic>?> getHadithBulughulByNumber(int number) =>
      _hit('hadits/bm/$number', () {
        if (failBulughul.contains(number)) throw Exception('timeout');
        return number < 1 || number > 1597 ? null : bulughulJson(number);
      });

  @override
  Future<List<Map<String, dynamic>>> getPerawiList() => _hit(
    'hadits/perawi',
    () => [for (final p in perawiList) Map<String, dynamic>.from(p)],
  );

  @override
  Future<Map<String, dynamic>?> getHadithByPerawi(String slug, int number) =>
      _hit('hadits/$slug/$number', () {
        return {
          'number': number,
          'arab': 'حَدَّثَنَا $slug $number',
          'id': 'Telah menceritakan kepada kami [$slug] hadits nomor $number.',
        };
      });

  int count(String path) => requests.where((r) => r == path).length;
}
