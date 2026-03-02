import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MainNavigationPage(),
  ));
}

// ---------------------------------------------------------
// 画面切り替えを管理するメインページ
// ---------------------------------------------------------
class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});
  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _screenIndex = 0;
  final List<Widget> _screens = [
    const NojimaThreeCalcPage(),
    const SimpleCalcPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_screenIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _screenIndex,
        onTap: (index) => setState(() => _screenIndex = index),
        selectedItemColor: Colors.blue[800],
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calculate), label: '見積モード'),
          BottomNavigationBarItem(icon: Icon(Icons.apps), label: '標準電卓'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// 画面1: エアコン見積モード (AirSave)
// ---------------------------------------------------------
class NojimaThreeCalcPage extends StatefulWidget {
  const NojimaThreeCalcPage({super.key});
  @override
  State<NojimaThreeCalcPage> createState() => _NojimaThreeCalcPageState();
}

class _NojimaThreeCalcPageState extends State<NojimaThreeCalcPage> {
  final formatter = NumberFormat("#,###");
  List<String> modelNames = ["機種 1", "機種 2", "機種 3"];
  List<List<dynamic>> allData = [[], [], []];
  int selectedIndex = 0; 
  String currentInput = "0"; 
  bool isNegative = false;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString('nojima_final_v15');
    final List<String>? savedNames = prefs.getStringList('nojima_names_v15');
    setState(() {
      if (jsonStr != null) {
        Iterable l = json.decode(jsonStr);
        allData = List<List<dynamic>>.from(l.map((model) => List<dynamic>.from(model)));
      }
      if (savedNames != null) modelNames = savedNames;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nojima_final_v15', json.encode(allData));
    await prefs.setStringList('nojima_names_v15', modelNames);
  }

  void _handleKey(String key) {
    setState(() {
      if (key == "C") { currentInput = "0"; isNegative = false; }
      else if (key == "±") { isNegative = !isNegative; }
      else if (key == "BS") { currentInput = currentInput.length > 1 ? currentInput.substring(0, currentInput.length - 1) : "0"; }
      else {
        if (currentInput == "0" && key != "00") currentInput = "";
        if (currentInput == "0" && key == "00") return;
        currentInput += key;
      }
    });
  }

  void _addItem(String name, {double? fixedPrice, bool isMinus = false}) {
    setState(() {
      double val = fixedPrice ?? (double.tryParse(currentInput) ?? 0);
      if (isMinus || (fixedPrice != null && fixedPrice < 0) || (fixedPrice == null && isNegative)) {
        val = -val.abs();
      }
      allData[selectedIndex].add({
        "id": DateTime.now().millisecondsSinceEpoch.toString() + name,
        "name": name, 
        "price": val
      });
      currentInput = "0"; isNegative = false; _saveData();
    });
  }

  void _editModelName(int index) {
    TextEditingController controller = TextEditingController(text: modelNames[index]);
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('機種名の変更'),
      content: TextField(controller: controller, decoration: const InputDecoration(hintText: "例: ダイキン 6畳")),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        TextButton(onPressed: () { setState(() { modelNames[index] = controller.text; _saveData(); }); Navigator.pop(context); }, child: const Text('保存')),
      ],
    ));
  }

  void _showMenu(String title, Map<String, double> items) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) => Container(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const Divider(),
        ...items.entries.map((e) => ListTile(
          title: Text(e.key), trailing: Text("¥${formatter.format(e.value)}"),
          onTap: () { _addItem(e.key, fixedPrice: e.value); Navigator.pop(context); },
        )),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    bool isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('AirSave', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[600],
      ),
      body: Row(children: [
        Container(width: 260, color: Colors.blueGrey[50], child: _buildLeftPanel()),
        Expanded(child: isPortrait ? _buildPriceColumn(selectedIndex) : Row(children: List.generate(3, (i) => Expanded(child: _buildPriceColumn(i))))),
      ]),
    );
  }

  Widget _buildLeftPanel() {
    return Column(children: [
      Container(
        margin: const EdgeInsets.all(10), padding: const EdgeInsets.all(12),
        width: double.infinity, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.blue[300]!, width: 2), borderRadius: BorderRadius.circular(8)),
        child: Text("${isNegative ? '-' : ''}${formatter.format(double.tryParse(currentInput) ?? 0)}", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueGrey), textAlign: TextAlign.right),
      ),
      _buildNumPad(),
      const Divider(height: 20),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 10), children: [
        _itemBtn("エアコン本体", Colors.blue[700]!, () => _addItem("本体")),
        _itemBtn("標準工事 (18,150円)", Colors.green[700]!, () => _addItem("標準工事", fixedPrice: 18150)),
        _itemBtn("室外機取り付けメニュー", Colors.orange[700]!, () => _showMenu("室外機取り付け", {"2F→1F高所": 14300, "3F→1F高所": 25300})),
        _itemBtn("屋外用配管カバーメニュー", Colors.cyan[700]!, () => _showMenu("屋外用配管カバー", {"屋外用配管カバー": 5500, "屋外用配管カバー2F→1": 15400, "屋外用配管カバー3F→1": 20900, "キャンペーン割": -5500, "標準再利用": 3300, "2F→1再利用": 6600, "3F→1再利用": 9900})),
        _itemBtn("室外機階段上げ", Colors.deepPurple[600]!, () => _showMenu("室外機階段上げ", {"内階段上げ": 1100, "内階段上げ(4.0kw以上)": 2200, "内階段上げ(加湿喚起タイプ)": 4400, "外階段上げ(感動エアコン)": 1100})),
        _itemBtn("取り外し（買い替え時）", Colors.purple[600]!, () => _showMenu("取り外し方法", {"標準取外し": 6600, "取外し2F→1": 9900, "取外し3F→1": 14300, "キャンペーン割": -6600})),
        _itemBtn("追加工事・特殊作業", Colors.grey[700]!, () => _addItem("追加工事・特殊作業")),
        _itemBtn("リサイクル (4,070円)", Colors.teal[600]!, () => _addItem("リサイクル", fixedPrice: 4070)),
        _itemBtn("特割", Colors.red[600]!, () => _addItem("特割", isMinus: true)),
        const SizedBox(height: 20),
      ])),
    ]);
  }

  Widget _buildNumPad() {
    List<String> keys = ["7", "8", "9", "4", "5", "6", "1", "2", "3", "±", "0", "00", "BS", "C"];
    return Wrap(alignment: WrapAlignment.center, children: keys.map((k) => SizedBox(
      width: 80, height: 50,
      child: Card(elevation: 2, color: (k == "C" || k == "BS") ? Colors.cyan[50] : (k == "±" ? Colors.blue[50] : Colors.white), 
        child: InkWell(onTap: () => _handleKey(k), child: Center(child: Text(k, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: (k == "C" || k == "BS") ? Colors.cyan[800] : Colors.black87))))),
    )).toList());
  }

  Widget _itemBtn(String label, Color col, VoidCallback tap) {
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: col, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: tap, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))));
  }

  Widget _buildPriceColumn(int index) {
    bool active = selectedIndex == index;
    double total = allData[index].fold(0.0, (sum, item) => sum + (item['price'] as double));
    return Container(
      margin: const EdgeInsets.all(5),
      decoration: BoxDecoration(border: Border.all(color: active ? Colors.blue[600]! : Colors.grey[300]!, width: active ? 4 : 1), borderRadius: BorderRadius.circular(12), color: Colors.white),
      child: Column(children: [
        InkWell(onLongPress: () => _editModelName(index), onTap: () => setState(() => selectedIndex = index), child: Container(height: 50, color: active ? Colors.blue[600] : Colors.grey[400], padding: const EdgeInsets.symmetric(horizontal: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(modelNames[index], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis)),
          IconButton(icon: const Icon(Icons.delete_forever, color: Colors.white, size: 22), onPressed: () => setState(() { allData[index] = []; _saveData(); })),
        ]))),
        Expanded(child: ReorderableListView(padding: EdgeInsets.zero, onReorder: (oldIdx, newIdx) { setState(() { if (newIdx > oldIdx) newIdx -= 1; final item = allData[index].removeAt(oldIdx); allData[index].insert(newIdx, item); _saveData(); }); }, children: [
          for (int i = 0; i < allData[index].length; i++) Container(key: ValueKey(allData[index][i]['id']), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[100]!))), child: ListTile(dense: true, leading: const Icon(Icons.drag_handle), title: Text(allData[index][i]['name'], style: const TextStyle(fontSize: 14)), subtitle: Text("¥${formatter.format(allData[index][i]['price'])}", style: TextStyle(color: allData[index][i]['price'] < 0 ? Colors.red[700] : Colors.black, fontWeight: FontWeight.w900, fontSize: 22)), onTap: () => _showEditDialog(index, i), trailing: IconButton(icon: const Icon(Icons.close), onPressed: () { setState(() { allData[index].removeAt(i); _saveData(); }); }))),
        ])),
        Container(padding: const EdgeInsets.all(15), width: double.infinity, decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8))), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [ const Text('合計（税込）', style: TextStyle(fontSize: 12, color: Colors.blueGrey)), Text("¥${formatter.format(total)}", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red[700]))])),
      ]),
    );
  }

  void _showEditDialog(int mIdx, int iIdx) {
    TextEditingController c = TextEditingController(text: allData[mIdx][iIdx]['price'].toInt().abs().toString());
    bool isN = allData[mIdx][iIdx]['price'] < 0;
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setS) => AlertDialog(title: Text('${allData[mIdx][iIdx]['name']}修正'), content: Row(children: [TextButton(onPressed: () => setS(() => isN = !isN), child: Text(isN ? "マイナス" : "プラス")), Expanded(child: TextField(controller: c, keyboardType: TextInputType.number, autofocus: true))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')), ElevatedButton(onPressed: () { setState(() { double p = double.tryParse(c.text) ?? 0; allData[mIdx][iIdx]['price'] = isN ? -p.abs() : p.abs(); _saveData(); }); Navigator.pop(context); }, child: const Text('保存'))])));
  }
}

// ---------------------------------------------------------
// 画面2: 標準電卓 (キーボード拡大・下部配置・横向き最適化版)
// ---------------------------------------------------------
class SimpleCalcPage extends StatefulWidget {
  const SimpleCalcPage({super.key});
  @override
  State<SimpleCalcPage> createState() => _SimpleCalcPageState();
}

class _SimpleCalcPageState extends State<SimpleCalcPage> {
  String _expression = ""; 
  String _result = "0";    
  final formatter = NumberFormat("#,###.###");

  void _btnPressed(String val) {
    setState(() {
      if (val == "C") {
        _expression = ""; _result = "0";
      } else if (val == "BS") {
        if (_expression.isNotEmpty) _expression = _expression.substring(0, _expression.length - 1);
      } else if (val == "=") {
        if (_result != "エラー" && _result != "...") _expression = _result.replaceAll(",", "");
      } else {
        if (_isOperator(val) && _expression.isNotEmpty && _isOperator(_expression[_expression.length - 1])) {
          _expression = _expression.substring(0, _expression.length - 1) + val;
        } else {
          _expression += val;
        }
      }
      _calculateRealTime();
    });
  }

  bool _isOperator(String char) => ["+", "-", "×", "÷", "%"].contains(char);

  void _calculateRealTime() {
    if (_expression.isEmpty) { _result = "0"; return; }
    try {
      String evalStr = _expression.replaceAll('×', '*').replaceAll('÷', '/');
      evalStr = evalStr.replaceAllMapped(RegExp(r'(\d+)%'), (match) => "(${match.group(1)}/100)");
      double calcResult = _evaluateExp(evalStr);
      if (calcResult.isInfinite || calcResult.isNaN) {
        _result = "エラー";
      } else {
        if (calcResult == calcResult.toInt()) {
          _result = NumberFormat("#,###").format(calcResult.toInt());
        } else {
          _result = NumberFormat("#,###.###").format(calcResult);
        }
      }
    } catch (e) {
      _result = "..."; 
    }
  }

  double _evaluateExp(String exp) {
    String cleanExp = exp;
    if (exp.isEmpty) return 0;
    if ("+-*/".contains(exp[exp.length - 1])) cleanExp = exp.substring(0, exp.length - 1);
    List<String> parts = _tokenize(cleanExp);
    if (parts.isEmpty) return 0;
    for (int i = 0; i < parts.length; i++) {
      if (parts[i] == "*" || parts[i] == "/") {
        double left = double.tryParse(parts[i-1]) ?? 0;
        double right = double.tryParse(parts[i+1]) ?? 1;
        double res = (parts[i] == "*") ? left * right : left / right;
        parts.replaceRange(i-1, i+2, [res.toString()]);
        i--;
      }
    }
    double total = double.tryParse(parts[0]) ?? 0;
    for (int i = 1; i < parts.length; i += 2) {
      double next = double.tryParse(parts[i+1]) ?? 0;
      if (parts[i] == "+") total += next;
      if (parts[i] == "-") total -= next;
    }
    return total;
  }

  List<String> _tokenize(String exp) {
    RegExp reg = RegExp(r'(\d+\.?\d*)|([\+\-\*/])');
    return reg.allMatches(exp).map((m) => m.group(0)!).toList();
  }

  @override
  Widget build(BuildContext context) {
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("たくぽち", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey[800],
        elevation: 0,
        toolbarHeight: isLandscape ? 40 : 56, // 横向きはバーも少し細くしてスペースを確保
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500), 
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end, // 全体を下に寄せる
            children: [
              // 1. 表示エリア（さらに高さを削ってキーボードに譲る）
              Expanded(
                flex: isLandscape ? 2 : 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  alignment: Alignment.bottomRight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Text(_expression, style: const TextStyle(fontSize: 30, color: Colors.black54)),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(_result, style: TextStyle(fontSize: 65, fontWeight: FontWeight.bold, color: Colors.blueGrey[900])),
                      ),
                    ],
                  ),
                ),
              ),
              // 2. ボタンエリア（横向き時に大きく表示）
              Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, isLandscape ? 10 : 20),
                child: _buildGrid(isLandscape),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(bool isLandscape) {
    final List<List<String>> grid = [
      ["C", "BS", "%", "÷"],
      ["7", "8", "9", "×"],
      ["4", "5", "6", "-"],
      ["1", "2", "3", "+"],
      ["0", "00", ".", "="],
    ];

    return GridView.builder(
      shrinkWrap: true, // 高さを中身に合わせる
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        // 横向きは1.6にすることで、ボタンをさらに縦に大きく
        childAspectRatio: isLandscape ? 1.6 : 1.15, 
        mainAxisSpacing: 8,
        crossAxisSpacing: 10,
      ),
      itemCount: 20,
      itemBuilder: (context, index) {
        String label = grid[index ~/ 4][index % 4];
        return _buildTouchButton(label);
      },
    );
  }

  Widget _buildTouchButton(String label) {
    bool isOp = _isOperator(label) || label == "=";
    bool isAction = ["C", "BS", "%"].contains(label);

    Color bgColor = Colors.white;
    Color textColor = Colors.black87;

    if (isAction) {
      bgColor = Colors.cyan[50]!;
      textColor = Colors.cyan[900]!;
    } else if (isOp) {
      bgColor = Colors.blue[600]!;
      textColor = Colors.white;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _btnPressed(label),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 2, offset: const Offset(0, 2)),
          ],
        ),
        child: Center(
          child: Text(label, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
