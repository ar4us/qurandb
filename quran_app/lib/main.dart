import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:archive/archive.dart';

// --- CONFIGURATION ---
// Replace this with your GitHub RAW URL once you upload the fonts folder
const String kBaseFontsUrl = "https://raw.githubusercontent.com/ar4us/qurandb/main/assets/font/";
// ---------------------

void main() {
  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quran Cloud App',
      theme: ThemeData(
        primarySwatch: Colors.brown,
        useMaterial3: true,
      ),
      home: const QuranHomePage(),
    );
  }
}

class QuranHomePage extends StatefulWidget {
  const QuranHomePage({super.key});

  @override
  State<QuranHomePage> createState() => _QuranHomePageState();
}

class _QuranHomePageState extends State<QuranHomePage> {
  Database? _db;
  Map<String, String>? _glyphs;
  bool _isLoading = true;
  final Set<String> _loadedFonts = {};
  bool _isExtractingFonts = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    Directory docsDir = await getApplicationDocumentsDirectory();
    
    // 1. Load Database (Keep it local as it's small)
    String dbPath = p.join(docsDir.path, "qpc-v4.db");
    if (!await File(dbPath).exists()) {
      ByteData data = await rootBundle.load("assets/data/qpc-v4.db");
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(dbPath).writeAsBytes(bytes, flush: true);
    }
    _db = await openDatabase(dbPath);

    // 2. Load Glyphs JSON
    String jsonString = await rootBundle.loadString('assets/data/qpc-v4.json');
    Map<String, dynamic> rawGlyphs = json.decode(jsonString);
    _glyphs = {};
    rawGlyphs.forEach((key, value) {
      _glyphs![value['id'].toString()] = value['text'];
    });

    // 3. Extract Fonts ZIP if needed
    String fontsDir = p.join(docsDir.path, "fonts");
    if (!await Directory(fontsDir).exists() || (await Directory(fontsDir).list().length) < 600) {
      setState(() => _isExtractingFonts = true);
      try {
        await Directory(fontsDir).create(recursive: true);
        ByteData data = await rootBundle.load("assets/fonts.zip");
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        
        Archive archive = ZipDecoder().decodeBytes(bytes);
        for (ArchiveFile file in archive) {
          String filename = file.name;
          if (file.isFile) {
            List<int> data = file.content as List<int>;
            File(p.join(fontsDir, filename))
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);
          }
        }
      } catch (e) {
        debugPrint("Extraction error: $e");
      }
      setState(() => _isExtractingFonts = false);
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadFontIfNeeded(int pageNumber) async {
    String fontFamily = 'p$pageNumber';
    if (_loadedFonts.contains(fontFamily) || _isExtractingFonts) return;

    Directory docsDir = await getApplicationDocumentsDirectory();
    String fontPath = p.join(docsDir.path, "fonts", "p$pageNumber.ttf");
    File fontFile = File(fontPath);

    if (!await fontFile.exists()) {
      debugPrint("Font file not found: $fontPath");
      return;
    }

    // Load into Flutter memory
    try {
      final fontData = await fontFile.readAsBytes();
      final fontLoader = FontLoader(fontFamily);
      fontLoader.addFont(Future.value(ByteData.view(fontData.buffer)));
      await fontLoader.load();
      
      _loadedFonts.add(fontFamily);
      if (mounted) setState(() {}); 
    } catch (e) {
      debugPrint("Font loading error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFDF6E3),
      appBar: AppBar(
        title: const Text("مصحف السحاب"),
        centerTitle: true,
        backgroundColor: const Color(0xFF8B4513).withOpacity(0.1),
      ),
      body: PageView.builder(
        reverse: true,
        itemCount: 604,
        itemBuilder: (context, index) {
          int pageNum = index + 1;
          _loadFontIfNeeded(pageNum);
          
          return QuranPage(
            pageNumber: pageNum,
            db: _db!,
            glyphs: _glyphs!,
            isFontLoaded: _loadedFonts.contains('p$pageNum'),
            isExtracting: _isExtractingFonts,
          );
        },
      ),
    );
  }
}

class QuranPage extends StatelessWidget {
  final int pageNumber;
  final Database db;
  final Map<String, String> glyphs;
  final bool isFontLoaded;
  final bool isExtracting;

  const QuranPage({
    super.key,
    required this.pageNumber,
    required this.db,
    required this.glyphs,
    required this.isFontLoaded,
    required this.isExtracting,
  });

  Future<List<Map<String, dynamic>>> _getPageData() async {
    return await db.query(
      'pages',
      where: 'page_number = ?',
      whereArgs: [pageNumber],
      orderBy: 'line_number',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isExtracting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text("جاري استخراج الخطوط (لأول مرة فقط)..."),
          ],
        ),
      );
    }

    if (!isFontLoaded) {
      return const Center(child: Text("جاري تحميل الخط..."));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getPageData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        return Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9EB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0D0B0), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: snapshot.data!.map((line) {
              return LineWidget(
                lineData: line,
                glyphs: glyphs,
                pageNumber: pageNumber,
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class LineWidget extends StatelessWidget {
  final Map<String, dynamic> lineData;
  final Map<String, String> glyphs;
  final int pageNumber;

  const LineWidget({
    super.key,
    required this.lineData,
    required this.glyphs,
    required this.pageNumber,
  });

  @override
  Widget build(BuildContext context) {
    final first = lineData['first_word_id']?.toString();
    final last = lineData['last_word_id']?.toString();
    final isCentered = lineData['is_centered'] == 1;

    if (first == null || last == null || first.isEmpty || last.isEmpty) {
      return const SizedBox(height: 40);
    }

    final int startId = int.parse(first);
    final int endId = int.parse(last);
    
    List<String> wordGlyphs = [];
    for (int i = startId; i <= endId; i++) {
      final String? glyph = glyphs[i.toString()];
      if (glyph != null) wordGlyphs.add(glyph);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: Wrap(
          alignment: isCentered ? WrapAlignment.center : WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: wordGlyphs.map((g) {
            return Text(
              g,
              style: TextStyle(
                fontFamily: 'p$pageNumber',
                fontSize: 22,
                color: const Color(0xFF333333),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
