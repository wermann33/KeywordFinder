import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

void main() {
  runApp(const MyApp());

  if (!Platform.isAndroid) {
    doWhenWindowReady(() {
      final win = appWindow;
      const initialSize = Size(1200, 800);
      win.minSize = const Size(800, 600);
      win.size = initialSize;
      win.alignment = Alignment.center;
      win.title = "Keyword Finder";
      win.show();
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keyword Liste',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class KeywordListPage extends StatefulWidget {
  const KeywordListPage({super.key});

  @override
  State<KeywordListPage> createState() => _KeywordListPageState();
}

class _KeywordListPageState extends State<KeywordListPage> {
  final _keywordsController = TextEditingController();
  List<String> _keywords = [];

  @override
  void initState() {
    super.initState();
    _loadKeywords();
  }

  @override
  Widget build(BuildContext context) {
    _keywords.sort((a, b) {
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    //calculating the height of the keyword list
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keyword Liste'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: _keywords.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_keywords[index]),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        _keywords.removeAt(index);
                        _saveKeywords();
                      });
                    },
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              Flexible(
                child: TextField(
                  textInputAction: TextInputAction.none,
                  controller: _keywordsController,
                  decoration: const InputDecoration(hintText: 'Keyword eingeben', hintStyle: TextStyle(fontSize: 18)),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      setState(() {
                        _keywords.add(value);
                        _keywordsController.clear();
                        _saveKeywords();
                      });
                    }
                  },
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                ),
                child: const Text(
                  'Keyword Hinzufügen',
                  style: TextStyle(fontSize: 16),
                ),
                onPressed: () {
                  if (_keywordsController.text.isNotEmpty) {
                    setState(() {
                      _keywords.add(_keywordsController.text);
                      _keywordsController.clear();
                      _saveKeywords();
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  fixedSize: const Size(500, 60),
                  backgroundColor: Colors.yellow,
                ),
                child: const Text(
                  'Text eingeben und nach Keywords durchsuchen',
                  style: TextStyle(color: Colors.black, fontSize: 18),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SearchPage(keywords: _keywords),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  _saveKeywords() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList('keywords', _keywords);
  }

  _loadKeywords() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _keywords = prefs.getStringList('keywords') ?? ['Organisation', 'Basisdemokratie'];
    setState(() {});
  }
}

class SearchPage extends StatefulWidget {
  final List<String> keywords;

  const SearchPage({Key? key, required this.keywords}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  final Map<String, List<String>> _keywordIndices = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_search);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suche'),
      ),
      body: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(hintText: 'Text eingeben oder per Copy/Paste einfügen', hintStyle: TextStyle(fontSize: 20)),
              maxLines: 10,
              keyboardType: TextInputType.multiline,
            ),
          ),
          for (String key in widget.keywords)
            if (_keywordIndices.isNotEmpty && _keywordIndices[key]!.isNotEmpty)
              Text(
                "Gefunden:  $key ${_keywordIndices[key]!.length} x ",
                style: const TextStyle(backgroundColor: Colors.deepOrange, fontSize: 16),
              ),
          Expanded(
            child: Container(
              color: const Color.fromARGB(255, 150, 205, 219),
              child: SingleChildScrollView(
                child: ListView.builder(
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                  itemCount: _keywordIndices.keys.length,
                  itemBuilder: (context, index) {
                    String keyword = _keywordIndices.keys.elementAt(index);
                    return Column(
                      children: [
                        for (String sentence in _keywordIndices[keyword]!)
                          ListTile(
                            title: Text.rich(
                              TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: _buildTextSpans(sentence, keyword),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _buildTextSpans(String sentence, String keyword) {
    List<TextSpan> spans = [];
    spans.add(const TextSpan(text: '-) '));
    for (String word in sentence.split(" ")) {
      if (word.toLowerCase().contains(keyword.toLowerCase()) == true) {
        spans.add(TextSpan(text: "$word ", style: const TextStyle(color: Colors.red)));
      } else {
        spans.add(TextSpan(text: "$word "));
      }
    }
    return spans;
  }

  void _search() {
    setState(() {
      _keywordIndices.clear();
      LineSplitter ls = const LineSplitter();
      List<String> sentences = ls.convert(_searchController.text);
      for (String keyword in widget.keywords) {
        _keywordIndices[keyword] = [];
        for (String sentence in sentences) {
          if (sentence.toLowerCase().contains(keyword.toLowerCase())) {
            _keywordIndices[keyword]!.add(sentence);
          }
        }
      }
    });
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: KeywordListPage(),
    );
  }
}
