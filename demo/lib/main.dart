import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'max_lines_demo.dart';
import 'min_font_size_demo.dart';
import 'overflow_replacement_demo.dart';
import 'preset_font_sizes_demo.dart';
import 'step_granularity.dart';
import 'sync_demo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue),
      home: const DemoApp(),
    );
  }
}

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

const List<MaterialColor> _demoColors = <MaterialColor>[
  Colors.red,
  Colors.purple,
  Colors.indigo,
  Colors.lightBlue,
  Colors.green,
  Colors.blueGrey,
];

const List<String> _demoNames = <String>[
  'MaxLines',
  'MinFontSize',
  'Group',
  'StepGranularity',
  'PresetFontSizes',
  'OverflowReplacement',
];

class _DemoAppState extends State<DemoApp> {
  bool _richText = false;
  int _selectedDemo = 0;
  MaterialColor get _selectedColor => _demoColors[_selectedDemo];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        actions: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _richText ? 'Rich Text' : 'Normal Text',
                style: const TextStyle(color: Colors.black, inherit: true),
              ),
              Switch(
                value: _richText,
                onChanged: (richText) {
                  setState(() {
                    _richText = richText;
                  });
                },
                activeThumbColor: _selectedColor[400],
                activeTrackColor: _selectedColor[200],
              ),
            ],
          ),
        ],
        title: Text(
          'AutoSizeText: ${_demoNames[_selectedDemo]}',
          style: TextStyle(color: _selectedColor[500], inherit: true),
        ),
      ),
      body: Container(
        color: _selectedColor[50],
        child: Padding(padding: const EdgeInsets.all(15), child: _buildDemo()),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedDemo,
        indicatorColor: _selectedColor[100],
        onDestinationSelected: (index) {
          setState(() {
            _selectedDemo = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.view_headline),
            label: 'maxLines',
          ),
          NavigationDestination(
            icon: Icon(Icons.text_fields),
            label: 'minFontSize',
          ),
          NavigationDestination(icon: Icon(Icons.sync), label: 'group'),
          NavigationDestination(
            icon: Icon(Icons.format_size),
            label: 'granularity',
          ),
          NavigationDestination(icon: Icon(Icons.settings), label: 'preset'),
          NavigationDestination(icon: Icon(Icons.layers), label: 'replacement'),
        ],
      ),
    );
  }

  Widget _buildDemo() {
    switch (_selectedDemo) {
      case 0:
        return MaxlinesDemo(_richText);
      case 1:
        return MinFontSizeDemo(_richText);
      case 2:
        return SyncDemo(_richText);
      case 3:
        return StepGranularityDemo(_richText);
      case 4:
        return PresetFontSizesDemo(_richText);
      default:
        return OverflowReplacementDemo(_richText);
    }
  }
}
